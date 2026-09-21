-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Artur Akhtyamov was listed both as a signed Toronto goalie on the roster
-- and on the team_prospects list -- cleaning up the duplicate by removing
-- the prospect-list entry (he's already a real player) and replacing him
-- with Ethan MacKenzie (Toronto's real 2026 3rd-round pick, #7 on The
-- Hockey Writers' 2026-27 Leafs prospect list), who wasn't already tracked
-- anywhere in this database.

delete from team_prospects where team_id = 'TOR' and name = 'Artur Akhtyamov';

insert into team_prospects (
  team_id, name, position, height, weight, nationality, club, league,
  potential, ovr_low, ovr_high, readiness
) values (
  'TOR', 'Ethan MacKenzie', 'D', '6''1"', 187, 'CAN', 'University of North Dakota', 'NCAA',
  'Bottom Pair', 67, 74, '2 Years Away'
);
