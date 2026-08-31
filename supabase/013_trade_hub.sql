-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Moves the Trade Hub off browser localStorage and onto Supabase, so trades are
-- actually shared across every GM instead of living only in whoever proposed it's
-- browser. Authorization: the sending club's GM (or the commissioner) proposes a
-- trade; the receiving club's GM (or the commissioner) approves or rejects it; the
-- proposer can retract it while it's still pending. Approving a trade immediately
-- moves the traded players between rosters on the site (the commissioner still has
-- to replicate the deal in NHL 27 itself — there's no way to automate that part).

create table if not exists trades (
  id uuid primary key default gen_random_uuid(),
  from_team_id text not null references league_teams(id),
  to_team_id text not null references league_teams(id),
  assets_from_team jsonb not null default '[]'::jsonb,
  assets_to_team jsonb not null default '[]'::jsonb,
  note text not null default '',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  proposed_by uuid not null default auth.uid() references profiles(id)
);

alter table trades enable row level security;

create policy "trades are publicly readable"
  on trades for select
  using (true);

create policy "the sending club's GM or the commissioner can propose a trade"
  on trades for insert
  with check (
    is_commissioner()
    or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = from_team_id)
  );

create policy "the receiving GM decides it, the proposer can retract it while pending"
  on trades for update
  using (
    is_commissioner()
    or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = to_team_id)
    or (status = 'pending' and exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = from_team_id))
  );

create policy "the proposer or the commissioner can delete a still-pending trade"
  on trades for delete
  using (
    is_commissioner()
    or (status = 'pending' and exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = from_team_id))
  );

-- Moves the actual players once a trade flips to approved. Runs as security
-- definer since the GM approving it isn't otherwise allowed to write to `players`
-- directly — the trades table's own RLS above is what actually authorized this.
create or replace function execute_trade_on_approval()
returns trigger
language plpgsql
security definer
as $$
declare
  asset jsonb;
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
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

drop trigger if exists execute_trade_on_approval_trigger on trades;
create trigger execute_trade_on_approval_trigger
  after update on trades
  for each row execute function execute_trade_on_approval();
