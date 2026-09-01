-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- The recurring "couldn't find a club assigned to me" bug (Jets, now Wild) is
-- always the same root cause: league_teams.gm_name was hand-typed from reading a
-- Discord nickname off screen, and lookalike characters (0 vs O, 1 vs l, etc.)
-- make that error-prone. This RPC lets a commissioner set gm_name directly from
-- the frontend, so the Commissioner Tools page can offer a dropdown of each
-- signed-in GM's EXACT stored discord_username/guild_nickname (typo-proof,
-- since it's the real value Discord OAuth gave us) instead of retyping a guess.

create or replace function set_team_gm_name(p_team_id text, p_gm_name text)
returns void
language plpgsql
security definer
as $$
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can reassign a team''s GM name';
  end if;

  if not exists (select 1 from league_teams where id = p_team_id) then
    raise exception 'Unknown team %', p_team_id;
  end if;

  update league_teams set gm_name = trim(p_gm_name) where id = p_team_id;
end;
$$;

-- Immediate fix for the Wild: the seeded gm_name ('Killercookie') is missing a
-- character the real Discord identity has. Update this once you've confirmed the
-- exact identity via the new Commissioner Tools dropdown -- or just run this now
-- if you already know the correct spelling.
-- update league_teams set gm_name = 'killercOOkie' where id = 'MIN';
