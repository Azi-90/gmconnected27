-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Simplified RFA rule: an outside team's offer on a restricted free agent
-- can't be awarded until the original team (free_agents.last_team_id) waives
-- their right of first refusal. The original team can always re-sign their
-- own RFA regardless of waiver state — this only blocks awarding SOMEONE
-- ELSE's offer. No qualifying-offer amounts or compensation picks, per your
-- call to keep this simple.

alter table free_agents add column if not exists rfa_waived boolean not null default false;

create or replace function waive_rfa_rights(p_free_agent_id text)
returns void
language plpgsql
security definer
as $$
declare
  fa free_agents;
begin
  select * into fa from free_agents where id = p_free_agent_id;
  if fa is null then
    raise exception 'Free agent not found';
  end if;

  if not (
    is_commissioner()
    or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = fa.last_team_id)
  ) then
    raise exception 'Only the original team or the commissioner can waive RFA rights';
  end if;

  update free_agents set rfa_waived = true where id = p_free_agent_id;
end;
$$;

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
    where free_agent_id = new.free_agent_id and id <> new.id and status = 'pending';
  end if;
  return new;
end;
$$;
