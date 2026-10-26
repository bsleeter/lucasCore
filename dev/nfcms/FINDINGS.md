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


## Pool definitions (corrected 2026-10-26)

The LUCAS stock groups do not pool the dead matter the way stage 3 matches it to FIA (src/dom.R FIA_DOM). The comparisons below use
stage 3's pooling, which also matches FIA's definitions (FIA litter = the forest floor, litter + duff):

| Pool | Stage 3 / FIA match (used here) | LUCAS stock group |
| --- | --- | --- |
| Standing dead | Snag Stem + Snag Branch | DOM: Standing Deadwood (same) |
| Down dead | AG Medium + AG Fast | DOM: Down Deadwood = AG Medium + BG Fast |
| Litter (forest floor) | AG Very Fast + AG Slow | DOM: Litter = AG Fast + AG Very Fast |
| Soil (vs FIA) | BG Slow + BG Very Fast + Deep Soil | DOM: Soil = these + AG Slow |

An earlier version of these notes used the LUCAS groups and wrongly found mature-stand down dead at a third of FIA's: fine woody
debris (AG Fast) had moved to litter and humus (AG Slow) to soil. The NFCMS comparison above keeps the LUCAS groups (NFCMS soil
includes the organic layer).

## Why roots, foliage and dead wood differ: FIA as referee (02-pools-fia.R, out/pools-by-type.csv)

FIA plots in P26's 14 counties (USGS table, latest visit per condition, 2001-2019, 2,059 conditions) against the run's 2020 forest
cells and NFCMS 2020, Mg C/ha:

| Pool, all forest | FIA plots | lucasCore 2020 | NFCMS 2020 |
| --- | --- | --- | --- |
| Live wood (aboveground, no foliage) | 76.5 | 84.1 | 95.7 |
| Roots + foliage | 20.0 (26% of wood) | 22.4 (27%) | 46.4 (48%) |
| Standing + down dead + forest floor | 33.9 (39.9 with current FIADB down dead) | 42.5 (11.3 + 17.5 + 13.7) | 58.9 (total - live - soil) |
| Mineral soil | 121.5 (FIA's modelled soil organic C) | 68.7 (calibrated to gSSURGO) | 76.6 (organic + mineral) |

- **Roots and foliage: lucasCore matches FIA** (share of wood 0.27 vs 0.26 overall, within 0.01-0.04 for every common type). NFCMS
  carries almost twice FIA's roots and foliage (share 0.39-0.53). FIA's CARBON_BG has no fine roots, but fine roots are a few percent
  of live carbon, so most of the gap is NFCMS's own allocation, not a lucasCore shortfall.
- **Dead wood and forest floor: lucasCore matches FIA in the main types** (Mixed Conifer 56 vs 53, Western Oak 15 vs 15, Ponderosa 28 vs
  29) and is above it overall (42.5 vs 33.9; 39.9 with current FIADB down dead), with more standing dead (11.3 vs 7.2: recent fires) and
  down dead (17.5 vs 14.1). **Low in the high-elevation conifers**: Fir/Spruce/Mountain Hemlock 44 vs 59, Lodgepole 22 vs 38.
- NFCMS's dead pools (total - live - soil, 59) are well above FIA and lucasCore; its pool boundaries (whether its soil includes the forest
  floor) are not documented in the metadata, so this split is approximate.
- **Western Oak**: lucasCore matches FIA in every pool (wood 47 vs 45; roots + foliage 11 vs 10; dead 15 vs 15). NFCMS has 74 wood,
  29 roots + foliage and 44 dead. The oak gap is NFCMS above FIA, not lucasCore below it.
- Of the 59 Mg C/ha total-ecosystem gap to NFCMS, about 24 is roots + foliage and 12 live wood, where NFCMS is above FIA; most of the rest
  is dead matter, where NFCMS is also above FIA.
- Caveats: FIA plot means are for visits centred on ~2010 and weight plots, not area; the run's 2020 includes the 2020 fires (North
  Complex in Plumas and Butte); NFCMS forest extent is larger (27,636 vs 21,394 km2), compared here only where both are forest.

## Dead pools by stand age (03-dead-by-age.R, out/dead-by-age.csv)

FIA plots in P26's counties against the run's 1985 starting stocks and its 2020 stocks, by stage 3's calibration age bands, with stage 3's
pooling. P26's calibration (Build result 2, Mediterranean Mountains): clearcut share of the last disturbance 0.75-1.0 in every type, down
wood decay multipliers 0.5-0.6 in the conifers, forest floor decay 1.3-2.7, snag decay at the upper bound (20) for Western Oak and Tanoak.

| Mg C/ha, all ages | Down FIA | Down 2020 | Floor FIA | Floor 2020 | Standing FIA | Standing 2020 |
| --- | --- | --- | --- | --- | --- | --- |
| California Mixed Conifer | 22.1 | 21.8 | 19.3 | 17.6 | 10.3 | 16.8 |
| Fir/Spruce/Mountain Hemlock | 26.6 | 20.3 | 16.1 | 12.9 | 15.0 | 12.2 |
| Ponderosa Pine | 15.7 | 14.3 | 11.3 | 10.6 | 1.4 | 3.3 |
| Western Oak | 4.2 | 7.7 | 6.1 | 6.3 | 5.4 | 0.7 |

- **Down dead and forest floor match FIA in mature stands of the main types** (Mixed Conifer 60-150 yr: down 17-22 vs 17-28, floor 15-18
  vs 19-20; oldest band 27 vs 25). The model runs high just after a disturbance (Mixed Conifer 0-20 yr: down 25-26 vs 10-13 in 2020,
  58 and 36 in the 1985 starting stocks): the clearcut residue of the spin-up's last disturbance (clearcut share near 1).
- **Fir/Spruce/Mountain Hemlock is low in mid-age stands**: down 16-18 vs 25-28 at 60-100 yr, floor 11-12 vs 16; the oldest band
  matches (31 vs 31). Lodgepole is low overall (22 vs 38 dead + floor).
- **Standing dead matches FIA in mature conifer stands** (within 1-4). The 2020 excess is young, recently burned cells (Mixed Conifer
  0-10 yr: 62 vs 11.5): snags from the 1985-2020 fires. **Western Oak** is the exception: about 0.5 in every band against FIA's 3-12,
  where the calibration put snag decay at its upper bound; its down dead is high instead (7.7 vs 4.2), so the oak fit moved snag carbon
  to the ground.
- Candidate fixes (dev first): fire rather than clearcut as the spin-up's last disturbance where fire is the regime (trims the young-stand
  residue that pushes the fit); separate snag fall from snag decay (one multiplier moves both, and the oak fit sits at its bound);
  look at Fir/Spruce and Lodgepole's mid-age down wood. The down dead target is uncertain: current FIADB is 1/0.7 x the calibrated values.
