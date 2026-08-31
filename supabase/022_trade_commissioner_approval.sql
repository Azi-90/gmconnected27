-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Adds a second required approval step to trades: the receiving GM approves
-- first (moving the trade to 'gm_approved'), then the commissioner gives
-- final sign-off (moving it to 'approved', which is what actually executes
-- the player move). Either step can instead reject the trade outright.
-- Since the commissioner already stands in for any GM everywhere else in
-- this app, they can also perform the first step themselves if needed.

alter table trades drop constraint if exists trades_status_check;
alter table trades add constraint trades_status_check
  check (status in ('pending', 'gm_approved', 'approved', 'rejected'));

create or replace function execute_trade_on_approval()
returns trigger
language plpgsql
security definer
as $$
declare
  asset jsonb;
begin
  if new.status = 'gm_approved' and old.status <> 'pending' then
    raise exception 'A trade can only move to gm_approved from pending';
  end if;

  if new.status = 'approved' then
    if old.status <> 'gm_approved' then
      raise exception 'The receiving GM must approve before the commissioner can finalize this trade';
    end if;
    if not is_commissioner() then
      raise exception 'Only the commissioner can give final approval';
    end if;

    perform take_action_snapshot('approve_trade');

    for asset in select * from jsonb_array_elements(new.assets_from_team) loop
      update players set team_id = new.to_team_id where id = asset->>'playerId';
    end loop;
    for asset in select * from jsonb_array_elements(new.assets_to_team) loop
      update players set team_id = new.from_team_id where id = asset->>'playerId';
    end loop;
  end if;

  return new;
end;
$$;
