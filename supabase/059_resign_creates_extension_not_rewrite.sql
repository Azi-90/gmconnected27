-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- propose_resign() was rewriting the player's CURRENT contract in place the
-- moment an offer was accepted -- so re-signing someone who still had 2
-- years left on their deal would instantly erase those 2 years and replace
-- them with the new one, mid-season. A re-signing is an extension: it can't
-- take effect until the player's existing contract actually expires. This
-- reuses the pending_contract_extensions system built for Byram/Minten/Metsa
-- (053) instead of a one-off -- the new deal is queued up and advance_season()
-- applies it automatically once the current contract's expiry_year is
-- reached, same as those three. The "Ext. YYYY-YY" badge on the roster/cap
-- sheet already reads from this table, so a freshly accepted re-sign will
-- show up there immediately with no frontend changes needed there.

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
  outcome text;
  cur_expiry_start int;
  eff_start int;
  effective_season text;
  new_expiry_year text;
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

    -- New deal starts the season right after the current one expires, not now.
    cur_expiry_start := split_part(p.expiry_year, '-', 1)::int;
    eff_start := cur_expiry_start + 1;
    effective_season := eff_start || '-' || lpad(((eff_start + 1) % 100)::text, 2, '0');
    new_expiry_year := (eff_start + p_term_years) || '-' || lpad(((eff_start + p_term_years + 1) % 100)::text, 2, '0');

    -- Replace any not-yet-applied extension this player already had queued.
    delete from pending_contract_extensions where team_id = p.team_id and player_name = p.name;

    insert into pending_contract_extensions (player_name, team_id, effective_season, new_cap_hit, new_term_years, new_expiry_year, new_status)
    values (p.name, p.team_id, effective_season, p_aav, p_term_years, new_expiry_year, 'UFA');
  end if;

  insert into resign_log (player_id, player_name, team_id, offered_aav, offered_term_years, expected_aav, outcome)
  values (p_player_id, p.name, p.team_id, p_aav, p_term_years, expected_aav, outcome);

  return jsonb_build_object('outcome', outcome, 'expectedAav', expected_aav, 'effectiveSeason', effective_season);
end;
$$;
