-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Overall corrections from "League Year 1 Contract Fixes (up to Florida).xlsx"
-- (covers ANA, BOS, BUF, CGY, CAR, CHI, COL, CBJ, DAL, DET, EDM, UTA --
-- Florida's tab was still empty). Cross-checked the sheet's "Game OVR"
-- column against the LIVE site data (not the sheet's own "Site OVR" column,
-- which was stale in a few spots) via a direct read of the players table.
-- Only applying the two clean categories: real numeric corrections, and
-- filling in players who already exist on the site but had a null overall.

update players set overall = 89 where id = 'buf-thompson';   -- Tage Thompson, was 90
update players set overall = 81 where id = 'buf-malenstyn';  -- Beck Malenstyn, was 80
update players set overall = 88 where id = 'uta-sergachev';  -- Mikhail Sergachev, was 83
update players set overall = 84 where id = 'uta-lee';        -- Anders Lee, was 88

update players set overall = 80 where id = 'uta-stenlund';   -- Kevin Stenlund, was null
update players set overall = 79 where id = 'uta-obrien';     -- Liam O'Brien, was null
update players set overall = 79 where id = 'uta-desimone';   -- Nick DeSimone, was null
update players set overall = 67 where id = 'uta-stauber';    -- Jaxson Stauber, was null
update players set overall = 76 where id = 'uta-simashev';   -- Dmitri Simashev, was null
update players set overall = 76 where id = 'uta-lamoureux';  -- Maveric Lamoureux, was null
update players set overall = 82 where id = 'det-sandinpellikka'; -- Axel Sandin Pellikka, was null
