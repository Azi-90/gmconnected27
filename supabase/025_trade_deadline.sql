-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Adds a commissioner-set trade deadline. Once it passes, nobody (including
-- the commissioner) can propose a NEW trade — enforced at the database
-- level, not just hidden in the UI. Trades already pending before the
-- deadline can still be approved/rejected afterward so nothing gets stuck.

alter table league_state add column if not exists trade_deadline timestamptz;

drop policy if exists "the sending club's GM or the commissioner can propose a trade" on trades;
create policy "the sending club's GM or the commissioner can propose a trade"
  on trades for insert
  with check (
    (
      (select trade_deadline from league_state where id = true) is null
      or now() < (select trade_deadline from league_state where id = true)
    )
    and (
      is_commissioner()
      or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = from_team_id)
    )
  );
