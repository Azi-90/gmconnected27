-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Run this AFTER 062.
--
-- Part 1: fixes an off-by-one bug in how propose_resign() computed a new
-- extension's final season. effective_season is already the FIRST season of
-- the new deal, so the last season is effective_start + (term - 1) -- not
-- effective_start + term. Verified against the original Minten/Metsa/Byram
-- rows from 053 (written correctly): e.g. Byram, effective 2027-28, 6 years,
-- ends 2032-33 = 2027 + 6 - 1. 059/061 (and the 060/062 backfills that used
-- the same broken math) all landed one year too late. Corrects the 6 rows
-- already queued, and redefines propose_resign() so future re-signs compute
-- it correctly.
--
-- Part 2: applies real contract updates for Montreal reported by the HabsGM
-- in Discord (Newhook, Bolduc, Xhekaj). Kreider's contract already matches
-- what was reported ($2,150,000 x 1yr) so it's untouched. Newhook already
-- has an active 2026-27 contract, so his new deal is queued as an extension
-- effective 2027-28 (same rule as every other re-signing). Bolduc and Xhekaj
-- currently show $0 / 0yr on the site -- a data gap, not a real contract --
-- so those are filled in directly as their real current deal.

update pending_contract_extensions set new_expiry_year = '2035-36' where team_id = 'PIT' and player_name = 'Benjamin Kindel';
update pending_contract_extensions set new_expiry_year = '2031-32' where team_id = 'PIT' and player_name = 'Erik Karlsson';
update pending_contract_extensions set new_expiry_year = '2031-32' where team_id = 'PIT' and player_name = 'Evgeni Malkin';
update pending_contract_extensions set new_expiry_year = '2031-32' where team_id = 'PIT' and player_name = 'Sidney Crosby';
update pending_contract_extensions set new_expiry_year = '2028-29' where team_id = 'NJD' and player_name = 'Cody Glass';
update pending_contract_extensions set new_expiry_year = '2033-34' where team_id = 'NJD' and player_name = 'Dawson Mercer';

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

  perform validate_aav(p_aav);

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
    cur_expiry_start := split_part(p.expiry_year, '-', 1)::int;
    eff_start := cur_expiry_start + 1;
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

-- Newhook: keep his current 2026-27 contract, queue the real new deal.
delete from pending_contract_extensions where team_id = 'MTL' and player_name = 'Alex Newhook';
insert into pending_contract_extensions (player_name, team_id, effective_season, new_cap_hit, new_term_years, new_expiry_year, new_status)
values ('Alex Newhook', 'MTL', '2027-28', 5550000, 4, '2030-31', 'UFA');

-- Bolduc and Xhekaj: fill in the real current contract (was $0 / 0yr).
update players set
  cap_hit = 4200000, salary = 4200000, signing_bonus = 0, total_value = 25200000,
  term_years = 6, expiry_year = '2031-32', status = 'UFA', contract_type = 'Standard Contract'
where team_id = 'MTL' and name = 'Zack Bolduc';

update players set
  cap_hit = 1500000, salary = 1500000, signing_bonus = 0, total_value = 1500000,
  term_years = 1, expiry_year = '2026-27', status = 'RFA', contract_type = 'Standard Contract'
where team_id = 'MTL' and name = 'Arber Xhekaj';
