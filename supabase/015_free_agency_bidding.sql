-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Real free agency bidding: any GM (or the commissioner) can submit an offer
-- (AAV + term) to a free agent on behalf of their club. Offers are visible to
-- everyone, same as trades. The commissioner awards one offer, which signs the
-- player onto that roster, removes them from the free agent pool, and declines
-- every other pending offer for that same player. Covered by the same
-- single-level undo as trades and draft picks.

-- free_agents only ever carried the columns needed to list them; signing one
-- back onto a roster needs the same bio fields `players` requires. Nullable
-- because the free agents seeded before this migration don't have this data —
-- going forward, advance_season() below carries it over automatically.
alter table free_agents add column if not exists number int;
alter table free_agents add column if not exists shoots text;
alter table free_agents add column if not exists height text;
alter table free_agents add column if not exists weight int;
alter table free_agents add column if not exists born text;
alter table free_agents add column if not exists birthplace text;

create table if not exists free_agent_offers (
  id uuid primary key default gen_random_uuid(),
  free_agent_id text not null references free_agents(id),
  team_id text not null references league_teams(id),
  aav bigint not null check (aav > 0),
  term_years int not null check (term_years between 1 and 8),
  signing_bonus bigint not null default 0,
  status text not null default 'pending' check (status in ('pending', 'awarded', 'declined')),
  created_at timestamptz not null default now(),
  proposed_by uuid not null default auth.uid() references profiles(id)
);

alter table free_agent_offers enable row level security;

create policy "free agent offers are publicly readable" on free_agent_offers for select using (true);

create policy "a club's GM or the commissioner can submit an offer"
  on free_agent_offers for insert
  with check (
    is_commissioner()
    or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = team_id)
  );

create policy "only the commissioner awards or declines an offer"
  on free_agent_offers for update
  using (is_commissioner());

create policy "the proposer or the commissioner can withdraw a pending offer"
  on free_agent_offers for delete
  using (
    is_commissioner()
    or (status = 'pending' and exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = team_id))
  );

alter table action_snapshots add column if not exists free_agent_offers_json jsonb not null default '[]'::jsonb;

create or replace function take_action_snapshot(p_action text)
returns void
language plpgsql
security definer
as $$
begin
  insert into action_snapshots (
    action, players_json, free_agents_json, league_state_json,
    draft_prospects_json, draft_lottery_results_json, trades_json, free_agent_offers_json
  )
  select
    p_action,
    coalesce((select jsonb_agg(p) from players p), '[]'::jsonb),
    coalesce((select jsonb_agg(f) from free_agents f), '[]'::jsonb),
    coalesce((select jsonb_agg(l) from league_state l), '[]'::jsonb),
    coalesce((select jsonb_agg(d) from draft_prospects d), '[]'::jsonb),
    coalesce((select jsonb_agg(r) from draft_lottery_results r), '[]'::jsonb),
    coalesce((select jsonb_agg(t) from trades t), '[]'::jsonb),
    coalesce((select jsonb_agg(o) from free_agent_offers o), '[]'::jsonb);
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

  delete from trades where true;
  insert into trades select * from jsonb_populate_recordset(null::trades, snap.trades_json);

  delete from free_agent_offers where true;
  insert into free_agent_offers select * from jsonb_populate_recordset(null::free_agent_offers, snap.free_agent_offers_json);

  delete from action_snapshots where id = snap.id;
end;
$$;

-- Carries the extra bio columns forward too, so anyone signed via this path
-- has a full record if they later hit free agency again.
create or replace function advance_season()
returns void
language plpgsql
security definer
as $$
declare
  old_season text;
  old_start_year int;
  new_season text;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can advance the season';
  end if;

  perform take_action_snapshot('advance_season');

  select season into old_season from league_state where id = true;
  old_start_year := split_part(old_season, '-', 1)::int;
  new_season := (old_start_year + 1) || '-' || lpad(((old_start_year + 2) % 100)::text, 2, '0');

  insert into free_agents (
    id, name, position, age, last_team_id, last_cap_hit, status,
    number, shoots, height, weight, born, birthplace
  )
  select
    'fa-' || p.id,
    p.name,
    p.position,
    greatest(extract(year from now())::int - (regexp_match(p.born, '\d{4}'))[1]::int, 18),
    p.team_id,
    p.cap_hit,
    case when p.status like 'RFA%' then 'RFA' else 'UFA' end,
    p.number, p.shoots, p.height, p.weight, p.born, p.birthplace
  from players p
  where p.expiry_year = old_season
  on conflict (id) do nothing;

  delete from players where expiry_year = old_season;

  update players set term_years = greatest(term_years - 1, 0) where expiry_year <> old_season;

  update league_state
  set season = new_season, draft_class_year = draft_class_year + 1
  where id = true;
end;
$$;

-- Switched to BEFORE UPDATE for the same reason as trades: the snapshot has to
-- capture this offer (and the free agent pool) before the award takes effect.
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
    select * into fa from free_agents where id = new.free_agent_id;
    if fa is null then
      raise exception 'That free agent has already been signed';
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
      new.term_years, expiry, 'Signed', null
    );

    delete from free_agents where id = fa.id;

    update free_agent_offers
    set status = 'declined'
    where free_agent_id = new.free_agent_id and id <> new.id and status = 'pending';
  end if;
  return new;
end;
$$;

drop trigger if exists execute_free_agent_award_trigger on free_agent_offers;
create trigger execute_free_agent_award_trigger
  before update on free_agent_offers
  for each row execute function execute_free_agent_award();
