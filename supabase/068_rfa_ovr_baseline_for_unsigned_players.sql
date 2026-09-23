-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Two related fixes for players with no real current contract (cap_hit
-- under $500k -- a proxy for "not actually signed," like an unsigned RFA
-- such as Nikishin or Edvinsson):
--
-- 1. The negotiation formula bases "expected value" on the player's
--    CURRENT cap hit. For someone showing $0, that's $0 -- so literally any
--    offer clears the 95% bar. Now falls back to a baseline estimated from
--    their overall rating instead, tiered roughly to real NHL market value.
--    Signed players with a real cap hit are unaffected.
--
-- 2. An accepted offer for an unsigned player has no existing deal to wait
--    out, so it should apply THIS season, not get queued as a future
--    extension like every other re-signing. The commissioner-approval
--    trigger now applies it directly to the player's row when
--    effective_season equals the CURRENT league season; every other case
--    (a player with a real current deal) still queues into
--    pending_contract_extensions as before.

create or replace function propose_resign(p_player_id text, p_aav bigint, p_term_years int)
returns jsonb
language plpgsql
security definer
as $$
declare
  p players;
  age int;
  age_mult numeric;
  baseline bigint;
  expected_aav bigint;
  outcome text;
  cur_season text;
  cur_season_start int;
  eff_start int;
  effective_season text;
  new_expiry_year text;
  is_unsigned boolean;
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

  perform validate_aav(p_aav);

  age := greatest(extract(year from now())::int - (regexp_match(p.born, '\d{4}'))[1]::int, 18);

  age_mult := case
    when age < 27 then 1.10
    when age <= 31 then 1.00
    when age <= 35 then 0.92
    else 0.80
  end;

  is_unsigned := p.cap_hit is null or p.cap_hit < 500000;

  if not is_unsigned then
    baseline := p.cap_hit;
  else
    baseline := case
      when p.overall is null then 1000000
      when p.overall >= 95 then 11000000
      when p.overall >= 90 then 8000000
      when p.overall >= 87 then 6500000
      when p.overall >= 84 then 5000000
      when p.overall >= 81 then 3500000
      when p.overall >= 78 then 2200000
      when p.overall >= 75 then 1500000
      else 1000000
    end;
  end if;

  expected_aav := round(baseline * age_mult);

  if p_aav >= round(expected_aav * 0.95) then
    outcome := 'accepted';
  elsif p_aav >= round(expected_aav * 0.80) then
    outcome := 'countered';
  else
    outcome := 'rejected';
  end if;

  if outcome = 'accepted' then
    select season into cur_season from league_state where id = true;
    cur_season_start := split_part(cur_season, '-', 1)::int;

    if is_unsigned then
      eff_start := cur_season_start; -- no current deal to wait out, starts now
    else
      eff_start := split_part(p.expiry_year, '-', 1)::int + 1;
    end if;

    effective_season := eff_start || '-' || lpad(((eff_start + 1) % 100)::text, 2, '0');
    new_expiry_year := (eff_start + p_term_years - 1) || '-' || lpad(((eff_start + p_term_years) % 100)::text, 2, '0');

    update resign_log set commissioner_status = 'rejected'
    where team_id = p.team_id and player_name = p.name and commissioner_status = 'pending';
  end if;

  insert into resign_log (
    player_id, player_name, team_id, offered_aav, offered_term_years, expected_aav, outcome,
    commissioner_status, effective_season, new_expiry_year
  )
  values (
    p_player_id, p.name, p.team_id, p_aav, p_term_years, expected_aav, outcome,
    case when outcome = 'accepted' then 'pending' else null end,
    effective_season, new_expiry_year
  );

  return jsonb_build_object('outcome', outcome, 'expectedAav', expected_aav, 'effectiveSeason', effective_season);
end;
$$;

create or replace function apply_resign_commissioner_decision()
returns trigger
language plpgsql
security definer
as $$
declare
  cur_season text;
begin
  if new.commissioner_status is distinct from old.commissioner_status then
    if old.commissioner_status is distinct from 'pending' then
      raise exception 'This re-signing has already been decided';
    end if;
    if not is_commissioner() then
      raise exception 'Only the commissioner can approve or reject a re-signing';
    end if;

    if new.commissioner_status = 'approved' then
      perform take_action_snapshot('resign_player');

      select season into cur_season from league_state where id = true;

      if new.effective_season = cur_season then
        -- No existing deal to wait out (was unsigned) -- applies immediately.
        update players
        set cap_hit = new.offered_aav, salary = new.offered_aav, signing_bonus = 0,
            total_value = new.offered_aav * new.offered_term_years, term_years = new.offered_term_years,
            expiry_year = new.new_expiry_year, status = 'UFA', contract_type = 'Standard Contract'
        where team_id = new.team_id and name = new.player_name;
      else
        delete from pending_contract_extensions where team_id = new.team_id and player_name = new.player_name;

        insert into pending_contract_extensions (player_name, team_id, effective_season, new_cap_hit, new_term_years, new_expiry_year, new_status)
        values (new.player_name, new.team_id, new.effective_season, new.offered_aav, new.offered_term_years, new.new_expiry_year, 'UFA');
      end if;

      insert into transactions_log (action, summary, team_ids)
      values (
        're_sign',
        new.player_name || ' re-signed by ' || new.team_id || ' ($' || new.offered_aav || '/yr x ' || new.offered_term_years || ' yr), effective ' || new.effective_season,
        array[new.team_id]
      );
    end if;
  end if;

  return new;
end;
$$;
