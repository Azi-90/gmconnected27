-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Follow-up to 049, same issue as 039 was for the first sheet: scratched
-- players have no usable position in the source ("SCR"), so 049 defaulted
-- them to forward. Wrong for the defensemen and goalies below, all on teams
-- this sheet covers for the first time (039 already covered the original 20
-- teams' equivalents). Matched by team + first initial + last-name suffix
-- rather than an exact name, since a couple of these use a short form in the
-- sheet (e.g. "Phil Myers") that may not match this database's stored full
-- first name (e.g. "Philippe Myers") exactly.

with position_fixes (team_id, initial, lastname, pos, ovr) as (
  values
    ('STL', 'T', 'Krug', 'D', 70),
    ('MIN', 'D', 'Hunt', 'D', 76),
    ('NJD', 'N', 'Daws', 'G', 75),
    ('NJD', 'D', 'Chisholm', 'D', 81),
    ('TBL', 'D', 'Hildeby', 'G', 78),
    ('TBL', 'E', 'Lilleberg', 'D', 81),
    ('TBL', 'M', 'Crozier', 'D', 80),
    ('TOR', 'E', 'Andrae', 'D', 80),
    ('TOR', 'P', 'Myers', 'D', 80),
    ('VAN', 'L', 'Schenn', 'D', 82),
    ('VAN', 'N', 'Tolopilo', 'G', 77),
    ('VGK', 'A', 'Pietrangelo', 'D', 70),
    ('VGK', 'D', 'Coghlan', 'D', 75),
    ('WSH', 'T', 'Liljegren', 'D', 82),
    ('WSH', 'J', 'Holl', 'D', 80)
)
update players p
set overall = f.ovr
from position_fixes f
where p.team_id = f.team_id
  and left(p.name, 1) = f.initial
  and p.name ilike '%' || f.lastname
  and p.position = f.pos;

-- Reconciliation: confirm every row above found exactly one player.
with position_fixes (team_id, initial, lastname, pos, ovr) as (
  values
    ('STL', 'T', 'Krug', 'D', 70),
    ('MIN', 'D', 'Hunt', 'D', 76),
    ('NJD', 'N', 'Daws', 'G', 75),
    ('NJD', 'D', 'Chisholm', 'D', 81),
    ('TBL', 'D', 'Hildeby', 'G', 78),
    ('TBL', 'E', 'Lilleberg', 'D', 81),
    ('TBL', 'M', 'Crozier', 'D', 80),
    ('TOR', 'E', 'Andrae', 'D', 80),
    ('TOR', 'P', 'Myers', 'D', 80),
    ('VAN', 'L', 'Schenn', 'D', 82),
    ('VAN', 'N', 'Tolopilo', 'G', 77),
    ('VGK', 'A', 'Pietrangelo', 'D', 70),
    ('VGK', 'D', 'Coghlan', 'D', 75),
    ('WSH', 'T', 'Liljegren', 'D', 82),
    ('WSH', 'J', 'Holl', 'D', 80)
)
select f.team_id, f.initial, f.lastname, f.pos
from position_fixes f
where not exists (
  select 1 from players p
  where p.team_id = f.team_id and left(p.name, 1) = f.initial
    and p.name ilike '%' || f.lastname and p.position = f.pos
);
