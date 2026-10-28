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
| Calibration settings: mature age 60, no fire/cut in 30 yr, 30 plots for own litter/duff fit, 200 snags for own fall rate, multiplier range 0.05-20, regional vs per-type scope | 3 | src/3-carbon-flows.R, src/calibrate.R | Carbon Assumptions: Decay Calibration Settings (2026-10-28) |
| The fitted decay multipliers and snag fall rates | 3 | Decay Calibration output | Carbon Assumptions: Fixed Decay Multipliers (2026-10-28); read-out still to do (to-do 20) |
| Soil targets (gSSURGO per cell) | 3 | stage 5 output, else defaults/spinup/soil-targets.csv | no |
| Disturbance transfers (each event: share of each pool to each pool / atmosphere / harvest) | 3, 4, runs | defaults/stockflow/event-pathways.csv | Carbon Assumptions: Disturbance Flows (fire, clearcut; 2026-10-28) |
| High-severity fire snag share per forest type | 3, 4 | defaults/spinup/fire-snag-share.csv | Carbon Assumptions: Fire Snag Share (2026-10-28) |
| Spin-up historical disturbance (high-severity fire) and last disturbances (fire, clearcut) | 4 | src/4-initial-stocks.R | Carbon Assumptions: Spin-up (2026-10-28) |
| Spin-up return interval per cell | 3, 4 | stage 5 (LANDFIRE FRI), else defaults/spinup/return-interval.csv | Carbon Assumptions: Spin-up (2026-10-28) |
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
- 2026-10-27 **Live Turnover done**: scenario sheet in Carbon Assumptions, per forest type (ecodivision optional): foliage, branch (and
  share to snags), stem, fine root and coarse root turnover (and their shares to the AG pools, which were fixed at 0.5), stem and branch
  snag fall. Every value optional, resolved per value: ecodivision row, then the forest type's all-ecodivisions row, then the CBM
  Crosswalk (root splits 0.5). A stem snag fall set by the user is used as given in every Carbon Options mode, ahead of the measured
  rate; a blank branch snag fall follows it in proportion. Empty by default (everything from CBM). Test: tests/phaseZ10-live-turnover.R;
  phaseZ7 still passes.
- 2026-10-28 **Spin-up done**: scenario sheet in Carbon Assumptions, per forest type (ecodivision optional; each blank value takes the
  forest type's all-ecodivisions row): return interval (blank = stage 5's LANDFIRE value), share of the historical cycles ended by
  clearcut (blank = 0, all high-severity fire), and the last disturbance outside the 1900-start year fire perimeters (blank = clearcut).
  The dynamics are linear, so stage 3 and 4 solve the average cycle with the fire and clearcut event matrices mixed by the share (a
  Monte Carlo of 20,000 random cycles agrees within 0.1%). Stage 3 writes the interval, its source and the share to Decay Calibration;
  stage 4 spins up with them; stage 8 applies the last disturbance. Stage 4 still builds curves for both last disturbances. Empty by
  default. Test: tests/phaseZ11-spinup.R (Placer: mixed conifer age-100 dead carbon after fire 101 -> 116 Mg C/ha at 300 yr with half
  clearcut cycles, 112 -> 92 at 60 yr; Western Oak post-fire share 0.20 -> 1.0; every other type unchanged).
- 2026-10-28 **Disturbance Flows and Fire Snag Share done**: two scenario sheets in Carbon Assumptions, filled from the package
  defaults (39 and 4 rows). Disturbance Flows: high-severity fire and clearcut only (user decision; the other events keep
  defaults/stockflow/event-pathways.csv), one row per flow - ecodivision and forest type optional, disturbance, from stand age, from
  pool, to pool, share. To = Atmosphere is the carbon burned, written as 90% CO2 / 9% CO / 1% CH4 (the split of every default row, so
  merging the gas rows loses nothing); the flow type follows the destination. Precedence per from -> to pair is ST-Sim's, measured in
  dev/stsim/02-stratum-row-precedence.R: ecodivision + forest type, then ecodivision, then forest type, then blank, each hiding the less
  specific rows at every age. Stage 3 expands an ecodivision row with a blank forest type to every class (so the untested ecodivision-only
  vs forest-type-only order never arises), gives every specific row set the younger age rows it would hide, and checks that each pool's
  shares add to at most 1 (stops the run otherwise). Fire Snag Share: per forest type (ecodivision optional), applied on top of the cell's
  flows; a Disturbance Flows row for an ecodivision + forest type wins for its pool. The spin-up (stages 3, 4) resolves rows per
  ecodivision too. Test: tests/phaseZ12-disturbance-flows.R (default-filled sheets reproduce phaseZ11's base exactly; clearcut merch to
  dead wood 0.03 -> 0.15 raises median AG Medium at age 0 from 4.1 to 11.4 Mg C/ha; an over-full row stops stage 3).
- 2026-10-28 **Decay Calibration Settings and Fixed Decay Multipliers done** (to-dos 18 and 20's override). Decay Calibration Settings,
  one row, every value optional: mature age (60), no fire or cutting within (30 yr), min mature plots for an ecodivision's own fit (30),
  min remeasured snags for an own snag fall rate (200), min plots for a cell's own condition-pool fit (200), decay multiplier range
  (0.05-20) and soil multiplier range (0.02-50); stage 3 stops if a minimum is not below its maximum. Fixed Decay Multipliers: per pool
  (snags, down logs, fine woody debris, litter, duff, forest floor = the last three together, soil), ecodivision and forest type optional
  (most specific row wins, as Disturbance Flows). In the measured calibration a fixed value is set before the fits, so the pools fitted
  after it (snags -> down logs, fine woody debris -> litter -> duff -> soil) are fitted with it, and it is left out of the shared fits;
  cells that take a pooled fit take a calibrated row's value, not a fixed one. With CBM defaults the fixed values replace 1; in the
  condition-pool options they replace the joint fit afterwards (logged). Decay Calibration records the pools fixed per cell; the bounds
  check skips them. Mature age per forest type is not in yet (one value). Test: tests/phaseZ13-decay-settings.R (defaults reproduce
  phaseZ7 exactly; mature age 80 / 20 yr: 101,001 vs 126,465 mature plots; min snags 500: 90 vs 120 cells with their own fall rate;
  max 10 caps every calibrated multiplier; fixed snag 1 gives mixed conifer the CBM snag decay rates).
- 2026-10-28 **Carbon Method with presets** (user decisions: two methods, FIA measured dead wood and CBM defaults; soil organic carbon kept
  as its own choice, gSSURGO or CBM, SoilGrids planned). Carbon Options moved from the Build into Carbon Assumptions as the Carbon Method
  page (first in the group): dead organic matter (4 FIA measured, 3 CBM; 1 and 2 stay in the list for older libraries - a value missing
  from a list cannot be read - but are not offered), Soil Organic Carbon (new column; blank = gSSURGO with FIA, CBM with CBM), and a Fill
  button that loads defaults/carbon-assumptions/<method>/<sheet>.csv into all eight sheets (tools/make_carbon_presets.R writes them:
  fia-measured = fitted fire/clearcut flows, fitted snag shares, settings written out; cbm-defaults = the LUCAS CONUS 1km fire/clearcut
  flows, restored as defaults/stockflow/event-pathways-lucas.csv, no snag shares, no settings). A scenario never filled (CBM Crosswalk,
  DOM Parameters and Disturbance Flows all empty) runs with the method's preset rows; once filled, an empty Fire Snag Share means none.
  tools/carbon-assumptions.R (new-library, sync-library, starter) fills from the same files, only when the scenario is unfilled. Stage 3
  stops if FIA measured dead wood has no FIA DataMart Folder (no silent fallback to condition pools). Flow types follow the pools as in
  the LUCAS table: DOM -> DOM is LULC: Transfer DOM. Precedence measured (phaseZ14): a scenario's own Carbon Method wins, else the first
  dependency with rows - so leave it unset on the Build (the starter no longer sets it there). Tests: tests/unit-carbon-assumptions.R
  (no SyncroSim, 1 s) and tests/phaseZ14-carbon-method.R (empty FIA = filled FIA exactly; empty CBM = filled CBM; CBM writes the LUCAS
  rows; gSSURGO soil with CBM dead wood). Running scenarios of one library at once from separate R processes or one multi-scenario
  console call failed (database locked / exit 65535): a follow-up.
