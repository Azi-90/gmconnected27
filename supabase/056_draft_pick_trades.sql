-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Real first-round pick trades reported by the commissioner. draft_picks
-- rows for future years (2028, 2029) don't exist yet -- they only get
-- created when advance_season() runs for that year -- so this upserts
-- them now with the correct owner instead of waiting and having to
-- remember to update it later.

insert into draft_picks (draft_year, original_team_id, current_owner_team_id)
values
  (2027, 'TOR', 'BOS'),  -- Boston has Toronto's 2027 first
  (2028, 'DAL', 'CAR'),  -- Carolina has Dallas's 2028 first
  (2027, 'FLA', 'CHI'),  -- Chicago has Florida's 2027 first
  (2027, 'EDM', 'CHI'),  -- Chicago has Edmonton's 2027 first
  (2027, 'VGK', 'NJD'),  -- New Jersey has Vegas's 2027 first
  (2028, 'COL', 'NSH'),  -- Nashville has Colorado's 2028 first
  (2029, 'FLA', 'OTT'),  -- Ottawa has Florida's 2029 first
  (2028, 'TOR', 'PHI'),  -- Philadelphia has Toronto's 2028 first
  (2027, 'TBL', 'SEA'),  -- Seattle has Tampa Bay's 2027 first
  (2027, 'COL', 'TOR'),  -- Toronto has Colorado's 2027 first
  (2028, 'FLA', 'UTA'),  -- Utah has Florida's 2028 first
  (2028, 'NYR', 'VGK')   -- Vegas has NY Rangers' 2028 first
on conflict (draft_year, original_team_id)
do update set current_owner_team_id = excluded.current_owner_team_id;

-- Sanity check: every pick above should now show its new owner, not its
-- original team.
select draft_year, original_team_id, current_owner_team_id
from draft_picks
where (draft_year, original_team_id) in (
  (2027, 'TOR'), (2028, 'DAL'), (2027, 'FLA'), (2027, 'EDM'),
  (2027, 'VGK'), (2028, 'COL'), (2029, 'FLA'), (2028, 'TOR'),
  (2027, 'TBL'), (2027, 'COL'), (2028, 'FLA'), (2028, 'NYR')
)
order by draft_year, original_team_id;
