-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Follow-up to 038: the source sheet gave no usable position for scratched
-- players (just "SCR"), so 038 defaulted them to forward as a best guess.
-- That default was wrong for the defensemen and goalies below -- their real
-- position blocked 038's position filter, so they never actually got an
-- overall. Confirmed live: Ryan Graves, Caleb Jones, and Yegor Chinakhov all
-- still showed no OVR on Pittsburgh's roster after 038 ran.
--
-- Chinakhov is a separate, unrelated issue: the source sheet itself has a typo
-- ("E. Chinakhov" instead of "Y. Chinakhov" for Yegor Chinakhov), so he's
-- matched by team + last name only, without the initial check.

with position_fixes (team_id, initial, lastname, pos, ovr) as (
  values
    ('BOS', 'C', 'Clifton', 'D', 82),
    ('CGY', 'B', 'Pachal', 'D', 80),
    ('CGY', 'J', 'Hanley', 'D', 80),
    ('CAR', 'P', 'Joseph', 'D', 80),
    ('CHI', 'E', 'Del Mastro', 'D', 77),
    ('CHI', 'K', 'Korchinski', 'D', 78),
    ('CHI', 'R', 'Ellis', 'D', 70),
    ('COL', 'N', 'Juulsen', 'D', 78),
    ('CBJ', 'J', 'Christiansen', 'D', 79),
    ('DAL', 'K', 'Capobianco', 'D', 78),
    ('DET', 'J', 'Bernard-Docker', 'D', 80),
    ('DET', 'J', 'Bryson', 'D', 82),
    ('EDM', 'S', 'Stastney', 'D', 79),
    ('EDM', 'T', 'Emberson', 'D', 80),
    ('FLA', 'A', 'Petrovic', 'D', 78),
    ('FLA', 'U', 'Balinskis', 'D', 83),
    ('LAK', 'E', 'Gustafsson', 'D', 79),
    ('NYI', 'M', 'Kessel', 'D', 79),
    ('NYR', 'M', 'Robertson', 'D', 78),
    ('NYR', 'V', 'Iorio', 'D', 78),
    ('OTT', 'T', 'Kleven', 'D', 83),
    ('PHI', 'S', 'Benoit', 'D', 81),
    ('PIT', 'C', 'Jones', 'D', 77),
    ('PIT', 'I', 'Solovyov', 'D', 78),
    ('PIT', 'R', 'Graves', 'D', 80),
    ('BUF', 'C', 'Ellis', 'G', 80),
    ('EDM', 'D', 'Levi', 'G', 81),
    ('NYI', 'V', 'Vanecek', 'G', 77),
    ('NYR', 'J', 'Korpisalo', 'G', 81)
)
update players p
set overall = f.ovr
from position_fixes f
where p.team_id = f.team_id
  and left(p.name, 1) = f.initial
  and p.name ilike '%' || f.lastname
  and p.position = f.pos;

-- Chinakhov: matched by last name only, no initial check (source sheet typo).
update players
set overall = 84
where team_id = 'PIT' and name ilike '%Chinakhov';

-- Reconciliation: confirm every row above found exactly one player. Zero rows
-- back means everything matched; anything listed needs a manual look.
with position_fixes (team_id, initial, lastname, pos, ovr) as (
  values
    ('BOS', 'C', 'Clifton', 'D', 82),
    ('CGY', 'B', 'Pachal', 'D', 80),
    ('CGY', 'J', 'Hanley', 'D', 80),
    ('CAR', 'P', 'Joseph', 'D', 80),
    ('CHI', 'E', 'Del Mastro', 'D', 77),
    ('CHI', 'K', 'Korchinski', 'D', 78),
    ('CHI', 'R', 'Ellis', 'D', 70),
    ('COL', 'N', 'Juulsen', 'D', 78),
    ('CBJ', 'J', 'Christiansen', 'D', 79),
    ('DAL', 'K', 'Capobianco', 'D', 78),
    ('DET', 'J', 'Bernard-Docker', 'D', 80),
    ('DET', 'J', 'Bryson', 'D', 82),
    ('EDM', 'S', 'Stastney', 'D', 79),
    ('EDM', 'T', 'Emberson', 'D', 80),
    ('FLA', 'A', 'Petrovic', 'D', 78),
    ('FLA', 'U', 'Balinskis', 'D', 83),
    ('LAK', 'E', 'Gustafsson', 'D', 79),
    ('NYI', 'M', 'Kessel', 'D', 79),
    ('NYR', 'M', 'Robertson', 'D', 78),
    ('NYR', 'V', 'Iorio', 'D', 78),
    ('OTT', 'T', 'Kleven', 'D', 83),
    ('PHI', 'S', 'Benoit', 'D', 81),
    ('PIT', 'C', 'Jones', 'D', 77),
    ('PIT', 'I', 'Solovyov', 'D', 78),
    ('PIT', 'R', 'Graves', 'D', 80),
    ('BUF', 'C', 'Ellis', 'G', 80),
    ('EDM', 'D', 'Levi', 'G', 81),
    ('NYI', 'V', 'Vanecek', 'G', 77),
    ('NYR', 'J', 'Korpisalo', 'G', 81)
)
select f.team_id, f.initial, f.lastname, f.pos
from position_fixes f
where not exists (
  select 1 from players p
  where p.team_id = f.team_id and left(p.name, 1) = f.initial
    and p.name ilike '%' || f.lastname and p.position = f.pos
);
