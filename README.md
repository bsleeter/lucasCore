# lucasCore

SyncroSim 3 add-on to ST-Sim (stsim 4.5.x) that builds LUCAS land-use and carbon models from national datasets: FIA growth
curves, CBM carbon parameters, spatial initial conditions, historical transitions, climate multipliers and initial stocks.
Version 1.0.0 (development). Plan: https://claude.ai/code/artifact/b04aa2f8-a1c2-4a73-99dc-672c8918139d

## Install (development)

```
"C:\Program Files\SyncroSim\SyncroSim.PackageManager.exe" --xinstall="F:\lucasCore"
```

`--xinstall` registers the folder, so SyncroSim runs the scripts in `src/` where they are. Close SyncroSim Studio first. In Studio,
tick lucasCore under File > Local Packages. lucasCore runs on the installed R; it needs no conda environment.

## Start a model

SyncroSim 3 has no local templates (File > New offers only Empty Library and the online templates of the central package index), so
lucasCore ships a starter library. An Empty Library does not work: it has no definitions, strata lists or Stock-Flow Definitions.

1. Copy `Starter/LUCAS Core (CONUS).ssim` to where the model will live and rename it (build it first with
   `Rscript tools/build_starter.R` if it is missing: it is not in git).
2. In SyncroSim Studio, File > Open the copy.
3. Open the **Build** scenario's properties and set, under LUCAS Core:
   - **Build Options**: cell size; secondary and tertiary strata (blank = States, Federal Lands); historical start and end years;
     projection end year (blank = no projection; it starts the year after the historical end); Forest Type Map: LANDFIRE EVT (default) or USFS forest type groups
   - **Study Area**: one row per unit, from any source ("State: California", "Ecodivision: Mediterranean Mountains", "Pyrome: ...",
     "HUC8: ..."); blank = all of CONUS
   - **Climate Options**: forest growth (None / Miami NPP / Tree ring), non-forest growth, decomposition; when projecting, the
     scenario (SSP), climate model and replicate
4. Run **Build**. Its dependency (Stock-Flow Definitions) and pipeline (stages 1, 5, 2, 3, 4, 6, 7, 8) are already set. California at
   1 km takes about 50 minutes; the result scenario holds every input an ST-Sim historical run needs except Run Control.
5. Make the historical run: `Rscript tools/new-historical.R "<library.ssim>" [--build=<result id>] [--iterations=1]` adds
   "Historical <start>-<end>", or in Studio: a new scenario with dependencies **the Build result first, then Stock-Flow
   Definitions** (the order matters: the first one supplies the whole Flow Pathways feed, and Stock-Flow Definitions has the diagram
   but no pathways), Run Control = start to end year, spatial, and Pipeline = ST-Sim. Placer County at 1 km: 12 minutes, one iteration.
6. Projections, one continuous run (mode 1): tick Run a projection in Build Options (end year), pick the LOCA2 scenario, model and
   replicate in Climate Options, and set Projection Options (reference years, iterations, seed, spatial tiles) and, if needed,
   Projection Transitions (one row per transition group: Target by strata level or Probability by any Stratum Source, a sampling set,
   excluded GAP statuses; empty = defaults/projection/transitions.csv). Stage 9 draws a whole historical year per projection year and
   iteration (groups in a sampling set share the draw) and writes targets and multiplier maps; the same new-historical.R then makes
   "Historical and Projection <start>-<end>". Placer County, 1 km, 1985-2050, 2 iterations: build 25 min, run 41 min.
7. Projections from a historical run (mode 2): make the historical run once with `tools/new-historical.R "<library>" --historical-only
   --bookend-maps`, then `Rscript tools/new-projection.R "<library>" --historical=<its result id> [--years=10]` for each projection.
   The projection scenario depends on the Build result, names the run in Projection Start, and runs stage 9 (which hands over the
   run's final state class, age and 14 carbon pool maps) then ST-Sim. Placer: historical run 12 min once; 10 years x 2 iterations 8 min.

To make several models, copy the starter again, or add scenarios to one library (each scenario has its own study area and strata).

Growth curves come three ways (Growth Curve Options): fit in the Build (default; stage 2 in the pipeline, about 13 minutes, CONUS);
fit once in the starter's optional Growth Curves scenario and shared by Builds as a dependency (remove stage 2 from their pipelines);
or copied from a result scenario of another lucasCore library (Growth Curves = Copy from another library, with the Source
Library path and, optionally, the Source Result Scenario Id; seconds instead of minutes).

Two more choices sit beside them. **Carbon Options**: dead organic matter decay calibrated (default: snags, down wood and forest floor to
FIA, soil to gSSURGO), FIA dead pools with CBM-default soil, or CBM defaults throughout (the CONUS 1km model's way); stage 3 logs
spin-up soil against gSSURGO for each. **Land Cover Crosswalks** (Crosswalks group): the EVT 2016, EVT 2001, RCMAP, C-CAP and USFS forest type group
crosswalks stage 5 uses, editable per scenario (`defaults/landcover/README.md`).

The starter is made by `tools/new-library.R`, which can also make or update any library directly:

```
Rscript tools/new-library.R "F:/path/My Model.ssim" [--rebuild-strata] [--rebuild-climate]
```

It writes the stsim definitions from `defaults/stsim`; every polygon source in `defaults/strata/presets.csv` as a Stratum Sources row,
with the stsim Secondary and Tertiary Strata lists holding every unit of every source (6,221 units; `defaults/strata/README.md`); the
LOCA2 scenario, model and replicate lists from the LOCA2 folder; and the "Stock-Flow Definitions" scenario. None of this can be a
stage: SyncroSim discards project-scope sheets that a stage saves during a run.

## Stages

| Stage | Script | What it does |
|---|---|---|
| 1 - Study Area and Strata | `src/1-study-area.R`, `src/strata.R` | Model lattice; study area from any source; primary = FIA ecodivisions (fixed); secondary and tertiary from Build Options |
| 2 - Fit Growth Curves | `src/2-growth-curves.R`, `src/growth.R`, `src/carbon.R` | Merchantable volume and live-tree carbon curves by forest type x ecodivision, fitted to FIA |
| 3 - Carbon Flows | `src/3-carbon-flows.R`, `src/flows.R`, `src/dom.R`, `src/calibrate.R` | Net growth, turnover, DOM decay calibrated to FIA dead carbon and gSSURGO soil; non-forest and event flows |
| 4 - Spin-up and Initial Stocks | `src/4-initial-stocks.R` | CBM spin-up: all 14 pools by age after high-severity fire or clearcut |
| 5 - Initial Conditions | `src/5-initial-conditions.R` | Annual NLCD on the grid; state class and stand age maps; return intervals and soil targets for stage 3 |
| 6 - Historical Transitions | `src/6-historical-transitions.R` | Transition pathways and annual spatial multipliers (NLCD land use and clearcut, MTBS fire, LANDFIRE thinning) |
| 7 - Climate Multipliers | `src/7-climate-multipliers.R`, `src/loca2.R` | Growth and decomposition multipliers: PRISM historical, LOCA2 projections (Climate Options) |
| 8 - Initial Stock Maps | `src/8-initial-stocks-spatial.R` | The 14 carbon pools of every cell as ST-Sim initial stocks |
| 9 - Projection Transitions | `src/9-projection-transitions.R` | Projection targets and multiplier maps that resample whole historical years (only with a projection); with Projection Start, the starting maps of a stand-alone projection |

Pipeline order: 1, 5, 2, 3, 4, 6, 7, 8, 9. Every stage ends with validation checks (`lucasCore_OutputValidation`); a check that cannot be
computed fails.

## Test

Each test builds a new library in `dev/libs` (a newly added stage is not visible to an existing library while the package version
is unchanged). `--units` takes Study Area units, comma-separated (default "County: Placer California", about 3,900 km2 over two ecodivisions; tests run in minutes).

| Test | Runs | Time (California, 1 km) |
|---|---|---|
| `tests/phaseA-smoke.R [--units=] [--secondary=] [--tertiary=]` | stage 1; with States strata, compares with the CONUS 1km model | 4 min |
| `tests/phaseB-growth.R`, `tests/phaseB-flows.R` | stage 2; stages 2-4 | 13, 21 min |
| `tests/phaseC-initial.R`, `tests/phaseD-transitions.R` | stages 1 + 5; 1 + 5 + 6 | 17, 30 min |
| `tests/phaseE-climate.R` | stages 1 + 7, then stage 7 with Miami, None, two projections and three refused setups | 25 min |
| `tests/phaseF-pipeline.R` | the whole build: stages 1, 5, 2, 3, 4, 6, 7, 8 | 51 min (California) |
| `tests/phaseG-starter.R` | the starter: Growth Curves, then Build depending on it | 35 min |
| `tests/phaseH-copy-curves.R` | stages 1-4 with curves copied from another library, and three refused sources | 10 min |
| `tests/phaseI-options.R` | the three dead organic matter options and an edited crosswalk row, on a starter copy | 35 min |
