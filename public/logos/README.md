# Team logos

Drop a logo image for each team into this folder, named by team ID
(the same IDs used in `src/data/teams.ts`), e.g.:

```
public/logos/CAR.svg   (or CAR.png)
public/logos/OTT.svg
public/logos/TOR.png
```

The app checks for `{ID}.svg` first, then `{ID}.png`, and falls back to the
colored circle badge automatically if neither file exists. No code changes
needed — just add the files and reload.

All 32 team IDs: BOS BUF DET FLA MTL OTT TBL TOR CAR CBJ NJD NYI NYR PHI PIT
WSH CHI COL DAL MIN NSH STL UTA WPG ANA CGY EDM LAK SJS SEA VAN VGK

Note: these are the NHL's trademarked logos. This app doesn't ship any —
source them yourself for private league use.
