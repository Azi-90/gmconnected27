-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Switches News generation from the Anthropic-powered Edge Function (needs a
-- paid API key) to free client-side templates. The frontend now writes
-- directly into news_articles after a trade/signing/season/draft event, so
-- this opens up inserts to any signed-in GM instead of only the service role.
-- The generate-news Edge Function is left in place unused, in case real AI
-- generation gets turned on later.

create policy "signed-in GMs can post auto-generated news" on news_articles for insert with check (auth.uid() is not null);
