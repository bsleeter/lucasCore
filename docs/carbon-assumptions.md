# Carbon calibration assumptions: what a user can change (inventory, 2026-10-27)

The user's requirement (2026-10-27): a user must be able to see, change or specify every assumption the carbon calibration (stages
2-4) depends on. This lists each one, where it lives today and whether a user can change it, then proposes how to expose them.
Status of the calibration itself: docs/carbon-build-process.md.

## The CBM crosswalk

Needed whatever the Carbon Options choice: every forest cell takes its live turnover rates (foliage, branch, stem, root), the branch
share to snags and the CBM snag-to-dead-pool rates from a CBM-CFS3 ecozone and species type, and every dead pool's base decay rate
and Q10 come from CBM (the calibration multiplies them). Today it is `defaults/cbm/species-crosswalk.csv`, one row per forest type
(28), read from the package - no user can see or change it without editing package files, and it cannot differ by region. Every
eastern type maps to Mixedwood Plains (Ontario) or Atlantic Maritime, western types to Montane Cordillera or Pacific Maritime (British
Columbia), Aspen/Birch to Boreal Shield West: Loblolly/Shortleaf Pine in Georgia runs on Ontario turnover rates.

lucasBuilder 2.0.4 (the original package) had this as a scenario sheet, "Spatial Unit and Species Type" (lucasbuilder_CrosswalkSpecies):
CBM ecozone, admin boundary and species type per stratum (optional), secondary/tertiary stratum (optional) and state class, plus an
optional average temperature overriding the climate value - with project lists of CBM ecozones, admin boundaries and species types.
Its CONUS library (F:/lucas-builder/lucasbuilder-conus-fia-update.ssim) had 132 rows, stratum x class, with a temperature on every row,
though each class used one ecozone everywhere. It also had Spin-up (per stratum x class: historical and most recent disturbance,
return interval, number of cycles, maximum age), Disturbance (CBM disturbance type -> ST-Sim transition group), Carbon Stock (CBM stock
-> ST-Sim stock type) and Merchantable Volume Curve (user volume curves by stratum x class x age).

## Inventory

| Assumption | Stage | Where it is now | User can change? |
| --- | --- | --- | --- |
| FIA forest type groups -> state class, east/west softwood/hardwood class | 2, 3 | defaults/growth/forest-type-crosswalk.csv | no |
| Growth curve fitting settings (lag, pooling, min plots, max age, first inventory year, outlier cap, FIA source, down dead adjustment) | 2 | Growth Curve Options | yes |
| Growth curves themselves | 2 | fitted, or copied from another library | copy only; no own curves |
| Merchantable carbon density (Mg C/m3), deciduous share | 2, 3 | defaults/growth/merch-carbon-density.csv | no |
| Coarse / fine root split (Li et al. 2003) | 2 | src/carbon.R | no |
| CBM ecozone / admin / species per forest type | 3 | defaults/cbm/species-crosswalk.csv | no |
| Live turnover rates and splits (foliage, branch -> snag / AG fast, stem, roots) | 3 | CBM tables via the crosswalk | no |
| Root turnover split 50% AG / 50% BG (fine -> AG/BG very fast, coarse -> AG/BG fast) | 3 | src/flows.R | no |
| Dead pool base decay rate, reference temperature, Q10, share emitted | 3 | defaults/cbm/tblDOMParametersDefault.csv | no |
| AG slow -> BG slow transfer (0.006/yr) | 3 | defaults/cbm/tblSlowAGToBGTransferRate.csv | no |
| Mean annual temperature per ecodivision | 3 | PRISM normals, computed | no (lucasBuilder: override per row) |
| Decay calibration choice (measured / condition pools / CBM defaults) | 3 | Carbon Options | yes |
| Calibration settings: mature age 60, no fire/cut in 30 yr, 30 plots for own litter/duff fit, 200 snags for own fall rate, multiplier range 0.05-20, regional vs per-type scope | 3 | src/3-carbon-flows.R, src/calibrate.R | no (to-do 18) |
| The fitted decay multipliers and snag fall rates | 3 | Decay Calibration output | no override (to-do 20) |
| Soil targets (gSSURGO per cell) | 3 | stage 5 output, else defaults/spinup/soil-targets.csv | no |
| Disturbance transfers (each event: share of each pool to each pool / atmosphere / harvest) | 3, 4, runs | defaults/stockflow/event-pathways.csv | no |
| High-severity fire snag share per forest type | 3, 4 | defaults/spinup/fire-snag-share.csv | no |
| Spin-up historical disturbance (high-severity fire) and last disturbances (fire, clearcut) | 4 | src/4-initial-stocks.R | no |
| Spin-up return interval per cell | 3, 4 | stage 5 (LANDFIRE FRI), else defaults/spinup/return-interval.csv | no |
| Flow order, stock groups, flow groups | all | Stock-Flow Definitions scenario | yes (ST-Sim sheets) |

## Proposal: "Carbon Assumptions" sheets, filled with the package defaults

The pattern the package already uses for the Land Cover Crosswalks: an editable scenario sheet that a new library opens filled with
the package's default rows; the stage uses the sheet, and logs every row that differs from the package default. Applied here, under a
Carbon Assumptions group on the Build scenario:

1. **CBM Crosswalk** (as lucasBuilder's): per state class, optionally per ecodivision (and secondary/tertiary stratum), the CBM ecozone,
   admin boundary and species type, and an optional mean temperature overriding PRISM. Project lists of CBM ecozones, admin
   boundaries and species types from the CBM tables. A row for a stratum overrides the class's all-strata row.
2. **Live Turnover**: per state class (optionally per ecodivision), each live pool's turnover rate and its split (foliage -> AG very
   fast; branch -> snag branch / AG fast; stem -> snag stem; fine root -> AG / BG very fast; coarse root -> AG / BG fast). Blank = from
   the CBM crosswalk; a value = the user's.
3. **Dead Organic Matter Parameters**: per dead pool, optionally per ecodivision: base decay rate at the reference temperature, Q10,
   reference temperature, share emitted (the rest to the next pool), AG slow -> BG slow transfer.
4. **Decay Calibration Settings** (to-do 18): targets, mature age (optionally per type), exclusion years, minimum plots and snags,
   multiplier range; per pool: calibrate, or fix the multiplier at a user value (to-do 20's override).
5. **Disturbance Flows**: the event table (each event's share of each pool to each destination, by stand age), and the per-type fire
   snag share - filled from the package defaults.
6. **Spin-up**: per state class (optionally per ecodivision): historical disturbance, last disturbances, return interval (blank = from
   stage 5).
7. **Growth inputs**: forest type crosswalk (FIA groups -> class, lag class), merchantable carbon density, deciduous share, root split;
   optionally user volume or carbon curves (lucasBuilder's Merchantable Volume Curve).

Read-out (to-do 20): pick ecodivision and forest type, see the rates the model runs with and where each came from (CBM default,
calibrated, measured, user).

## Decisions (user, 2026-10-27)

- Every sheet has an optional ecodivision column; a row for an ecodivision overrides the all-ecodivisions row of the same forest type.
- The sheets live in their own **Carbon Assumptions** scenario, not on the Build: Builds depend on it, so one set of assumptions is
  shared by many scenarios - and, like the growth curves, by other libraries (a copy-from-library option, as Growth Curve Options has).
- Disturbance Flows covers the two major events only: high-severity fire and clearcut.
- Build order: CBM Crosswalk, DOM Parameters, Live Turnover, Spin-up, Disturbance Flows, Decay Calibration Settings, Growth Inputs, then
  the read-out.

## Progress

- 2026-10-27 **CBM Crosswalk done**: project lists CBM Ecozones and CBM Species Types (with the rates each sets); scenario sheet CBM
  Crosswalk (ecodivision optional, forest type, ecozone, species type, optional mean temperature) in a Carbon Assumptions scenario that
  tools/new-library.R creates filled with the package default and the starter's Build depends on; tools/sync-library.R adds both to an
  existing library (then add the scenario to the Build's dependencies). Stage 3 resolves each cell's row (ecodivision row first), logs
  rows that differ from the package default, and falls back to the package default without the dependency. Admin boundary left out:
  nothing in lucasCore uses it. Test: tests/phaseZ8-cbm-crosswalk.R. A library made in Studio gets the lists but no Carbon Assumptions
  scenario (stage 3 then uses the package default) - the user can create one or copy it from the starter.
- 2026-10-27 **Dead Organic Matter Parameters done**: scenario sheet in Carbon Assumptions (ecodivision optional, dead pool, base decay
  rate, reference temperature, Q10, share emitted, AG Slow -> BG Slow transfer), filled from defaults/cbm/dom-parameters.csv (CBM-CFS3's
  values) by tools/carbon-assumptions.R (new-library and sync-library). Stage 3 resolves each cell's rows (ecodivision first) for the
  decay rates; stages 7 and 11 take the climate multipliers' Q10s from it (a raster by ecodivision where rows differ; the pools of one
  climate flow group must share a Q10, else the stage's check fails). Defaults reproduce the previous rates within 2e-8. Test:
  tests/phaseZ9-dom-parameters.R (REUSE=1 rechecks the last runs).
