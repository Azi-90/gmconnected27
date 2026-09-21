-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Two changes:
--
-- 1. Re-signing now needs commissioner sign-off, same as trades and free
--    agent awards. propose_resign() still runs the player-side negotiation
--    (does the player like the money?) but an accepted offer no longer
--    applies itself -- it sits in resign_log with commissioner_status =
--    'pending' until the commissioner approves it (via updating that row,
--    same pattern as trades). Only on approval does the extension actually
--    get queued into pending_contract_extensions.
--
-- 2. Real NHL salary rules, enforced server-side: no AAV below the league
--    minimum ($1,000,000 for 2026-27 per the CBA's scheduled increases), and
--    no AAV above 20% of that season's cap -- applies to both re-signing
--    offers and free agent bids. Also fixes free_agent_offers' term limit:
--    8 years only applies when re-signing with your CURRENT team (already
--    correct in propose_resign) -- a new-team signing is capped at 7.

alter table resign_log add column if not exists commissioner_status text
  check (commissioner_status in ('pending', 'approved', 'rejected'));
alter table resign_log add column if not exists effective_season text;
alter table resign_log add column if not exists new_expiry_year text;

alter table free_agent_offers drop constraint if exists free_agent_offers_term_years_check;
alter table free_agent_offers add constraint free_agent_offers_term_years_check check (term_years between 1 and 7);

create or replace function validate_aav(p_aav bigint)
returns void
language plpgsql
stable
as $$
declare
  cap bigint;
  max_aav bigint;
begin
  select salary_cap into cap from league_state where id = true;
  max_aav := round(cap * 0.20);
  if p_aav < 1000000 then
    raise exception 'AAV must be at least the NHL minimum salary of $1,000,000';
  end if;
  if p_aav > max_aav then
    raise exception 'AAV cannot exceed the NHL max-salary rule of 20%% of the cap ($%)', max_aav;
  end if;
end;
$$;

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
    new_expiry_year := (eff_start + p_term_years) || '-' || lpad(((eff_start + p_term_years + 1) % 100)::text, 2, '0');

    -- Only one live proposal per player at a time -- a fresh accepted offer
    -- supersedes whatever was still sitting in the commissioner's queue.
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

      delete from pending_contract_extensions where team_id = new.team_id and player_name = new.player_name;

      insert into pending_contract_extensions (player_name, team_id, effective_season, new_cap_hit, new_term_years, new_expiry_year, new_status)
      values (new.player_name, new.team_id, new.effective_season, new.offered_aav, new.offered_term_years, new.new_expiry_year, 'UFA');

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

drop trigger if exists resign_log_commissioner_decision on resign_log;
create trigger resign_log_commissioner_decision
  after update on resign_log
  for each row
  execute function apply_resign_commissioner_decision();

create or replace function enforce_free_agent_offer_bounds()
returns trigger
language plpgsql
as $$
begin
  perform validate_aav(new.aav);
  return new;
end;
$$;

drop trigger if exists free_agent_offer_salary_bounds on free_agent_offers;
create trigger free_agent_offer_salary_bounds
  before insert on free_agent_offers
  for each row
  execute function enforce_free_agent_offer_bounds();
