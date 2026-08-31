-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Rule-based re-signing v1 (the "AI for resigning/FAs" item is still waiting
-- on an Anthropic API key — this gives you a working extension flow today,
-- swappable for real AI later without touching the UI).
--
-- A team's GM (or the commissioner) offers their own rostered player an
-- extension (AAV + term). Since there's no personality/negotiation AI yet,
-- the outcome is decided by a simple age-based expected-value formula against
-- the player's CURRENT cap hit (their last contract is the fairest baseline
-- we have, since most players don't have an overall yet):
--   under 27: expects a 10% raise · 27-31: expects roughly market value
--   32-35: will take a modest discount · 36+: will take a real discount
-- Offer >= 95% of expected -> accepted. >= 80% -> countered (rejected, but
-- tells you what they'd actually take). Below that -> flatly rejected.
--
-- Also fixes a pre-existing bug: free agent signings were inserting
-- status = 'Signed', which isn't one of the real ContractStatus values the
-- UI knows how to badge — normalized to 'UFA'.

create table if not exists resign_log (
  id uuid primary key default gen_random_uuid(),
  player_id text not null,
  player_name text not null,
  team_id text not null references league_teams(id),
  offered_aav bigint not null,
  offered_term_years int not null,
  expected_aav bigint not null,
  outcome text not null check (outcome in ('accepted', 'countered', 'rejected')),
  created_at timestamptz not null default now()
);

alter table resign_log enable row level security;
create policy "resign log is publicly readable" on resign_log for select using (true);
create policy "only commissioners write the resign log directly" on resign_log for all using (is_commissioner()) with check (is_commissioner());

alter table action_snapshots add column if not exists resign_log_json jsonb not null default '[]'::jsonb;

create or replace function take_action_snapshot(p_action text)
returns void
language plpgsql
security definer
as $$
begin
  insert into action_snapshots (
    action, players_json, free_agents_json, league_state_json,
    draft_prospects_json, draft_lottery_results_json, trades_json, free_agent_offers_json,
    progression_log_json, news_articles_json, draft_picks_json, retirement_log_json, resign_log_json
  )
  select
    p_action,
    coalesce((select jsonb_agg(p) from players p), '[]'::jsonb),
    coalesce((select jsonb_agg(f) from free_agents f), '[]'::jsonb),
    coalesce((select jsonb_agg(l) from league_state l), '[]'::jsonb),
    coalesce((select jsonb_agg(d) from draft_prospects d), '[]'::jsonb),
    coalesce((select jsonb_agg(r) from draft_lottery_results r), '[]'::jsonb),
    coalesce((select jsonb_agg(t) from trades t), '[]'::jsonb),
    coalesce((select jsonb_agg(o) from free_agent_offers o), '[]'::jsonb),
    coalesce((select jsonb_agg(g) from progression_log g), '[]'::jsonb),
    coalesce((select jsonb_agg(n) from news_articles n), '[]'::jsonb),
    coalesce((select jsonb_agg(k) from draft_picks k), '[]'::jsonb),
    coalesce((select jsonb_agg(e) from retirement_log e), '[]'::jsonb),
    coalesce((select jsonb_agg(s) from resign_log s), '[]'::jsonb);
end;
$$;

create or replace function undo_last_action()
returns void
language plpgsql
security definer
as $$
declare
  snap action_snapshots;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can undo';
  end if;

  select * into snap from action_snapshots order by created_at desc limit 1;
  if snap is null then
    raise exception 'Nothing to undo';
  end if;

  delete from free_agent_offers where true;

  delete from players where true;
  insert into players select * from jsonb_populate_recordset(null::players, snap.players_json);

  delete from free_agents where true;
  insert into free_agents select * from jsonb_populate_recordset(null::free_agents, snap.free_agents_json);

  delete from league_state where true;
  insert into league_state select * from jsonb_populate_recordset(null::league_state, snap.league_state_json);

  delete from draft_prospects where true;
  insert into draft_prospects select * from jsonb_populate_recordset(null::draft_prospects, snap.draft_prospects_json);

  delete from draft_lottery_results where true;
  insert into draft_lottery_results select * from jsonb_populate_recordset(null::draft_lottery_results, snap.draft_lottery_results_json);

  delete from draft_picks where true;
  insert into draft_picks select * from jsonb_populate_recordset(null::draft_picks, snap.draft_picks_json);

  delete from trades where true;
  insert into trades select * from jsonb_populate_recordset(null::trades, snap.trades_json);

  insert into free_agent_offers select * from jsonb_populate_recordset(null::free_agent_offers, snap.free_agent_offers_json);

  delete from progression_log where true;
  insert into progression_log select * from jsonb_populate_recordset(null::progression_log, snap.progression_log_json);

  delete from news_articles where true;
  insert into news_articles select * from jsonb_populate_recordset(null::news_articles, snap.news_articles_json);

  delete from retirement_log where true;
  insert into retirement_log select * from jsonb_populate_recordset(null::retirement_log, snap.retirement_log_json);

  delete from resign_log where true;
  insert into resign_log select * from jsonb_populate_recordset(null::resign_log, snap.resign_log_json);

  delete from action_snapshots where id = snap.id;
end;
$$;

create or replace function propose_resign(p_player_id text, p_aav bigint, p_term_years int)
returns jsonb
language plpgsql
security definer
as $$
declare
  p players;
  age int;
  age_mult numeric;
  expected_aav bigint;
  cur_season text;
  start_year int;
  expiry text;
  outcome text;
begin
  select * into p from players where id = p_player_id;
  if p is null then
    raise exception 'Player not found';
  end if;

  if not (
    is_commissioner()
    or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = p.team_id)
  ) then
    raise exception 'Only that club''s GM or the commissioner can propose a re-signing';
  end if;

  if p.retirement_announced_season is not null then
    raise exception 'This player plans to retire and cannot be re-signed';
  end if;

  if p_term_years < 1 or p_term_years > 8 then
    raise exception 'Term must be between 1 and 8 years';
  end if;

  if p_aav <= 0 then
    raise exception 'AAV must be positive';
  end if;

  age := greatest(extract(year from now())::int - (regexp_match(p.born, '\d{4}'))[1]::int, 18);

  age_mult := case
    when age < 27 then 1.10
    when age <= 31 then 1.00
    when age <= 35 then 0.92
    else 0.80
  end;

  expected_aav := round(p.cap_hit * age_mult);

  if p_aav >= round(expected_aav * 0.95) then
    outcome := 'accepted';
  elsif p_aav >= round(expected_aav * 0.80) then
    outcome := 'countered';
  else
    outcome := 'rejected';
  end if;

  if outcome = 'accepted' then
    perform take_action_snapshot('resign_player');

    select season into cur_season from league_state where id = true;
    start_year := split_part(cur_season, '-', 1)::int;
    expiry := (start_year + p_term_years) || '-' || lpad(((start_year + p_term_years + 1) % 100)::text, 2, '0');

    update players
    set cap_hit = p_aav, salary = p_aav, term_years = p_term_years, expiry_year = expiry,
        contract_type = 'Re-signed', signing_bonus = 0, total_value = p_aav * p_term_years
    where id = p_player_id;
  end if;

  insert into resign_log (player_id, player_name, team_id, offered_aav, offered_term_years, expected_aav, outcome)
  values (p_player_id, p.name, p.team_id, p_aav, p_term_years, expected_aav, outcome);

  return jsonb_build_object('outcome', outcome, 'expectedAav', expected_aav);
end;
$$;

update players set status = 'UFA' where status = 'Signed';

create or replace function execute_free_agent_award()
returns trigger
language plpgsql
security definer
as $$
declare
  fa free_agents;
  cur_season text;
  start_year int;
  expiry text;
  new_player_id text;
begin
  if new.status = 'awarded' and old.status is distinct from 'awarded' then
    select * into fa from free_agents where id = new.free_agent_id and signed_by_team_id is null;
    if fa is null then
      raise exception 'That free agent has already been signed';
    end if;

    if fa.status = 'RFA' and new.team_id <> fa.last_team_id and not fa.rfa_waived then
      raise exception 'This is a restricted free agent — the original team must waive their right of first refusal before an outside offer can be awarded';
    end if;

    perform take_action_snapshot('award_free_agent');

    select season into cur_season from league_state where id = true;
    start_year := split_part(cur_season, '-', 1)::int;
    expiry := (start_year + new.term_years) || '-' || lpad(((start_year + new.term_years + 1) % 100)::text, 2, '0');
    new_player_id := 'signed-' || replace(gen_random_uuid()::text, '-', '');

    insert into players (
      id, team_id, name, number, position, shoots, height, weight, born, birthplace,
      contract_type, cap_hit, salary, signing_bonus, total_value, clause, term_years, expiry_year, status, overall
    ) values (
      new_player_id, new.team_id, fa.name, coalesce(fa.number, 0), fa.position, coalesce(fa.shoots, 'L'),
      coalesce(fa.height, '—'), coalesce(fa.weight, 0), coalesce(fa.born, '—'), coalesce(fa.birthplace, '—'),
      'Standard Contract', new.aav, new.aav, new.signing_bonus, new.aav * new.term_years, '—',
      new.term_years, expiry, 'UFA', null
    );

    update free_agents set signed_by_team_id = new.team_id, signed_at = now() where id = fa.id;

    update free_agent_offers
    set status = 'declined'
    where free_agent_id = new.free_agent_id and id <> new.id and status = 'pending';
  end if;
  return new;
end;
$$;
