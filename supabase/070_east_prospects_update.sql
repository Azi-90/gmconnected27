-- Run this in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Eastern Conference prospect pass from the commissioner's own scouting
-- notes (all 16 East teams): potential-tier corrections, graduated/cut
-- prospects removed, and a handful of real new adds (bios verified via
-- research, not guessed). Several teams drop below 5 prospects after these
-- removals -- see the summary after this file for which ones need topping
-- up.

-- === Tier corrections ===
update team_prospects set potential = 'Top 6' where id = 'd1ee3019-2e47-45da-9739-3a38a8ea0bf3';   -- Nate Danielson (DET)
update team_prospects set potential = 'Top 6' where id = '9459f3c0-8408-47dd-bd9e-c09e8b69d057';   -- J.P. Hurlbert (DET)
update team_prospects set potential = 'Elite' where id = '2fc915f3-4e28-418f-b142-6aecfb437ad2';   -- Alexander Zharovsky (MTL)
update team_prospects set potential = 'Elite' where id = '29dc7c1c-4ab6-4bb5-8873-df8403501d53';   -- David Reinbacher (MTL)
update team_prospects set potential = 'Elite' where id = '74a80ac4-e450-4d4a-b893-79ce0f763aa6';   -- Jacob Fowler (MTL)
update team_prospects set potential = 'Top 6' where id = 'fb8ebb65-a727-4b65-afc9-d1381513f2e9';   -- Jaxon Cover (OTT)
update team_prospects set potential = 'Top 6' where id = '68a29368-2801-4f39-b63c-f85fdaf8bb43';   -- Jonas Lagerberg Hoen (OTT)
update team_prospects set potential = 'Top 6' where id = '1a610fee-42d9-4a2a-b25c-3bac7488816c';   -- Sam O'Reilly (TBL)
update team_prospects set potential = 'Top 6' where id = 'e908cabb-db1f-47e7-9782-3bb897fd622e';   -- Tinus Luc Koblar (TOR)
update team_prospects set potential = 'Elite' where id = '7e9b64ba-b584-4f37-836d-9f5a4e2a88d9';   -- Daxon Rudolph (BUF)
update team_prospects set potential = 'Elite' where id = '10025120-6449-460f-bbe8-6030faf61ca3';   -- Konsta Helenius (BUF)
update team_prospects set potential = 'Top 6' where id = '12424360-9142-4ad2-826b-176fe45fe0d1';   -- Bradly Nadeau (CAR)
update team_prospects set potential = 'Top 6' where id = '0ed82f93-6ce9-49ef-a6de-8df1d6af7ac8';   -- Felix Unger Sörum (CAR)
update team_prospects set potential = 'Top 6' where id = 'b383dbd5-ca7d-4088-9e2a-457c2a404e52';   -- Alexander Command (NJD)
update team_prospects set potential = 'Elite' where id = '02bd622c-7e56-49db-a87d-e17180b8f17e';   -- Alberts Smits (NYR)
update team_prospects set potential = 'Top 6' where id = 'f30b2523-6371-4af9-a460-a0b430853b53';   -- Cole Beaudoin (NYR)
update team_prospects set potential = 'Top 6' where id = 'b5940b65-38a7-44fd-b599-1a33b8aa631e';   -- Jett Luchanko (PHI)
update team_prospects set potential = 'Elite' where id = '358b52ea-b44a-414e-aaec-43af7e3ea36b';   -- Cole Hutson (WSH)
update team_prospects set potential = 'Top 6' where id = '6fb23577-f15e-4106-8f5c-90d9a19af535';   -- Ilya Protas (WSH)
update team_prospects set potential = 'Elite' where id = '7dc4654f-fe36-4dae-aafb-273319cadcf9';   -- Victor Eklund (NYI)

-- === Removals (graduated to the main roster, cut, or traded away) ===
delete from team_prospects where id in (
  'a48e4545-960b-42ec-8518-36ab47081625', -- James Hagens (BOS)
  'c8b1c2a4-9760-41df-b918-980ad512e3fc', -- Will Zellers (BOS)
  'dc1ef447-55be-4f39-ba10-bc4bc222282a', -- Dans Ločmelis (BOS)
  'd7192d53-a0ed-45d0-bd21-2fe9b7c91f5d', -- Cooper Simpson (BOS)
  '8a32f736-d2e1-411c-8ff1-c259241793c0', -- Brodie Ziemer (BUF)
  '192ae4c7-3091-4116-abcb-a1a05bbc8394', -- Ivan Ryabkin (CAR)
  '7a22d65b-d61e-43c8-9933-f672002405f5', -- William Håkansson (CAR)
  'c519f6d8-e427-48c0-8167-bf3e90dbff8f', -- Luca Del Bel Belluz (CBJ)
  'ee0cdc55-5a12-48a7-a738-c9a0189bf744', -- Gracyn Sawchyn (FLA)
  '4a2d30d4-e625-486f-a8e8-dd61ffeb0e9f', -- Jack Devine (FLA)
  '7dee383c-8229-426c-96c6-ee179ef6ca4e', -- Marek Alscher (FLA)
  '09a2c366-df34-4366-8a3e-40ec72be64d6', -- Ryder Cali (FLA)
  '45baf745-575c-4f69-959f-5c373e5b07f7', -- Matias Vanhanen (NJD)
  'bdc9fe60-db1e-439c-b624-27bf48bac696', -- Mikhail Yegorov (NJD)
  '2fa155fa-81b6-4f9b-895a-416ee770d396', -- Seamus Casey (NJD)
  '90f17fa6-4618-436c-a805-701d76e66b11', -- Danny Nelson (NYI)
  'e19c3ed8-6028-44a3-9587-48ecfdf7f70d', -- Malcolm Spence (NYR)
  'f802c6eb-4277-4e1d-bc33-1d5601d3da7e', -- Carter Yakemchuk (OTT) -- already on OTT's roster
  'dde99ac8-e25f-476a-86e1-8da7c30086d0', -- Porter Martone (PHI)
  '7dec3a62-16ba-45e6-8beb-d01ab9d84c54', -- Jack Berglund (PHI)
  '080b65f1-c6d7-4ec9-847e-7e0b803467b9', -- Bill Zonnon (PIT)
  '521f193d-4154-4175-89a3-829fd289ef0d', -- Owen Pickering (PIT)
  'cc187143-11fc-4b07-bda5-8355be7bd71b', -- Rutger McGroarty (PIT) -- already on PIT's roster
  '7971b752-c16c-48c6-b673-5b719a0b29ad', -- Dylan Duke (TBL)
  '2108f225-b6b9-49c3-a4e2-1fe3ecceb49a', -- Ethan Czata (TBL)
  'a883214a-2078-4479-a39e-e7e7bfd83566', -- Ethan Gauthier (TBL)
  '99380f21-2012-44b9-9536-cd8b63a79e74', -- Alexander Bilecki (TOR)
  'ac280a18-e6f8-46cd-87ae-d57f21df10f3', -- Ethan MacKenzie (TOR)
  '64c9ba6c-74dd-42b5-a26e-a5f0f8496466', -- Miroslav Holinka (TOR)
  '1f9c2249-ef20-4eba-93ef-1745ce268751'  -- Ivan Miroshnichenko (WSH)
);

-- === New prospects added (real bios, verified via research) ===
insert into team_prospects (team_id, name, position, height, weight, nationality, club, league, potential, ovr_low, ovr_high, readiness)
values
  ('OTT', 'Lucas Beckman', 'G', '6''2"', 194, 'CAN', 'Cape Breton Eagles', 'QMJHL', 'Starter', 72, 79, '2 Years Away'),
  ('PIT', 'Liam Ruck', 'RW', '6''0"', 174, 'CAN', 'Medicine Hat Tigers', 'WHL', 'Top 6', 74, 81, '2 Years Away'),
  ('PIT', 'Markus Ruck', 'C', '6''0"', 168, 'CAN', 'Medicine Hat Tigers', 'WHL', 'Middle 6', 67, 74, '2 Years Away'),
  ('WSH', 'Terik Parascak', 'RW', '6''0"', 190, 'CAN', 'Hershey Bears', 'AHL', 'Top 6', 74, 81, '1 Year Away');
