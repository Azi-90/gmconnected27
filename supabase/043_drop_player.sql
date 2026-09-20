-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Lets a team's GM (or the commissioner) drop a player straight to free
-- agency -- the main use case is a team that's over the salary cap needing
-- to shed a contract immediately, but it works anytime. Mirrors the same
-- insert-then-delete move advance_season() already uses for expiring
-- contracts, and gets the same single-level undo coverage as other
-- consequential actions (trades, free-agent awards, drafts).

create or replace function drop_player(p_player_id text)
returns void
language plpgsql
security definer
as $$
declare
  p players;
begin
  select * into p from players where id = p_player_id;
  if p is null then
    raise exception 'Player not found';
  end if;

  if not (
    is_commissioner()
    or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = p.team_id)
  ) then
    raise exception 'Only that club''s GM or the commissioner can drop a player';
  end if;

  perform take_action_snapshot('drop_player');

  insert into free_agents (
    id, name, position, age, last_team_id, last_cap_hit, status,
    number, shoots, height, weight, born, birthplace
  )
  values (
    'fa-' || p.id,
    p.name,
    p.position,
    greatest(extract(year from now())::int - (regexp_match(p.born, '\d{4}'))[1]::int, 18),
    p.team_id,
    p.cap_hit,
    case when p.status like 'RFA%' then 'RFA' else 'UFA' end,
    p.number, p.shoots, p.height, p.weight, p.born, p.birthplace
  )
  on conflict (id) do update set
    last_team_id = excluded.last_team_id,
    last_cap_hit = excluded.last_cap_hit,
    status = excluded.status;

  delete from players where id = p_player_id;
end;
$$;
