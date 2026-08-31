-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Many GMs' Discord nicknames follow a "TeamGM | Name" convention (e.g. "CanesGM | Jechten"),
-- so an exact-string match against the roster's bare gm_name ("Jechten") was failing.
-- This matches on either the whole identity string, or any "|"/"-"/":"/"/" separated segment of it.

create or replace function gm_nickname_matches(identity text, gm_name text)
returns boolean
language sql
immutable
as $$
  select
    lower(trim(coalesce(identity, ''))) = lower(trim(gm_name))
    or exists (
      select 1
      from unnest(regexp_split_to_array(coalesce(identity, ''), '[|/:•–—-]')) as seg
      where lower(trim(seg)) = lower(trim(gm_name))
    );
$$;

drop policy if exists "a GM can only claim the team they're assigned to on the league roster" on team_claims;

create policy "a GM can only claim the team they're assigned to on the league roster"
  on team_claims for insert
  with check (
    auth.uid() = user_id
    and not exists (select 1 from team_claims existing where existing.user_id = auth.uid())
    and exists (
      select 1
      from league_teams lt
      join profiles p on p.id = auth.uid()
      where lt.id = team_claims.team_id
        and gm_nickname_matches(coalesce(p.guild_nickname, p.discord_username), lt.gm_name)
    )
  );
