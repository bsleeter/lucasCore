# P26 historical run vs NFCMS v3.0, 2020 (validation) - 2026-10-26

`01-p26-2020.R`: result 14 (P26 historical run, 150 m, iteration average) against NFCMS 3.0 (RDS-2025-0019, PSW, 30 m averaged over each
cell's forest pixels), on cells forest in both (20,420 km2). Outputs in dev/nfcms/out.

| Pool (2020) | lucasCore Tg C | NFCMS Tg C | ratio | Mg C/ha (lucas / NFCMS) | cell correlation |
| --- | --- | --- | --- | --- | --- |
| Live biomass (above + below, leaves, fine roots) | 218.8 | 291.9 | 0.75 | 107 / 143 | 0.82 |
| Aboveground woody (no leaves) | 172.8 | 196.7 | 0.88 | 85 / 96 | 0.81 |
| Soil (organic + mineral) | 168.0 | 156.9 | 1.07 | 82 / 77 | 0.51 |
| Total ecosystem | 449.0 | 569.8 | 0.79 | 220 / 279 | 0.78 |

- Where carbon is placed agrees well (live r = 0.82); the levels differ.
- Aboveground wood is 12% lower; most of the live gap is roots and foliage: live minus aboveground wood is 22 Mg C/ha in lucasCore
  (27% of wood) and 47 in NFCMS (48% of wood).
- Dead wood and litter (total - live - soil): 30 Mg C/ha in lucasCore, 59 in NFCMS.
- Soil: 7% higher in lucasCore (calibrated to gSSURGO), weakly correlated (0.51).
- By type, the largest live gaps are Western Oak (58 vs 104 Mg C/ha), Pinyon/Juniper and Ponderosa Pine; California Mixed Conifer is
  closest (128 vs 157). Every county is low (total ecosystem ratio 0.74-0.94).
- Forest area: lucasCore's 2020 forest state classes cover 21,394 km2, NFCMS forest pixels 27,636 km2 (20,420 in both).

## Why roots, foliage and dead wood differ: FIA as referee (02-pools-fia.R, out/pools-by-type.csv)

FIA plots in P26's 14 counties (USGS table, latest visit per condition, 2001-2019, 2,059 conditions) against the run's 2020 forest
cells and NFCMS 2020, Mg C/ha:

| Pool, all forest | FIA plots | lucasCore 2020 | NFCMS 2020 |
| --- | --- | --- | --- |
| Live wood (aboveground, no foliage) | 76.5 | 84.1 | 95.7 |
| Roots + foliage | 20.0 (26% of wood) | 22.4 (27%) | 46.4 (48%) |
| Standing dead + down dead + litter | 33.9 (39.9 with current FIADB down dead) | 30.3 | 58.9 |
| Soil | 121.5 (FIA's modelled soil organic C) | 82.1 (calibrated to gSSURGO) | 76.6 |

- **Roots and foliage: lucasCore matches FIA** (share of wood 0.27 vs 0.26 overall, and within 0.01-0.04 for every common type).
  NFCMS's live biomass carries almost twice FIA's roots and foliage (share 0.39-0.53 by type). FIA's CARBON_BG has no fine roots,
  which NFCMS includes, but fine roots are a few percent of live carbon, so most of the gap is NFCMS's own allocation (CASA), not a
  lucasCore shortfall.
- **Dead wood and litter: NFCMS is 1.7x FIA; lucasCore is 0.9x FIA overall but low in the high-elevation conifers** (Fir/Spruce/
  Mountain Hemlock 32 vs 59, Lodgepole 15 vs 38, Ponderosa 18 vs 29, Mixed Conifer 41 vs 53). Split: lucasCore has more standing dead
  than FIA (11.3 vs 7.2) and less down dead (9.1 vs 14.1, or 20.2 with FIADB's current values) and litter (9.8 vs 12.6). Worth a look
  at stage 3's decay calibration per type, and the down dead factor (item 9) sets the target.
- **Soil**: lucasCore and NFCMS agree (82 vs 77); FIA's modelled soil organic carbon is higher (121).
- **Western Oak**: lucasCore matches FIA (wood 47 vs 45; roots + foliage 11 vs 10; dead 9 vs 15). NFCMS has 74 wood (+60% over FIA),
  29 roots + foliage and 44 dead (3x FIA). The oak gap is NFCMS above FIA, not lucasCore below it.
- So of the 59 Mg C/ha total-ecosystem gap to NFCMS, about 24 is roots + foliage and 29 dead wood + litter, both where NFCMS is well
  above FIA's own plot estimates; 12 is live wood (NFCMS above both); soil goes the other way (-5).
- Caveats: FIA plot means are for visits centred on ~2010 and weight plots, not area; the run's 2020 includes the 2020 fires (North
  Complex in Plumas and Butte); NFCMS forest extent is larger (27,636 vs 21,394 km2), compared here only where both are forest.
