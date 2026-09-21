-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Free agency becomes blind, timed bidding: offers on a free agent are hidden
-- from every other team while they're still pending, and every night at
-- 12:00 AM EST a job ranks all outstanding offers per free agent and marks
-- the highest AAV as "leading" (the rest become "outbid"). That doesn't sign
-- anyone by itself -- the commissioner still has to click Award on the
-- leading offer, same as every other transaction in this app. Once an offer
-- is resolved (leading/outbid/awarded/declined) it becomes visible to
-- everyone, so bids only stay secret while they're still live.
--
-- Note on the schedule: pg_cron schedules are in UTC and don't shift for
-- daylight saving. 05:00 UTC is 12:00 AM EST (UTC-5, standard time) but
-- 1:00 AM EDT during daylight saving (roughly mid-March to early November).
-- If you want it to hold at exactly 12:00 AM local through DST too, say so
-- and I'll add the twice-yearly schedule swap -- left simple for now.

-- 1. Widen the status values to add the two new "in progress" states.
alter table free_agent_offers drop constraint if exists free_agent_offers_status_check;
alter table free_agent_offers add constraint free_agent_offers_status_check
  check (status in ('pending', 'leading', 'outbid', 'awarded', 'declined'));

-- 2. Blind bidding: a pending offer is only visible to its own team (and the
-- commissioner). Once it's resolved to any other status, everyone can see it.
drop policy if exists "free agent offers are publicly readable" on free_agent_offers;
create policy "pending offers are blind, resolved offers are public"
  on free_agent_offers for select
  using (
    status <> 'pending'
    or is_commissioner()
    or exists (select 1 from team_claims tc where tc.user_id = auth.uid() and tc.team_id = team_id)
  );

-- 3. Awarding an offer must also clear out any "outbid" siblings, not just
-- "pending" ones, now that nightly resolution can put offers in that state.
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
  end if;
  return new;
end;
$$;

-- 4. The nightly resolver: for every unsigned free agent, rank all of their
-- still-live offers (pending/leading/outbid -- everything short of a final
-- awarded/declined) by AAV, highest first, tie broken by whoever bid first.
-- Top bid becomes "leading", everyone else becomes "outbid". Purely
-- informational -- no roster changes happen here, so this intentionally
-- isn't snapshotted for undo (it runs unattended every night; consuming the
-- app's single undo slot with an automatic action would make it too easy to
-- accidentally undo something a commissioner did on purpose earlier that day).
create or replace function resolve_nightly_free_agency()
returns void
language plpgsql
security definer
as $$
begin
  with ranked as (
    select
      o.id,
      row_number() over (
        partition by o.free_agent_id
        order by o.aav desc, o.created_at asc
      ) as rnk
    from free_agent_offers o
    join free_agents fa on fa.id = o.free_agent_id and fa.signed_by_team_id is null
    where o.status in ('pending', 'leading', 'outbid')
  )
  update free_agent_offers o
  set status = case when r.rnk = 1 then 'leading' else 'outbid' end
  from ranked r
  where o.id = r.id;
end;
$$;

-- 5. Lets the Free Agency page show "N blind bids in progress" per free
-- agent without revealing any amount -- just a count, safe to expose to
-- everyone regardless of the blind-bidding RLS policy above.
create or replace function pending_offer_counts()
returns table(free_agent_id text, pending_count bigint)
language sql
security definer
stable
as $$
  select free_agent_id, count(*) as pending_count
  from free_agent_offers
  where status = 'pending'
  group by free_agent_id;
$$;

-- 6. Schedule it. Requires the pg_cron extension -- this statement enables it,
-- but if your Supabase plan needs it turned on from the dashboard first
-- (Database -> Extensions -> pg_cron), do that, then re-run from here down.
create extension if not exists pg_cron;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'resolve-free-agency-nightly') then
    perform cron.unschedule('resolve-free-agency-nightly');
  end if;
end;
$$;

select cron.schedule(
  'resolve-free-agency-nightly',
  '0 5 * * *',
  $$select resolve_nightly_free_agency();$$
);
