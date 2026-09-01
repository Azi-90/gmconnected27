-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Follow-up to 031_real_contracts_refresh.sql: a handful of players didn't get
-- updated because their real name (as spelled by the research pass) didn't
-- exactly match how the name is stored in this database -- mostly diacritics
-- (accented letters) going one way or the other, plus one genuine spelling
-- variant (Fyodor vs Fedor Svechkov). Confirmed live on the site: Tim Stutzle
-- and Juraj Slafkovsky were both still showing stale contracts after 031 ran.
--
-- Same values as 031, just with alternate spellings added as extra match targets.

with real_contracts (player_name, cap_hit, term_years, expiry_year, status) as (
  values
    ('Tim Stützle', 8350000, 5, '2030-31', 'UFA'),
    ('Noah Ostlund', 887000, 1, '2026-27', 'RFA'),
    ('Michael Brandsegg-Nygard', 954000, 2, '2027-28', 'RFA'),
    ('Juraj Slafkovsky', 7600000, 5, '2030-31', 'UFA'),
    ('Janis Jerome Moser', 6750000, 5, '2030-31', 'UFA'),
    ('Jerome Moser', 6750000, 5, '2030-31', 'UFA'),
    ('JJ Moser', 6750000, 5, '2030-31', 'UFA'),
    ('Viggo Bjorck', 1080000, 3, '2028-29', 'RFA'),
    ('Isak Rosen', 925000, 2, '2027-28', 'RFA'),
    ('Liam Ohgren', 887000, 1, '2026-27', 'RFA'),
    ('Aatu Raty', 850000, 1, '2026-27', 'RFA'),
    ('Fedor Svechkov', 1250000, 2, '2027-28', 'RFA')
)
update players p
set
  cap_hit = rc.cap_hit,
  salary = rc.cap_hit,
  total_value = rc.cap_hit * rc.term_years,
  term_years = rc.term_years,
  expiry_year = rc.expiry_year,
  status = rc.status
from real_contracts rc
where p.name = rc.player_name;
