# lucasCore

SyncroSim 3 add-on to ST-Sim (stsim 4.5.x) that builds LUCAS land-use and carbon models from national datasets: FIA growth
curves, CBM carbon parameters, spatial initial conditions, historical transitions and projections. Version 1.0.0 (development,
Phase A). Plan: https://claude.ai/code/artifact/b04aa2f8-a1c2-4a73-99dc-672c8918139d

## Install (development)

```
"C:\Program Files\SyncroSim\SyncroSim.PackageManager.exe" --xinstall="F:\lucasCore"
```

`--xinstall` registers the folder, so SyncroSim runs the scripts in `src/` where they are. Close SyncroSim Studio first.

## Make a library

```
Rscript tools/new-library.R "F:/path/My Model.ssim"
```

Creates the library with stsim + lucasCore, writes the stsim project definitions from `defaults/stsim` (state classes, strata
lists, transition, stock and flow types), and turns multiprocessing and conda off. Secondary and tertiary strata are chosen
here from `defaults/strata/presets.csv` (States, Counties, HUC6, HUC8, EPA Level III Ecoregions, Pyromes, Federal Lands, GAP
Status): `--secondary=Counties --tertiary="GAP Status"`. Defaults: States and Federal Lands (the CONUS 1km model). It also creates the
"Stock-Flow Definitions" scenario (flow diagram, order, groups, output options) that stage 3 scenarios depend on. This is not a stage: SyncroSim discards
project-scope sheets that a stage saves during a run.

## Stages

| Stage | Script | Status |
|---|---|---|
| 1 - Study Area and Strata | `src/1-study-area.R` | Done: model lattice; primary = FIA ecodivisions (fixed); secondary and tertiary from Stratum Sources |
| 2 - Fit Growth Curves | `src/2-growth-curves.R`, `src/growth.R` | Done: 551 merchantable volume curves (forest state class x ecodivision), parameters, PDF report |
| 3 - Carbon Flows | `src/3-carbon-flows.R`, `src/flows.R`, `src/dom.R`, `src/calibrate.R` | Done: net growth and its split, turnover, DOM decay at PRISM temperature calibrated to FIA dead carbon (snags, down wood, litter) and gSSURGO soil; non-forest and event flows from LUCAS defaults |
| 4 - Spin-up and Initial Stocks | `src/4-initial-stocks.R`, `src/dom.R` | Done: CBM spin-up as a fixed point with the calibrated stage 3 rates; all 14 pools by age for a last disturbance of high-severity fire or clearcut |
| 5 - Initial Conditions | `src/5-initial-conditions.R` | Done: annual NLCD on the model grid, forest type (EVT), grass/shrub (RCMAP), wetland (C-CAP), state class and stand age (CMS) maps; per-cell return intervals (LANDFIRE FRI) and gSSURGO soil targets for stage 3 |
| 6-9 | | Planned |

Pipeline order: 1, 5, 2, 3, 4 (stage 3 calibrates with stage 5's return intervals and soil targets; without them it uses provisional defaults).

Every stage ends with validation checks (`lucasCore_OutputValidation`); a check that cannot be computed fails.

## Test

```
Rscript tests/phaseA-smoke.R
```

Builds a scratch library in `dev/libs`, runs stage 1 for California and compares the strata with the CONUS 1km model.
`Rscript tests/phaseB-growth.R` runs stage 2 in a new library; `Rscript tests/phaseB-flows.R` runs stages 2-4 (about 21 minutes);
`Rscript tests/phaseC-initial.R --units=California` runs stages 1 and 5 (about 17 minutes for California at 1 km).
A newly added stage is not visible to an existing library while the package version is unchanged: test it in a new library.
