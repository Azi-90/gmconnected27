-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Retirement, announced a full season ahead of time. Every advance_season():
-- 1. Anyone who announced retirement LAST season actually retires now
--    (removed from the league entirely, not sent to free agency).
-- 2. Remaining players roll age-based odds; a hit flags them as retiring at
--    the end of THIS season, visible immediately on their roster card.
--
-- Odds are purely age-based since veterans don't have overalls yet:
--   32-34: 3%   35-37: 10%   38-39: 25%   40+: 45%   under 32: never.

alter table players add column if not exists retirement_announced_season text;

create table if not exists retirement_log (
  id uuid primary key default gen_random_uuid(),
  season text not null,
  team_id text not null references league_teams(id),
  player_id text not null,
  player_name text not null,
  position text not null,
  age int not null,
  created_at timestamptz not null default now()
);

alter table retirement_log enable row level security;
create policy "retirement log is publicly readable" on retirement_log for select using (true);
create policy "only commissioners write the retirement log" on retirement_log for all using (is_commissioner()) with check (is_commissioner());

alter table action_snapshots add column if not exists retirement_log_json jsonb not null default '[]'::jsonb;

create or replace function take_action_snapshot(p_action text)
returns void
language plpgsql
security definer
as $$
begin
  insert into action_snapshots (
    action, players_json, free_agents_json, league_state_json,
    draft_prospects_json, draft_lottery_results_json, trades_json, free_agent_offers_json,
    progression_log_json, news_articles_json, draft_picks_json, retirement_log_json
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
    coalesce((select jsonb_agg(e) from retirement_log e), '[]'::jsonb);
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

  delete from action_snapshots where id = snap.id;
end;
$$;

create or replace function advance_season()
returns void
language plpgsql
security definer
as $$
declare
  old_season text;
  old_start_year int;
  new_season text;
  old_draft_year int;
  new_draft_year int;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can advance the season';
  end if;

  perform take_action_snapshot('advance_season');

  select season, draft_class_year into old_season, old_draft_year from league_state where id = true;
  old_start_year := split_part(old_season, '-', 1)::int;
  new_season := (old_start_year + 1) || '-' || lpad(((old_start_year + 2) % 100)::text, 2, '0');
  new_draft_year := old_draft_year + 1;

  -- Retirements announced last season actually happen now.
  insert into retirement_log (season, team_id, player_id, player_name, position, age)
  select
    old_season, p.team_id, p.id, p.name, p.position,
    greatest(extract(year from now())::int - (regexp_match(p.born, '\d{4}'))[1]::int, 18)
  from players p
  where p.retirement_announced_season = old_season;

  delete from players where retirement_announced_season = old_season;

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

  update players p
  set
    overall = greatest(least(
      p.overall + case
        when r.roll < 0.60 then greatest(round((p.dev_ceiling - p.overall) * 0.4)::int, 1)
        when r.roll < 0.80 then greatest(round((p.dev_ceiling - p.overall) * 0.4)::int, 1) + 3
        when r.roll < 0.95 then 1
        else -2
      end,
      99), 40),
    dev_years_left = p.dev_years_left - 1
  from (select id, random() as roll from players where dev_ceiling is not null and dev_years_left > 0) r
  where p.id = r.id;

  update league_state
  set season = new_season, draft_class_year = new_draft_year
  where id = true;

  insert into draft_picks (draft_year, original_team_id, current_owner_team_id)
  select new_draft_year, id, id from league_teams
  on conflict (draft_year, original_team_id) do nothing;

  if not exists (select 1 from draft_prospects where draft_year = new_draft_year) then
    perform generate_draft_class(new_draft_year);
  end if;

  -- Announce new retirements for the season that just started.
  update players p
  set retirement_announced_season = new_season
  from (
    select id,
      greatest(extract(year from now())::int - (regexp_match(born, '\d{4}'))[1]::int, 18) as age,
      random() as roll
    from players
    where retirement_announced_season is null
  ) r
  where p.id = r.id
    and (
      (r.age >= 40 and r.roll < 0.45)
      or (r.age >= 38 and r.roll < 0.25)
      or (r.age >= 35 and r.roll < 0.10)
      or (r.age >= 32 and r.roll < 0.03)
    );
end;
$$;
