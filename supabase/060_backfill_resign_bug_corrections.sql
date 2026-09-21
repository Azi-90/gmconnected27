-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Fixes the 6 real re-signings that went through before 059 landed, using
-- the pre-mutation contract data recovered from action_snapshots (confirmed
-- via CHECK_resign_bug_prestate.sql -- every snapshot_at matched resigned_at
-- exactly). Restores each player's contract to what it was before the buggy
-- immediate overwrite, then queues the terms they actually agreed to as a
-- proper extension via pending_contract_extensions, effective the season
-- after their real current contract expires.

update players set
  cap_hit = 986000, salary = 986000, signing_bonus = 0, total_value = 1972000,
  term_years = 2, expiry_year = '2027-28', status = 'RFA', contract_type = 'Entry-Level Contract'
where team_id = 'PIT' and name = 'Benjamin Kindel';

update players set
  cap_hit = 10000000, salary = 10000000, signing_bonus = 0, total_value = 10000000,
  term_years = 1, expiry_year = '2026-27', status = 'UFA', contract_type = 'Standard Contract (Extension)'
where team_id = 'PIT' and name = 'Erik Karlsson';

update players set
  cap_hit = 5500000, salary = 5500000, signing_bonus = 0, total_value = 5500000,
  term_years = 1, expiry_year = '2026-27', status = 'UFA', contract_type = '35+ Contract (Extension)'
where team_id = 'PIT' and name = 'Evgeni Malkin';

update players set
  cap_hit = 8700000, salary = 8700000, signing_bonus = 0, total_value = 8700000,
  term_years = 1, expiry_year = '2026-27', status = 'UFA', contract_type = '35+ Contract (Extension)'
where team_id = 'PIT' and name = 'Sidney Crosby';

update players set
  cap_hit = 2500000, salary = 2500000, signing_bonus = 0, total_value = 2500000,
  term_years = 1, expiry_year = '2026-27', status = 'UFA', contract_type = 'Standard Contract'
where team_id = 'NJD' and name = 'Cody Glass';

update players set
  cap_hit = 4000000, salary = 4000000, signing_bonus = 0, total_value = 4000000,
  term_years = 1, expiry_year = '2026-27', status = 'RFA', contract_type = 'Standard Contract'
where team_id = 'NJD' and name = 'Dawson Mercer';

delete from pending_contract_extensions
where (team_id, player_name) in (
  ('PIT', 'Benjamin Kindel'), ('PIT', 'Erik Karlsson'), ('PIT', 'Evgeni Malkin'),
  ('PIT', 'Sidney Crosby'), ('NJD', 'Cody Glass'), ('NJD', 'Dawson Mercer')
);

insert into pending_contract_extensions (player_name, team_id, effective_season, new_cap_hit, new_term_years, new_expiry_year, new_status)
values
  ('Benjamin Kindel', 'PIT', '2028-29', 3000000, 8, '2036-37', 'UFA'),
  ('Erik Karlsson',   'PIT', '2027-28', 8000000, 5, '2032-33', 'UFA'),
  ('Evgeni Malkin',   'PIT', '2027-28', 4400000, 5, '2032-33', 'UFA'),
  ('Sidney Crosby',   'PIT', '2027-28', 7000000, 5, '2032-33', 'UFA'),
  ('Cody Glass',      'NJD', '2027-28', 2400000, 2, '2029-30', 'UFA'),
  ('Dawson Mercer',   'NJD', '2027-28', 4400000, 7, '2034-35', 'UFA');
