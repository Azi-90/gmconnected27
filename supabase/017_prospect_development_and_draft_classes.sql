-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Wires up two things that were previously just described in the UI copy but
-- never actually implemented:
--
-- 1. Prospect development: every advance_season(), a drafted-and-signed
--    prospect rolls one of four outcomes (60% expected / 20% breakout / 15%
--    slow / 5% bust) that nudges their overall toward their projected NHL
--    potential range, for up to 4 seasons after being drafted.
-- 2. Procedural draft classes: the 2027 class is real Elite Prospects data.
--    Once the site advances past it, advance_season() auto-generates the next
--    class (rank-tapered ratings, weighted position/nationality mix) so the
--    draft never runs out of prospects.

-- Note: draft_prospects.proj_low/proj_high is a PROJECTED DRAFT POSITION range
-- (e.g. 1-4 means "expected to go 1st-to-4th overall"), not a rating — so it
-- can't be reused as a development ceiling. dev_ceiling below is a real rating
-- ceiling derived from ovr_high + a bonus for the prospect's potential tier.
alter table players add column if not exists dev_ceiling int;
alter table players add column if not exists dev_years_left int;

create or replace function draft_prospect(p_prospect_id uuid, p_team_id text)
returns void
language plpgsql
security definer
as $$
declare
  pr draft_prospects;
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
    new_player_id, p_team_id, pr.name, 0,
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

create or replace function generate_draft_class(p_draft_year int)
returns void
language plpgsql
security definer
as $$
declare
  first_names text[] := array['James','William','Alexander','Ethan','Lucas','Mason','Owen','Connor','Ryan','Jack','Noah','Carter','Tyler','Cole','Brayden','Liam','Nathan','Blake','Dylan','Hunter','Elias','Viktor','Erik','Filip','Oskar','Nikolaj','Anton','Mikael','Jakub','Adam','Marcus','Simon','Gustav','Emil','Axel','Leo','Felix','Max','Otto','Henrik'];
  last_names text[] := array['Andersson','Nilsson','Karlsson','Johansson','Svensson','Bergstrom','Lindgren','Nystrom','Novak','Dvorak','Kovar','Kowalski','MacDonald','Campbell','Fraser','Wilson','Miller','Cooper','Bennett','Reid','Sinclair','Chartrand','Belanger','Girard','Tremblay','Roy','Petrov','Smirnov','Volkov','Orlov','Makarov','Larsson','Eriksson','Gustafsson','Hallberg','Sandstrom','Holm','Berg','Lindqvist','Ahonen'];
  heights text[] := array['5''9"','5''10"','5''11"','6''0"','6''1"','6''2"','6''3"','6''4"'];
  clubs text[] := array['North Stars','Ice Wolves','River Kings','Thunderbirds','Steel City','Harbor City','Lakeside Prep','Northern Lights','Royal Oaks','Frontier','Summit','Blue Line Academy','Rapids','Union','Capital City','Bay Area','Valley','Metro'];
  rnk int;
  pos text;
  nat text;
  ovr_lo int;
  ovr_hi int;
  proj_lo int;
  proj_hi int;
  pot text;
  ready text;
  r numeric;
  nr numeric;
begin
  for rnk in 1..40 loop
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

    ovr_lo := round(84 - (rnk - 1) * 0.35)::int;
    ovr_hi := ovr_lo + 4 + floor(random() * 3)::int;
    -- proj_low/proj_high is a projected DRAFT POSITION range (matches the real
    -- 2027 seed data's convention, e.g. rank 1 -> "1-4"), not a rating.
    proj_lo := greatest(1, rnk - 3);
    proj_hi := rnk + 3 + round(rnk * 0.6)::int + floor(random() * 4)::int;

    pot := case
      when pos = 'D' then case when rnk <= 3 then 'Elite' when rnk <= 12 then 'Top 4D' else 'Bottom Pair' end
      when pos = 'G' then case when rnk <= 3 then 'Elite' else 'Starter' end
      else case when rnk <= 5 then 'Elite' when rnk <= 15 then 'Top 6' else 'Middle 6' end
    end;

    ready := case
      when rnk <= 8 and random() < 0.5 then 'NHL Ready'
      when rnk <= 20 then '1 Year Away'
      else case when random() < 0.5 then '1 Year Away' else '2 Years Away' end
    end;

    insert into draft_prospects (
      draft_year, rank, name, position, height, weight, nationality, club, league,
      ovr_low, ovr_high, potential, proj_low, proj_high, readiness
    ) values (
      p_draft_year, rnk,
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
      ovr_lo, ovr_hi, pot, proj_lo, proj_hi, ready
    );
  end loop;
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

  -- Prospect development: roll the 60/20/15/5 curve for anyone still developing.
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

  if not exists (select 1 from draft_prospects where draft_year = new_draft_year) then
    perform generate_draft_class(new_draft_year);
  end if;
end;
$$;
