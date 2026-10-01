-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Run this AFTER 071. New real prospects for the West, bios verified via
-- research. Skipped adding Björck (WPG), Lindstein (STL), Nyman (SEA),
-- Cagnoni (SJS), and Howard (EDM) as prospects -- all 5 are already on
-- their teams' actual 2026-27 NHL rosters, same reasoning as Engström and
-- Murashov in the East pass. Also corrects three names from the original
-- list: Tenner -> Tanner Molendyk, Casron -> Carson Rehkopf, Markus ->
-- Marcus Nordmark, and Hrabel -> Hrabal.
--
-- Edmonton ends this pass with zero prospects on the site (all 5 of its
-- existing ones were marked for removal in 071, and its one planned new
-- add, Howard, turned out to already be on the NHL roster) -- flagging
-- that clearly rather than silently leaving it empty.

insert into team_prospects (team_id, name, position, height, weight, nationality, club, league, potential, ovr_low, ovr_high, readiness)
values
  ('MIN', 'Carson Lambos', 'D', '6''1"', 197, 'CAN', 'Iowa Wild', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
  ('STL', 'Michael Buchinger', 'D', '6''0"', 192, 'CAN', 'Springfield Thunderbirds', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
  ('NSH', 'Tommy Bleyl', 'D', '6''0"', 170, 'USA', 'Michigan State University', 'NCAA', 'Top 4D', 74, 81, '2 Years Away'),
  ('NSH', 'Tanner Molendyk', 'D', '5''11"', 190, 'CAN', 'Milwaukee Admirals', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
  ('VAN', 'Adam Novotny', 'LW', '6''1"', 205, 'CZE', 'Peterborough Petes', 'OHL', 'Top 6', 74, 81, '2 Years Away'),
  ('SEA', 'Eduard Šalé', 'LW', '6''1"', 174, 'CZE', 'Coachella Valley Firebirds', 'AHL', 'Top 6', 74, 81, '1 Year Away'),
  ('SEA', 'Ty Nelson', 'D', '5''10"', 198, 'CAN', 'Coachella Valley Firebirds', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
  ('SEA', 'Carson Rehkopf', 'C', '6''2"', 201, 'CAN', 'Coachella Valley Firebirds', 'AHL', 'Top 6', 74, 81, '1 Year Away'),
  ('SEA', 'Caden Price', 'D', '6''1"', 190, 'CAN', 'Coachella Valley Firebirds', 'AHL', 'Top 4D', 74, 81, '2 Years Away'),
  ('SJS', 'Filip Bystedt', 'C', '6''2"', 187, 'SWE', 'San Jose Barracuda', 'AHL', 'Top 6', 74, 81, '1 Year Away'),
  ('ANA', 'Marcus Nordmark', 'LW', '6''2"', 180, 'SWE', 'Djurgårdens IF', 'SHL', 'Top 6', 74, 81, '2 Years Away'),
  ('UTA', 'Ethan Belchetz', 'LW', '6''5"', 228, 'CAN', 'Michigan State University', 'NCAA', 'Elite', 80, 88, '2 Years Away'),
  ('UTA', 'Michael Hrabal', 'G', '6''7"', 216, 'CZE', 'Tucson Roadrunners', 'AHL', 'Starter', 72, 79, '1 Year Away');
