-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Eeli Tolvanen and Mike Reilly are listed on the Free Agency page even though
-- 037 already added them as signed, rostered players (NYR and CAR
-- respectively). They were never removed from free_agents when that happened,
-- so they're showing up in both places. Removing the stale free_agents rows.

delete from free_agents where name in ('Eeli Tolvanen', 'Mike Reilly');
