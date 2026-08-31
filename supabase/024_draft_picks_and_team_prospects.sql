-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Two additions:
-- 1. Draft picks become real, tradeable assets. Previously "who's on the
--    clock" was just read off a plain array of team ids in
--    draft_lottery_results — there was no persistent notion of "Team X's
--    2028 pick" you could hand to someone else in a trade. Now every team
--    gets one draft_picks row per draft year (original_team_id fixed,
--    current_owner_team_id changes when traded); the lottery sets each
--    ORIGINAL team's pick_number from standings, and whoever currently OWNS
--    that pick_number is who's actually on the clock.
-- 2. team_prospects: a small organizational pipeline of 5 prospects per team,
--    separate from the shared draft class board — just a roster of names to
--    track, not wired into contract signing (that's a natural next step if
--    you want it later).

create table if not exists draft_picks (
  id uuid primary key default gen_random_uuid(),
  draft_year int not null,
  original_team_id text not null references league_teams(id),
  current_owner_team_id text not null references league_teams(id),
  pick_number int,
  used boolean not null default false,
  unique (draft_year, original_team_id)
);

alter table draft_picks enable row level security;
create policy "draft picks are publicly readable" on draft_picks for select using (true);
create policy "only commissioners modify draft picks directly" on draft_picks for all using (is_commissioner()) with check (is_commissioner());

-- Backfill: one pick per team for every draft year that already exists.
insert into draft_picks (draft_year, original_team_id, current_owner_team_id)
select dy.draft_year, t.id, t.id
from (select distinct draft_year from draft_prospects) dy
cross join league_teams t
on conflict (draft_year, original_team_id) do nothing;

-- Backfill pick_number from any lottery that's already been drawn.
update draft_picks dp
set pick_number = o.pos
from draft_lottery_results r,
     jsonb_array_elements_text(r.draft_order) with ordinality as o(team_id, pos)
where dp.draft_year = r.draft_year and dp.original_team_id = o.team_id;

-- Backfill used = true for picks already exercised (pre-trade, so
-- original = owner is a safe assumption for this one-time backfill).
update draft_picks dp
set used = true
where exists (
  select 1 from draft_prospects p
  where p.draft_year = dp.draft_year and p.drafted_by_team_id = dp.original_team_id
);

alter table action_snapshots add column if not exists draft_picks_json jsonb not null default '[]'::jsonb;

create or replace function take_action_snapshot(p_action text)
returns void
language plpgsql
security definer
as $$
begin
  insert into action_snapshots (
    action, players_json, free_agents_json, league_state_json,
    draft_prospects_json, draft_lottery_results_json, trades_json, free_agent_offers_json,
    progression_log_json, news_articles_json, draft_picks_json
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
    coalesce((select jsonb_agg(k) from draft_picks k), '[]'::jsonb);
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

  delete from action_snapshots where id = snap.id;
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

  insert into draft_picks (draft_year, original_team_id, current_owner_team_id)
  select draft_yr, id, id from league_teams
  on conflict (draft_year, original_team_id) do nothing;

  update draft_picks dp
  set pick_number = o.pos
  from unnest(order_arr) with ordinality as o(team_id, pos)
  where dp.draft_year = draft_yr and dp.original_team_id = o.team_id;
end;
$$;

create or replace function draft_prospect(p_prospect_id uuid, p_pick_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  pr draft_prospects;
  pick draft_picks;
  rand_ovr int;
  tier_bonus int;
  ceiling int;
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

  select * into pick from draft_picks where id = p_pick_id and used = false;
  if pick is null then
    raise exception 'Pick not found or already used';
  end if;

  select * into pr from draft_prospects where id = p_prospect_id and draft_year = pick.draft_year and drafted_by_team_id is null;
  if pr is null then
    raise exception 'Prospect not found, already drafted, or from the wrong draft year';
  end if;

  perform take_action_snapshot('draft_prospect');

  update draft_prospects set drafted_by_team_id = pick.current_owner_team_id, drafted_at = now() where id = p_prospect_id;
  update draft_picks set used = true where id = p_pick_id;

  select season into cur_season from league_state where id = true;
  start_year := split_part(cur_season, '-', 1)::int;
  expiry := (start_year + 3) || '-' || lpad(((start_year + 4) % 100)::text, 2, '0');
  rand_ovr := pr.ovr_low + floor(random() * (pr.ovr_high - pr.ovr_low + 1))::int;
  new_player_id := 'prospect-' || replace(p_prospect_id::text, '-', '');

  tier_bonus := case pr.potential
    when 'Elite' then 8
    when 'Top 6' then 6
    when 'Top 4D' then 6
    when 'Starter' then 5
    when 'Middle 6' then 4
    when 'Bottom Pair' then 3
    else 4
  end;
  ceiling := pr.ovr_high + tier_bonus;

  insert into players (
    id, team_id, name, number, position, shoots, height, weight, born, birthplace,
    contract_type, cap_hit, salary, signing_bonus, total_value, clause, term_years, expiry_year, status, overall,
    dev_ceiling, dev_years_left
  ) values (
    new_player_id, pick.current_owner_team_id, pr.name, 0,
    case when pr.position in ('C', 'LW', 'RW', 'D', 'G') then pr.position else 'C' end,
    'L', pr.height, pr.weight,
    'January 1, ' || (pr.draft_year - 18)::text,
    pr.nationality,
    'Entry-Level Contract', 900000, 850000, 0, 2700000, '—', 3, expiry, 'RFA', rand_ovr,
    ceiling, 4
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

-- Extends trade execution to move draft picks, not just players. Each asset
-- in the jsonb array now has a "type" field ('player' or 'pick').
create or replace function execute_trade_on_approval()
returns trigger
language plpgsql
security definer
as $$
declare
  asset jsonb;
begin
  if new.status = 'gm_approved' and old.status <> 'pending' then
    raise exception 'A trade can only move to gm_approved from pending';
  end if;

  if new.status = 'approved' then
    if old.status <> 'gm_approved' then
      raise exception 'The receiving GM must approve before the commissioner can finalize this trade';
    end if;
    if not is_commissioner() then
      raise exception 'Only the commissioner can give final approval';
    end if;

    perform take_action_snapshot('approve_trade');

    for asset in select * from jsonb_array_elements(new.assets_from_team) loop
      if asset->>'type' = 'pick' then
        update draft_picks set current_owner_team_id = new.to_team_id
        where id = (asset->>'pickId')::uuid and current_owner_team_id = new.from_team_id and used = false;
      else
        update players set team_id = new.to_team_id where id = asset->>'playerId';
      end if;
    end loop;
    for asset in select * from jsonb_array_elements(new.assets_to_team) loop
      if asset->>'type' = 'pick' then
        update draft_picks set current_owner_team_id = new.from_team_id
        where id = (asset->>'pickId')::uuid and current_owner_team_id = new.to_team_id and used = false;
      else
        update players set team_id = new.from_team_id where id = asset->>'playerId';
      end if;
    end loop;
  end if;

  return new;
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
end;
$$;

create table if not exists team_prospects (
  id uuid primary key default gen_random_uuid(),
  team_id text not null references league_teams(id),
  name text not null,
  position text not null,
  height text not null,
  weight int not null,
  nationality text not null,
  club text not null,
  league text not null,
  potential text not null,
  ovr_low int not null,
  ovr_high int not null,
  readiness text not null,
  created_at timestamptz not null default now()
);

alter table team_prospects enable row level security;
create policy "team prospects are publicly readable" on team_prospects for select using (true);
create policy "only commissioners modify team prospects for now" on team_prospects for all using (is_commissioner()) with check (is_commissioner());

create or replace function seed_team_prospects()
returns void
language plpgsql
security definer
as $$
declare
  first_names text[] := array['James','William','Alexander','Ethan','Lucas','Mason','Owen','Connor','Ryan','Jack','Noah','Carter','Tyler','Cole','Brayden','Liam','Nathan','Blake','Dylan','Hunter','Elias','Viktor','Erik','Filip','Oskar','Nikolaj','Anton','Mikael','Jakub','Adam','Marcus','Simon','Gustav','Emil','Axel','Leo','Felix','Max','Otto','Henrik'];
  last_names text[] := array['Andersson','Nilsson','Karlsson','Johansson','Svensson','Bergstrom','Lindgren','Nystrom','Novak','Dvorak','Kovar','Kowalski','MacDonald','Campbell','Fraser','Wilson','Miller','Cooper','Bennett','Reid','Sinclair','Chartrand','Belanger','Girard','Tremblay','Roy','Petrov','Smirnov','Volkov','Orlov','Makarov','Larsson','Eriksson','Gustafsson','Hallberg','Sandstrom','Holm','Berg','Lindqvist','Ahonen'];
  heights text[] := array['5''9"','5''10"','5''11"','6''0"','6''1"','6''2"','6''3"','6''4"'];
  clubs text[] := array['North Stars','Ice Wolves','River Kings','Thunderbirds','Steel City','Harbor City','Lakeside Prep','Northern Lights','Royal Oaks','Frontier','Summit','Blue Line Academy','Rapids','Union','Capital City','Bay Area','Valley','Metro'];
  team_row league_teams;
  pos text;
  nat text;
  ovr_lo int;
  ovr_hi int;
  pot text;
  ready text;
  r numeric;
  nr numeric;
  pr numeric;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can seed team prospects';
  end if;

  for team_row in select * from league_teams loop
    if (select count(*) from team_prospects where team_id = team_row.id) >= 5 then
      continue;
    end if;

    for i in 1..5 loop
      r := random();
      pos := case
        when r < 0.20 then 'C' when r < 0.35 then 'LW' when r < 0.50 then 'RW'
        when r < 0.85 then 'D' else 'G'
      end;

      nr := random();
      nat := case
        when nr < 0.40 then 'Canada' when nr < 0.65 then 'USA' when nr < 0.75 then 'Sweden'
        when nr < 0.83 then 'Finland' when nr < 0.90 then 'Czechia' else 'Russia'
      end;

      pr := random();
      pot := case
        when pos = 'D' then case when pr < 0.15 then 'Top 4D' else 'Bottom Pair' end
        when pos = 'G' then 'Starter'
        else case when pr < 0.15 then 'Top 6' else 'Middle 6' end
      end;

      ovr_lo := 60 + floor(random() * 12)::int;
      ovr_hi := ovr_lo + 4 + floor(random() * 4)::int;
      ready := (array['1 Year Away', '2 Years Away'])[1 + floor(random() * 2)::int];

      insert into team_prospects (
        team_id, name, position, height, weight, nationality, club, league,
        potential, ovr_low, ovr_high, readiness
      ) values (
        team_row.id,
        first_names[1 + floor(random() * array_length(first_names, 1))::int] || ' ' ||
          last_names[1 + floor(random() * array_length(last_names, 1))::int],
        pos,
        heights[1 + floor(random() * array_length(heights, 1))::int],
        160 + floor(random() * 65)::int,
        nat,
        clubs[1 + floor(random() * array_length(clubs, 1))::int],
        case nat
          when 'Canada' then (array['OHL', 'WHL', 'QMJHL'])[1 + floor(random() * 3)::int]
          when 'USA' then (array['USHL', 'NCAA'])[1 + floor(random() * 2)::int]
          when 'Sweden' then 'SHL'
          when 'Finland' then 'Liiga'
          when 'Czechia' then 'Extraliga'
          else 'MHL'
        end,
        pot, ovr_lo, ovr_hi, ready
      );
    end loop;
  end loop;
end;
$$;
