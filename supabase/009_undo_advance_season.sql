-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Safety net: advance_season() now takes a full snapshot of players/free_agents/
-- league_state right before it makes any changes, and undo_last_advance_season()
-- restores from that snapshot. This is a single-level undo (restores the most
-- recent snapshot, then deletes it) — good enough to safely try Advance Season
-- without risking real data, not a full history stack.

create table if not exists season_snapshots (
  id uuid primary key default gen_random_uuid(),
  season text not null,
  created_at timestamptz not null default now(),
  players_json jsonb not null,
  free_agents_json jsonb not null,
  league_state_json jsonb not null
);

alter table season_snapshots enable row level security;
create policy "only commissioners can see season snapshots" on season_snapshots for select using (is_commissioner());
create policy "only commissioners can manage season snapshots" on season_snapshots for all using (is_commissioner()) with check (is_commissioner());

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

  select season into old_season from league_state where id = true;
  old_start_year := split_part(old_season, '-', 1)::int;
  new_season := (old_start_year + 1) || '-' || lpad(((old_start_year + 2) % 100)::text, 2, '0');

  insert into season_snapshots (season, players_json, free_agents_json, league_state_json)
  select
    old_season,
    coalesce((select jsonb_agg(p) from players p), '[]'::jsonb),
    coalesce((select jsonb_agg(f) from free_agents f), '[]'::jsonb),
    coalesce((select jsonb_agg(l) from league_state l), '[]'::jsonb);

  insert into free_agents (id, name, position, age, last_team_id, last_cap_hit, status)
  select
    'fa-' || p.id,
    p.name,
    p.position,
    greatest(extract(year from now())::int - (regexp_match(p.born, '\d{4}'))[1]::int, 18),
    p.team_id,
    p.cap_hit,
    case when p.status like 'RFA%' then 'RFA' else 'UFA' end
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

create or replace function undo_last_advance_season()
returns void
language plpgsql
security definer
as $$
declare
  snap season_snapshots;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can undo';
  end if;

  select * into snap from season_snapshots order by created_at desc limit 1;
  if snap is null then
    raise exception 'No advance-season snapshot to restore';
  end if;

  delete from players;
  insert into players select * from jsonb_populate_recordset(null::players, snap.players_json);

  delete from free_agents;
  insert into free_agents select * from jsonb_populate_recordset(null::free_agents, snap.free_agents_json);

  delete from league_state;
  insert into league_state select * from jsonb_populate_recordset(null::league_state, snap.league_state_json);

  delete from season_snapshots where id = snap.id;
end;
$$;
