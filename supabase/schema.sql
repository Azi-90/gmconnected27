-- Run this once in Supabase Dashboard -> SQL Editor -> New query -> Run.

-- One row per signed-in user, auto-created on first sign-in via Discord OAuth.
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  discord_username text,
  avatar_url text,
  is_commissioner boolean not null default false,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "profiles are publicly readable"
  on profiles for select
  using (true);

create policy "users can update their own profile"
  on profiles for update
  using (auth.uid() = id);

-- Auto-create a profile row whenever a new user signs up via Discord OAuth.
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, discord_username, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'user_name'),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- One row per team once a GM claims it. team_id matches the static ids in src/data/teams.ts (e.g. 'OTT').
create table if not exists team_claims (
  team_id text primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  claimed_at timestamptz not null default now()
);

alter table team_claims enable row level security;

create policy "team claims are publicly readable"
  on team_claims for select
  using (true);

create policy "a signed-in user can claim one unclaimed team for themselves"
  on team_claims for insert
  with check (
    auth.uid() = user_id
    and not exists (select 1 from team_claims existing where existing.user_id = auth.uid())
  );

create policy "a GM can release their own claim, or the commissioner can release any"
  on team_claims for delete
  using (
    auth.uid() = user_id
    or exists (select 1 from profiles p where p.id = auth.uid() and p.is_commissioner)
  );

-- After you sign in once with Discord, run this to make yourself commissioner
-- (replace with your actual discord_username as shown in the profiles table):
-- update profiles set is_commissioner = true where discord_username = 'your-discord-username';
