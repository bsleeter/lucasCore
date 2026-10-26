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
