# Building a library: the curve fitting and carbon calibration (status 2026-10-27)

Where the build stands after commit 1ed1bed (measured dead-wood calibration made the default). A Build scenario runs stages
0, 1, 5, 2, 3, 4, 6, 7, 8, 12 in that order; the curve fitting is stages 2-4 (stage 5 runs first so stages 3-4 get its return
intervals and soil targets).

## What the user does

1. Create a library from the package: the starter fills the Build scenario, option sheets with defaults, Projection Setup and
   Projection Climate.
2. Data Sources: point the paths at the national data; for the dead-wood calibration also set the FIA DataMart Folder (all states'
   PLOT, COND, TREE and COND_DWM_CALC tables plus FIADB_REFERENCE, about 15 GB).
3. Carbon Assumptions: on its Carbon Method page pick the dead organic matter method (FIA measured dead wood or CBM defaults) and the
   soil source (gSSURGO or CBM), press Fill to see the rows, and add the scenario to the Build's dependencies - first, and with no
   Carbon Method on the Build itself (a scenario's own rows win, then the first dependency that has them).
4. Build: set Study Area, Build Options, Growth Curve Options, and run (California at 1 km about 50 minutes).
5. Projections: Projection Setup (stages 9-10) on the Build result, one Projection Climate (stage 11) per LOCA2 future, then the
   projections (end year in Run Settings).

## Stage 2 - growth and live carbon curves (fitted to FIA)

- Merchantable volume by stand age per forest type x ecodivision: V = A (1 - exp(-k (t - lag)^c)). One model per type: A and k per
  ecodivision, c shared, a pull toward the type's national curve; lag fitted per type; ecodivisions with no plots get A and k from a
  climate regression.
- Live-tree carbon by age fitted directly to FIA plots (saplings included); foliage and root shares fitted to FIA; merchantable stem
  carbon = volume x a US wood density; branches/tops = the remainder; roots split coarse/fine as CBM does.
- FIA source (Growth Curve Options): USGS condition tables (default) or FIA DataMart (same curves within 1% on the median).
- Output: Live-Tree Carbon Curves, every live pool by cell and age.

## Stage 3 - carbon flows

| Piece | Source | Fitted? |
| --- | --- | --- |
| Net growth | mass balance on the stage 2 curves | derived exactly |
| Live turnover (foliage, branch, stem, roots) | CBM defaults for the type's mapped Canadian ecozone and species (defaults/cbm) | no |
| Dead pool decay | CBM base rate x Q10 temperature effect at the ecodivision's mean temperature x a fitted multiplier | yes |
| Snag fall | FIA remeasured standing dead trees, per type x ecodivision (else type) | measured |
| Soil decay | fitted so spin-up soil matches gSSURGO | yes |
| Fire and clearcut transfers | event table fitted to FIA plots after those events, plus a per-type fire snag share | yes, California plots only |

Dead pool decay, Carbon Method "FIA measured dead wood" (default; the other method is CBM defaults, no calibration):
1. Targets: FIA measured dead wood in mature stands (age >= 60, no fire or cutting at the plot in the past 30 years): standing dead ->
   snags; logs and piles -> AG Medium; fine woody debris -> AG Fast; litter -> AG Very Fast; duff -> AG Slow.
2. Snag fall set from measurement first; the snag multiplier then covers only decay while standing.
3. Each multiplier fitted to its own measured pool in the order carbon flows: snags, then down logs and fine woody debris, then litter,
   then duff (one pass; no multiplier can stand in for another pool's error).
4. Scope: snag, down log and fine woody debris rates regional (one set per ecodivision, shared by its types); litter and duff per forest
   type. A type with fewer than 30 mature plot conditions in its ecodivision takes its forest type's rates pooled over ecodivisions.
   "Fitted At" in the Decay Calibration table says which.
5. Without the DataMart folder stage 3 logs it and uses the previous calibration (modelled FIA condition-table pools at every age).

## Stage 4 - spin-up and initial stocks

Repeated growth cycles ended by high-severity fire at the cell's return interval (LANDFIRE, stage 5), solved directly for the stable
state; then the last disturbance (fire or clearcut); then growth to every age. Uses exactly the rates and event flows stage 3 wrote.
Stage 8 maps these curves to initial stock rasters with the fire and harvest history: post-fire inside an interagency perimeter of
1900 to the start year, post-clearcut elsewhere. Carbon Assumptions: Spin-up can set, per forest type (optionally per ecodivision),
the return interval, a share of the historical cycles ended by clearcut (the average cycle is solved), and fire instead of clearcut
outside the perimeters.

## How well it works

532-cell national test library: stages 3-4 in 9 minutes, all checks pass; spin-up mature pools / measured (median, cells with >= 100
plots): snags 0.85, down logs 0.86, fine woody debris 0.90, litter 0.99, duff 0.99.

## Not finished / open

- Snags short in 96 cells even with snag decay at its minimum (inputs or fall rate; not diagnosed).
- Duff multiplier at its upper bound (20) in 19 cells.
- Fire/clearcut transfers and the four fire snag shares come from California plots but apply everywhere (now editable, per ecodivision
  too, in Carbon Assumptions: Disturbance Flows and Fire Snag Share).
- Calibration settings (mature age, exclusion years, plot and snag minimums, multiplier ranges) and fixed multipliers are on the
  Carbon Assumptions sheets (2026-10-28); mature age is one value for every forest type.
- Live turnover not fitted; users cannot view or override rates (to-do 20 rate sheet not built).
- DLL rebuilt and P26 synced 2026-10-28; the P26 rebuild happens in a new library (guide walkthrough).
- The guide's carbon chapter still describes the old calibration.
