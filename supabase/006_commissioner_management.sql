-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Closes a real gap: right now nothing stops any signed-in GM from flagging
-- themselves commissioner directly via the API (the old "update your own profile"
-- policy didn't restrict which columns you could change). This locks that down
-- and lets an existing commissioner manage other commissioners from the app
-- instead of needing SQL every time.

-- No matter which policy allowed an UPDATE through, silently revert any change
-- to is_commissioner unless the person making the change is already a commissioner.
create or replace function protect_commissioner_flag()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.is_commissioner is distinct from old.is_commissioner then
    if not exists (select 1 from profiles where id = auth.uid() and is_commissioner) then
      new.is_commissioner := old.is_commissioner;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_commissioner_flag_trigger on profiles;
create trigger protect_commissioner_flag_trigger
  before update on profiles
  for each row execute function protect_commissioner_flag();

-- Commissioners can also update OTHER people's profile rows (needed to promote/demote
-- someone else). The trigger above still protects is_commissioner from anyone who
-- isn't already a commissioner, even through this policy.
create policy "commissioners can update any profile"
  on profiles for update
  using (is_commissioner())
  with check (true);

-- One-time bootstrap: since nobody is a commissioner yet, the trigger would block
-- everyone, including you. Run this ONE update (only once, ever) to make yourself
-- the first commissioner — replace the value with your own discord_username, which
-- you can find by running: select id, discord_username, guild_nickname from profiles;
-- update profiles set is_commissioner = true where discord_username = 'your-discord-username';
