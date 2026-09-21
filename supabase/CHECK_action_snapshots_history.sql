-- READ-ONLY. Run this ALONE in the SQL Editor.
select id, action, created_at
from action_snapshots
order by created_at desc
limit 15;
