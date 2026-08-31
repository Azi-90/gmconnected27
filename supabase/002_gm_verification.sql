-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Adds Discord-server-nickname verification so a GM can only claim the team
-- they were already assigned on the league roster.

alter table profiles add column if not exists guild_nickname text;

-- Mirrors the gmName assignments in src/data/teams.ts. This is the authoritative
-- list the claim policy checks against (kept in the database, not just the client,
-- so the check can't be bypassed by editing frontend code).
create table if not exists league_teams (
  id text primary key,
  city text not null,
  name text not null,
  gm_name text not null
);

alter table league_teams enable row level security;

create policy "league teams are publicly readable"
  on league_teams for select
  using (true);

insert into league_teams (id, city, name, gm_name) values
  ('BOS', 'Boston', 'Bruins', 'Ksteiding1'),
  ('BUF', 'Buffalo', 'Sabres', 'Sublime'),
  ('DET', 'Detroit', 'Red Wings', 'Zink'),
  ('FLA', 'Florida', 'Panthers', 'Timebot12'),
  ('MTL', 'Montréal', 'Canadiens', 'Hopsin56'),
  ('OTT', 'Ottawa', 'Senators', 'KG3'),
  ('TBL', 'Tampa Bay', 'Lightning', 'Chuggernaut'),
  ('TOR', 'Toronto', 'Maple Leafs', 'Omarsaeed26'),
  ('CAR', 'Carolina', 'Hurricanes', 'Jechten'),
  ('CBJ', 'Columbus', 'Blue Jackets', 'CalHockey'),
  ('NJD', 'New Jersey', 'Devils', 'Jay'),
  ('NYI', 'New York', 'Islanders', 'mstith_'),
  ('NYR', 'New York', 'Rangers', 'Taufer'),
  ('PHI', 'Philadelphia', 'Flyers', 'Sycesg'),
  ('PIT', 'Pittsburgh', 'Penguins', 'D*Rock'),
  ('WSH', 'Washington', 'Capitals', 'Maniac'),
  ('CHI', 'Chicago', 'Blackhawks', 'GrecoISU'),
  ('COL', 'Colorado', 'Avalanche', 'SnipingPilot'),
  ('DAL', 'Dallas', 'Stars', 'Dr. Rockzo'),
  ('MIN', 'Minnesota', 'Wild', 'Killercookie'),
  ('NSH', 'Nashville', 'Predators', 'FCKNKILL'),
  ('STL', 'St. Louis', 'Blues', 'Reese'),
  ('UTA', 'Utah', 'Mammoth', 'GSmi26'),
  ('WPG', 'Winnipeg', 'Jets', 'JaiEl'),
  ('ANA', 'Anaheim', 'Ducks', 'Pshaver'),
  ('CGY', 'Calgary', 'Flames', 'AC'),
  ('EDM', 'Edmonton', 'Oilers', 'Aucoin'),
  ('LAK', 'Los Angeles', 'Kings', 'Granddaddypurps'),
  ('SJS', 'San Jose', 'Sharks', 'IcyRambo'),
  ('SEA', 'Seattle', 'Kraken', 'Sebastion'),
  ('VAN', 'Vancouver', 'Canucks', 'Lunchboxhero_'),
  ('VGK', 'Vegas', 'Golden Knights', 'Polska')
on conflict (id) do update set gm_name = excluded.gm_name;

-- Replace the old "any unclaimed team" policy with one that requires the
-- claimant's Discord server nickname (falling back to their global Discord
-- username if we couldn't read a nickname) to match the roster's gm_name.
drop policy if exists "a signed-in user can claim one unclaimed team for themselves" on team_claims;

create policy "a GM can only claim the team they're assigned to on the league roster"
  on team_claims for insert
  with check (
    auth.uid() = user_id
    and not exists (select 1 from team_claims existing where existing.user_id = auth.uid())
    and exists (
      select 1
      from league_teams lt
      join profiles p on p.id = auth.uid()
      where lt.id = team_claims.team_id
        and lower(trim(coalesce(p.guild_nickname, p.discord_username, ''))) = lower(trim(lt.gm_name))
    )
  );
