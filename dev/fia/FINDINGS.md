# FIA DataMart instead of the USGS condition tables (to-do item 9) - California prototype, 2026-10-26

`01-datamart-ca.R` derives the two condition tables stages 2-4 read (USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds,
USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds) from FIA DataMart CSVs: CA_PLOT, CA_COND, CA_TREE (FIADB 9.5) and
FIADB_REFERENCE (REF_FOREST_TYPE, REF_SPECIES), in Data Sources/FIA/DataMart. Compared condition by condition (compare-ca.csv):

- All 13,164 USGS California conditions are found by PLT_CN + CONDID. Identical: plot ids, INVYR, stand age, forest type group
  (FORTYPCD -> REF_FOREST_TYPE.TYPGRPCD), DSTRBCD1, TRTCD1, and the ecodivision (from the plot's fuzzed LAT/LON in the ecodivision
  map; PLOT has no ECOSUBCD) in 100% of conditions.
- Live trees and merchantable volume: per acre of the condition, each tree x TPA_UNADJ divided by the condition's share of the plot
  size it was measured on (MICRPROP_UNADJ below 5 in, MACRPROP_UNADJ from the plot's MACRO_BREAKPOINT_DIA, else SUBPPROP_UNADJ).
  Dividing by CONDPROP_UNADJ instead was off in 28% of conditions (every multi-condition plot). Within 1%: live aboveground, roots and
  volume 100%, foliage (DRYBIO_FOLIAGE x REF_SPECIES.CARBON_RATIO_LIVE) 99.7%; total live = aboveground + roots + foliage, 99.9%.
- Standing dead (STATUSCD 2, STANDING_DEAD_CD 1): 99.1% within 1%. Understory 100%, litter 98.7%, soil 99.8% (COND columns as they are).
- **Down dead wood: DataMart's CARBON_DOWN_DEAD is 1.4286 x the USGS value (1/0.7) in practically every condition.** Not explained
  yet: either FIADB revised its down dead estimates after February 2024 or the USGS table scaled them. Stage 3 calibrates decay to the
  FIA dead pools, so this matters for carbon.
- DataMart has more conditions: 3,062 from 1994 (California's periodic inventory, not in the USGS table, which starts in 2001), and
  3,215 from 2021-2024 (inventories after the USGS snapshot). Stages 2-4 filter by Growth Options' minimum inventory year anyway.

## FIADB carbon pool definitions and the down dead factor (2026-10-26)

FIADB user guide, database description, COND table - identical wording in v9.2 (April 2024) and v9.4 (August 2025):
- **CARBON_DOWN_DEAD**: woody material **> 3 in (7.6 cm)** in diameter on the ground, **and stumps and their roots > 3 in**. Modelled
  from geographic area, forest type and live tree carbon density (Smith and Heath 2008); not a sum of plot measurements.
- **CARBON_LITTER**: organic material on the forest floor, **including fine woody debris, humus, and fine roots in the organic forest
  floor layer** above mineral soil. Modelled from litter measurements on a subset of plots, area, elevation, forest type group, live tree
  carbon and climate (Domke et al. 2016).
- **CARBON_SOIL_ORG**: fine organic material below the soil surface to 1 m; **does not include roots**. Modelled from soil measurements
  on a subset of plots, with soil order and surficial geology (Domke et al. 2017).
- v9.4's change notes mention no carbon changes. The DataMart files are FIADB 9.5 (April 2026), newer than any guide found.

**The down dead factor is one constant per state, not 0.7** (03-down-dead-by-state.R): current FIADB / USGS table = CA 1.4286, NY 1.4706,
ME 1.2048, CO 1.1111, MN 1.0309, AZ 0.8000, MT 0.7634, GA 4.0000 - the same for every condition in a state (5th = 95th percentile). Litter
and soil also changed in some states (unchanged in only 4-6% of conditions in ME, MN, NY; 86-100% in CA, CO, GA). So FIADB's down dead
estimates were rescaled state by state after February 2024 (and litter and soil revised in some states), undocumented in the v9.4 guide.
A per-state constant looks like the Smith and Heath model being scaled to field measurements (FIA's down woody material plots) state by
state - a hypothesis to confirm from the 9.5 release notes or FIA. Since down dead is modelled from live tree carbon, its rise with stand
age is built into the model, not observed.

### Correction (2026-10-26, later): the per-state factor is more likely in the USGS table, not a FIADB change

No FIADB 9.5 release notes were found. FIA's FIADB update history (apps.fs.usda.gov/fiadb-api/fiadb_update_history) logs no change to
down dead since at least 2017; it does log the NSVB reprocessing (September 2023), litter and soil carbon model updates for 47 states in
November 2023 (not California), and soil lab data added in 2025-2026 for 24 northern states. Domke et al. (2013, PLOS ONE) describe the
national GHG inventory's adjustment of modelled down dead wood by a **state-level ratio of field-measured (P3 down woody material) to
modelled carbon density** - exactly one constant per state. So the likelier reading: **the USGS table holds the field-adjusted values and
current FIADB the raw Smith and Heath model**; USGS / FIADB = the state's field/model ratio: GA 0.25, NY 0.68, CA 0.70, ME 0.83, CO 0.90,
MN 0.97, AZ 1.25, MT 1.31. If so the USGS down dead is the better calibration target, and item 9's DataMart setting should apply per-state
field adjustments (not a single 0.7). To confirm: compute California's field/model ratio from DataMart's down woody material tables
(COND_DWM_CALC) and compare with 0.70. Litter and soil differences in the northern states are probably the November 2023 model update and
the added soil lab data (the USGS table may predate them).

## CONUS comparison (02-compare-conus.R, all 48 states; compare-conus.csv) and the state down dead factors

- DataMart (FIADB 9.5): 897,304 forest conditions in 48 states (inventories 1968-2026); **536,037 of the USGS table's 536,082 conditions
  found (99.99%)**. Within 1%: plot ids, inventory year, ecodivision, stand age 100%; forest type group 99.99%; live aboveground carbon
  and merchantable volume 100%, roots 99.9%, foliage and total live 99.3-99.7%, standing dead 99.9%, understory 99.96%; litter 84% and
  soil 94% (FIA's November 2023 model updates and added soil data); down dead differs by the state factors below.
- Stage 2's fitting data: USGS 185,161 plot-conditions, DataMart 195,786; 138,355 identical (plot, type, age). The rest are newer visits
  (2021-2026) replacing a plot-condition's latest visit, so DataMart curves fit newer data. Reproducing the USGS route exactly would need
  a last-inventory-year setting.
- **Down dead: USGS / FIADB is one constant in every one of the 48 states** (down-dead-state-factors.csv), range 0.17 (NJ) to 2.05 (TN),
  given to two decimals (CA 0.70, GA 0.25, TX 1.93; NV, NM and WY share 1.136). Round, published-looking state values, three western states
  sharing one: consistent with the national GHG inventory's state field/model adjustment (Domke et al. 2013), with a regional value where
  a state's down woody material sample is small. So item 9's DataMart route should apply these per-state factors (shipped as a package
  default) rather than a single 0.7, to reproduce the USGS route; confirm against COND_DWM_CALC for one state.

## Measured dead carbon from FIA's down woody material plots (05-dwm-mixed-conifer.R, out-dwm/)

California COND_DWM_CALC (2001-2025), components matched to CBM pools: coarse woody debris >= 3 in + slash piles -> AG Medium; fine woody
debris < 3 in -> AG Fast; litter -> AG Very Fast; duff -> AG Slow; standing dead trees -> snags. DWM conditions per P26 type: Mixed Conifer
3,422 (3,413 in M260), Western Oak 3,939, Ponderosa 1,150, Fir/Spruce/MH 904, Lodgepole 83; with a recorded fire at the plot location
483 / 531 / 115 / 79 / 3, with a recorded harvest 691 / 202 / 300 / 110 / 2.

California Mixed Conifer, M260 (3,312 aged conditions), Mg C/ha by stand age:

| Age | Standing dead | Coarse woody debris + piles | Fine woody debris | Litter | Duff | Modelled down dead (x 0.70) | Modelled litter |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0-20 | 8.4 | 10.2 | 4.0 | 6.7 | 2.8 | 11.9 | 13.8 |
| 20-40 | 1.6 | 7.8 | 2.4 | 8.1 | 5.8 | 13.1 | 16.5 |
| 60-80 | 5.5 | 8.5 | 3.1 | 9.3 | 8.8 | 18.0 | 18.4 |
| 100-150 | 13.2 | 10.9 | 3.0 | 8.8 | 6.7 | 25.5 | 19.0 |
| 150-300 | 19.0 | 13.6 | 2.5 | 7.5 | 6.5 | 27.1 | 19.0 |

- **Measured coarse woody debris is about half the modelled down dead in mature stands** (9-14 vs 18-27) and only slowly rises with age;
  young stands carry a legacy (10.2 at 0-20 yr, dipping to 7.8). The model's down dead also counts stumps and their roots, which the
  transects do not measure, but that cannot explain a factor of two.
- Fine woody debris is small and flat (2.3-3.1; 4.0 in young stands). Litter (6.7-9.3) and duff (2.8-8.8) give a forest floor of 9-17,
  below the modelled 14-19.
- **The post-disturbance legacy is measurable.** By years since the last recorded fire at the plot: standing dead 28-32 in the first 10
  years, 17 at 10-20 years; coarse woody debris rising 9 -> 13 as snags fall; forest floor low (7, burned) and recovering. Since harvest:
  standing dead 5-9, coarse woody debris about 10, forest floor intact (12-15). This is the fire-last / clearcut-last distinction the
  spin-up makes, observed directly.
- So measured targets would ask for much less down wood in mature stands than the calibration targets today, which removes the need for
  the very slow down wood decay (0.25-0.30) that inflates young stands.
