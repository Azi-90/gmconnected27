-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- 044's blind-bidding policy let the commissioner see every pending offer's
-- team and amount, on the assumption they'd need it to manage things. They
-- don't -- resolve_nightly_free_agency() and pending_offer_counts() both run
-- as security definer, so the commissioner tools already work without this.
-- All it actually did was let the commissioner (who usually also runs a
-- team) see other teams' live bids before the nightly resolution picks a
-- leader, which defeats the point of blind bidding. Pending offers are now
-- visible only to the team that placed them; everyone -- commissioner
-- included -- sees a bid's team/amount once it's resolved (leading, outbid,
-- awarded, or declined), same as before.

drop policy if exists "pending offers are blind, resolved offers are public" on free_agent_offers;
create policy "pending offers are blind, resolved offers are public"
  on free_agent_offers for select
  using (
    status <> 'pending'
    or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = team_id)
  );
