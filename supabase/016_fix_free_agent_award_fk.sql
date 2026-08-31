-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Fixes: "update or delete on table free_agents violates foreign key constraint
-- free_agent_offers_free_agent_id_fkey" when awarding an offer. The award
-- trigger was deleting the free_agents row while offers still referenced it.
-- Fix: mark the free agent as signed instead of deleting it (same pattern
-- draft_prospects already uses for drafted_by_team_id) — the row stays, the
-- free agency page just stops listing it.

alter table free_agents add column if not exists signed_by_team_id text references league_teams(id);
alter table free_agents add column if not exists signed_at timestamptz;

create or replace function execute_free_agent_award()
returns trigger
language plpgsql
security definer
as $$
declare
  fa free_agents;
  cur_season text;
  start_year int;
  expiry text;
  new_player_id text;
begin
  if new.status = 'awarded' and old.status is distinct from 'awarded' then
    select * into fa from free_agents where id = new.free_agent_id and signed_by_team_id is null;
    if fa is null then
      raise exception 'That free agent has already been signed';
    end if;

    perform take_action_snapshot('award_free_agent');

    select season into cur_season from league_state where id = true;
    start_year := split_part(cur_season, '-', 1)::int;
    expiry := (start_year + new.term_years) || '-' || lpad(((start_year + new.term_years + 1) % 100)::text, 2, '0');
    new_player_id := 'signed-' || replace(gen_random_uuid()::text, '-', '');

    insert into players (
      id, team_id, name, number, position, shoots, height, weight, born, birthplace,
      contract_type, cap_hit, salary, signing_bonus, total_value, clause, term_years, expiry_year, status, overall
    ) values (
      new_player_id, new.team_id, fa.name, coalesce(fa.number, 0), fa.position, coalesce(fa.shoots, 'L'),
      coalesce(fa.height, '—'), coalesce(fa.weight, 0), coalesce(fa.born, '—'), coalesce(fa.birthplace, '—'),
      'Standard Contract', new.aav, new.aav, new.signing_bonus, new.aav * new.term_years, '—',
      new.term_years, expiry, 'Signed', null
    );

    update free_agents set signed_by_team_id = new.team_id, signed_at = now() where id = fa.id;

    update free_agent_offers
    set status = 'declined'
    where free_agent_id = new.free_agent_id and id <> new.id and status = 'pending';
  end if;
  return new;
end;
$$;

-- Same fix applies to undo: it was wiping free_agents before free_agent_offers,
-- which hits the same foreign key violation. Delete the child table first,
-- restore it last (after free_agents exists again to satisfy the FK).
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

  delete from action_snapshots where id = snap.id;
end;
$$;
