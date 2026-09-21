-- READ-ONLY. Run this ALONE (nothing else in the query box) in the SQL Editor.
select pg_get_functiondef(oid) as live_definition
from pg_proc
where proname = 'propose_resign';
