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
