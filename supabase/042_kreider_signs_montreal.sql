-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Chris Kreider signed with the Montreal Canadiens on Sep 12, 2026 (1 year,
-- $2.15M cap hit) -- missed in 041's free-agency sweep since he wasn't
-- re-checked there. Confirmed via NHL.com, TSN, and puckpedia.com.

insert into players (
  id, team_id, name, number, position, shoots, height, weight, born, birthplace,
  contract_type, cap_hit, salary, signing_bonus, total_value, clause, term_years, expiry_year, status
) values (
  'mtl-kreider', 'MTL', 'Chris Kreider', 22, 'LW', 'L', '6''3"', 231, 'Apr 30, 1991', 'Boxford, MA, USA',
  'Standard Contract', 2150000, 2150000, 0, 2150000, '—', 1, '2026-27', 'UFA'
)
on conflict (id) do nothing;

delete from free_agents where name = 'Chris Kreider';
