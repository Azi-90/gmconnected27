-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Real-world resolutions since the Sep 11 free-agent snapshot, researched via
-- NHL.com's official Free Agent Tracker (updated Sep 18, 2026) and multiple
-- beat-reporter sources.

-- Cutter Gauthier (Anaheim RFA) signed a real deal Sep 15, 2026: 6 years,
-- $81M total, $13.5M AAV. He was zeroed out back in migration 033 as unsigned
-- -- now applying his real, actual contract.
update players
set cap_hit = 13500000,
    salary = 13500000,
    total_value = 81000000,
    term_years = 6,
    expiry_year = '2031-32',
    status = 'UFA'
where name = 'Cutter Gauthier';

-- Cam Talbot signed with Columbus (Sep 14, 2026): 1 year, $950,000. He was a
-- free agent (last team DET) in our data; now a real, rostered CBJ goalie.
insert into players (
  id, team_id, name, number, position, shoots, height, weight, born, birthplace,
  contract_type, cap_hit, salary, signing_bonus, total_value, clause, term_years, expiry_year, status
) values (
  'cbj-talbot', 'CBJ', 'Cam Talbot', 33, 'G', 'L', '6''3"', 201, 'Jul 5, 1987', 'Caledonia, ON, CAN',
  'Standard Contract', 950000, 950000, 0, 950000, '—', 1, '2026-27', 'UFA'
)
on conflict (id) do nothing;

delete from free_agents where name = 'Cam Talbot';

-- Scott Morrow was never actually an open free agent -- he re-signed with the
-- New York Rangers back on Aug 19, 2026 (before our Sep 11 snapshot), so he
-- belongs back on their roster instead of in the free-agent pool.
insert into players (
  id, team_id, name, number, position, shoots, height, weight, born, birthplace,
  contract_type, cap_hit, salary, signing_bonus, total_value, clause, term_years, expiry_year, status
) values (
  'nyr-morrow', 'NYR', 'Scott Morrow', 60, 'D', 'R', '6''2"', 194, 'Nov 1, 2002', 'Darien, CT, USA',
  'Standard Contract', 850000, 850000, 0, 850000, '—', 1, '2026-27', 'RFA'
)
on conflict (id) do nothing;

delete from free_agents where name = 'Scott Morrow';

-- These are no longer real options on the open NHL market, so they're coming
-- out of the free-agent pool entirely rather than sitting there stale:
--   John Klingberg   -- retired, announced Sep 11, 2026
--   Jonathan Quick    -- retired back in April 2026
--   Marcus Johansson  -- signed in the SHL (Sweden), Jun 5, 2026
--   Jeff Skinner      -- signed in Switzerland, Aug 14, 2026
--   Calle Jarnkrok    -- signed in the SHL (Sweden), Aug 31, 2026
--   Pavol Regenda     -- signed in the SHL (Sweden), Sep 17, 2026
--   Jesse Puljujarvi  -- already under contract in Switzerland since 2025;
--                        was never actually part of this year's NHL market
delete from free_agents
where name in (
  'John Klingberg', 'Jonathan Quick', 'Marcus Johansson', 'Jeff Skinner',
  'Calle Jarnkrok', 'Pavol Regenda', 'Jesse Puljujarvi'
);

-- Everyone else checked (Laine, Tarasenko, Bunting, van Riemsdyk, Perron,
-- Drouin, Reilly Smith, Saad, Kane, Kurashev, Stanley, Grzelcyk, Petry,
-- Forbort, Reimer, Mrazek, Kreider) is still a genuine unsigned NHL free
-- agent -- left as-is. Same for the PTOs still just tryouts, not contracts
-- (Nick Blankenburg/TOR, Carson Soucy/CBJ, Ben Hutton/OTT, Tyson Jost/NSH,
-- Kole Lind/TBL) -- worth rechecking in a few days once camp rosters settle.
