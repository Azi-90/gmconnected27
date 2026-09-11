-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Real NHL transactions confirmed between Aug 31 and Sep 11, 2026, cross-checked
-- across PuckPedia, ESPN, NHL.com's official trade tracker, and beat reporters
-- for all 32 teams. Only the two moves below are applied here -- everything else
-- found in research was either already reflected in our data, a depth/PTO
-- signing for a player we don't currently track, or a next-season extension that
-- shouldn't overwrite this year's cap number (see notes at the end).

-- Luke Evangelista: traded Nashville -> New Jersey (Sep 1, 2026) for a
-- conditional 2028 1st-round pick and a 2028 2nd. Contract terms unchanged.
update players set team_id = 'NJD' where name = 'Luke Evangelista';

-- Chris Kreider: Anaheim placed him on unconditional waivers to terminate his
-- contract (Sep 9, 2026); he cleared unclaimed Sep 10 and is now a free agent
-- with no team, not an Anaheim Duck. Move him the same way advance_season()
-- moves an expiring contract into free agency.
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
  'UFA',
  p.number, p.shoots, p.height, p.weight, p.born, p.birthplace
from players p
where p.name = 'Chris Kreider'
on conflict (id) do nothing;

delete from players where name = 'Chris Kreider';

-- Not applied, and why:
--   Brady Tkachuk (OTT -> FLA, June 2026 trade) -- already correctly on FLA in
--     our data, nothing to fix.
--   Zeev Buium (VAN), Braeden Bowman (VGK) -- real new extensions (8yr/$75.04M
--     and 6yr/$20.4M) reported this week, but it's unclear whether the new money
--     starts this season or next; applying it now risks overwriting a correct
--     2026-27 cap number with a future year's figure. Revisit once the effective
--     season is confirmed.
--   Fraser Minten (BOS, 7yr/$50.4M) and Zach Metsa (BUF, 1yr/$900K) -- both
--     explicitly reported as extensions that begin in 2027-28, not this season,
--     so this year's cap sheet is already correct as-is.
--   Ilya Samsonov (SJS), Alex Formenton (EDM), Eeli Tolvanen (NYR),
--     Pierre-Olivier Joseph / Cayden Primeau / Justin Robidas / Skyler
--     Brind'Amour / Mike Reilly (CAR), Jacob Melanson (SEA), Tyson Jost (NSH,
--     PTO), Kole Lind (TBL, PTO), Brendan Brisson (TOR) -- depth signings/PTOs
--     for players not currently tracked in this database. Not added since they
--     weren't part of any team's rostered player set to begin with.
