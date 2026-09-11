-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- These 9 players were confirmed signed since Aug 31, 2026 but weren't already
-- rostered anywhere in this database, so 036 deliberately left them out (there
-- was nothing to "correct" -- they needed to be added as new rows instead).
-- Bio and contract data pulled from puckpedia.com player pages.
--
-- A few jersey numbers weren't listed on their PuckPedia profile (brand new
-- signings, team hasn't issued a number yet in their system) -- those are
-- best-effort placeholders and purely cosmetic; nothing else depends on them.

insert into players (
  id, team_id, name, number, position, shoots, height, weight, born, birthplace,
  contract_type, cap_hit, salary, signing_bonus, total_value, clause, term_years, expiry_year, status
) values
  ('edm-formenton', 'EDM', 'Alex Formenton', 26, 'LW', 'L', '6''3"', 194, 'Sep 13, 1999', 'Barrie, ON, CAN',
    'Two-Way Contract', 850000, 850000, 0, 850000, '—', 1, '2026-27', 'UFA'),

  ('sjs-samsonov', 'SJS', 'Ilya Samsonov', 40, 'G', 'L', '6''3"', 205, 'Feb 22, 1997', 'Magnitogorsk, RUS',
    'Two-Way Contract', 850000, 850000, 0, 850000, '—', 1, '2026-27', 'UFA'),

  ('nyr-tolvanen', 'NYR', 'Eeli Tolvanen', 82, 'LW', 'L', '5''10"', 183, 'Apr 22, 1999', 'Vihti, FIN',
    'Standard Contract', 1500000, 1500000, 0, 1500000, '—', 1, '2026-27', 'UFA'),

  ('car-poj', 'CAR', 'Pierre-Olivier Joseph', 44, 'D', 'L', '6''2"', 185, 'Jul 1, 1999', 'Laval, QC, CAN',
    'Standard Contract', 850000, 850000, 0, 850000, '—', 1, '2026-27', 'UFA'),

  ('car-primeau', 'CAR', 'Cayden Primeau', 30, 'G', 'L', '6''3"', 203, 'Aug 11, 1999', 'Farmington Hills, MI, USA',
    'Standard Contract', 912500, 912500, 0, 1825000, '—', 2, '2027-28', 'UFA'),

  ('car-robidas', 'CAR', 'Justin Robidas', 46, 'C', 'R', '5''8"', 176, 'Mar 13, 2003', 'Plano, TX, USA',
    'Two-Way Contract', 850000, 850000, 0, 850000, '—', 1, '2026-27', 'RFA'),

  ('car-brindamour', 'CAR', 'Skyler Brind''Amour', 76, 'C', 'L', '6''3"', 190, 'Jul 27, 1999', 'Raleigh, NC, USA',
    'Two-Way Contract', 850000, 850000, 0, 850000, '—', 1, '2026-27', 'UFA'),

  ('car-reilly', 'CAR', 'Mike Reilly', 6, 'D', 'L', '6''2"', 192, 'Jul 13, 1993', 'Chicago, IL, USA',
    'Standard Contract', 850000, 850000, 0, 850000, '—', 1, '2026-27', 'UFA'),

  ('sea-melanson', 'SEA', 'Jacob Melanson', 63, 'RW', 'R', '6''1"', 205, 'Apr 22, 2003', 'Halifax, NS, CAN',
    'Standard Contract', 1450000, 1450000, 0, 4350000, '—', 3, '2028-29', 'RFA'),

  ('tor-brisson', 'TOR', 'Brendan Brisson', 91, 'LW', 'L', '6''0"', 192, 'Oct 22, 2001', 'Manhattan Beach, CA, USA',
    'Two-Way Contract', 850000, 850000, 0, 850000, '—', 1, '2026-27', 'UFA')
on conflict (id) do nothing;

-- Still not added, on purpose:
--   Tyson Jost (NSH) and Kole Lind (TBL) -- both signed Professional Tryout
--     Agreements (PTOs), not contracts. A PTO doesn't guarantee a roster spot,
--     so adding them as rostered players would overstate what's actually
--     confirmed. Revisit once/if either one earns a real contract out of camp.
