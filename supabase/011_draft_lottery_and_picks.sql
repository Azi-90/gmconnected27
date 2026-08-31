-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Draft lottery (weighted by standings, worst record = best odds, like the real
-- thing) and the actual pick mechanic. The commissioner runs both — picks are
-- "announced" here and then executed in NHL 27, same as trades.

-- draft_lottery_results was originally keyed by season text; re-key it by
-- draft_year int to match draft_prospects.draft_year directly. Table is empty
-- so this is safe to recreate.
drop table if exists draft_lottery_results;
create table draft_lottery_results (
  draft_year int primary key,
  draft_order jsonb not null,
  drawn_at timestamptz not null default now()
);

alter table draft_lottery_results enable row level security;
create policy "draft lottery results are publicly readable" on draft_lottery_results for select using (true);
create policy "only commissioners can run the lottery" on draft_lottery_results for all using (is_commissioner()) with check (is_commissioner());

-- Weighted lottery: each team gets (33 - standings rank) "balls" (worst record = 32
-- balls, best = 1), all balls get shuffled, and the draft order is each team's
-- first appearance in the shuffle. Higher weight = more balls = more likely to
-- land early, without a manual weighted-sampling loop.
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

-- Executes one pick: assigns the prospect to the team as a new entry-level rookie,
-- and once the whole round is done, moves every prospect nobody picked into free
-- agency.
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
