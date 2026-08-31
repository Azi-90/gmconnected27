-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- The actual "advance season" operation, as a single atomic database function so
-- it can't partially apply. expiry_year is the ground truth for when a contract
-- ends (it's a fixed target season like '2027-28') — term_years next to it is
-- informational and just gets decremented for display, it isn't used to decide
-- who expires.

create or replace function advance_season()
returns void
language plpgsql
security definer
as $$
declare
  old_season text;
  old_start_year int;
  new_season text;
begin
  if not is_commissioner() then
    raise exception 'Only the commissioner can advance the season';
  end if;

  select season into old_season from league_state where id = true;
  old_start_year := split_part(old_season, '-', 1)::int;
  new_season := (old_start_year + 1) || '-' || lpad(((old_start_year + 2) % 100)::text, 2, '0');

  -- Contracts whose final season was the one just completed move to free agency.
  -- Age is approximated from the first 4-digit year found in the free-text `born`
  -- field, since it's not a strict date format (e.g. "Aug 8, 2002").
  insert into free_agents (id, name, position, age, last_team_id, last_cap_hit, status)
  select
    'fa-' || p.id,
    p.name,
    p.position,
    greatest(extract(year from now())::int - (regexp_match(p.born, '\d{4}'))[1]::int, 18),
    p.team_id,
    p.cap_hit,
    case when p.status like 'RFA%' then 'RFA' else 'UFA' end
  from players p
  where p.expiry_year = old_season
  on conflict (id) do nothing;

  delete from players where expiry_year = old_season;

  -- Everyone still under contract ages a year (display only, floor of 0).
  update players set term_years = greatest(term_years - 1, 0) where expiry_year <> old_season;

  update league_state
  set season = new_season, draft_class_year = draft_class_year + 1
  where id = true;
end;
$$;
