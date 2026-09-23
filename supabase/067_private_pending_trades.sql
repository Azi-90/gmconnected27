-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Trades were publicly readable at every stage, so a proposed trade was
-- visible to the whole league before the receiving GM had even decided on
-- it. Same fix as blind free agency bids: a 'pending' trade is now only
-- visible to the two teams actually involved. Once the receiving GM
-- approves it (status moves to 'gm_approved'), it becomes visible to
-- everyone, same as before -- that's the point where both sides have
-- actually agreed, and the commissioner needs to be able to review it
-- for final approval anyway.
--
-- No commissioner bypass here on purpose, same reasoning as the free
-- agency fix: the commissioner is also a team GM, and doesn't need to see
-- a pending trade to do their job -- they only act once it reaches
-- gm_approved, which is already public by then.
--
-- Column reference is fully qualified (trades.from_team_id /
-- trades.to_team_id) to avoid the exact bug found in the free-agent-offers
-- policy, where an unqualified name inside the subquery bound to the
-- subquery's own table instead of the outer row.

drop policy if exists "trades are publicly readable" on trades;
create policy "pending trades are private to the two teams, others become public"
  on trades for select
  using (
    status <> 'pending'
    or exists (
      select 1 from team_claims tc
      where tc.user_id = auth.uid()
        and (tc.team_id = trades.from_team_id or tc.team_id = trades.to_team_id)
    )
  );
