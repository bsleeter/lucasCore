# Dead organic matter calibration from measured FIA data - proposal for the package

Status: proposal, 2026-10-26. Evidence and scripts: `dev/fia/` (scripts 05-15, `FINDINGS.md`) and `dev/nfcms/` (`FINDINGS.md`). Developed
on P26's region (California, Mediterranean Mountains ecodivision, the four main forest types: California Mixed Conifer, Fir/Spruce/Mountain
Hemlock, Ponderosa Pine, Western Oak). Already in the package: the FIA-consistent pool grouping (`src/dom.R` `FIA_DOM`, LUCAS stock groups,
commit a77735b) and the spin-up fire fix (`disturbance_matrices`, commit 1747b49). Related UI work: to-do item 18.

## 1. Summary

Stage 3 today calibrates four dead-pool decay multipliers and a "clearcut share" so that the spin-up's dead pools match FIA's condition
table by stand age, at every age. Two of its three targets (down dead and litter) are models of live tree carbon, not measurements, so
their rise with stand age is an assumption; fitting young stands made the decay rates absorb what is really the effect of the last
disturbance. The proposal:

1. **Calibrate decay to FIA's measured dead pools** (the down woody material plots), one multiplier per measured pool, in **mature stands
   only** (age >= 60 by default). Decay is **regional** (one set per ecodivision, shared by every forest type) for snags, down logs and
   fine woody debris; **leaf litter and duff decay vary by forest type** (user decision 2026-10-27).
2. **Set snag fall from measurement** (remeasured standing dead trees), separate from snag decay.
3. **Make high-severity fire the spin-up's last disturbance** (no fitted clearcut share), as the old LUCAS spin-up did.
4. **Fit the high-severity fire and clearcut event flows to FIA plots measured after those events**, including a per-forest-type share of
   the stand a fire leaves as snags.
5. Use young stands as a **check on the disturbance flows**, not as a calibration target, and expose the key choices in the UI.

On P26 this reproduces FIA's measured pools in mature stands and after high-severity fire and clearcut (section 3).

## 2. What changes, and why

### 2.1 Targets: measured pools, mature stands

FIA's down woody material (DWM) protocol measures dead material on a subset of plots (2001-present), in components that map almost one to
one onto CBM's pools:

| FIA measurement (COND_DWM_CALC; TREE) | CBM pool |
| --- | --- |
| Coarse woody debris >= 3 in, plus slash piles | AG Medium |
| Fine woody debris < 3 in (three size classes) | AG Fast |
| Litter | AG Very Fast |
| Duff | AG Slow |
| Standing dead trees (TREE, every plot) | Snag Stem + Snag Branch |

Today's targets, by contrast: CARBON_DOWN_DEAD (Smith and Heath 2008, a function of live tree carbon; the USGS table scales it by a state
field factor) and CARBON_LITTER (Domke et al. 2016). In California Mixed Conifer the measured down logs are about half the modelled down
dead in mature stands (9-14 vs 18-27 Mg C/ha), and the measured forest floor 9-17 vs 14-19.

**Mature stands only.** Dead carbon in a young stand is mostly what its last fire or harvest left; in a mature stand it is the balance of
turnover inputs and decay, which is what the decay rates control. Calibrate on conditions with stand age >= 60 (the user expects this to
vary by forest type eventually) and no recorded fire or harvest at the plot in the past 30 years.

**Five multipliers** (snags; down logs = AG Medium + BG Fast; fine woody debris = AG Fast; litter = AG Very Fast; duff = AG Slow), plus
soil to gSSURGO as today. Dead coarse roots (BG Fast) have no measurement and ride with down logs.

**Regional and forest type terms** (user decision 2026-10-27). Decay is a property of the region (climate) more than of the stand, so
snag, down log and fine woody debris multipliers are fitted once per ecodivision, jointly over its forest types. Leaf litter and duff
multipliers are fitted per forest type, because forest floor stocks differ sharply by type in the same region (measured litter 4 Mg
C/ha in Fir/Spruce against 9-10 in the other three P26 types) - litter quality differs (needles, oak leaves), and the per-type term may
also absorb errors in the uncalibrated, type-specific inputs (foliage biomass and turnover). On P26 (`06-calibrate-measured.R` with
`LUCAS_POOLED`), the misfit left from CBM defaults is: per-type fit 2.5%, this hybrid 3.0%, fully regional 7.1%; the hybrid's largest
loss is Western Oak down logs. Live turnover, snag fall, the fire snag share and the growth curves stay per forest type. The CBM Q10s
(2.65 leaf litter and duff, 2.0 the others, 1.0 deep soil) and the region's mean temperature set each base rate before the multiplier.

### 2.2 Snag fall from measurement

The snag multiplier today scales snag decay and snag fall together. FIA's remeasured standing dead trees give the fall rate directly
(carbon-weighted share fallen by the next visit; 18,437 snags in the four types): Mixed Conifer 0.047 per year (half-life 15 years),
Fir/Spruce 0.045, Ponderosa 0.110, Western Oak 0.079 - about twice CBM's fall rate as the calibration had left it. Fire-killed snags fall
at about the same rate overall (slower in the first three years in the conifers, faster at 4-10). Proposal: fix snag fall per forest type
(and region) from these data; the snag multiplier then fits standing decay and emission only (it comes out near zero).

### 2.3 Spin-up: fire as the last disturbance

The fitted clearcut share (0.85-1.0 in every type) was not observed; the optimiser used clearcut residue to add down wood. With mature-stand
targets the last disturbance matters little for the fit, so use high-severity fire, as the old spin-up did. Stage 8 still applies clearcut
where a cell's history has one. The spin-up's fire return interval (LANDFIRE FRI_REPLAC per cell today) is to be exposed (to-do 18).

### 2.4 Disturbance flows fitted to plots after the event

Before/after pairs (a plot measured before a stand-replacing event and again within five years) and plots by years since the event give:

| | LUCAS today | FIA | Proposed |
| --- | --- | --- | --- |
| High-severity fire: share of live wood left as snags | 0.97 | 0.54 pooled pairs; fitted per type to snags 0-20 yr after | Mixed Conifer 0.28, Ponderosa 0.36, Western Oak 0.40, Fir/Spruce 0.42 (rest burned; stem : branch as 0.65 : 0.30) |
| High-severity fire: forest floor kept | 0.46 in the table, but 1.0 in the spin-up (bug, fixed) | 0.18 | humus 80% burned (was 8%), leaf litter 100% |
| Clearcut: snags left standing | 0 | ~4 Mg C/ha after cut | 0.4 |
| Clearcut: felled snags left on site | 1 | | 0 (removed or burned) |
| Clearcut: existing down logs kept | 1 | | 0.5 |
| Clearcut: branches, tops, foliage left as slash | 1.0 | 0.04 of the wood (pairs) | 0.04 |

High-severity fire is defined in the data as a recorded crown fire or a fire after which the stand age reset; clearcut as a recorded
cutting after which the stand age reset (FIA has no clearcut code). Low- and medium-severity fire, selection harvest, salvage and insects
are not fitted yet.

## 3. Results on P26 (dev, `dev/fia/out-cal-clearcut`)

Mature stands (>= 60 yr), measured / model, Mg C/ha, California Mixed Conifer: snags 5.5-15.4 / 7.5-13.5, down logs 8.6-13.5 / 9.4-12.4,
fine woody debris 2.5-3.1 / 1.8-3.5, litter 8.1-9.3 / 7.8-9.6, duff 7.6-9.9 / 6.3-9.8 (misfit cut 95-98% from CBM defaults). Ponderosa
and Western Oak fit similarly; Fir/Spruce's oldest stands are short on snags (13 vs 22).

After high-severity fire (0-5 / 5-10 / 10-20 yr), Mixed Conifer: snags 38 / 49 / 22 measured vs 43 / 31 / 22; down logs 9 / 14 / 21 vs
12 / 17 / 21; forest floor 6.5 / 6.6 / 7.6 vs 5.6 / 5.7 / 6.7. Before these changes the model had 128 Mg C/ha of snags and 19 of forest
floor at 0-5 years.

After clearcut, Mixed Conifer: down logs 7.4 / 10.6 / 7.4 vs 8.1 / 7.3 / 6.2 (was 20.9 / 17.1 / 13.2); snags 4.3 vs 4.1 (was 0).

Decay multipliers (x CBM), per-type fit: snags ~0 (0.05-0.14), down logs 0.74-0.96, fine woody debris 1.8-2.3, litter 0.22-0.72, duff
3.2-7.1. Hybrid fit (the proposal): regional snags 0.05, down logs 0.85, fine woody debris 2.14; by type litter 0.31 / 0.72 / 0.22 / 0.28
and duff 3.25 / 7.10 / 3.16 / 3.38 (Mixed Conifer / Fir-Spruce / Ponderosa / Western Oak). The section 3 results above are from the
per-type fit; the hybrid's mature-stand fit is in `dev/fia/out-cal-regional/hybrid-decay.rds`. The full set of rates a stand runs with
(region: temperature, Q10, decay; type: turnover, snag fall, litter and duff decay, growth; fire and clearcut shares) is tabulated by
`dev/fia/16-rate-table.R` (to-do 20, the user rate sheet).

## 4. Implementation

| Piece | Files | What |
| --- | --- | --- |
| FIA data | `src/fia.R`, Data Sources | DataMart route also reads `<ST>_COND_DWM_CALC.csv` and the TREE remeasurement fields (PREV_TRE_CN, STANDING_DEAD_CD, AGENTCD, RECONCILECD), cached as today; the USGS .Rds route has no DWM, so measured targets need DataMart (or a shipped target table, below) |
| Targets | `src/calibrate.R` | per ecodivision x forest type x age band (>= 60): measured snags, down logs + piles, fine woody debris, litter, duff; exclusion of recent fire/harvest; pooled to the forest type where plots are few (as the growth curves) |
| Snag fall | `src/fia.R`, `src/calibrate.R`, `src/dom.R` | fall rates per forest type x ecodivision (pooled fallback); `scale_decay` leaves snag fall out of the snag multiplier; stage 3 writes the fall flow multipliers |
| Calibration | `src/calibrate.R`, `src/dom.R`, `src/3-carbon-flows.R` | five decay groups (`DECAY_GROUPS`), fire as the last disturbance; snag, down log and fine woody debris multipliers fitted jointly per ecodivision over its forest types, litter and duff per ecodivision x type (pooled to the type where plots are few); OutputDecayCalibration gains the new multipliers and the fall rate; the decay figure (`src/figures.R`) shows five pools |
| Rate sheet | `package.xml`, `ui/` | to-do 20: pick ecodivision and forest type, view and override temperature, Q10s, decay (regional) and turnover, snag fall, litter/duff decay, fire and clearcut shares, growth values (type) |
| Event flows | `defaults/stockflow/event-pathways.csv`, `src/3-carbon-flows.R` | high-severity fire and clearcut rows as above. The per-type fire snag share needs state-class-specific rows: stage 3 already writes stsim_FlowPathway from this table, so it can write class rows - first confirm how ST-Sim combines a state-class row with a blank-class row for the same flow (override or sum) and write rows accordingly |
| Shipped defaults | `defaults/spinup/` | snag fall rates and fire snag shares by forest type (and region), so a build without DataMart still gets them |
| UI | `package.xml`, `ui/CarbonOptionsView.cs` | to-do 18: targets (measured / modelled), minimum age, last disturbance, fire return interval |
| Tests | `tests/` | a stage 3-4 test on the test library comparing with the dev results; checks that every multiplier is inside its bounds and that measured targets exist for each cell or its type |

Every Build's stage 3-4 results change (they already do with the fire fix): a package version bump and a note in the guide's carbon chapter.

## 5. Before CONUS use

- **Coverage.** The fits use California's DWM plots and one ecodivision. DWM tables are needed for every state (small next to the TREE
  tables), and the fits repeated per ecodivision x forest type, with pooling rules where plots are few.
- **Small samples.** Clearcut: 72 plots; fire pairs: 65, mostly Western Oak. Two clearcut values sit at the edge of the searched range
  (snags kept 0.4, slash 0.04).
- **Remaining misfits.** Fir/Spruce old-stand snags (13 vs 22); the forest floor 5-10 years after clearcut (9.8 vs 4.1); measured down logs
  and snags rise with age in old stands more than the model's.
- **Other events.** Low- and medium-severity fire, selection harvest, salvage and insects keep their current flows until fitted the same way.
- **Validation.** Rebuild P26 and compare its historical run with FIA (mature and young stands) and with NFCMS 2020; repeat in a second
  region (e.g. the Northeast) to test transferability.
