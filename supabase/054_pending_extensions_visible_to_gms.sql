-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- pending_contract_extensions was commissioner-only readable, but the whole
-- point of marking it on the cap sheet is for every GM to see it. Nothing
-- sensitive in here (it's just a known, already-signed real contract), so
-- opening up select the same way players/free_agents/trades already are.
-- Insert/update/delete stay commissioner-only.

drop policy if exists "only commissioners can see pending extensions" on pending_contract_extensions;
create policy "pending extensions are publicly readable" on pending_contract_extensions for select using (true);
