-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Moves rosters/contracts/free agents/prospects from static app code into the
-- database, so they can actually be mutated (trades, signings, season advancement,
-- the draft) instead of being fixed at build time.

-- Small reusable helper — avoids repeating the same subquery in every policy below.
create or replace function is_commissioner()
returns boolean
language sql
stable
as $$
  select coalesce((select p.is_commissioner from profiles p where p.id = auth.uid()), false);
$$;

-- league_teams already exists (from 002_gm_verification.sql) with id/city/name/gm_name.
-- Extend it with the metadata that used to live only in src/data/teams.ts.
alter table league_teams add column if not exists abbr text;
alter table league_teams add column if not exists conference text;
alter table league_teams add column if not exists division text;
alter table league_teams add column if not exists color text;

update league_teams set
  abbr = id,
  conference = case when id in ('BOS','BUF','DET','FLA','MTL','OTT','TBL','TOR','CAR','CBJ','NJD','NYI','NYR','PHI','PIT','WSH') then 'Eastern' else 'Western' end,
  division = case
    when id in ('BOS','BUF','DET','FLA','MTL','OTT','TBL','TOR') then 'Atlantic'
    when id in ('CAR','CBJ','NJD','NYI','NYR','PHI','PIT','WSH') then 'Metropolitan'
    when id in ('CHI','COL','DAL','MIN','NSH','STL','UTA','WPG') then 'Central'
    else 'Pacific'
  end,
  color = case id
    when 'BOS' then '#FFB81C' when 'BUF' then '#003087' when 'DET' then '#CE1126' when 'FLA' then '#C8102E'
    when 'MTL' then '#AF1E2D' when 'OTT' then '#C41230' when 'TBL' then '#002868' when 'TOR' then '#00205B'
    when 'CAR' then '#CC0000' when 'CBJ' then '#002654' when 'NJD' then '#CE1126' when 'NYI' then '#00539B'
    when 'NYR' then '#0038A8' when 'PHI' then '#F74902' when 'PIT' then '#FCB514' when 'WSH' then '#C8102E'
    when 'CHI' then '#CF0A2C' when 'COL' then '#6F263D' when 'DAL' then '#006847' when 'MIN' then '#154734'
    when 'NSH' then '#FFB81C' when 'STL' then '#002F87' when 'UTA' then '#71AFE5' when 'WPG' then '#041E42'
    when 'ANA' then '#F47A38' when 'CGY' then '#C8102E' when 'EDM' then '#FF4C00' when 'LAK' then '#A2AAAD'
    when 'SJS' then '#006D75' when 'SEA' then '#99D9D9' when 'VAN' then '#00205B' when 'VGK' then '#B4975A'
  end
where abbr is null;

alter table league_teams alter column abbr set not null;
alter table league_teams alter column conference set not null;
alter table league_teams alter column division set not null;
alter table league_teams alter column color set not null;

-- Singleton row holding whole-league state.
create table if not exists league_state (
  id boolean primary key default true check (id),
  season text not null default '2026-27',
  salary_cap bigint not null default 104000000,
  phase text not null default 'season' check (phase in ('season', 'offseason', 'draft')),
  draft_class_year int not null default 2027
);
insert into league_state (id) values (true) on conflict do nothing;

alter table league_state enable row level security;
create policy "league state is publicly readable" on league_state for select using (true);
create policy "only commissioners can change league state" on league_state for update using (is_commissioner()) with check (is_commissioner());

-- Rostered players / contracts.
create table if not exists players (
  id text primary key,
  team_id text not null references league_teams(id),
  name text not null,
  number int not null,
  position text not null,
  shoots text not null,
  height text not null,
  weight int not null,
  born text not null,
  birthplace text not null,
  contract_type text not null,
  cap_hit bigint not null,
  salary bigint not null,
  signing_bonus bigint not null default 0,
  total_value bigint not null,
  clause text not null default '—',
  term_years int not null,
  expiry_year text not null,
  status text not null,
  overall int
);

alter table players enable row level security;
create policy "players are publicly readable" on players for select using (true);
create policy "only commissioners can modify players for now" on players for all using (is_commissioner()) with check (is_commissioner());

-- Unsigned players. Signing one = insert a row into `players` + delete the row here.
create table if not exists free_agents (
  id text primary key,
  name text not null,
  position text not null,
  age int not null,
  last_team_id text references league_teams(id),
  last_cap_hit bigint not null default 0,
  status text not null check (status in ('UFA', 'RFA'))
);

alter table free_agents enable row level security;
create policy "free agents are publicly readable" on free_agents for select using (true);
create policy "only commissioners can modify free agents for now" on free_agents for all using (is_commissioner()) with check (is_commissioner());

-- One draft class's worth of prospects. drafted_by_team_id/drafted_at get filled in on draft night.
create table if not exists draft_prospects (
  id uuid primary key default gen_random_uuid(),
  draft_year int not null,
  rank int not null,
  name text not null,
  position text not null,
  height text not null,
  weight int not null,
  nationality text not null,
  club text not null,
  league text not null,
  ovr_low int not null,
  ovr_high int not null,
  potential text not null,
  proj_low int not null,
  proj_high int not null,
  readiness text not null,
  drafted_by_team_id text references league_teams(id),
  drafted_at timestamptz
);

alter table draft_prospects enable row level security;
create policy "draft prospects are publicly readable" on draft_prospects for select using (true);
create policy "only commissioners can modify draft prospects for now" on draft_prospects for all using (is_commissioner()) with check (is_commissioner());

-- One row per team per season. The commissioner enters these from the actual games played in NHL 27.
create table if not exists standings (
  team_id text not null references league_teams(id),
  season text not null,
  wins int not null default 0,
  losses int not null default 0,
  ot_losses int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (team_id, season)
);

alter table standings enable row level security;
create policy "standings are publicly readable" on standings for select using (true);
create policy "only commissioners can enter standings" on standings for all using (is_commissioner()) with check (is_commissioner());

-- One row per season, storing the lottery-drawn draft order once the commissioner runs it.
create table if not exists draft_lottery_results (
  season text primary key,
  draft_order jsonb not null,
  drawn_at timestamptz not null default now()
);

alter table draft_lottery_results enable row level security;
create policy "draft lottery results are publicly readable" on draft_lottery_results for select using (true);
create policy "only commissioners can run the lottery" on draft_lottery_results for all using (is_commissioner()) with check (is_commissioner());
