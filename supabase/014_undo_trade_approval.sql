-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Extends the single-level undo safety net to cover trade approvals. Approving a
-- trade moves players between rosters, but nothing was snapshotting the trades
-- table or the trade's own status change, so "Undo Last Action" couldn't touch it.
-- Now approving a trade takes a snapshot (including the trades table itself)
-- right before the roster move, and undo restores the trades table alongside
-- everything else.

alter table action_snapshots add column if not exists trades_json jsonb not null default '[]'::jsonb;

create or replace function take_action_snapshot(p_action text)
returns void
language plpgsql
security definer
as $$
begin
  insert into action_snapshots (
    action, players_json, free_agents_json, league_state_json,
    draft_prospects_json, draft_lottery_results_json, trades_json
  )
  select
    p_action,
    coalesce((select jsonb_agg(p) from players p), '[]'::jsonb),
    coalesce((select jsonb_agg(f) from free_agents f), '[]'::jsonb),
    coalesce((select jsonb_agg(l) from league_state l), '[]'::jsonb),
    coalesce((select jsonb_agg(d) from draft_prospects d), '[]'::jsonb),
    coalesce((select jsonb_agg(r) from draft_lottery_results r), '[]'::jsonb),
    coalesce((select jsonb_agg(t) from trades t), '[]'::jsonb);
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

  delete from action_snapshots where id = snap.id;
end;
$$;

-- Switched to BEFORE UPDATE so the snapshot captures the trade's pre-approval
-- row (an AFTER trigger would snapshot it already flipped to 'approved', which
-- would make undo a no-op on the trade's own status).
create or replace function execute_trade_on_approval()
returns trigger
language plpgsql
security definer
as $$
declare
  asset jsonb;
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    perform take_action_snapshot('approve_trade');

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
  before update on trades
  for each row execute function execute_trade_on_approval();
