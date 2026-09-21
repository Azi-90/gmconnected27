-- READ-ONLY. Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Shows the actual function body currently live in the database, so we can
-- tell whether 059/061's redefinition really took, or whether an older
-- version of propose_resign is still (or again) active.

select pg_get_functiondef(oid) as live_definition
from pg_proc
where proname = 'propose_resign';

-- Also: was there a recent resign_log entry for Mercer, and did it go
-- through the pending-approval path or bypass it?
select id, player_name, team_id, offered_aav, offered_term_years, outcome,
       commissioner_status, effective_season, new_expiry_year, created_at
from resign_log
where player_name = 'Dawson Mercer'
order by created_at desc
limit 5;
