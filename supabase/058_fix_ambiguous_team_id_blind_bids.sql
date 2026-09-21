-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- The real bug behind blind bids leaking: the select policy's own subquery
-- had `tc.team_id = team_id` with the second `team_id` unqualified. Postgres
-- resolves an unqualified column to the innermost scope first, so it bound
-- to the subquery's OWN `team_claims.team_id` instead of the outer
-- `free_agent_offers.team_id` -- making the check `tc.team_id = tc.team_id`,
-- which is trivially true for anyone who has claimed any team at all. That's
-- why even non-commissioner accounts (and even teams that had no bid at all,
-- like PIT showing up in the raw response) could see every pending bid, not
-- just their own. 057 removed the is_commissioner() bypass but this deeper
-- bug was already there since 044 and was masked by it.
--
-- Fix: qualify the outer column explicitly so the subquery actually compares
-- against the row being checked, not itself.

drop policy if exists "pending offers are blind, resolved offers are public" on free_agent_offers;
create policy "pending offers are blind, resolved offers are public"
  on free_agent_offers for select
  using (
    status <> 'pending'
    or exists (
      select 1 from team_claims tc
      where tc.user_id = auth.uid() and tc.team_id = free_agent_offers.team_id
    )
  );
