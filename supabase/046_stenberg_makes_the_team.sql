-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Ivar Stenberg makes San Jose's roster out of camp -- moving him off the
-- team_prospects list and onto the real players table with his actual entry-
-- level contract (confirmed via puckpedia.com: 3yr/$1,075,000 AAV, RFA).
-- Replacing him on the prospect list with Igor Chernyshov (2024 2nd-rounder,
-- #4 on Daily Faceoff's 2026-27 Sharks prospect pool ranking), who wasn't
-- already tracked anywhere in this database.

delete from team_prospects where team_id = 'SJS' and name = 'Ivar Stenberg';

insert into players (
  id, team_id, name, number, position, shoots, height, weight, born, birthplace,
  contract_type, cap_hit, salary, signing_bonus, total_value, clause, term_years, expiry_year, status, overall
) values (
  'sjs-stenberg', 'SJS', 'Ivar Stenberg', 41, 'LW', 'L', '6''0"', 181, 'Sep 30, 2007', 'Gothenburg, SWE',
  'Entry-Level Contract', 1075000, 1075000, 0, 3225000, '—', 3, '2028-29', 'RFA', 80
)
on conflict (id) do nothing;

insert into team_prospects (
  team_id, name, position, height, weight, nationality, club, league,
  potential, ovr_low, ovr_high, readiness
) values (
  'SJS', 'Igor Chernyshov', 'LW', '6''2"', 194, 'RUS', 'San Jose Barracuda', 'AHL',
  'Top 6', 77, 84, '1 Year Away'
);
