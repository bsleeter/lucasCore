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
