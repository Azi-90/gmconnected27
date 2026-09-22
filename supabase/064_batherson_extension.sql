-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Drake Batherson signs a real extension: 8 years, $10,750,000 AAV. His
-- current deal ($4,980,000 x 1yr) runs through 2026-27, so this queues in
-- the same way as the other recent extensions -- effective 2027-28, not
-- applied to his current contract.

delete from pending_contract_extensions where team_id = 'OTT' and player_name = 'Drake Batherson';

insert into pending_contract_extensions (player_name, team_id, effective_season, new_cap_hit, new_term_years, new_expiry_year, new_status)
values ('Drake Batherson', 'OTT', '2027-28', 10750000, 8, '2034-35', 'UFA');
