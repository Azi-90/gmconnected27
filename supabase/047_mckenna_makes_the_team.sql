-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Same move as Stenberg in 046: Gavin McKenna makes Toronto's opening
-- roster off his real entry-level deal (confirmed via puckpedia.com — and
-- yes, it really is the same contract as Stenberg's: both are 2026 1st-round
-- entry-level max deals, 3yr/$1,075,000 AAV, RFA). He comes off the
-- team_prospects list. Replacing him with Alexander Bilecki (Toronto's 2026
-- 2nd-round pick, ranked #6 on The Hockey Writers' 2026-27 Leafs prospect
-- list), who wasn't already tracked anywhere in this database.

delete from team_prospects where team_id = 'TOR' and name = 'Gavin McKenna';

insert into players (
  id, team_id, name, number, position, shoots, height, weight, born, birthplace,
  contract_type, cap_hit, salary, signing_bonus, total_value, clause, term_years, expiry_year, status, overall
) values (
  'tor-mckenna', 'TOR', 'Gavin McKenna', 92, 'LW', 'L', '5''11"', 170, 'Dec 20, 2007', 'Whitehorse, YT, CAN',
  'Entry-Level Contract', 1075000, 1075000, 0, 3225000, '—', 3, '2028-29', 'RFA', 83
)
on conflict (id) do nothing;

insert into team_prospects (
  team_id, name, position, height, weight, nationality, club, league,
  potential, ovr_low, ovr_high, readiness
) values (
  'TOR', 'Alexander Bilecki', 'D', '6''2"', 181, 'CAN', 'Kitchener Rangers', 'OHL',
  'Bottom Pair', 68, 75, '2 Years Away'
);
