-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Generalizes the season-advance-only undo into a single safety net covering
-- every commissioner action: advancing the season, drawing the lottery, and each
-- individual draft pick. Every one of those now snapshots all five affected
-- tables first, and there's one "undo_last_action()" that restores the most
-- recent snapshot no matter which action created it. Still single-level (undoes
-- the most recent action only, then deletes that snapshot), not a full history.

drop table if exists season_snapshots;
create table action_snapshots (
  id uuid primary key default gen_random_uuid(),
  action text not null,
  created_at timestamptz not null default now(),
  players_json jsonb not null,
  free_agents_json jsonb not null,
  league_state_json jsonb not null,
  draft_prospects_json jsonb not null,
  draft_lottery_results_json jsonb not null
);

alter table action_snapshots enable row level security;
create policy "only commissioners can see action snapshots" on action_snapshots for select using (is_commissioner());
create policy "only commissioners can manage action snapshots" on action_snapshots for all using (is_commissioner()) with check (is_commissioner());

create or replace function take_action_snapshot(p_action text)
returns void
language plpgsql
security definer
as $$
begin
  insert into action_snapshots (
    action, players_json, free_agents_json, league_state_json,
    draft_prospects_json, draft_lottery_results_json
  )
  select
    p_action,
    coalesce((select jsonb_agg(p) from players p), '[]'::jsonb),
    coalesce((select jsonb_agg(f) from free_agents f), '[]'::jsonb),
    coalesce((select jsonb_agg(l) from league_state l), '[]'::jsonb),
    coalesce((select jsonb_agg(d) from draft_prospects d), '[]'::jsonb),
    coalesce((select jsonb_agg(r) from draft_lottery_results r), '[]'::jsonb);
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
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can advance the season';
  end if;

  perform take_action_snapshot('advance_season');

  select season into old_season from league_state where id = true;
  old_start_year := split_part(old_season, '-', 1)::int;
  new_season := (old_start_year + 1) || '-' || lpad(((old_start_year + 2) % 100)::text, 2, '0');

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

create or replace function run_draft_lottery()
returns void
language plpgsql
security definer
as $$
declare
  cur_season text;
  draft_yr int;
  order_arr text[];
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can run the draft lottery';
  end if;

  perform take_action_snapshot('run_draft_lottery');

  select season, draft_class_year into cur_season, draft_yr from league_state where id = true;

  with ranked as (
    select t.id,
           coalesce(s.wins * 2 + s.ot_losses, 0) as pts,
           rank() over (order by coalesce(s.wins * 2 + s.ot_losses, 0) asc) as rnk
    from league_teams t
    left join standings s on s.team_id = t.id and s.season = cur_season
  ),
  balls as (
    select id from ranked, generate_series(1, (33 - rnk)::int)
  ),
  shuffled as (
    select id, row_number() over (order by random()) as rn from balls
  ),
  first_seen as (
    select id, min(rn) as first_rn from shuffled group by id
  )
  select array_agg(id order by first_rn) into order_arr from first_seen;

  insert into draft_lottery_results (draft_year, draft_order)
  values (draft_yr, to_jsonb(order_arr))
  on conflict (draft_year) do update set draft_order = excluded.draft_order, drawn_at = now();
end;
$$;

create or replace function draft_prospect(p_prospect_id uuid, p_team_id text)
returns void
language plpgsql
security definer
as $$
declare
  pr draft_prospects;
  rand_ovr int;
  new_player_id text;
  cur_season text;
  start_year int;
  expiry text;
  picked_count int;
  team_count int;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can execute draft picks';
  end if;

  select * into pr from draft_prospects where id = p_prospect_id and drafted_by_team_id is null;
  if pr is null then
    raise exception 'Prospect not found or already drafted';
  end if;

  perform take_action_snapshot('draft_prospect');

  update draft_prospects set drafted_by_team_id = p_team_id, drafted_at = now() where id = p_prospect_id;

  select season into cur_season from league_state where id = true;
  start_year := split_part(cur_season, '-', 1)::int;
  expiry := (start_year + 3) || '-' || lpad(((start_year + 4) % 100)::text, 2, '0');
  rand_ovr := pr.ovr_low + floor(random() * (pr.ovr_high - pr.ovr_low + 1))::int;
  new_player_id := 'prospect-' || replace(p_prospect_id::text, '-', '');

  insert into players (
    id, team_id, name, number, position, shoots, height, weight, born, birthplace,
    contract_type, cap_hit, salary, signing_bonus, total_value, clause, term_years, expiry_year, status, overall
  ) values (
    new_player_id, p_team_id, pr.name, 0,
    case when pr.position in ('C', 'LW', 'RW', 'D', 'G') then pr.position else 'C' end,
    'L', pr.height, pr.weight,
    'January 1, ' || (pr.draft_year - 18)::text,
    pr.nationality,
    'Entry-Level Contract', 900000, 850000, 0, 2700000, '—', 3, expiry, 'RFA', rand_ovr
  );

  select count(*) into picked_count from draft_prospects where draft_year = pr.draft_year and drafted_by_team_id is not null;
  select count(*) into team_count from league_teams;

  if picked_count >= team_count then
    insert into free_agents (id, name, position, age, last_team_id, last_cap_hit, status)
    select
      'fa-prospect-' || replace(dp.id::text, '-', ''),
      dp.name,
      case when dp.position in ('C', 'LW', 'RW', 'D', 'G') then dp.position else 'C' end,
      extract(year from now())::int - (dp.draft_year - 18),
      null,
      0,
      'UFA'
    from draft_prospects dp
    where dp.draft_year = pr.draft_year and dp.drafted_by_team_id is null
    on conflict (id) do nothing;

    delete from draft_prospects where draft_year = pr.draft_year and drafted_by_team_id is null;
  end if;
end;
$$;
