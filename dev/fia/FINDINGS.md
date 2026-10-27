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

## Decay calibrated to measured pools in mature stands (06-calibrate-measured.R, out-cal/; user decision 2026-10-26: age >= 60)

P26's inputs (Build result 2), Mediterranean Mountains, targets from California DWM plots aged >= 60 with no recorded fire or harvest
in the past 30 years (Mixed Conifer 1,986 conditions, Western Oak 1,203, Fir/Spruce 606, Ponderosa 475), fire as the spin-up's last
disturbance, five multipliers (snags; down logs = AG Medium + BG Fast; fine woody debris = AG Fast; litter = AG Very Fast; duff = AG Slow).

| Type | Current: snag / down wood / floor / clearcut share | Measured-mature: snag / down logs / fine woody / litter / duff | Misfit cut |
| --- | --- | --- | --- |
| California Mixed Conifer | 0.85 / 0.31 / 1.71 / 0.85 | 0.92 / 0.73 / 2.07 / 0.31 / 3.33 | 95% |
| Fir/Spruce/Mountain Hemlock | 0.60 / 0.26 / 2.41 / 0.86 | 0.65 / 0.73 / 2.14 / 0.72 / 7.21 | 98% |
| Ponderosa Pine | 1.64 / 0.27 / 1.75 / 0.99 | 2.19 / 0.71 / 2.22 / 0.22 / 3.25 | 98% |
| Western Oak | 20 (bound) / 0.61 / 3.04 / 1.00 | 1.41 / 0.90 / 1.65 / 0.28 / 3.45 | 95% |

- Down log decay moves back toward CBM's default (0.71-0.90, from 0.26-0.31). Fine woody debris and duff decay faster than CBM's default,
  leaf litter slower. Western Oak's snag rate is no longer at a bound.
- Mature fit by band: litter, duff and fine woody debris within about 1-2 Mg C/ha in every band. Down logs and snags match on average but
  not in shape: the measured values rise with age (Mixed Conifer down logs 8.6 -> 13.5, snags 5.5 -> 15.4) while the model's fall or stay
  flat (13.8 -> 7.8; 8.8 -> 12.7): the model still carries legacy from the spin-up fire at 60-100 years and adds too little in old stands.
- Young stands (check, not fitted) miss badly, in a way that points at the disturbance flows and at what FIA records as a disturbance:
  after fire the model has 4-5 times the measured snags (Mixed Conifer 0-5 yr: 128 vs 28) and twice the down logs; after harvest it puts
  25-30 Mg C/ha of slash in fine woody debris where 3-4 is measured, and no snags where 5-10 are. FIA's fire codes (DSTRBCD 30-32) include
  ground fires and its cutting code (TRTCD 10) includes partial cuts, while the model's are stand-replacing; and slash is often piled or
  burned. Next: restrict the chronosequences to crown fire (32) and to clearcuts where they can be identified, and compare the LUCAS
  event flows (share of the stand killed, left standing, consumed; slash left) with what the plots show.

## Young stands after stand-replacing events only (07-young-stand-replacing.R, out-cal/young-stand-replacing.*)

High-severity fire = a recorded crown fire, or a recorded fire after which the stand age reset; clearcut = a recorded cutting after which
the stand age reset (FIA has no clearcut code). Mediterranean Mountains DWM conditions within 30 years: high-severity fire Mixed Conifer
124 (of 482 with any fire), Western Oak 243, Ponderosa 33, Fir/Spruce 35; clearcut Mixed Conifer 44, Ponderosa 28, none for Fir/Spruce or
Western Oak. Against the model's fire-last and clearcut-last curves (decay calibrated to mature stands), Mg C/ha, 0-5 years after:

| | Snags | Down logs | Fine woody debris | Forest floor |
| --- | --- | --- | --- | --- |
| Mixed Conifer, high-severity fire | 38 / 128 | 9 / 14 | 2.0 / 4.5 | 6.5 / 19 |
| Fir/Spruce, high-severity fire | 61 / 147 | 8 / 11 | 2.7 / 4.6 | 3.1 / 10 |
| Western Oak, high-severity fire | 27 / 58 | 4 / 8 | 1.5 / 3.6 | 4.8 / 16 |
| Mixed Conifer, clearcut | 4 / 0 | 7 / 17 | 5.9 / 28 | 13 / 27 |
| Ponderosa, clearcut | 5 / 0 | 6 / 7 | 3.0 / 14 | 7 / 22 |

- The shapes are right: after fire, snags fall over 10-20 years and down logs rise (Mixed Conifer 9 -> 14 -> 21; Fir/Spruce 8 -> 19 -> 44);
  after clearcut, few snags and a decaying slash pulse. What is wrong is the size of what the event leaves.
- **High-severity fire leaves 2-3.5x too many snags** and **consumes too little of the forest floor** (model 10-19 vs measured 3-7). The
  model's pre-fire stand is the spin-up stand at the return interval (154-200 yr), probably more biomass than the stands that burned, and
  its fire kills every tree into snags; plots called high severity still include some partial mortality.
- **Clearcut leaves 3-5x too much slash** (fine woody debris 28 vs 6 in Mixed Conifer; forest floor 27 vs 13) and no snags where 4-5 are
  measured: the model leaves all branches, tops and stumps on site; real cuts pile and burn, chip or yard much of it, and keep a few snags.
- So after decay is fitted to mature stands, the young-stand misfit belongs to the LUCAS disturbance flows (defaults/stockflow/
  event-pathways.csv): high-severity fire's share killed to snags vs consumed, and its forest floor consumption; clearcut's share of
  branches and tops left on site. These are the next things to compare with the plots.

## Event flows fitted to FIA before/after pairs (08-event-shares.R, 09-fit-events.R, event-pathways-fitted.csv, out-cal-events/)

Pairs: a DWM visit 0-5 years after a stand-replacing event and the same condition at the previous visit, before it; stand-replacing =
live aboveground wood after <= 20% of before. Shares of the live aboveground wood before (ratio of sums):

| | FIA pairs | LUCAS today |
| --- | --- | --- |
| High-severity fire (65 pairs: 53 Western Oak, 8 Mixed Conifer, 2 Fir/Spruce, 2 Ponderosa): snags | 0.54 | 0.97 |
| ... down logs added within 5 years | ~0 | 0 |
| ... forest floor kept | 0.18 | 0.46 |
| Clearcut (11 pairs, 8 Mixed Conifer): slash (fine woody debris + down logs added) | 0.04 | 0.32 |
| ... snags | ~0 | 0 |
| ... forest floor kept | 0.71 | 1.00 |

Fitted values (stands >= 11 yr), in a dev copy of the event table: fire - merchantable -> snag 0.65 (emitted 0.35), other wood -> snag
0.30 (emitted 0.70), humus (AG Slow) emitted 0.80 (was 0.08); clearcut - other wood and foliage left on site 0.13 (the rest emitted, as
pile burning: an assumption, it could be removed instead), leaf litter and humus 29% emitted.

Rerun (decay refitted to mature stands with the new spin-up fire; multipliers barely move: down logs 0.60-0.78, the rest within 0.05):
- Clearcut now matches: Mixed Conifer 0-5 yr fine woody debris 10.8 vs 5.9 (was 27.6), forest floor 14 vs 13-15 (was 27).
- Fire snags halve but stay above the plots: Mixed Conifer 0-5 yr 79 vs 38 (was 128), Fir/Spruce 90 vs 61, Western Oak 36 vs 27,
  Ponderosa 33 vs 23. With the share now matched, the rest is the size of the stand that burned: the model burns its spin-up stand at the
  return interval (154-200 yr), larger than the average stand FIA saw burn.
- Forest floor after fire stays high (15-18 vs 4-7): the fire now burns 80% of the humus, so the excess comes from what falls in right
  after (killed foliage and fine roots go to leaf litter, branch snags to fine woody debris) - to check next.
- Samples are small (11 clearcut pairs; the fire pairs mostly Western Oak): these values are a first fit for P26's region, not CONUS.

## Post-fire forest floor: a spin-up bug (10-postfire-floor.R; fixed in src/dom.R 2026-10-26)

Tracing California Mixed Conifer's forest floor through a high-severity fire showed the fire burned none of it (leaf litter 9.4 -> 9.4,
humus 9.0 -> 9.0). disturbance_matrices() took the largest FromAgeMin over the whole event, so from age 11 a fire kept only its age-11
live-pool rows and dropped every blank-age row - all dead-pool burning (forest floor, fine woody debris, down logs, snags) and the fine
root mortality. ST-Sim applies blank-age rows at every age, so runs burned dead pools while the spin-up and the decay calibration (stages
3 and 4) never did. Fixed: the age row is chosen per from -> to stock pair. Only the three fire events have age-specific rows.

With the fix and the fitted event table, the floor just after a fire is 5.1 Mg C/ha (humus left 1.8, killed foliage and fine roots 3.3),
and against the plots, 0-5 / 5-10 / 10-20 years after high-severity fire (measured / model): Mixed Conifer 6.5/6.3, 6.6/7.3, 7.6/8.4;
Ponderosa 4.0/4.9; Fir/Spruce 3.1/5.2; Western Oak 4.8/3.6. The mature-stand calibration is essentially unchanged (mature stands are far
from the spin-up fire). Every Build's stage 3-4 results change with the fix: young stands' initial dead pools were overstated.

## Size of the stand that burns (11-burned-stand-size.R, out-cal-events/burned-stand-size.csv)

High-severity fire plots in Mediterranean Mountains with a visit before the fire (237 of 327): live aboveground wood and stand age at
that visit, against the model's spin-up stand at the return interval (P26 carbon curves), Mg C/ha:

| Type | FIA before fire: mean (median) | FIA stand age before: mean (median) | Model at the return interval | Return interval |
| --- | --- | --- | --- | --- |
| California Mixed Conifer (52) | 136 (114) | 125 (105) | 150 | 154 |
| Fir/Spruce/Mountain Hemlock (21) | 148 (131) | 140 (130) | 161 | 200 |
| Ponderosa Pine (18) | 89 (62) | 116 (105) | 82 | 168 |
| Western Oak (146) | 55 (32) | 85 (75) | 77 | 164 |

- For the conifers the model burns a stand close to FIA's average burned stand (within about 10%; larger than the median, since the
  distribution is skewed). Western Oak burns at 40% more wood than FIA's burned oak stands, which were younger (85 vs the 164-year cycle).
- So stand size explains only part of the snag excess after fire (Mixed Conifer: model 77 vs measured 38 Mg C/ha at 0-5 years). The rest
  is the snag share and how fast fire-killed snags come down: the 0.54 share is pooled over pairs that are mostly Western Oak (Mixed Conifer's
  own 8 pairs give 0.46), and the measured snags fall faster in the first decade than the model's (Mixed Conifer 38 -> 49 -> 22 vs 77 ->
  55 -> 38 at 0-5, 5-10, 10-20 yr). Next: type-specific snag shares where pairs allow, and a check of post-fire snag fall rates from
  remeasured fire-killed trees.

## Snag fall rates from remeasured dead trees (12-snag-fall.R, out-cal-events/snag-fall.csv)

18,437 standing dead trees in Mediterranean Mountains (P26's four types) remeasured at the next visit (8-9 years later), 3,568 of them
fire-killed (fire agent, or a fire at the plot in the 10 years before). Carbon-weighted share that fell, as an annual rate (half-life):

| Type | Other snags | Fire-killed | Fire-killed 0-3 yr after | 4-10 yr after | Model: fall / decay / total loss |
| --- | --- | --- | --- | --- | --- |
| California Mixed Conifer | 0.047 (15 yr) | 0.050 (14) | 0.045 | 0.061 | 0.028 / 0.020 / 0.048 |
| Fir/Spruce/Mountain Hemlock | 0.045 (15) | 0.054 (13) | 0.036 | 0.076 | 0.019 / 0.014 / 0.033 |
| Ponderosa Pine | 0.110 (6) | 0.168 (4) | 0.175 | 0.145 | 0.069 / 0.051 / 0.120 |
| Western Oak | 0.079 (9) | 0.082 (8) | 0.083 | 0.079 | 0.044 / 0.032 / 0.076 |

- **Snags fall about twice as fast as the model lets them** (Mixed Conifer 0.047-0.050 per year vs 0.028; the model's half-life standing
  is 25 years against a measured 14-15). The model's fall plus decay together roughly equal the measured fall alone, which is what one
  multiplier on both produces: the calibration had to keep standing snag carbon right in mature stands, and could only do it by slowing
  fall and decay together.
- Fire-killed snags fall at about the same rate as other snags overall, with a delay in the conifers: slower in the first 3 years, faster
  at 4-10 (Fir/Spruce 0.036 -> 0.076). Ponderosa's snags fall fastest (half-life about 4 years after fire).
- So the snag fall rate should be set from these measurements, per forest type, and only snag decay (and emission) left to the
  calibration - the separation the snag multiplier lacks today. Faster fall would also bring the post-fire snag pool down toward the plots
  (Mixed Conifer 77 vs 38 at 0-5 years) and move carbon into down logs sooner, which mature stands need (their down logs run low in old
  stands).

## Snag fall fixed at the measured rates (13-snag-fall-fixed.R, snag-fall-measured.csv, out-cal-snagfall/)

Stem snag fall set to the measured 'other snags' rate (Mixed Conifer 0.047, Fir/Spruce 0.045, Ponderosa 0.110, Western Oak 0.079 per year;
branch snags scaled alike), the snag multiplier fitting only snag decay and emission; fitted event table and the fire fix as before.

- The calibration drives snag decay to its lower bound (0.05 x CBM; Ponderosa 0.12): with fall at the measured rate, standing snags in
  mature stands already lose carbon as fast as their stock allows, so standing decay has almost nothing left to do. Down log decay rises
  toward CBM's default (0.84-1.05, from 0.58-0.77) because snags now deliver more to the ground.
- Mature fit: Mixed Conifer and Ponderosa unchanged; old Mixed Conifer down logs a little closer (10.4 vs 13.5, was 9.3); Fir/Spruce's
  snags now fall short in old stands (13.4 vs 21.7, was 18.1).
- Post-fire snags do not change (Mixed Conifer 0-5 yr: 77 vs measured 38) - the measured fall rate is about the old model's fall + decay,
  so the standing pool drains at the same speed. Down logs after fire now overshoot (Mixed Conifer 0-5 / 5-10 / 10-20 yr: 13.7 / 24.3 /
  30.1 vs 9.1 / 14.2 / 21.4). So the post-fire snag excess is the size of the snag pulse, not how fast it falls: Mixed Conifer's own
  before/after pairs gave 0.46 of the wood to snags and its 0-5 year snags (38 of a pre-fire 136) suggest about 0.3, against the pooled
  0.54 used. A per-type fire snag share is the remaining lever.
- Keep the measured fall rates regardless: they are observed, and they make snag decay a small, separately fitted term.
