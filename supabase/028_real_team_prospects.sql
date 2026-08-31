-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Replaces the procedurally-generated team_prospects with each team's real,
-- researched top organizational prospects as of August 2026 — sourced from
-- Elite Prospects, Daily Faceoff's prospect pool breakdowns, The Athletic,
-- DobberProspects, and team beat coverage. Utah has 4 instead of 5: their
-- apparent 5th (Cole Beaudoin) turned out to already be a real New York
-- Rangers prospect surfaced independently by the Metro division research
-- pass, so it was dropped rather than risk inserting the wrong team.
--
-- ovr_low/ovr_high are derived from the potential tier (not researched —
-- there's no real public "overall" number for prospects), consistent with
-- how the shared draft board's ranges work:
--   Elite 80-88 · Top 6 / Top 4D 74-81 · Starter 72-79 · Middle 6 / Bottom Pair 65-74

delete from team_prospects where true;

insert into team_prospects (team_id, name, position, height, weight, nationality, club, league, potential, ovr_low, ovr_high, readiness) values
-- Atlantic
('BOS', 'James Hagens', 'C', '5''11"', 177, 'USA', 'Providence Bruins', 'AHL', 'Elite', 80, 88, 'NHL Ready'),
('BOS', 'Dean Letourneau', 'C', '6''7"', 229, 'USA', 'Boston College', 'NCAA', 'Top 6', 74, 81, '2 Years Away'),
('BOS', 'Will Zellers', 'LW', '5''10"', 176, 'USA', 'University of North Dakota', 'NCAA', 'Middle 6', 67, 74, '1 Year Away'),
('BOS', 'Dans Ločmelis', 'C', '6''1"', 179, 'LAT', 'Providence Bruins', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('BOS', 'Cooper Simpson', 'LW', '6''0"', 180, 'USA', 'University of North Dakota', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),

('BUF', 'Konsta Helenius', 'C', '5''11"', 190, 'FIN', 'Rochester Americans', 'AHL', 'Top 6', 74, 81, 'NHL Ready'),
('BUF', 'Daxon Rudolph', 'D', '6''2"', 202, 'CAN', 'University of Denver', 'NCAA', 'Top 4D', 74, 81, '2 Years Away'),
('BUF', 'Radim Mrtka', 'D', '6''6"', 207, 'CZE', 'Rochester Americans', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
('BUF', 'Ilia Morozov', 'C', '6''3"', 205, 'RUS', 'Miami University', 'NCAA', 'Top 6', 74, 81, '2 Years Away'),
('BUF', 'Brodie Ziemer', 'RW', '5''11"', 190, 'USA', 'University of Minnesota', 'NCAA', 'Middle 6', 67, 74, '1 Year Away'),

('DET', 'Trey Augustine', 'G', '6''1"', 183, 'USA', 'Grand Rapids Griffins', 'AHL', 'Starter', 72, 79, 'NHL Ready'),
('DET', 'Michael Brandsegg-Nygård', 'RW', '6''1"', 207, 'NOR', 'Grand Rapids Griffins', 'AHL', 'Top 6', 74, 81, 'NHL Ready'),
('DET', 'Carter Bear', 'LW', '6''0"', 180, 'CAN', 'Grand Rapids Griffins', 'AHL', 'Top 6', 74, 81, 'NHL Ready'),
('DET', 'J.P. Hurlbert', 'LW', '6''0"', 183, 'USA', 'University of Michigan', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),
('DET', 'Nate Danielson', 'C', '6''2"', 187, 'CAN', 'Grand Rapids Griffins', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),

('FLA', 'Simas Ignatavičius', 'RW', '6''3"', 201, 'LTU', 'Geneve-Servette', 'NL', 'Middle 6', 67, 74, '2 Years Away'),
('FLA', 'Ryder Cali', 'C', '6''2"', 209, 'CAN', 'Providence College', 'NCAA', 'Top 6', 74, 81, '2 Years Away'),
('FLA', 'Jack Devine', 'RW', '6''0"', 181, 'USA', 'Charlotte Checkers', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),
('FLA', 'Gracyn Sawchyn', 'C', '5''11"', 157, 'CAN', 'Charlotte Checkers', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('FLA', 'Marek Alscher', 'D', '6''3"', 205, 'CZE', 'Charlotte Checkers', 'AHL', 'Bottom Pair', 65, 72, '1 Year Away'),

('MTL', 'Michael Hage', 'C', '6''1"', 187, 'CAN', 'University of Michigan', 'NCAA', 'Elite', 80, 88, '1 Year Away'),
('MTL', 'Alexander Zharovsky', 'RW', '6''1"', 163, 'RUS', 'Salavat Yulaev Ufa', 'KHL', 'Top 6', 74, 81, '2 Years Away'),
('MTL', 'Jacob Fowler', 'G', '6''2"', 211, 'USA', 'Laval Rocket', 'AHL', 'Starter', 72, 79, 'NHL Ready'),
('MTL', 'Gleb Pugachyov', 'RW', '6''3"', 200, 'RUS', 'Torpedo Nizhny Novgorod', 'KHL', 'Top 6', 74, 81, '2 Years Away'),
('MTL', 'David Reinbacher', 'D', '6''3"', 209, 'AUT', 'Laval Rocket', 'AHL', 'Top 4D', 74, 81, 'NHL Ready'),

('OTT', 'Carter Yakemchuk', 'D', '6''3"', 219, 'CAN', 'Belleville Senators', 'AHL', 'Top 4D', 74, 81, 'NHL Ready'),
('OTT', 'Logan Hensler', 'D', '6''2"', 197, 'USA', 'University of Wisconsin', 'NCAA', 'Top 4D', 74, 81, '1 Year Away'),
('OTT', 'Kasper Halttunen', 'RW', '6''4"', 205, 'FIN', 'Belleville Senators', 'AHL', 'Top 6', 74, 81, 'NHL Ready'),
('OTT', 'Jaxon Cover', 'LW', '6''1"', 185, 'CAN', 'London Knights', 'OHL', 'Middle 6', 67, 74, '2 Years Away'),
('OTT', 'Jonas Lagerberg Hoen', 'RW', '6''3"', 185, 'SWE', 'Leksands IF', 'SHL', 'Middle 6', 67, 74, '2 Years Away'),

('TBL', 'Sam O''Reilly', 'C', '6''1"', 183, 'CAN', 'Syracuse Crunch', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),
('TBL', 'Benjamin Rautiainen', 'C', '6''0"', 174, 'FIN', 'Syracuse Crunch', 'AHL', 'Top 6', 74, 81, '1 Year Away'),
('TBL', 'Ethan Gauthier', 'RW', '5''11"', 183, 'CAN', 'Syracuse Crunch', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),
('TBL', 'Ethan Czata', 'C', '6''2"', 179, 'CAN', 'Guelph Storm', 'OHL', 'Middle 6', 67, 74, '2 Years Away'),
('TBL', 'Dylan Duke', 'LW', '5''10"', 184, 'USA', 'Syracuse Crunch', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),

('TOR', 'Gavin McKenna', 'LW', '6''0"', 165, 'CAN', 'Penn State Nittany Lions', 'NCAA', 'Elite', 80, 88, 'NHL Ready'),
('TOR', 'Ben Danford', 'D', '6''2"', 192, 'CAN', 'Toronto Marlies', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
('TOR', 'Artur Akhtyamov', 'G', '6''2"', 176, 'RUS', 'Toronto Marlies', 'AHL', 'Starter', 72, 79, '1 Year Away'),
('TOR', 'Tinus Luc Koblar', 'C', '6''2"', 176, 'NOR', 'Rögle BK', 'SHL', 'Middle 6', 67, 74, '2 Years Away'),
('TOR', 'Miroslav Holinka', 'C', '6''1"', 185, 'CZE', 'Toronto Marlies', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),

-- Metropolitan
('CAR', 'Bradly Nadeau', 'LW', '5''10"', 161, 'CAN', 'Chicago Wolves', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),
('CAR', 'Felix Unger Sörum', 'RW', '5''11"', 172, 'SWE', 'Chicago Wolves', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('CAR', 'William Håkansson', 'D', '6''4"', 207, 'SWE', 'Luleå HF', 'SHL', 'Bottom Pair', 65, 72, '2 Years Away'),
('CAR', 'Semyon Frolov', 'G', '6''3"', 203, 'RUS', 'Spartak Moskva', 'MHL', 'Starter', 72, 79, '2 Years Away'),
('CAR', 'Ivan Ryabkin', 'LW', '5''11"', 205, 'RUS', 'Charlottetown Islanders', 'QMJHL', 'Middle 6', 67, 74, '2 Years Away'),

('CBJ', 'Jackson Smith', 'D', '6''4"', 198, 'CAN', 'Tri-City Americans', 'WHL', 'Top 4D', 74, 81, '2 Years Away'),
('CBJ', 'Cayden Lindstrom', 'C', '6''4"', 216, 'CAN', 'Michigan State University', 'NCAA', 'Top 6', 74, 81, '2 Years Away'),
('CBJ', 'Pyotr Andreyanov', 'G', '6''2"', 207, 'RUS', 'Zvezda Moskva', 'VHL', 'Starter', 72, 79, '2 Years Away'),
('CBJ', 'Luca Del Bel Belluz', 'C', '6''1"', 185, 'CAN', 'Cleveland Monsters', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),
('CBJ', 'Oscar Hemming', 'LW', '6''4"', 198, 'FIN', 'Boston College', 'NCAA', 'Top 6', 74, 81, '2 Years Away'),

('NJD', 'Mikhail Yegorov', 'G', '6''5"', 181, 'RUS', 'Boston University', 'NCAA', 'Starter', 72, 79, '1 Year Away'),
('NJD', 'Anton Silayev', 'D', '6''7"', 207, 'RUS', 'Utica Comets', 'AHL', 'Top 4D', 74, 81, 'NHL Ready'),
('NJD', 'Alexander Command', 'C', '6''1"', 187, 'SWE', 'Örebro HK', 'SHL', 'Middle 6', 67, 74, '2 Years Away'),
('NJD', 'Seamus Casey', 'D', '5''10"', 180, 'USA', 'Utica Comets', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
('NJD', 'Matias Vanhanen', 'LW', '5''11"', 176, 'FIN', 'Everett Silvertips', 'WHL', 'Middle 6', 67, 74, '2 Years Away'),

('NYI', 'Victor Eklund', 'LW', '5''11"', 161, 'SWE', 'Hamilton Hammers', 'AHL', 'Top 6', 74, 81, 'NHL Ready'),
('NYI', 'Malte Gustafsson', 'D', '6''4"', 201, 'SWE', 'HV71', 'SHL', 'Top 4D', 74, 81, '2 Years Away'),
('NYI', 'Kashawn Aitcheson', 'D', '6''2"', 196, 'CAN', 'Hamilton Hammers', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
('NYI', 'Cole Eiserman', 'LW', '6''0"', 196, 'USA', 'Hamilton Hammers', 'AHL', 'Top 6', 74, 81, '1 Year Away'),
('NYI', 'Danny Nelson', 'C', '6''3"', 220, 'USA', 'University of Notre Dame', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),

('NYR', 'Alberts Smits', 'D', '6''3"', 209, 'LAT', 'Jukurit', 'Liiga', 'Top 4D', 74, 81, '2 Years Away'),
('NYR', 'Liam Greentree', 'RW', '6''3"', 216, 'CAN', 'Hartford Wolf Pack', 'AHL', 'Top 6', 74, 81, '1 Year Away'),
('NYR', 'Cole Beaudoin', 'C', '6''2"', 209, 'CAN', 'Hartford Wolf Pack', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),
('NYR', 'Malcolm Spence', 'LW', '6''2"', 201, 'CAN', 'University of Michigan', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),
('NYR', 'E.J. Emery', 'D', '6''3"', 185, 'USA', 'University of North Dakota', 'NCAA', 'Top 4D', 74, 81, '2 Years Away'),

('PHI', 'Porter Martone', 'RW', '6''3"', 214, 'CAN', 'Philadelphia Flyers', 'NHL', 'Elite', 80, 88, 'NHL Ready'),
('PHI', 'Jett Luchanko', 'C', '5''11"', 180, 'CAN', 'Lehigh Valley Phantoms', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('PHI', 'Oliver Bonk', 'D', '6''2"', 176, 'CAN', 'Lehigh Valley Phantoms', 'AHL', 'Top 4D', 74, 81, 'NHL Ready'),
('PHI', 'Jack Berglund', 'C', '6''2"', 209, 'SWE', 'Färjestad BK', 'SHL', 'Middle 6', 67, 74, '2 Years Away'),
('PHI', 'Jack Nesbitt', 'C', '6''4"', 185, 'CAN', 'Windsor Spitfires', 'OHL', 'Top 6', 74, 81, '2 Years Away'),

('PIT', 'Harrison Brunicke', 'D', '6''3"', 201, 'CAN', 'Wilkes-Barre/Scranton Penguins', 'AHL', 'Top 4D', 74, 81, 'NHL Ready'),
('PIT', 'Rutger McGroarty', 'LW', '6''1"', 212, 'USA', 'Wilkes-Barre/Scranton Penguins', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),
('PIT', 'Will Horcoff', 'LW', '6''5"', 201, 'USA', 'University of Michigan', 'NCAA', 'Top 6', 74, 81, '2 Years Away'),
('PIT', 'Bill Zonnon', 'LW', '6''2"', 187, 'CAN', 'Wilkes-Barre/Scranton Penguins', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('PIT', 'Owen Pickering', 'D', '6''5"', 206, 'CAN', 'Wilkes-Barre/Scranton Penguins', 'AHL', 'Bottom Pair', 65, 72, '1 Year Away'),

('WSH', 'Cole Hutson', 'D', '5''10"', 165, 'USA', 'Boston University', 'NCAA', 'Top 4D', 74, 81, '1 Year Away'),
('WSH', 'Andrew Cristall', 'LW', '5''10"', 183, 'CAN', 'Hershey Bears', 'AHL', 'Top 6', 74, 81, 'NHL Ready'),
('WSH', 'Ilya Protas', 'C', '6''6"', 225, 'BLR', 'Hershey Bears', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('WSH', 'Lynden Lakovic', 'LW', '6''4"', 201, 'CAN', 'Moose Jaw Warriors', 'WHL', 'Middle 6', 67, 74, '2 Years Away'),
('WSH', 'Ivan Miroshnichenko', 'LW', '6''1"', 185, 'RUS', 'Hershey Bears', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),

-- Central
('CHI', 'Anton Frondell', 'C', '6''1"', 196, 'SWE', 'Chicago Blackhawks', 'NHL', 'Top 6', 74, 81, 'NHL Ready'),
('CHI', 'Roman Kantserov', 'RW', '5''9"', 176, 'RUS', 'Chicago Blackhawks', 'NHL', 'Top 6', 74, 81, 'NHL Ready'),
('CHI', 'Nick Lardis', 'RW', '5''11"', 165, 'CAN', 'Chicago Blackhawks', 'NHL', 'Middle 6', 67, 74, 'NHL Ready'),
('CHI', 'Vaclav Nestrasil', 'RW', '6''6"', 205, 'CZE', 'University of Massachusetts', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),
('CHI', 'Xavier Villeneuve', 'D', '5''11"', 163, 'CAN', 'Boston University', 'NCAA', 'Top 4D', 74, 81, '2 Years Away'),

('COL', 'Ilya Nabokov', 'G', '6''1"', 179, 'RUS', 'Metallurg Magnitogorsk', 'KHL', 'Starter', 72, 79, '1 Year Away'),
('COL', 'Egor Shilov', 'C', '6''1"', 176, 'RUS', 'Victoriaville Tigres', 'QMJHL', 'Top 6', 74, 81, '2 Years Away'),
('COL', 'Mikhail Gulyayev', 'D', '5''10"', 183, 'RUS', 'Avangard Omsk', 'KHL', 'Top 4D', 74, 81, '1 Year Away'),
('COL', 'Beckett Hamilton', 'C', '5''11"', 170, 'CAN', 'Red Deer Rebels', 'WHL', 'Middle 6', 67, 74, '2 Years Away'),
('COL', 'Tobias Tvrznik', 'G', '6''4"', 183, 'CZE', 'Wenatchee Wild', 'WHL', 'Starter', 72, 79, '2 Years Away'),

('DAL', 'Emil Hemming', 'RW', '6''2"', 196, 'FIN', 'Texas Stars', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('DAL', 'Cameron Schmidt', 'RW', '5''8"', 161, 'CAN', 'Victoria Royals', 'WHL', 'Top 6', 74, 81, '1 Year Away'),
('DAL', 'Jakub Vanecek', 'D', '6''2"', 198, 'CZE', 'Tri-City Americans', 'WHL', 'Bottom Pair', 65, 72, '2 Years Away'),
('DAL', 'Brandon Gorzynski', 'LW', '6''2"', 185, 'USA', 'Arizona State University', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),
('DAL', 'Tristan Bertucci', 'D', '6''2"', 187, 'CAN', 'Texas Stars', 'AHL', 'Bottom Pair', 65, 72, '1 Year Away'),

('MIN', 'Charlie Stramel', 'C', '6''3"', 216, 'USA', 'Iowa Wild', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('MIN', 'David Spacek', 'D', '6''0"', 190, 'CZE', 'Iowa Wild', 'AHL', 'Bottom Pair', 65, 72, 'NHL Ready'),
('MIN', 'Adam Benak', 'C', '5''8"', 163, 'CZE', 'Western Michigan University', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),
('MIN', 'Adam Andersson', 'C', '6''4"', 190, 'SWE', 'Leksands IF U20', 'J20 Nationell', 'Middle 6', 67, 74, '2 Years Away'),
('MIN', 'Riley Heidt', 'C', '5''11"', 170, 'CAN', 'Iowa Wild', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),

('NSH', 'Wyatt Cullen', 'LW', '6''1"', 176, 'USA', 'University of Minnesota', 'NCAA', 'Top 6', 74, 81, '2 Years Away'),
('NSH', 'Brady Martin', 'C', '6''1"', 190, 'CAN', 'Nashville Predators', 'NHL', 'Middle 6', 67, 74, 'NHL Ready'),
('NSH', 'Ryker Lee', 'LW', '6''0"', 185, 'USA', 'Michigan State University', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),
('NSH', 'Yegor Surin', 'C', '6''1"', 192, 'RUS', 'Lokomotiv Yaroslavl', 'KHL', 'Top 6', 74, 81, '1 Year Away'),
('NSH', 'Cameron Reid', 'D', '6''0"', 183, 'CAN', 'University of Michigan', 'NCAA', 'Top 4D', 74, 81, '2 Years Away'),

('STL', 'Tynan Lawrence', 'C', '6''0"', 185, 'CAN', 'Boston University', 'NCAA', 'Top 6', 74, 81, '2 Years Away'),
('STL', 'Justin Carbonneau', 'RW', '6''1"', 201, 'CAN', 'Springfield Thunderbirds', 'AHL', 'Top 6', 74, 81, '1 Year Away'),
('STL', 'Adam Jiricek', 'D', '6''2"', 180, 'CZE', 'Springfield Thunderbirds', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
('STL', 'Maddox Dagenais', 'C', '6''4"', 196, 'CAN', 'Quebec Remparts', 'QMJHL', 'Top 6', 74, 81, '2 Years Away'),
('STL', 'Otto Stenberg', 'C', '5''11"', 188, 'SWE', 'Springfield Thunderbirds', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),

('UTA', 'Caleb Desnoyers', 'C', '6''2"', 180, 'CAN', 'Moncton Wildcats', 'QMJHL', 'Top 6', 74, 81, '1 Year Away'),
('UTA', 'Daniil But', 'LW', '6''6"', 215, 'RUS', 'Tucson Roadrunners', 'AHL', 'Top 6', 74, 81, 'NHL Ready'),
('UTA', 'Dmitri Simashev', 'D', '6''5"', 200, 'RUS', 'Tucson Roadrunners', 'AHL', 'Top 4D', 74, 81, 'NHL Ready'),
('UTA', 'Tij Iginla', 'LW', '6''0"', 190, 'CAN', 'Kelowna Rockets', 'WHL', 'Top 6', 74, 81, '1 Year Away'),

('WPG', 'Brayden Yager', 'C', '6''0"', 170, 'CAN', 'Manitoba Moose', 'AHL', 'Top 6', 74, 81, 'NHL Ready'),
('WPG', 'Brad Lambert', 'C', '6''1"', 172, 'FIN', 'Manitoba Moose', 'AHL', 'Top 6', 74, 81, 'NHL Ready'),
('WPG', 'Nikita Chibrikov', 'RW', '5''10"', 170, 'RUS', 'Manitoba Moose', 'AHL', 'Middle 6', 67, 74, 'NHL Ready'),
('WPG', 'Colby Barlow', 'LW', '6''1"', 194, 'CAN', 'Manitoba Moose', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('WPG', 'Kieron Walton', 'C', '6''6"', 227, 'CAN', 'Sudbury Wolves', 'OHL', 'Middle 6', 67, 74, '2 Years Away'),

-- Pacific
('ANA', 'Nikita Klepov', 'RW', '6''0"', 180, 'USA', 'Saginaw Spirit', 'OHL', 'Top 6', 74, 81, '2 Years Away'),
('ANA', 'Roger McQueen', 'C', '6''6"', 198, 'CAN', 'San Diego Gulls', 'AHL', 'Top 6', 74, 81, '1 Year Away'),
('ANA', 'Stian Solberg', 'D', '6''2"', 205, 'NOR', 'San Diego Gulls', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
('ANA', 'Lucas Pettersson', 'C', '5''11"', 170, 'SWE', 'San Diego Gulls', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('ANA', 'Herman Träff', 'RW', '6''3"', 216, 'SWE', 'San Diego Gulls', 'AHL', 'Middle 6', 67, 74, '2 Years Away'),

('CGY', 'Carson Carels', 'D', '6''2"', 198, 'CAN', 'University of North Dakota', 'NCAA', 'Top 4D', 74, 81, '2 Years Away'),
('CGY', 'Cole Reschny', 'C', '5''10"', 187, 'CAN', 'University of North Dakota', 'NCAA', 'Top 6', 74, 81, '2 Years Away'),
('CGY', 'Hunter Brzustewicz', 'D', '6''0"', 190, 'USA', 'Calgary Wranglers', 'AHL', 'Top 4D', 74, 81, '1 Year Away'),
('CGY', 'Ethan Wyttenbach', 'LW', '5''11"', 185, 'USA', 'Quinnipiac University', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),
('CGY', 'Tobias Trejbal', 'G', '6''4"', 190, 'CZE', 'University of Massachusetts', 'NCAA', 'Starter', 72, 79, '2 Years Away'),

('EDM', 'Tommy Lafrenière', 'C', '6''0"', 172, 'CAN', 'Western Michigan University', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),
('EDM', 'Rudolfs Bērzkalns', 'C', '6''4"', 204, 'LAT', 'Muskegon Lumberjacks', 'USHL', 'Top 6', 74, 81, '2 Years Away'),
('EDM', 'Samuel Jonsson', 'G', '6''5"', 201, 'SWE', 'Bakersfield Condors', 'AHL', 'Starter', 72, 79, '1 Year Away'),
('EDM', 'Connor Ungar', 'G', '6''2"', 196, 'CAN', 'Bakersfield Condors', 'AHL', 'Starter', 72, 79, '1 Year Away'),
('EDM', 'William Nicholl', 'C', '6''0"', 183, 'CAN', 'London Knights', 'OHL', 'Middle 6', 67, 74, '2 Years Away'),

('LAK', 'Henry Brzustewicz', 'D', '6''2"', 203, 'USA', 'London Knights', 'OHL', 'Top 4D', 74, 81, '2 Years Away'),
('LAK', 'Carter George', 'G', '6''1"', 183, 'CAN', 'Ontario Reign', 'AHL', 'Starter', 72, 79, '1 Year Away'),
('LAK', 'Hampton Slukynsky', 'G', '6''2"', 185, 'USA', 'Ontario Reign', 'AHL', 'Starter', 72, 79, '1 Year Away'),
('LAK', 'Elton Hermansson', 'RW', '6''1"', 183, 'SWE', 'MoDo Hockey', 'Allsvenskan', 'Top 6', 74, 81, '2 Years Away'),
('LAK', 'Vojtech Čihař', 'LW', '6''1"', 181, 'CZE', 'Kelowna Rockets', 'WHL', 'Middle 6', 67, 74, '2 Years Away'),

('SJS', 'Ivar Stenberg', 'LW', '6''0"', 181, 'SWE', 'Frölunda HC', 'SHL', 'Top 6', 74, 81, '2 Years Away'),
('SJS', 'Keaton Verhoeff', 'D', '6''4"', 212, 'CAN', 'University of North Dakota', 'NCAA', 'Top 4D', 74, 81, '2 Years Away'),
('SJS', 'Ryan Lin', 'D', '5''11"', 176, 'CAN', 'Vancouver Giants', 'WHL', 'Top 4D', 74, 81, '2 Years Away'),
('SJS', 'Joshua Ravensbergen', 'G', '6''5"', 190, 'CAN', 'Michigan State University', 'NCAA', 'Starter', 72, 79, '1 Year Away'),
('SJS', 'Quentin Musty', 'LW', '6''2"', 200, 'USA', 'San Jose Barracuda', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),

('SEA', 'Chase Reid', 'D', '6''2"', 187, 'USA', 'Michigan State University', 'NCAA', 'Top 4D', 74, 81, '2 Years Away'),
('SEA', 'Jake O''Brien', 'C', '6''2"', 170, 'CAN', 'Coachella Valley Firebirds', 'AHL', 'Top 6', 74, 81, '1 Year Away'),
('SEA', 'Oscar Fisker Mølgaard', 'C', '6''0"', 168, 'DEN', 'Coachella Valley Firebirds', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('SEA', 'Jagger Firkus', 'RW', '5''11"', 170, 'CAN', 'Coachella Valley Firebirds', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('SEA', 'Casey Mutryn', 'RW', '6''3"', 206, 'USA', 'Boston College', 'NCAA', 'Middle 6', 67, 74, '2 Years Away'),

('VAN', 'Jonathan Lekkerimäki', 'RW', '5''11"', 172, 'SWE', 'Abbotsford Canucks', 'AHL', 'Top 6', 74, 81, 'NHL Ready'),
('VAN', 'Braeden Cootes', 'C', '6''0"', 183, 'CAN', 'Seattle Thunderbirds', 'WHL', 'Top 6', 74, 81, '1 Year Away'),
('VAN', 'Aleksei Medvedev', 'G', '6''3"', 181, 'RUS', 'London Knights', 'OHL', 'Starter', 72, 79, '2 Years Away'),
('VAN', 'Kirill Kudryavtsev', 'D', '5''11"', 201, 'RUS', 'Abbotsford Canucks', 'AHL', 'Bottom Pair', 65, 72, '1 Year Away'),
('VAN', 'Caleb Malhotra', 'C', '6''2"', 182, 'CAN', 'Brantford Bulldogs', 'OHL', 'Top 6', 74, 81, '2 Years Away'),

('VGK', 'Trevor Connelly', 'LW', '6''1"', 185, 'USA', 'Henderson Silver Knights', 'AHL', 'Top 6', 74, 81, '1 Year Away'),
('VGK', 'Matyas Sapovaliv', 'C', '6''4"', 194, 'CZE', 'Henderson Silver Knights', 'AHL', 'Middle 6', 67, 74, '1 Year Away'),
('VGK', 'Mathieu Cataford', 'C', '5''11"', 191, 'CAN', 'Rimouski Océanic', 'QMJHL', 'Middle 6', 67, 74, '2 Years Away'),
('VGK', 'Lukas Cormier', 'D', '5''10"', 176, 'CAN', 'Henderson Silver Knights', 'AHL', 'Bottom Pair', 65, 72, '1 Year Away'),
('VGK', 'Carl Lindbom', 'G', '6''1"', 180, 'SWE', 'Henderson Silver Knights', 'AHL', 'Starter', 72, 79, '1 Year Away');
