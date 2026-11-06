# Climate multipliers (stage 7)

- `flow-multipliers.csv`: the flow groups of each climate effect (role), and for decomposition the CBM DOM pools whose Q10 applies.
  Climate Options (scenario sheet) picks each role's model: forest growth None / Miami NPP / Tree ring (default), non-forest growth
  None / Miami NPP (default), decomposition None / Q10 (default). None writes no multiplier: the flow runs at normal climate.
- `tree-ring-coefficients.csv`: the tree-ring forest growth response by FIA ecodivision (stsim stratum name and Id):
  `multiplier = 1 + PrecipCoef (P/Pn - 1) + PrecipLagCoef (P last year/Pn - 1) + TempCoef (T - Tn)`, floored at 0, with Pn and Tn the
  1991-2020 mean of the same PRISM files. Built by `tools/make_tree_ring_coefficients.R`: standard ring-width indices of 1,288 CONUS
  ITRDB chronologies (NOAA NCEI, `Data Sources/ITRDB`) regressed on PRISM annual climate at each site (1895-2023, current PRISM release,
  `Data Sources/Climate/prism/annual-us25m`), pooled by ecodivision with a random-effects mean. Ecodivisions with fewer than 10 sites
  (Marine, Savanna) take the pooled CONUS coefficients. `MiamiBeta` is the ring-width slope on the Miami multiplier (for reference).

Why tree ring is the default (2026-10-20, dev/climate/05-07): predicting each site's annual ring-width index from the other sites'
coefficients, the Miami forest multiplier does worse than a constant (RMSE 0.285 vs 0.266); Miami's swings are about twice what ring
growth supports (pooled slope 0.51; Mediterranean Mountains 0.27, Marine Mountains 0.14). The tree-ring response does best (RMSE 0.260,
r 0.42), mostly through last year's precipitation, which matters as much as this year's; temperature has almost no effect. Ring width is
the most climate-sensitive part of growth and ITRDB sites were chosen for climate sensitivity, so these coefficients are upper bounds on
the sensitivity of total growth. FIA remeasurement could not test annual sensitivity: every design failed a placebo test (dev/climate/01-04).

Tree rings say nothing about grassland and shrubland growth, which keeps Miami NPP.

## Projections (LOCA2)

A projection runs when Build Options sets a Projection End Year (it starts the year after Historical End). Climate Options then names
the Projection Scenario (SSP), Climate Model (GCM) and Replicate (ensemble member), needed unless every climate effect is None; a blank
replicate = the model's lowest-numbered member with a run of that scenario. The three drop-down lists are project sheets
written by `tools/new-library.R` from the folders under the LOCA2 folder (`<gcm>/<member>/<historical|ssp>/{pr,tasmax,tasmin}/*.monthly.nc`;
rerun it with `--rebuild-climate` after adding runs). SyncroSim cannot filter one drop-down by another, so stage 7 checks the
combination and, when it does not exist, stops with the models or replicates that have the scenario.

For each projected year (historical end year + 1 to the Projection End Year, at most 2100) stage 7 builds annual temperature (mean of
monthly (tasmax + tasmin) / 2) and precipitation (sum of monthly totals) from the monthly files (`src/loca2.R`) and applies the same
models as the historical years, against the climate model's OWN 1991-2020 normal (historical run 1991-2014 + the SSP run 2015-2020).
This delta method removes the model's bias against PRISM (ACCESS-CM2 over California: 11.7 C and 446 mm vs PRISM 11.9 C and 478 mm),
so the historical and projected series join at the end year on the same meaning of 1.0. The precomputed LOCA2 rasters in the LOCA2
folders (x100 integers, 6 km grid, 1981-2010 normal) are not used.

## CO2 fertilization (stage 11, to-do 46)

A Projection Climate scenario's Climate page also sets CO2 fertilization (None / Low / Central / High; blank = Central). Growth of
every class in `co2-classes.csv` is multiplied, in each projection year, by `1 + beta x ln(CO2 / reference CO2)` (floored at 0), as a
"CO2" Flow Multiplier Type on its growth flow group, so it multiplies with the climate and Site Productivity multipliers. The No Climate
projection does not depend on a Projection Climate result, so it has no CO2 effect (user decision 2026-11-06).

- `co2-ssp.csv`: global annual mean CO2 (ppm) of the CMIP6 SSPs, 2015-2100, and the historical series 2000-2014 (Meinshausen et al.
  2020, GMD, doi:10.5194/gmd-13-3571-2020), taken from the RCMIP v5.1.0 annual means (Nicholls et al. 2020, Zenodo
  doi:10.5281/zenodo.4589756, `rcmip-concentrations-annual-means-v5-1-0.csv`, World rows). The Scenario column is the LOCA2 folder code.
- `co2-betas.csv`: beta per ln CO2 (Low / Central / High) by vegetation type, from the literature review "CO2 fertilization betas for
  LUCAS" (2026-11-05/06; values checked against the primary papers), accepted by the user 2026-11-06. The betas match biomass
  production (the growth flow into live pools), not GPP and not stock change.
- `co2-classes.csv`: each state class's vegetation type and growth flow group. Agriculture has no growth in the package's carbon
  rates, so its rows change nothing unless a library gives it growth.
- `co2-ecm-share.csv`: each forest type group's ectomycorrhizal share of live basal area, by ecodivision where FIA has 30 or more
  conditions, else CONUS (StratumId blank). Built by `tools/make_co2_ecm_share.R` from the FIA DataMart TREE tables (live trees,
  DIA >= 1 in, inventories 2010-) and `co2-mycorrhiza-genus.csv` (a genus-level assignment: listed genera are ECM, arbutoid or ericoid
  (= 1) or dual AM/ECM (= 0.5); every other genus is AM). A forest class's beta is `share x ECM + (1 - share) x AM`, for young and for
  mature stands; a forest class with no share takes the "Forest" row at every age.
- `co2-age-bands.csv`: forest betas taper with stand age: the young value at 0-25 years, two thirds and one third of the way to the
  mature value at 26-50 and 51-75, the mature value from 76. No study gives an age threshold; this is a modelling choice (the review).

The reference CO2 is the SSP's CO2 in the Build's historical end year (the growth curves are fitted to FIA remeasurements that already
carry the historical CO2), or a ppm given on the page. An optional ceiling holds CO2 at that ppm (600 = no extrapolation beyond the
FACE experiments). CO2 Beta Adjustments rows replace betas of the chosen series by state class, optionally one stratum and one age
band. Stage 11 writes the betas it used to CO2 Fertilization Betas and the series to CO2 Series. Because its flow multiplier rows hide
the Build's, it copies the Build's stsim_FlowMultiplier rows (stage 3's carbon rates) into its result with the CO2 rows.
