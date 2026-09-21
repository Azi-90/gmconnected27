-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- A shared, commissioner-only log of every real transaction (trades that get
-- final approval, free-agent awards, accepted re-signings, player drops), so
-- the commissioner has a running alert feed instead of having to notice each
-- one happening across separate pages. "Acknowledged" is shared across every
-- commissioner (there can be more than one, per Manage Commissioners) rather
-- than tracked per-person -- simpler, and matches how the rest of this app's
-- shared state works.

create table if not exists transactions_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  action text not null,
  summary text not null,
  team_ids text[] not null default '{}',
  acknowledged boolean not null default false
);

alter table transactions_log enable row level security;
create policy "only commissioners can see the transaction log" on transactions_log for select using (is_commissioner());
create policy "only commissioners can acknowledge transactions" on transactions_log for update using (is_commissioner()) with check (is_commissioner());

-- Trade: log it once the commissioner gives final approval and it actually executes.
create or replace function execute_trade_on_approval()
returns trigger
language plpgsql
security definer
as $$
declare
  asset jsonb;
begin
  if new.status = 'gm_approved' and old.status <> 'pending' then
    raise exception 'A trade can only move to gm_approved from pending';
  end if;

  if new.status = 'approved' then
    if old.status <> 'gm_approved' then
      raise exception 'The receiving GM must approve before the commissioner can finalize this trade';
    end if;
    if not is_commissioner() then
      raise exception 'Only the commissioner can give final approval';
    end if;

    perform take_action_snapshot('approve_trade');

    for asset in select * from jsonb_array_elements(new.assets_from_team) loop
      if asset->>'type' = 'pick' then
        update draft_picks set current_owner_team_id = new.to_team_id
        where id = (asset->>'pickId')::uuid and current_owner_team_id = new.from_team_id and used = false;
      else
        update players set team_id = new.to_team_id where id = asset->>'playerId';
      end if;
    end loop;
    for asset in select * from jsonb_array_elements(new.assets_to_team) loop
      if asset->>'type' = 'pick' then
        update draft_picks set current_owner_team_id = new.from_team_id
        where id = (asset->>'pickId')::uuid and current_owner_team_id = new.to_team_id and used = false;
      else
        update players set team_id = new.from_team_id where id = asset->>'playerId';
      end if;
    end loop;

    insert into transactions_log (action, summary, team_ids)
    values (
      'trade',
      'Trade approved: ' || new.from_team_id || ' <-> ' || new.to_team_id,
      array[new.from_team_id, new.to_team_id]
    );
  end if;

  return new;
end;
$$;

-- Free agency: log it when an offer is actually awarded.
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

    if fa.status = 'RFA' and new.team_id <> fa.last_team_id and not fa.rfa_waived then
      raise exception 'This is a restricted free agent — the original team must waive their right of first refusal before an outside offer can be awarded';
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
    where free_agent_id = new.free_agent_id and id <> new.id and status in ('pending', 'outbid');

    insert into transactions_log (action, summary, team_ids)
    values (
      'free_agent_award',
      fa.name || ' signed by ' || new.team_id || ' ($' || new.aav || '/yr x ' || new.term_years || ' yr)',
      array[new.team_id]
    );
  end if;
  return new;
end;
$$;

-- Re-signing: log it only when the offer is actually accepted.
create or replace function propose_resign(p_player_id text, p_aav bigint, p_term_years int)
returns jsonb
language plpgsql
security definer
as $$
declare
  p players;
  age int;
  age_mult numeric;
  expected_aav bigint;
  cur_season text;
  start_year int;
  expiry text;
  outcome text;
begin
  select * into p from players where id = p_player_id;
  if p is null then
    raise exception 'Player not found';
  end if;

  if not (
    is_commissioner()
    or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = p.team_id)
  ) then
    raise exception 'Only that club''s GM or the commissioner can propose a re-signing';
  end if;

  if p.retirement_announced_season is not null then
    raise exception 'This player plans to retire and cannot be re-signed';
  end if;

  if p_term_years < 1 or p_term_years > 8 then
    raise exception 'Term must be between 1 and 8 years';
  end if;

  if p_aav <= 0 then
    raise exception 'AAV must be positive';
  end if;

  age := greatest(extract(year from now())::int - (regexp_match(p.born, '\d{4}'))[1]::int, 18);

  age_mult := case
    when age < 27 then 1.10
    when age <= 31 then 1.00
    when age <= 35 then 0.92
    else 0.80
  end;

  expected_aav := round(p.cap_hit * age_mult);

  if p_aav >= round(expected_aav * 0.95) then
    outcome := 'accepted';
  elsif p_aav >= round(expected_aav * 0.80) then
    outcome := 'countered';
  else
    outcome := 'rejected';
  end if;

  if outcome = 'accepted' then
    perform take_action_snapshot('resign_player');

    select season into cur_season from league_state where id = true;
    start_year := split_part(cur_season, '-', 1)::int;
    expiry := (start_year + p_term_years) || '-' || lpad(((start_year + p_term_years + 1) % 100)::text, 2, '0');

    update players
    set cap_hit = p_aav, salary = p_aav, term_years = p_term_years, expiry_year = expiry,
        contract_type = 'Re-signed', signing_bonus = 0, total_value = p_aav * p_term_years
    where id = p_player_id;

    insert into transactions_log (action, summary, team_ids)
    values (
      're_sign',
      p.name || ' re-signed by ' || p.team_id || ' ($' || p_aav || '/yr x ' || p_term_years || ' yr)',
      array[p.team_id]
    );
  end if;

  insert into resign_log (player_id, player_name, team_id, offered_aav, offered_term_years, expected_aav, outcome)
  values (p_player_id, p.name, p.team_id, p_aav, p_term_years, expected_aav, outcome);

  return jsonb_build_object('outcome', outcome, 'expectedAav', expected_aav);
end;
$$;

-- Drop: log it whenever a player is sent to free agency this way.
create or replace function drop_player(p_player_id text)
returns void
language plpgsql
security definer
as $$
declare
  p players;
begin
  select * into p from players where id = p_player_id;
  if p is null then
    raise exception 'Player not found';
  end if;

  if not (
    is_commissioner()
    or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = p.team_id)
  ) then
    raise exception 'Only that club''s GM or the commissioner can drop a player';
  end if;

  perform take_action_snapshot('drop_player');

  insert into free_agents (
    id, name, position, age, last_team_id, last_cap_hit, status,
    number, shoots, height, weight, born, birthplace
  )
  values (
    'fa-' || p.id,
    p.name,
    p.position,
    greatest(extract(year from now())::int - (regexp_match(p.born, '\d{4}'))[1]::int, 18),
    p.team_id,
    p.cap_hit,
    case when p.status like 'RFA%' then 'RFA' else 'UFA' end,
    p.number, p.shoots, p.height, p.weight, p.born, p.birthplace
  )
  on conflict (id) do update set
    last_team_id = excluded.last_team_id,
    last_cap_hit = excluded.last_cap_hit,
    status = excluded.status;

  delete from players where id = p_player_id;

  insert into transactions_log (action, summary, team_ids)
  values ('drop_player', p.name || ' dropped by ' || p.team_id || ' to free agency', array[p.team_id]);
end;
$$;

create or replace function acknowledge_all_transactions()
returns void
language plpgsql
security definer
as $$
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can acknowledge transactions';
  end if;

  update transactions_log set acknowledged = true where acknowledged = false;
end;
$$;
