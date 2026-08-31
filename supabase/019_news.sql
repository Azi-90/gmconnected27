-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- News articles table backing the League News page. Rows are written only by
-- the "generate-news" Edge Function (using the service role key, which
-- bypasses RLS entirely) after a trade, signing, season advance, lottery, or
-- completed draft — never directly by a GM. That's why there's no insert
-- policy at all here: nobody with a regular session can write to this table.

create table if not exists news_articles (
  id uuid primary key default gen_random_uuid(),
  headline text not null,
  body text not null,
  event_type text not null,
  team_ids text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table news_articles enable row level security;
create policy "news articles are publicly readable" on news_articles for select using (true);
