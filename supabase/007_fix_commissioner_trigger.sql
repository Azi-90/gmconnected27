-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Bug fix: the trigger from 006 checked auth.uid() to decide whether to allow an
-- is_commissioner change. But auth.uid() is NULL when a query runs directly in the
-- SQL Editor (no logged-in app session), so the trigger was treating that as "not a
-- commissioner" and silently reverting the change. Direct SQL Editor access is
-- already a privileged, trusted context (only you can get there), so it should be
-- allowed through — the self-promotion block should only apply to requests coming
-- from the app itself (where auth.uid() is a real signed-in user).

create or replace function protect_commissioner_flag()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.is_commissioner is distinct from old.is_commissioner then
    if auth.uid() is not null and not exists (select 1 from profiles where id = auth.uid() and is_commissioner) then
      new.is_commissioner := old.is_commissioner;
    end if;
  end if;
  return new;
end;
$$;

-- Now re-run the bootstrap update — it will actually stick this time.
update profiles set is_commissioner = true where discord_username = 'azi_jechten';
