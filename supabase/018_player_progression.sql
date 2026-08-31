-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Stat-based progression for rostered players, from the formulas Derek supplied
-- (NHL 27 GM Connected can't edit overalls mid-season, so this produces the
-- report the commissioner manually mirrors in the game's Edit Player menu at
-- the season-reset checkpoint). The commissioner enters each player's season
-- box score totals, then runs progression once for the whole league.
--
-- This only ADJUSTS an overall that already exists — it never invents one for
-- a player who doesn't have one yet (real veteran overalls are still waiting
-- on actual NHL 27 data, per Derek's standing rule). Today that means it's
-- live for drafted-and-signed prospects; it'll cover everyone automatically
-- once real ratings are loaded in.

create table if not exists player_season_stats (
  player_id text not null,
  season text not null,
  games_played int not null default 0,
  goals int not null default 0,
  assists int not null default 0,
  shots int not null default 0,
  hits int not null default 0,
  blocks int not null default 0,
  takeaways int not null default 0,
  giveaways int not null default 0,
  faceoff_pct numeric,
  plus_minus int not null default 0,
  save_pct numeric,
  gaa numeric,
  wins int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (player_id, season)
);

alter table player_season_stats enable row level security;
create policy "player season stats are publicly readable" on player_season_stats for select using (true);
create policy "only commissioners enter player season stats" on player_season_stats for all using (is_commissioner()) with check (is_commissioner());

create table if not exists progression_log (
  id uuid primary key default gen_random_uuid(),
  season text not null,
  player_id text not null,
  player_name text not null,
  old_overall int not null,
  new_overall int not null,
  delta int not null,
  note text not null default '',
  created_at timestamptz not null default now()
);

alter table progression_log enable row level security;
create policy "progression log is publicly readable" on progression_log for select using (true);
create policy "only commissioners write the progression log" on progression_log for all using (is_commissioner()) with check (is_commissioner());

alter table action_snapshots add column if not exists progression_log_json jsonb not null default '[]'::jsonb;

create or replace function take_action_snapshot(p_action text)
returns void
language plpgsql
security definer
as $$
begin
  insert into action_snapshots (
    action, players_json, free_agents_json, league_state_json,
    draft_prospects_json, draft_lottery_results_json, trades_json, free_agent_offers_json,
    progression_log_json
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
    coalesce((select jsonb_agg(g) from progression_log g), '[]'::jsonb);
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

  delete from trades where true;
  insert into trades select * from jsonb_populate_recordset(null::trades, snap.trades_json);

  insert into free_agent_offers select * from jsonb_populate_recordset(null::free_agent_offers, snap.free_agent_offers_json);

  delete from progression_log where true;
  insert into progression_log select * from jsonb_populate_recordset(null::progression_log, snap.progression_log_json);

  delete from action_snapshots where id = snap.id;
end;
$$;

create or replace function apply_player_progression(p_season text)
returns void
language plpgsql
security definer
as $$
declare
  rec record;
  gp numeric;
  ppg numeric;
  ps numeric;
  expected numeric;
  delta int;
  age int;
  new_overall int;
  focus text;
  off_focus numeric;
  phys_focus numeric;
  def_focus numeric;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can apply progression';
  end if;

  perform take_action_snapshot('apply_progression');

  for rec in
    select s.*, p.position, p.overall, p.born, p.name
    from player_season_stats s
    join players p on p.id = s.player_id
    where s.season = p_season and s.games_played >= 10 and p.overall is not null
  loop
    gp := rec.games_played;
    ppg := (rec.goals + rec.assists)::numeric / gp;
    off_focus := ppg;
    phys_focus := rec.hits::numeric / gp;

    if rec.position = 'G' then
      ps := ((coalesce(rec.save_pct, 0.890) - 0.890) * 600)
        + ((2.85 - coalesce(rec.gaa, 2.85)) * 12)
        + (rec.wins::numeric / gp * 15);
      focus := 'Reflexes, Breakaway Save Ability, Positioning';
    elsif rec.position = 'D' then
      def_focus := rec.blocks::numeric / gp + rec.takeaways::numeric / gp;
      ps := (ppg * 35)
        + (rec.blocks::numeric / gp * 6)
        + (phys_focus * 3)
        + (rec.takeaways::numeric / gp * 4)
        - (rec.giveaways::numeric / gp * 3)
        + (rec.plus_minus::numeric / gp * 8);
      if def_focus >= off_focus and def_focus >= phys_focus then
        focus := 'Defensive Awareness, Stick Checking, Shot Blocking';
      elsif phys_focus >= off_focus then
        focus := 'Body Checking, Aggression, Balance';
      else
        focus := 'Passing, Offensive Awareness, Puck Control';
      end if;
    else
      ps := (ppg * 45)
        + (rec.shots::numeric / gp * 2)
        + (phys_focus * 2)
        + (rec.blocks::numeric / gp * 3)
        + (rec.takeaways::numeric / gp * 3)
        - (rec.giveaways::numeric / gp * 2.5)
        + ((coalesce(rec.faceoff_pct, 50) - 50) * 0.2);
      if off_focus >= phys_focus then
        if rec.goals >= rec.assists then
          focus := 'Wrist/Slap Shot Accuracy, Offensive Awareness';
        else
          focus := 'Passing, Puck Control, Offensive Awareness';
        end if;
      else
        focus := 'Body Checking, Aggression, Balance';
      end if;
    end if;

    expected := case
      when rec.overall >= 88 then 65
      when rec.overall >= 84 then 57
      when rec.overall >= 80 then 42
      else 25
    end;

    delta := round((ps - expected) / 15);

    age := extract(year from now())::int - coalesce((regexp_match(rec.born, '\d{4}'))[1]::int, extract(year from now())::int - 25);

    if age < 23 and delta > 0 then
      delta := delta + 1;
    elsif age >= 31 and delta < 0 then
      delta := round(delta * 1.2);
    end if;

    delta := greatest(least(delta, 3), -3);
    new_overall := greatest(least(rec.overall + delta, 99), 40);

    update players set overall = new_overall where id = rec.player_id;

    insert into progression_log (season, player_id, player_name, old_overall, new_overall, delta, note)
    values (p_season, rec.player_id, rec.name, rec.overall, new_overall, delta, focus);
  end loop;
end;
$$;
