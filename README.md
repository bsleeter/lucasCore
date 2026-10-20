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
lists, transition, stock and flow types), and turns multiprocessing and conda off. This is not a stage: SyncroSim discards
project-scope sheets that a stage saves during a run.

## Stages

| Stage | Script | Status |
|---|---|---|
| 1 - Study Area and Strata | `src/1-study-area.R` | Done: model lattice, primary (ecodivision), secondary (state), tertiary (federal land) strata |
| 2-9 | | Planned |
| U - Spike (development) | `src/u-spike.R` | Phase A spike only; removed before release |

Every stage ends with validation checks (`lucasCore_OutputValidation`); a check that cannot be computed fails.

## Test

```
Rscript tests/phaseA-smoke.R
```

Builds a scratch library in `dev/libs`, runs stage 1 for California and compares the strata with the CONUS 1km model.
