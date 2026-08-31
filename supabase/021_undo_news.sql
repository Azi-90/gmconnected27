-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- News articles weren't covered by the undo snapshot, so undoing a trade,
-- signing, season advance, lottery, or draft left the auto-generated article
-- behind even after the underlying action was rolled back. Adds news_articles
-- to the same snapshot/restore cycle as everything else.

alter table action_snapshots add column if not exists news_articles_json jsonb not null default '[]'::jsonb;

create or replace function take_action_snapshot(p_action text)
returns void
language plpgsql
security definer
as $$
begin
  insert into action_snapshots (
    action, players_json, free_agents_json, league_state_json,
    draft_prospects_json, draft_lottery_results_json, trades_json, free_agent_offers_json,
    progression_log_json, news_articles_json
  )
  select
    p_action,
    coalesce((select jsonb_agg(p) from players p), '[]'::jsonb),
    coalesce((select jsonb_agg(f) from free_agents f), '[]'::jsonb),
    coalesce((select jsonb_agg(l) from league_state l), '[]'::jsonb),
    coalesce((select jsonb_agg(d) from draft_prospects d), '[]'::jsonb),
    coalesce((select jsonb_agg(r) from draft_lottery_results r), '[]'::jsonb),
    coalesce((select jsonb_agg(t) from trades t), '[]'::jsonb),
    coalesce((select jsonb_agg(o) from free_agent_offers o), '[]'::jsonb),
    coalesce((select jsonb_agg(g) from progression_log g), '[]'::jsonb),
    coalesce((select jsonb_agg(n) from news_articles n), '[]'::jsonb);
end;
$$;

create or replace function undo_last_action()
returns void
language plpgsql
security definer
as $$
declare
  snap action_snapshots;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can undo';
  end if;

  select * into snap from action_snapshots order by created_at desc limit 1;
  if snap is null then
    raise exception 'Nothing to undo';
  end if;

  delete from free_agent_offers where true;

  delete from players where true;
  insert into players select * from jsonb_populate_recordset(null::players, snap.players_json);

  delete from free_agents where true;
  insert into free_agents select * from jsonb_populate_recordset(null::free_agents, snap.free_agents_json);

  delete from league_state where true;
  insert into league_state select * from jsonb_populate_recordset(null::league_state, snap.league_state_json);

  delete from draft_prospects where true;
  insert into draft_prospects select * from jsonb_populate_recordset(null::draft_prospects, snap.draft_prospects_json);

  delete from draft_lottery_results where true;
  insert into draft_lottery_results select * from jsonb_populate_recordset(null::draft_lottery_results, snap.draft_lottery_results_json);

  delete from trades where true;
  insert into trades select * from jsonb_populate_recordset(null::trades, snap.trades_json);

  insert into free_agent_offers select * from jsonb_populate_recordset(null::free_agent_offers, snap.free_agent_offers_json);

  delete from progression_log where true;
  insert into progression_log select * from jsonb_populate_recordset(null::progression_log, snap.progression_log_json);

  delete from news_articles where true;
  insert into news_articles select * from jsonb_populate_recordset(null::news_articles, snap.news_articles_json);

  delete from action_snapshots where id = snap.id;
end;
$$;
