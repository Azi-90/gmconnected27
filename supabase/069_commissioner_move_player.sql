-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Lets the commissioner move any player directly to another team, no trade
-- proposal or approval from either side needed -- for league-admin moves
-- (correcting a bad import, an expansion/relocation-style move, etc.),
-- not a substitute for real trades between GMs. Snapshotted for undo and
-- logged to the transaction alert feed like every other real move.

create or replace function commissioner_move_player(p_player_id text, p_new_team_id text)
returns void
language plpgsql
security definer
as $$
declare
  p players;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can move a player directly';
  end if;

  select * into p from players where id = p_player_id;
  if p is null then
    raise exception 'Player not found';
  end if;

  if not exists (select 1 from league_teams where id = p_new_team_id) then
    raise exception 'Unknown team';
  end if;

  if p.team_id = p_new_team_id then
    raise exception '% is already on that team', p.name;
  end if;

  perform take_action_snapshot('move_player');

  update players set team_id = p_new_team_id where id = p_player_id;

  insert into transactions_log (action, summary, team_ids)
  values (
    'move_player',
    p.name || ' moved from ' || p.team_id || ' to ' || p_new_team_id || ' by the commissioner',
    array[p.team_id, p_new_team_id]
  );
end;
$$;
