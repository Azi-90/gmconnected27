-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Trade block: a team's GM (or the commissioner) can flag their own players
-- as available to trade. Visible as a badge on the roster/cap sheet and
-- rolled up into a league-wide list on the Trade Hub page.

alter table players add column if not exists on_trade_block boolean not null default false;

create or replace function set_trade_block(p_player_id text, p_on_block boolean)
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
    raise exception 'Only that club''s GM or the commissioner can change trade block status';
  end if;

  update players set on_trade_block = p_on_block where id = p_player_id;
end;
$$;
