-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Bug fix: undo_last_advance_season() had bare `delete from players;` etc with no
-- WHERE clause, which Supabase's Postgres blocks as a safety guard against
-- accidental full-table deletes. Functionally we DO want to delete every row here
-- (we're restoring from a snapshot right after), so `where true` satisfies the
-- guard without changing behavior.

create or replace function undo_last_advance_season()
returns void
language plpgsql
security definer
as $$
declare
  snap season_snapshots;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can undo';
  end if;

  select * into snap from season_snapshots order by created_at desc limit 1;
  if snap is null then
    raise exception 'No advance-season snapshot to restore';
  end if;

  delete from players where true;
  insert into players select * from jsonb_populate_recordset(null::players, snap.players_json);

  delete from free_agents where true;
  insert into free_agents select * from jsonb_populate_recordset(null::free_agents, snap.free_agents_json);

  delete from league_state where true;
  insert into league_state select * from jsonb_populate_recordset(null::league_state, snap.league_state_json);

  delete from season_snapshots where id = snap.id;
end;
$$;
