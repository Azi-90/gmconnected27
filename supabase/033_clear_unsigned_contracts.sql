-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Follow-up to 031/032: 9 real players are unsigned (RFA still in negotiation, or
-- on a PTO) as of this data pull, so 031 deliberately skipped them rather than
-- overwrite their contract with a real number that doesn't exist yet. Per request,
-- clear the stale dollar figures on those 9 so the site shows a clean RFA/UFA tag
-- instead of a leftover contract that no longer means anything.
--
-- expiry_year is set to the CURRENT season (not a placeholder like 'N/A') because
-- the cap sheet's year-column layout parses expiry_year as a season string
-- (seasonStartYear() does parseInt(season.split('-')[0])) -- a non-numeric value
-- would turn into NaN and break the whole team's cap sheet grid, not just this
-- player's row. Using the current season also means these 9 will naturally roll
-- into the free-agent pool the next time the commissioner advances the season
-- (the existing advance_season logic already does that for any expiry_year
-- matching the season being advanced past), which is the right outcome for an
-- unsigned player anyway.

with unsigned_players (player_name, status) as (
  values
    ('Cutter Gauthier', 'RFA'),
    ('Alexander Nylander', 'UFA'),
    ('Chris Driedger', 'UFA'),
    ('Simon Edvinsson', 'RFA'),
    ('Zack Bolduc', 'RFA'),
    ('Arber Xhekaj', 'RFA'),
    ('Alexander Nikishin', 'RFA'),
    ('Adam Fantilli', 'RFA'),
    ('Cal Petersen', 'UFA')
)
update players p
set
  cap_hit = 0,
  salary = 0,
  signing_bonus = 0,
  total_value = 0,
  term_years = 0,
  expiry_year = (select season from league_state where id = true),
  status = up.status
from unsigned_players up
where p.name = up.player_name;
