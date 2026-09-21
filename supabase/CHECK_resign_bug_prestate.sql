-- READ-ONLY. Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Recovers each affected player's contract as it was immediately BEFORE the
-- buggy propose_resign() overwrote it in place, by pulling it out of the
-- action_snapshots row that was taken right before that mutation (same
-- transaction, so its created_at should be the closest snapshot to the
-- resign_log entry). Doesn't change anything -- just confirms what we'd be
-- restoring before I write the actual fix.

select
  rl.player_name,
  rl.team_id,
  rl.offered_aav as new_aav,
  rl.offered_term_years as new_term_years,
  rl.created_at as resigned_at,
  s.created_at as snapshot_at,
  (select elem->>'cap_hit' from jsonb_array_elements(s.players_json) elem where elem->>'id' = rl.player_id) as pre_cap_hit,
  (select elem->>'salary' from jsonb_array_elements(s.players_json) elem where elem->>'id' = rl.player_id) as pre_salary,
  (select elem->>'signing_bonus' from jsonb_array_elements(s.players_json) elem where elem->>'id' = rl.player_id) as pre_signing_bonus,
  (select elem->>'total_value' from jsonb_array_elements(s.players_json) elem where elem->>'id' = rl.player_id) as pre_total_value,
  (select elem->>'term_years' from jsonb_array_elements(s.players_json) elem where elem->>'id' = rl.player_id) as pre_term_years,
  (select elem->>'expiry_year' from jsonb_array_elements(s.players_json) elem where elem->>'id' = rl.player_id) as pre_expiry_year,
  (select elem->>'status' from jsonb_array_elements(s.players_json) elem where elem->>'id' = rl.player_id) as pre_status,
  (select elem->>'contract_type' from jsonb_array_elements(s.players_json) elem where elem->>'id' = rl.player_id) as pre_contract_type
from resign_log rl
join lateral (
  select *
  from action_snapshots
  where action = 'resign_player'
  order by abs(extract(epoch from (created_at - rl.created_at)))
  limit 1
) s on true
where rl.outcome = 'accepted'
  and (rl.player_name, rl.team_id) in (
    ('Benjamin Kindel', 'PIT'),
    ('Erik Karlsson', 'PIT'),
    ('Evgeni Malkin', 'PIT'),
    ('Sidney Crosby', 'PIT'),
    ('Cody Glass', 'NJD'),
    ('Dawson Mercer', 'NJD')
  )
order by rl.created_at desc;
