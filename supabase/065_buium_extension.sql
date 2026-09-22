-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Zeev Buium (VAN, traded from Minnesota) signs a real extension: 8 years,
-- $75.04M total = $9,380,000 AAV. His current ELC ($967,000 x 1yr) runs
-- through 2026-27, so this queues the same way as the other extensions --
-- effective 2027-28.

delete from pending_contract_extensions where team_id = 'VAN' and player_name = 'Zeev Buium';

insert into pending_contract_extensions (player_name, team_id, effective_season, new_cap_hit, new_term_years, new_expiry_year, new_status)
values ('Zeev Buium', 'VAN', '2027-28', 9380000, 8, '2034-35', 'UFA');
