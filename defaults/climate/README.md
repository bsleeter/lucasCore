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

Climate Options also names a Projection Scenario (SSP), Climate Model (GCM) and Replicate (ensemble member); blank scenario = historical
only, blank replicate = the model's lowest-numbered member with a run of that scenario. The three drop-down lists are project sheets
written by `tools/new-library.R` from the folders under the LOCA2 folder (`<gcm>/<member>/<historical|ssp>/{pr,tasmax,tasmin}/*.monthly.nc`;
rerun it with `--rebuild-climate` after adding runs). SyncroSim cannot filter one drop-down by another, so stage 7 checks the
combination and, when it does not exist, stops with the models or replicates that have the scenario.

For each projected year (historical end year + 1 to the Projection End Year, at most 2100) stage 7 builds annual temperature (mean of
monthly (tasmax + tasmin) / 2) and precipitation (sum of monthly totals) from the monthly files (`src/loca2.R`) and applies the same
models as the historical years, against the climate model's OWN 1991-2020 normal (historical run 1991-2014 + the SSP run 2015-2020).
This delta method removes the model's bias against PRISM (ACCESS-CM2 over California: 11.7 C and 446 mm vs PRISM 11.9 C and 478 mm),
so the historical and projected series join at the end year on the same meaning of 1.0. The precomputed LOCA2 rasters in the LOCA2
folders (x100 integers, 6 km grid, 1981-2010 normal) are not used.
