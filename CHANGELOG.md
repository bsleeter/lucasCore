# Changelog

Changes to lucasCore by version. Version numbers follow [Semantic Versioning](https://semver.org/).

## Unreleased

No library update needed: the new outputs are sheets of their own, which a 1.5 library gains when it is opened with this
version. A Build made before it has no carbon capacity until the Build (or its stage 8) is rerun; runs already made on that
Build can then be drawn against it.

### Added
- Carbon carrying capacity (stage 8, `src/capacity.R`): what each cell would hold in live biomass, dead wood and litter
  under its potential natural vegetation and natural fire regime, as a yardstick for historical runs and projections.
  - **Definition.** The natural-regime mean: for each ecodivision and forest type, the type's stock curve after a
    high-severity fire (stage 4) averaged over the stand ages of a landscape burning at its replacement-fire return
    interval (the one the spin-up used), a stand burning with the same chance every year. The old-growth end of the curve
    is kept as an upper bound. Soil is not counted (the model's soil starts from gNATSGO, which carries the land's use).
  - **Potential vegetation.** A cell that is forest today keeps its type. LANDFIRE Biophysical Settings decide where land
    is off its potential: developed and farmed land takes the BpS mix of forest (the type stage 5 says the cell would
    reach), grassland, shrubland and bare ground. Natural grassland, shrubland and barren land keeps its own class (the annual
    NLCD maps these groups from satellite observations, BpS is a modeled product); the new page Carbon Capacity
    Options (Carbon Assumptions; two choices, each explained; `ui/CarbonCapacityView.cs`) can count it as forest on its BpS
    forest share instead.
    `defaults/landcover/bps-groups.csv` gained a `NonForestCover` column for this. Without a BpS file the
    capacity of developed and farmed land is its starting stock, and the log says so.
  - **Build outputs:** Carbon Capacity Summary (by ecodivision, secondary stratum and land cover at the start), Carbon
    Capacity by Type, and Carbon Capacity Maps (capacity, upper bound, its live biomass part, starting stock, forest share).
  - **Run Figures (stage 13):** a figure of the run's stock against the capacity, its share of the capacity, and the
    deficit by cause in the first and last year (land use; natural non-forest cover on land counted as forest; disturbed land
    waiting to return; and, on land in its potential cover, live biomass apart from dead wood and litter), a map figure, and
    the sheet Run Carbon Against Capacity (one row per year).
  - **Compare Runs (stage 14):** a figure of each run's share of the capacity and last-year deficit by cause, and the sheet
    Compare Carbon Against Capacity.
  - **Limits:** stand-replacing fire only; today's forest type taken as natural; fixed at the Build's historical climate.
    A full BpS to forest type group crosswalk, as a user choice, is to-do 69 in `docs/ui-improvements.md`.
  - `dev/capacity/check-library.R` computes the capacity of an existing Build result outside SyncroSim (read-only) and
    draws a run against it.

- Stand age (stage 5, `src/stand-age.R`; the new page LUCAS Core > Stand Age and the table Stand Age: Unknown Ages).
  - **A cell's stand age** is now the age of the 30 m pixel at its centre (a cell whose centre pixel has none takes the mean
    of its pixels that do). It was the mean of the cell's pixels, which leaves a landscape short of young and old stands;
    Stand Age can set the mean again.
  - **Forest burned between the start year and the age map's year** (NASA CMS 1990, TreeMap 2016) showed in the age map as
    what grew back or as its unburned remnants. A forest cell inside an interagency fire perimeter of those years now takes,
    in order: the user's stand age raster; the user's age for its forest type (Unknown Ages); NASA CMS 1990 where it saw
    the stand before its fire (a TreeMap Build); else the percentile (default the 75th) of the ages of unburned forest of
    its type in its ecodivision. Stand Age can keep the age map's value instead.
  - **A stand age raster** (optional, with the year of its ages) sets the age of every forest cell it covers.
  - **Stand Age Summary** (Build Results) lists, by forest type and rule, the cells, their mean age and the age map's.
  - **This changes a Build's starting ages and carbon** wherever fires fall between the start year and the age map's year,
    and, through the centre pixel, everywhere a little. Yellowstone at 300 m (TreeMap ages): 49% of forest cells are inside
    a 1986-2016 perimeter and go from a mean of about 100 years to 140; the land starts at 90% of its carbon capacity
    instead of 86%. To reproduce an earlier Build, set Stand Age to the mean of the cell's pixels and to keep the age map's
    value.

### Tests
- `tests/unit-capacity.R`: the regime weights and mean against hand values and their limits, the table by type, the BpS
  cover lookup, the cell rules under both settings of the option, and the run side (series, deficit by cause).
- `tests/unit-stand-age.R`: the options, the Unknown Ages table, the percentiles of the unburned forest, and the order of the
  rules.

## 1.5.1 - 2026-11-18

No library update: the new Wood Products parameters are in a sheet of their own (Wood Products Future), which a 1.5 library
gains when it is opened with this version. Existing Wood Products scenarios and their results are unchanged.

### Added
- Wood products futures (stage 18). The Wood Products page has a group "A different wood products future": a few parameters
  that move harvested carbon from one path to another from a start year on, to explore, for example, a move to longer-lived
  products or to more bioenergy. Left blank they reproduce the earlier results exactly (the model is not touched when none
  is set). They act on top of the parameter draws, so the interval stays and the band moves, and none adds or loses carbon.
  - **Apply from year** (blank: the projection's first year; a historical run: its first year) and **Fully reached by year**
    (blank: at once; otherwise a straight-line ramp).
  - **Shift to long-lived products** (0 to 1, default 0): that share of the carbon bound for paper and for end uses with a
    half-life of 12 years or less goes to building end uses (67 years or more) instead, in the building mix of the year, and
    is solid wood from there on.
  - **Product lifetime multiplier** (default 1): multiplies every half-life in use, on everything in use from the start year.
  - **Extra share burned for energy** (0 to 1, default 0): that share of the industrial roundwood is burned with energy
    capture in the year harvested instead of made into products. The model does not credit the fossil fuel displaced.
  - **Discarded wood recovered**, **Discarded paper recovered** (defaults: the table's last year, 0.09 and 0.50) and
    **Discards burned for energy** (default 0): the set fates take the values given and the other fates keep their
    proportions in what is left.
  - The run log names each parameter that differs from its default, with the years it applies; the figures' note line says
    when a result used them. A value out of range, or a start year after the run, stops the stage with a message.
  - Code: `wp_levers`, `wp_lever_w` and `wp_lever_fates` in `src/wood-products.R`; the new single-row sheet `WoodProductsFuture`
    (`LeverFromYear`, `LeverFullYear`, `LongLivedShift`, `LifetimeMultiplier`, `ExtraEnergyShare`, `RecoveredWood`,
    `RecoveredPaper`, `DiscardEnergyShare`), shown with `WoodProductsOptions` on the one Wood Products page (data feed
    `WoodProductsPage`).
- Wood Products page: a diagram of where the carbon of one harvest goes. It follows 100 units of harvested carbon of a
  region, wood type and log size for a chosen number of years, with the page's parameters in full effect beside the
  defaults: products in use by class, what has been discarded, recovered products, landfills and dumps, and what has been
  emitted with and without energy capture. It redraws as the parameters change (`ui/WoodProductsFate.cs`,
  `ui/WoodProductsDiagram.cs`).

### Tests
- `tests/unit-wood-products.R`: the levers (no lever set gives identical results; carbon conserved with each; the years
  before the start year untouched; a shift to long-lived products and longer lifetimes raise the stored carbon, more
  bioenergy and burned discards lower it; by-hand cases of the shift, the fates, the ramp and the lifetime multiplier).
- `tests/unit-wood-products-fate.R` (with `tests/wood-products-fate.ps1`): the diagram's C# model against the R model, six
  cases, equal to 1e-9.
- `tests/phaseZ30-wood-products.R`: the stage with blank levers (identical sheets), with a shift, with phased-in bioenergy,
  with every lever and draws, and with bad values.

## 1.5.0 - 2026-11-18

Library update 1.5: opening a library adds the wetland methane flow types, groups, flow order and output filters, the Marsh
Salinity and Methane Uncertainty flow multiplier types and the Climate Options wetland growth choice. A Build made with 1.4
keeps working; wetlands release methane after its next Build (stages 0, 3, 7 and 8; a Projection Climate after stage 11).

### Added
- Wetland methane (to-do 54). Emergent and forested wetlands release part of the carbon their soil and litter already emit as
  CH4 instead of CO2, so no carbon is added or lost: in a normal climate year every pool loses what it lost before, and the
  starting stocks a Build writes are unchanged. This is minor version 1.5: a library gains the definitions when it is opened
  (update 1.5) and the methane with its next Build (stages 0, 3, 7 and 8; a Projection Climate with stage 11).
  - Source pools: soil (BG Slow) and root litter (BG Very Fast) in emergent wetland; in the forested wetland classes also the
    three forest-floor pools (AG Very Fast, AG Fast, AG Slow), because most decay in a forest is on the forest floor (Great
    Dismal Swamp test: 3.6 to 4.1 Mg C/ha/yr from the five pools, about 3.0 to 3.5 of it from the forest floor). Each source pool
    has a CO2 flow of its own (`Emission: <pool> -> Atmosphere (Wetland)`) and a CH4 flow (`Emission: <pool> -> Atmosphere CH4`).
    Estuarine forested wetland has no methane yet.
  - The split: a class's methane fraction is its target (Mg C/ha/yr as CH4) over what its source pools emit, held at 30% of that
    emission (`src/nonforest-solve.R`, `src/flows.R`). Targets by class and region are literature values (SOCCR2 chapters 13 and
    15, the IPCC 2013 Wetlands Supplement, Krauss et al. 2016, Knox et al. 2019, Delwiche et al. 2021, Bansal et al. 2023,
    Arias-Ortiz et al. 2024): `defaults/stockflow/emergent-wetland-regions.csv` (column `CH4`) and
    `defaults/spinup/wetland-ch4.csv`. Where the cap binds a class releases less than its target and stage 3 says so; no package
    target reaches it.
  - Temperature: methane has a Q10 of 3.83 (Yvon-Durocher et al. 2014) and wetland soil CO2 a Q10 of 2.0, in new flow groups
    `Q10 Wetland CH4` and `Q10 Wetland Soil` (`defaults/climate/flow-multipliers.csv`, new column `Q10`); wetland litter CO2 keeps
    the Q10 of its pool. In a warm year the pools lose more and a larger share of it is methane. Soil of every other class still
    has no temperature response.
  - Marsh salinity: an estuarine emergent cell takes the methane target of the salinity zones LANDFIRE EVT 2016 maps in it
    (`defaults/stockflow/marsh-salinity-evt.csv`, `marsh-salinity-ch4.csv`; Arias-Ortiz et al. 2024 Table 3), written by stage 8 as
    a pair of flow spatial multipliers (type Marsh Salinity): one on the methane and one on the matching CO2, so the cell's
    carbon loss is unchanged. A cell with no zone keeps its class target. Marsh elevation is not modelled (to-do 66). Gulf
    fresh and oligohaline marsh takes the Coastal Plains palustrine target (0.40), not the synthesis mean for warm sites (1.286):
    that mean is chamber-dominated, three times the tower-based fresh marsh value, and more than the cap allows. Gulf brackish
    marsh, and the Gulf class target used where no zone is mapped, are the Krauss et al. 2016 Louisiana brackish tower (0.111)
    for the same reason, in place of the synthesis mean (0.161).
  - Carbon Assumptions > Wetland Methane (new page; sheets Wetland Options, Wetland Methane Targets, Marsh Salinity Targets):
    the two Q10s, the cap, the CO2 equivalent of methane carbon (33.5 by default; stage 0 writes it into the CO2e group weights),
    a target for any class and region or salinity zone, and a low and a high beside any target. Left empty, the package values
    apply. The package targets carry draft literature ranges (`defaults/stockflow/wetland-methane-targets.csv`,
    `marsh-salinity-ch4.csv`, each with its basis). Uncertainty Draws = n makes each of a run's first n Monte Carlo iterations
    draw every target from its range (triangular, one quantile for all targets) as a methane factor and the CO2 factor that
    offsets it (flow multiplier type Methane Uncertainty; per-iteration salinity maps), so each iteration conserves carbon;
    later iterations run at the targets. With 0 draws, the default, the ranges do nothing.
  - Climate Options > Wetland Growth (new): how emergent marsh growth follows the year's climate: None, Miami NPP, Temperature
    (the default: the temperature term of Miami NPP) or Temperature and Miami NPP (temperature for tidal marsh, Miami NPP
    inland). Before, marsh growth had no climate response.
  - Outputs: flow groups `Emission: Wetland CH4`, `Emission: Wetland CH4 (CO2e)` and `Emission: Wetland Methane Source CO2`;
    methane is inside `Emission: Total Rh`, so NEP and NBP in carbon are unchanged and their CO2e versions count methane at its
    CO2 equivalent.
  - Run Figures (stage 13) and Compare Runs (stage 14): a Wetland methane figure when a run's wetlands released any: methane per year (by the kind of
    wetland in Run Figures, a line per run in Compare Runs), and net biome productivity as CO2 with that methane at its CO2 equivalent.
  - Tested at 300 m on Sabine and Lacassine NWRs (Louisiana) and the Great Dismal Swamp: the yearly change in ecosystem carbon
    matches NBP to within 1 Mg C in every iteration. Method summary: `dev/wetland-ch4/wetland-methane-method.html`; literature:
    `dev/wetland-ch4/literature-ch4.md`. Methane follows the yearly mean temperature, not the warm season (to-do 67), and water
    level is not modelled.

### Fixed
- Stage 3 stopped with a missing soil multiplier where no cell of an emergent wetland budget reached its gNATSGO soil target
  (Sabine and Lacassine NWRs at 300 m): the soil multiplier now falls back to 1 there, the package rate.
- Forested wetland methane overshot its target where the fire return interval is short and the stands are old (Sabine and
  Lacassine NWRs: swamp at 0.99 Mg C/ha/yr against 0.27). Stage 3 set the methane share on a stand averaged over one disturbance
  cycle, 11 years there, which emits far less than the stands the library has. The share is now set on the stand ages present
  (stage 5's maps), and on a disturbance cycle only where the library has no cell of the class.
- A Build whose Stock-Flow Definitions dependency was made with an earlier lucasCore ran with the new flow types missing from the
  flow order, group memberships and output filters, so those flows moved carbon that net biome productivity never counted (Sabine
  and Lacassine at 300 m: about 1,200 Mg C a year from 424 ha of forested wetland litter). Stage 0 now stops and names the missing
  flow types; `tools/sync-library.R` adds them to the library.

## 1.4.1 - 2026-11-16

No library update: a 1.4.0 library opens as it is. A Build made with 1.4.0 keeps working; rerun it (or stages 0 and 6) to get the
tabular output options and the new forest return.

### Changed
- Forest return after a stand-replacing fire has a second witness, LANDFIRE's 2016 vegetation type (user 2026-11-15). The
  Yellowstone historical run converted 76,000 ha of the 1988 burn to shrubland and annual grassland in 2018: NLCD shows 2% of
  that burn as forest in 2016, where LANDFIRE maps half of it as a tree type (and TreeMap 2016 agrees), so NLCD was missing
  slow-growing lodgepole regeneration. Three changes, all in the package defaults, so a Build made before them needs stage 6
  rerun (and a Projection Setup made from it, stage 9):
  - Stage 6: a disturbed forest cell also returns where most of its LANDFIRE 2016 pixels are a tree type
    (`defaults/transitions/evt2016-tree-classes.csv`) and its forest loss (the last year NLCD shows forest, or a later
    high-severity fire on most of the cell) came at least 15 years before 2016. It returns 15 years after the loss. The guard is
    there because the label is not reliable on young burns: at Yellowstone 31-39% of high-severity burns of 3-4 years earlier are
    "tree", against 6-17% at 5-9 years (`src/post-disturbance.R`, `PD_WITNESS`). No new data: every Build already reads this layer.
  - Settings (`tools/fit_post_disturbance.R`, refitted): the share back at the window counts the witness, so the yearly return
    chance of projections rises (Temperate Steppe Mountains 0.015 to 0.031: 50% back by year 30, NLCD alone 29%). Where NLCD's
    own curve is still rising by a point a year when the record ends, the window is left open to 40 years: 12 of the 20 rows,
    Temperate Steppe Mountains among them (30 to 40; it was the one ecodivision where return was faster after the window than
    before it). Return age and the fitted windows themselves are unchanged.
  - Regions (`post-disturbance-regions.csv`, new column `ForestGrassClass`): disturbed forest that does not come back converts
    to natural perennial grassland, not annual, in Temperate Steppe Mountains, Temperate Desert Mountains and
    Tropical/Subtropical Steppe Mountains. Shrubland there still converts to annual grass; Mediterranean Mountains is unchanged.
- Land Use Demand's five sources ship with the package instead of being downloaded (`defaults/land-use-demand`, 7 MB): the RPA
  county urbanization and timber harvest, the ICLUS county table, Hauer's county populations and the Census county populations,
  each reduced to what stage 9 reads by `tools/make_land_use_demand_tables.R` (sources, licences and what was reduced:
  `defaults/land-use-demand/README.md`; the files they were made from and their checksums: `made-from.csv`). In 1.4.0 they were
  Data Download datasets: 7.5 GB fetched, mostly ICLUS maps, for a few megabytes read. The multipliers are still computed in the
  stage, and `tests/unit-land-use-demand.R` checks that each table gives the same ratios as its published file. The Data
  Download handlers are removed and the Data Download page lists the five as shipped; a path set on the Data Sources page still
  wins (the published file, or another edition). No change to results; no library update.

### Fixed
- A Historical or Projection scenario made in Studio on a Build result had no tabular state class or transition output: the Build
  wrote the stock and flow output options, the spatial output options and the three output filters, and not ST-Sim's Output
  Options (only `tools/new-historical.R` and `tools/new-projection.R` set them). Stage 0 now writes them whenever the scenario
  has none (`defaults/stockflow/stsim_OutputOptions.csv`: state class, transition and transition attribute summaries every year; the
  attributes are where management costs are reported). A scenario that sets
  its own Output Options replaces them whole. A Build made before this needs stage 0 rerun, or the two boxes ticked by hand.
- Data Download page: RCMAP Cover Time Series was listed but could not be ticked (its row in `defaults/download/endpoints.csv`
  had no Fetched value), yet a download with every dataset ticked fetched it anyway: 188 GB that no stage reads (only
  `tools/fit_shrub_post_disturbance.R`, whose fitted settings ship in `defaults/transitions/post-disturbance-settings.csv`). It is
  now a developer dataset (Fetched = optional): not listed on the page, and not fetched by a blank dataset list. To refit, run a
  Data Download scenario whose Datasets is `RcmapCoverFolder`, set by script.
- A Build could fail at the end of stage 8 on its own crop harvest check ("no agriculture cell harvests more than its foliage";
  Dallas-Fort Worth metro, 154 pasture cells of 262,096 agriculture cells). An agriculture cell with no surveyed crop pixels takes
  the crop harvest multiplier of its neighbours, and a pasture cell filled from cropland could end above all of its foliage,
  because cropland's lower harvest rate allows a higher multiplier. A filled cell is now held to its own class's limit, as the
  cells with their own crops already were, and the log says how many were held. No change to a Build that passed.

## 1.4.0 - 2026-11-15

What happens after a disturbance, and what people do about it: burned and harvested land now sits in disturbed classes that return
or convert, land reforests, and projections can carry post-disturbance recovery, forest management, fuel treatments and rangeland
restoration with their costs. Also new: harvested wood products, and alternative amounts of land use change in projections.

**Upgrading:** install `lucasCore-1.4.0.ssimpkg` in place of 1.3.2, and back up each library's .ssim before opening it: library update 1.4 runs when a 1.3 library is opened. It adds the Disturbed state classes with their return and conversion transitions, the management transitions and their costs, the Reforestation group and types, the simulation group, and the new columns (BpsFile,
the Land Cover Layers maps). A library needs a Data Download of BpsFile and a new Build for reforestation; with BpS missing and
Reforestation on, stage 5 stops with a message. Turn it off on Reforestation Options to build as before.

### Added
- Land Use Demand: alternative amounts of urbanization in a projection, to see a wide range of what could happen with development
  under different scenario assumptions. Every method is a ratio per unit and year that multiplies the Urbanization target's drawn
  area, as it is (a ratio of 1 keeps the reference period's rate). Set on the Projection > Land Use Change page: one page with a
  card per kind of change (urbanization, intensification, agricultural expansion and contraction, cropland and pasture exchange,
  forest harvest). Cropland and pasture exchange takes the same choices for both directions plus a balance (pasture to cropland times it, cropland to
  pasture over it: above 1 is more cropland, the more intensive agriculture). Each card asks how much (the choice shows only its own settings, custom multipliers are entered in the card,
  with a sentence and a chart of the multiplier through time) and folds the units, shared draw, protected land and placement
  behind "Where and how". It replaces the Land Use page and the Land Use Demand sheets as separate pages. New output sheet Land
  Use Multipliers Applied (every unit and year). Urbanization is one of:
  - **Historical years as drawn** (the default: no ratio).
  - **Historical high years / low years**: each target unit's mean area in its highest (lowest) third of reference years over its
    mean in all of them.
  - **RPA 2020 Assessment ratio**: RPA's urbanization relative to its own 2012-2020 step, for one of its four RCP-SSP pairs (the
    mean of its five climate models), pooled by metropolitan area (other counties by state) or by state.
  - **ICLUS v2.1.1 (EPA) ratio**: new suburban and denser land (ICLUS classes 12-16) relative to ICLUS's first modelled decade,
    2010-2020, for SSP2-RCP4.5 or SSP5-RCP8.5 (the mean of its two climate models), to 2100; pooled as RPA.
  - **Population (SSP) x land per new resident**: two levers. How many people: Hauer's (2019) county populations for SSP1 to SSP5,
    2020-2100, on the Census 2020 population. How much land each new resident takes, relative to 2010-2020 (0.5 compact, 1.5
    sprawl). By county (default), metropolitan area or state. New developed land a year = c0 x population + c1 x population gain,
    fitted on Annual NLCD and Census estimates of 3,053 counties, 2000-2020 (c1 / c0 = 176 years, editable); as a ratio a county's
    own land per person cancels, and a county that loses people keeps the development that goes on without growth.
  - **Custom ratio table**: the user's own ratio by year for any Stratum Source unit, or everywhere; linear between its years.
  Ratios are interpolated between the midpoints of each source's steps and keep the last value afterwards; every method but the
  custom table is capped (Highest Ratio Allowed, 3). **Intensification Follows** applies the method to Intensification too (with
  Population: the people's ratio over the land factor, so compact growth intensifies more). **Ag Expansion Demand** and **Ag
  Contraction Demand** are settings of their own, with the methods that need no outside source: historical high or low years,
  or the custom table (its rows say what they apply to: Urbanization, Ag Expansion or Ag Contraction). No published source is
  offered for agriculture: RPA's does not match Annual NLCD and barely changes, and ICLUS models none. **Forest Harvest Demand**
  (clearcut and selection) has the same three, and **RPA 2020 Assessment (forest products) ratio**: the timber harvest of the
  study area's RPA region, for one of the four RCP-SSP pairs, relative to 2020 (Johnston, Guo and Prestemon 2023, FOROM; every
  five years to 2070, then kept). It is a narrow, demand-driven outlook: harvest rises in every scenario (2070: 1.04 to 1.45
  times 2020) and the six regions move together; a ratio of volume, so volume per hectare is taken as unchanged. Forest Management
  rows act on the targets it leaves.
  The ratios are computed in the stage from published data, five new Data Sources that Data Download fetches (group Land use
  demand; nothing pre-computed ships): **RpaLandUseFile** (Mihiar, Lewis and Coulston 2023, https://doi.org/10.2737/RDS-2023-0026),
  **IclusCountyFile** (U.S. EPA 2020; the four 90 m map sets, 6.3 GB, are tabulated by county and only the table is kept),
  **PopulationProjectionFile** (Hauer 2019, https://doi.org/10.17605/OSF.IO/9YNFC; summed to county totals) and
  **CensusPopulationFile** (county estimates 2010-2020), and **RpaForestProductsFolder** (https://doi.org/10.2737/RDS-2022-0073-2). The Target Strata need not be counties: every cell takes its county's
  ratio (the Counties stratum source) and a target unit the mean of its cells, weighted by where its historical urbanization was.
  The log says when target units span several ratio units (a state or ecoregion gets one blended ratio), when a unit takes its
  state's ratio (too little urbanization in the source's base step, or a county its tables lack) and which units no source covers
  (ratio 1); the stage stops when a table is missing, when there is no Counties source, or when no county of the study area is in
  the source. The analysis behind the choices is in `dev/land-use-demand`: RPA against Annual NLCD 2012-2020 for 3,021 counties
  (urbanization agrees in total, 0.96, not by county; agriculture does not agree); the population model explains where
  development is (R2 0.67) but not how a county's rate changes between decades, so its county ratios are scenarios, not
  predictions. Tests: `tests/unit-land-use-demand.R`, and `tests/phaseZ32-land-use-demand.R` (stage 9 alone on a Build result, once
  per method: Puget Lowland at 990 m; every check passed and the kinds without a setting kept the baseline's targets). Known
  limit: the five download handlers have not yet fetched their sources through a Data Download run.

- Stage 18 - Wood Products (to-do 59): what becomes of the carbon a run harvests. ST-Sim moves harvest and land-clearing wood to
  Forestry Sector and nothing flows out of it; this stage follows it through products in use, landfills and dumps, by year, with
  the USFS harvested wood products model (`src/wood-products.R`: Smith et al. 2006, Skog 2008, the HWP-C calculator; parameter
  tables and sources in `defaults/wood-products`). Run it in its own scenario on the run's Build result, like Run Figures; a
  projection is joined to its historical run. Before the run it starts from each region's harvest history from 1906, scaled to the
  run. Parameter draws (default 100 per iteration) give a 90% interval. New page Wood Products; new output sheets Wood Products,
  Wood Products by End Use, Wood Products Spin-up and Wood Products Figures (Export > LUCAS Core > Wood Products Figures). On a
  national harvest series the model's stock is within 7% of the US Inventory's and its stock change within 3% (1990-2016).
  Tests: `tests/unit-wood-products.R`, `tests/unit-wood-products-national.R`, `tests/phaseZ30-wood-products.R` (the stage on a
  library's runs, read-only).
- Run Figures and Compare Runs show the wood products of a run that stage 18 has followed (its newest Wood Products result): a
  Harvested wood products figure (carbon stored in use and in landfills and dumps; net biome productivity with the change in that
  store added, the production approach), and in Compare Runs' carbon summary the columns HWP and NBP + HWP (Compare Carbon Summary:
  HwpStored, HwpStockChange, NbpWithProducts). A historical run takes its projection's result when it has none of its own. Runs
  without a result are drawn as before. Test: `tests/phaseZ31-wood-products-figures.R`.
- Management Actions (Projection > Management Actions; to-do 58): replanting after a disturbance, with or without site preparation
  (pile and burn, or mechanical), and salvage logging, as an area a year in chosen years and strata units, within a window of
  years since the disturbance. Replanting returns disturbed forest to its own type at age 0; a survival share fails and stays
  disturbed; it can go first where natural return is least likely (far from live forest). Six new transition types, three groups,
  site preparation carbon flows, mapped and summarized. With spatial tiles every action names a unit of the tile level. An empty
  page is the baseline. Changes Build results (new pathways); projection results only when actions are set.
- Forest Management (Projection > Forest Management): improved forest management as changes to the harvest a projection draws
  from the historical record, by years and place (a unit at any of the three strata levels): a share of clearcut moved to
  selection (by area, or by volume: the same wood removed), a share of selection moved to light selection, a harvest scale, and
  minimum and maximum stand ages per harvest type (a maximum protects older forest). A row by a strata level the harvest targets
  are not keyed on splits them by each place's historical harvest. Stage 9 writes the reshaped targets and age multipliers;
  Projection Results > Forest Management (as set up) lists each row's drawn and managed harvest. An empty page is the drawn harvest.
- Rangeland restoration after fire (Projection > Management Actions): aerial seeding, drill seeding and sagebrush planting on
  burned sage and sage steppe, and herbicide then seeding on burned invaded steppe and on annual grass in the Great Basin and steppe
  ecodivisions. Each is an area a year (or a budget) in chosen years and places, with a window in years since the fire and a
  success share: what establishes goes to Native Sage Steppe at age 0, the rest stays as it was and can still return or convert.
  Defaults from a literature review (success 0.15 aerial, 0.25 drill, 0.35 planting, 0.3 herbicide and seeding; costs per
  hectare by region with ranges, `defaults/management/costs.csv`; provisional). Eight new transition types and a group: a new
  Build is needed for restoration. Library update: the types, group and cost attribute type, and the output filter rows.- Fuel Treatments (Projection > Fuel Treatments): mechanical thinning, prescribed burn, and thin and burn on upland forest, as an
  area a year (or a budget) in chosen years and places, with a stand-age window, a retreatment interval and a priority (random,
  or where wildfire burned more often). A treatment keeps the forest type and stand age; its carbon moves when it happens
  (thinning: a quarter of live biomass cut, most merchantable wood to the forestry sector, slash piled and burned; prescribed burn:
  most litter and fine woody debris burned, some coarse wood and snags, 2% of foliage scorched, 5% of live trees killed). For a wildfire in a treated cell, the severity shift: less
  high and medium severity and more low, by years since the treatment (thin and burn: high severity x0.28 the first five years,
  fading by 20), keeping the expected burned area (fire methods 1 and 2). Each type tracks its own time since treatment (ST-Sim
  time since transition). Costs per hectare by region (`defaults/fuel-treatments/`, 2024 USD, provisional, ranges per iteration);
  thinning's wood earns the harvest timber revenue. New types and pathways: a new Build is needed for treatments. Projection
  Results > Fuel Treatments (as set up) lists each row. Library update: the treatment groups join existing output filters.
- Timber revenue on every projection: transition attribute Management Revenue: Harvest Timber on clearcut, selection and light
  selection, per ecodivision, forest type and 10-year age band = merchantable volume (the Build's curves) x removal share (0.97,
  0.5, 0.2) x regional stumpage price (`defaults/forest-management/stumpage.csv`, 2024 USD/m3, softwood or hardwood by
  `forest-type-wood.csv`, provisional, with ranges sampled per iteration). Harvesting less shows as revenue given up in the Compare
  Cost Summary.
- Light selection: `Forest Harvest: Forest Selection 20%` (20% of live biomass removed) takes Forest Selection's minimum ages
  (stage 6; projections on older Builds get them as multipliers). `Forest Harvest: Forest Selection 85%`, unused and with flows
  that sent its merchantable wood to dead wood, is gone from new libraries (existing libraries keep it in their lists, unused).
- Management costs: Management Actions rows carry costs and revenue per unit area, as ST-Sim transition attributes (group
  Management Cost: Planting, Site Preparation, Salvage Logging, and Management Revenue: Salvage Timber; USD), so a projection with
  Transition attributes output reports them a year by type and strata. New projections (`tools/new-projection.R`) turn that
  output on.
  - Defaults by region (`defaults/management/costs.csv`, 2024 USD per hectare, provisional, with low-high ranges and sources;
    each ecodivision's region in `cost-regions.csv`): California, Pacific Northwest, Interior West, South, Northeast, and national
    values where a region has none. A study area spanning several regions gets each ecodivision's own. A row's own values win.
  - Ranges: each value is a Beta distribution over its range (SD a sixth of it), drawn once per iteration, so several iterations
    give the cost spread. Cost Range "Fixed values" turns that off for a row.
  - Salvage: logging cost and timber revenue apart (net = revenue - cost); the revenue falls 25% a year with years since the fire.
  - Budget mode: a row can give a budget (USD a year) instead of an area; stage 9 plants or salvages the area it pays for at the
    central cost per area.
  - Compare Runs: a Compare Cost Summary per projection, with costs, revenue and net cost over the run (mean and the
    iterations' range), the extra net cost over the baseline, and the carbon gained with USD per Mg C and per Mg CO2e on two
    bases: total ecosystem carbon at the end, and that plus the carbon stored in harvested wood products (stage 18 on both runs).
- Seven study area and strata sources (Stratum Sources presets 11-17): FWS Refuges, DoD Installations, National Forests,
  Wilderness, Tribal Lands, BLM National Conservation Lands and Metropolitan Areas. The first five and BLM come from PAD-US 4.0 (a
  new edition of the PAD-US units download), Tribal Lands from Census TIGER/Line 2022 (a new Data Download dataset), Metropolitan
  Areas from the Counties polygons grouped by the OMB 2023 metro delineation. Custom sources now take Numbers 18-20. Existing
  libraries get them with `tools/new-library.R <library> --rebuild-strata`, and a Data Download with Fetch new editions.
- The Reforestation transition: group Reforestation, one type per forest class ("Reforestation: <type>"), pathways from every
  natural non-forest class to every forest class, age reset; no carbon flows, so the grass or shrub carbon carries over and the
  forest grows from age 0 (`tools/make_reforestation.R`). Historical runs (stage 6): a cell reforests in the year NLCD shows it as
  forest (41-43) for the second year running, as the forest type stage 5 gives it (new Land Cover Layers map: the forest type of
  every cell). Projections: a Target group in its own sampling set, drawing from the last 10 years of the record (stage 9), placed
  by a fitted Reforestation surface (stage 10) whose events follow the stage 5 rule, with new covariates Forest potential (BpS),
  Distance to forest and Forest share within 1 km.
- Reforestation Options (scenario, LUCAS Core group): the transition on or off, the cutoff (blank = fitted by ecodivision), how
  LANDFIRE's riparian and savanna types read (forest potential by default), and the number of recent years projections draw from.
- Data Source LANDFIRE Biophysical Settings 2020 (BpsFile), fetched by the Data Download; its attribute table and the potential of
  each vegetation group ship in `defaults/landcover`.
- Stratum Source National Parks (Number 10): every National Park Service unit in CONUS (384) by name, from PAD-US 4.0 NPS fee land,
  for a study area of one park. New Data Download dataset PAD-US 4.0 management units (`study-area/padus-units/padus4-units.gpkg`);
  `tools/make_nps_units.R` writes the unit list with stable ids. Existing libraries: `tools/new-library.R <library> --rebuild-strata`
  (custom sources now take Numbers 11-20).
- `tools/new-projection.R --base=<id> --also=<ids>`: a projection on a Projection Setup made on a quick-test result.

### Changed
- Projection pages reorganized by what drives the change. Transitions is now **Land Use Change** (its layout: see Added; urbanization, intensification,
  agriculture, forest harvest), laid out as the management pages: each group with its choices and a short note beside them (how
  much and by which strata or rate units, the shared draw, protected land as GAP check boxes, and where each of its types goes:
  method, surface, adjacency for land use, patch sizes), written straight into its row, and an "In words" sentence per group.
  Fire's row (rate units, shared draw, protected land) moved to the top of the **Fire** page. New **Natural Change** page:
  Reforestation Options (moved from its own item) and the Reforestation row; insects and drought go here later. The two tables
  stay on Land Use behind **Show tables** (source and event classes are edited there); Forest Management, Fuel Treatments and
  Management Actions hide their tables behind **Show table** too. Management Actions is renamed **Post-Disturbance Recovery**
  (its outputs: Post-Disturbance Recovery (as set up)). Projection menu: Run Settings, Land Use Change, Spatial Allocation, Fire, Natural
  Change, Fuel Treatments, Forest Management, Post-Disturbance Recovery, Climate. Display only: no change to the sheets or results.
- Build stage 5: reforestation (to-do 57). A natural cell that is barren, shrub, grass or emergent wetland at the start and that
  NLCD later shows as forest no longer always starts as forest. It starts as its start-year class when its potential vegetation
  (LANDFIRE BpS 2020) is not forest, or when it is forest potential but NLCD first shows forest only at or after its ecodivision's
  cutoff: 11-12 years in the Southeast, 18-20 in the East and Marine lowlands, 23-24 in the Marine and Mediterranean mountains,
  26-29 in the dry West (`defaults/landcover/reforestation-cutoff.csv`, fitted by `tools/fit_reforestation_cutoff.R` as the 90th
  percentile of the years forest takes to come back after a dated clearcut or high-severity fire). Cells that come back before
  the cutoff stay forest with the regrowth age, as do cells that flicker between forest and shrub or grass. On Lassen Volcanic
  National Park (150 m) 117 of 6,591 such cells reforest, and the start has 0.8% less live carbon. Changes Build results.
- Post-disturbance settings fitted (`defaults/transitions/post-disturbance-settings.csv`, to-do 57 step 7). Forest by ecodivision
  from MTBS high-severity loss followed in NLCD (`tools/fit_post_disturbance.R`). Shrub classes from RCMAP sagebrush and shrub
  cover after moderate and high severity fire on NLCD shrub pixels (`tools/fit_shrub_post_disturbance.R`): Sage and Native Sage
  Steppe window 27 years, 43% back; Invaded Sage Steppe kept slower (0.6 times the return probability, reburns convert); Non-sage
  20 years, 79% back; Chaparral 8 years, 87% back, reburn conversion 0.10. Changes Build and Run results.
- Moderate-severity fire is now stand-replacing in the shrub classes (Sage, Native and Invaded Sage Steppe, Non-sage, Chaparral):
  like high severity it moves the cell into its disturbed class (age reset), and a moderate or high reburn there can convert it.
  RCMAP shows moderate-severity shrub fire losing and regaining cover as high-severity fire does. Its carbon follows: moderate fire
  in these classes burns and kills what high-severity fire does (`defaults/stockflow/nonforest-fire.csv`). Forest is unchanged
  (high only). Changes Run results.
- `Forest Harvest: Salvage Logging` now acts on the 31 disturbed forest classes (28 upland, 3 wetland twins) instead of the live
  forest classes: within 5 years of the disturbance (the class's age), staying in the class with its age, so return and conversion
  keep their clock. Its carbon flows are unchanged and on a disturbed class take mostly snags to the forestry sector. Salvage has
  no mapped source or default target, so results do not change; it is there for management scenarios (to-do 58).
- Build stage 5: a check that every forest cell has an age failed when a fire perimeter started cells in a disturbed class; it now
  allows the disturbed classes an age, and names any failing cells by class.

### Removed
- `Shrubland: Post Fire Shrub` (class 59) and the two transition types that led to it (`Ag Contraction Cropland: Shrubland Post
  Fire Shrub`, `Ag Contraction Pasture: Shrubland Post Fire Shrub`). Nothing reached the class: no cell starts in it, agriculture
  contracts to the nearest natural class, and fire now moves land into the disturbed classes. New libraries no longer have it;
  existing libraries keep it in their lists, unused. No change to results.
- The 28 `Succession Post Fire: <type>` transition types and their groups (`Succession: Post Fire Recovery` and the empty
  `Succession`). No pathway used them: burned forest now returns from its disturbed class by `Post-disturbance: Forest Return`.
  Same as above for new and existing libraries. No change to results.

### Fixed
- Data Download fetched the Cropland Data Layer again when its files had been unzipped into `land-cover/cdl` by hand over a failed
  earlier download, and failed again. The Data Sources page then showed "home failed", and a Build could stop on the failed
  manifest row. A year whose file is in place and is the national 30 m layer is now recorded as it is, with its checksum, by hand.
  Only the missing years are fetched.
- Run Figures and Compare Runs stopped with "Object reference not set to an instance of an object" when the Build result they
  depend on had lost its maps from the library's data folder (Puget Lowlands). They now take the model grid from the run's own
  initial conditions map when the Build's cannot be read, and say so in the log.
- Compare Runs' summary tables: a long run name or many columns made the headers and values overlap. Columns are now sized by the
  width of their text as drawn, and the table scaled to fit.
- Ag Change targets were ignored in spatial projections (ST-Sim warned "At least one Transition Target has been defined with a
  non-primary Transition Group"; seen in 1.3.2 too). Ag Change was a transition simulation group, so it was the primary group of
  both its types, while their targets (one area per unit each) are on the types' own `[Type]` groups; ST-Sim's spatial allocation
  uses only the primary group's target, so cropland to pasture and pasture to cropland ran at their pathway probability and stage
  10's multipliers. Ag Change is no longer a simulation group, so each type's `[Type]` group is primary and takes its target; the
  Ag Change group still sums both, and the two `[Type]` groups are mapped. The 1.4 library update removes the row; on 1.3.x,
  delete Ag Change from the project's Transition Simulation Groups. Changes projection results where cropland or pasture change
  (not Lassen). New `tests/unit-primary-groups.R`: every default and management target is on a primary group.

## 1.3.2 - 2026-11-11

A fix for projections started from a 1.3 historical run, and better starting ages for regrowing forest.

**Upgrading:** install `lucasCore-1.3.2.ssimpkg` in place of 1.3.1. There is no library update: switch a library's lucasCore
package to 1.3.2 (`SyncroSim.Console.exe --add --package --pkg=lucasCore --ver=1.3.2 --lib=<library.ssim>`). Both changes take
effect at the next Build; rerun the Build and then the historical run before a Projection Setup that starts from it.

### Fixed
- A Projection Setup that starts from a historical run stopped with "historical run ... has no <year> map for DOM: Peat". The
  stock output filter still had peat maps off from before 1.3.0 filled that stock, so a historical run wrote no final peat map.
  Peat maps are now on (`defaults/stockflow/stsim_OutputFilterStocks.csv`).

### Changed
- Build stage 5: a cell that starts as forest only because NLCD shows it as forest in a later year, and whose record shows it
  regrowing (not forest at the start, then forest within 20 years and staying forest), takes its starting stand age from that
  record instead of from NASA CMS or TreeMap. Those sources gave 1980s clearcuts and burns ages of about 45 years, so they started
  with mature forest carbon and their regrowth was missed. Settings in `defaults/landcover/regrowth-age.csv`. On existing maps this
  resets 45 kha in the Northern Sierra Nevada (P26) and 58 kha in the Puget Lowlands. Changes Build results.

## 1.3.1 - 2026-11-11

A fix for library update 1.3.

**Upgrading:** install `lucasCore-1.3.1.ssimpkg` in place of 1.3.0. Opening a 1.2 library runs library update 1.3, as in 1.3.0
it was meant to. A library already at 1.3 needs no update; switch its lucasCore package to 1.3.1
(`SyncroSim.Console.exe --add --package --pkg=lucasCore --ver=1.3.1 --lib=<library.ssim>`). Builds and results are as in 1.3.0.

### Fixed
- Projection Setup (stage 10) no longer stops when a study area has too few historical events of a kind to fit its suitability
  surface (fewer than 30 in the fitting region: a park with almost no urbanization, a county with no agriculture). The surface
  drops its covariates; developed and agriculture change is placed by adjacency alone (the curve read from the study area's annual
  maps), other change at random within its strata. The run log and the suitability summary say which surfaces fell back and why.
  Stage 9 with the burn probability fire option no longer stops when the study area has no burnable land.
- Strata polygons read from Data Sources Home ignored newer editions of a dataset, so a preset whose layer exists only in a newer
  edition (the PAD-US units file) could not be read. A preset now reads the newest edition that has its layer.
- Build stage 6: pathway rows written by ecodivision (`fire.csv` and `post-disturbance.csv`: reburn proportions, return window and
  conversion age) lost their ecodivision, so every ecodivision's rows applied everywhere. Each disturbed forest class had about 19
  return pathways, so its yearly return chance was drawn 19 times: on Lassen 90% of a burn came back in its first eligible year
  instead of 7% a year. Conversion started at the earliest window of any ecodivision (12 years instead of 25 there), and reburn
  proportions stacked. Only the study area's ecodivisions' rows are kept now, and a Build check stops on any pathway written twice.
  Changes Build and Run results; libraries built before this need a new Build.
- Historical runs no longer return disturbed land to forest in the year it burned (return pathways from age 2), and Projection
  Setup (stage 10) fits a suitability surface whose covariate has fewer distinct values than its smooth term allows.
- Library update 1.3 stopped with "SQL logic error, near "s": syntax error", and the library stayed at 1.2. The update's
  description had an apostrophe in it, and SyncroSim writes that text into the library without quoting it.

## 1.3.0 - 2026-11-11

Forested wetlands as classes of their own, peat as its own soil stock, and a carbon fluxes figure that breaks the balance down by
driver. Tested on the Great Dismal Swamp (Chesapeake and Suffolk, Virginia). Includes every fix from 1.2.1 to 1.2.3.

**Upgrading:** install `lucasCore-1.3.0.ssimpkg`. Opening a 1.2 library with it runs library update 1.3, which adds the new state
classes, transition types, stock, flows and groups. Close Studio before you update. A library needs a new Build to give its forested
wetlands their own classes and peat. Until then its results stay as they were in 1.2.

### Added
- Forested wetland classes Wetland: Spruce/Fir Group (121), Wetland: Oak/Gum/Cypress Group (601) and Wetland: Elm/Ash/Cottonwood
  Group (701). Each one twins its upland group. FIA conditions on hydric sites (physiographic class 31-39) are split off to the twin,
  so the twins get their own growth curves, dead wood fits, stem turnover, CO2 ECM share and minimum harvest ages. A regions table
  picks the twin for each ecodivision. The twins have their own Ag Contraction transition types and carbon burial into Deep Soil
  (0.25 / 0.1 / 0 Mg C/ha/yr).
- Palustrine forested cells now start as their region's twin class. Estuarine forested cells start as Wetland: Estuarine Forested
  (91), and Wetland: Palustrine Forested (90) starts empty.
- DOM: Peat stock. In Build stage 8, each cell with a gNATSGO Histosol share starts with the organic soil carbon above its class's
  soil, capped by that share. Peat does not decay. It is lost to fire in any class (0.03 / 0.07 / 0.15 of the stock by severity),
  to drainage under cropland and pasture, and to urbanization. Peat counts in DOM: Soil and Total Ecosystem, and has a cell in the
  flow diagram.
- Data Sources and Data Download: the Histosol share (`soils-terrain/histosol/*.tif`). The Download page can now tick the Cropland
  Data Layer, tidal marsh NPP and the Histosol share.
- Run Figures, Carbon fluxes is now six panels: NPP, Rh and NEP; losses by cause (fire, insect, forest harvest, land use change,
  crop harvest, drained peat) with NBP; emissions by driver (fire on vegetation and on peat, insect, harvest, urbanization, other
  land change, drained peat); removals (harvested wood, wood from land use change, crop harvest, lateral export); a waterfall from
  NPP to NBP; and NBP by land cover. Compare Figures uses the same causes.

### Changed
- Dead wood decay: a wetland class with enough FIA plots gets its own fit, with duff held at its upland type's value (FIA hydric
  duff is muck or peat). A wetland class with too few plots takes its ecodivision's upland values.
- The Organic Soil Share flow multiplier and the Organic Soil flow group are retired. Peat flows now draw on DOM: Peat.

### Fixed
- Build stage 4: the soil spin-up leaves peat fire out, as stage 3 calibrates. Before this, wetland soil started at a quarter of its
  target.
- Stages 5 and 6: if a parallel step runs out of memory, it runs again on half the workers. An error names its NLCD year.
- Stage 7 and later: PROJ no longer fetches datum grids from the internet, and the climate window is in NAD83 (EPSG:4269). Behind
  some firewalls, the climate step stopped with "invalid extent".
- Run Figures: the carbon by secondary stratum chart is at least one chart row tall per unit. A run with many units failed with
  "figure margins too large".

## 1.2.3 - 2026-11-10

A Build fix for machines with less memory than cores.

**Upgrading:** install `lucasCore-1.2.3.ssimpkg`. There are no schema changes from 1.2.0, so a 1.2 library needs no update; switch
its lucasCore package to 1.2.3 (`SyncroSim.Console.exe --add --package --pkg=lucasCore --ver=1.2.3 --lib=<library.ssim>`).
Results are as in 1.2.2; only how many parallel workers stages 5 and 6 start changes.

### Fixed
- Build stage 5 (and stage 6): the parallel NLCD steps start no more workers than the free memory allows (2 GB each), and each
  worker's terra memory share is divided among them. Left at terra's own share, every worker planned on most of the free memory,
  and on a machine with less memory than cores stage 5 failed with `std::bad_alloc`. tests/unit-par-workers.R checks it.

## 1.2.2 - 2026-11-10

USFS forest type tiles kept whole in the data home, and a Data Download fix for networks that block remote reads of Box.

**Upgrading:** install `lucasCore-1.2.2.ssimpkg`. There are no schema changes from 1.2.0, so a 1.2 library needs no update; switch
its lucasCore package to 1.2.2 (`SyncroSim.Console.exe --add --package --pkg=lucasCore --ver=1.2.2 --lib=<library.ssim>`).
Only the Data Download changes; Builds and their results are as in 1.2.1.

### Changed
- Data Download, USFS forest type groups: each FIA region's tile is kept whole at the top of the data home, like TreeMap, and only
  the tiles a study area touches are fetched; a second study area in the same region reads the tile already there. A region
  downloaded earlier keeps reading its clipped copy. A tile's zip (any name) or its `<REGION>_ForestType.tif` saved by hand in
  `<home>/supplied` is used instead of fetching.

### Fixed
- Data Download, USFS forest type groups: on a network where GDAL cannot read the Box zips remotely, the stage stopped with "file
  does not exist". It now fetches every tile whose extent touches the study area instead.

## 1.2.1 - 2026-11-10

Grass and shrub live carbon fitted to field biomass, and California's crop mix filled where a county's report leaves a crop out.

**Upgrading:** install `lucasCore-1.2.1.ssimpkg`. There are no schema changes from 1.2.0, so a 1.2 library needs no update; switch
its lucasCore package to 1.2.1 (`SyncroSim.Console.exe --add --package --pkg=lucasCore --ver=1.2.1 --lib=<library.ssim>`).
The changes are in the package defaults, so rerun the Build to use them; results made with 1.2.0 keep their values.

### Changed
- Grassland and shrubland (to-do 55): growth stays on RAP NPP for every class, and each class's turnover is now fitted so its live
  stocks match field biomass (aboveground and roots, from a literature review). Chaparral's wood turnover is 0.08 a year (was
  0.03), which puts mature Mediterranean chaparral growth at about 2.5 Mg C/ha/yr with its stocks unchanged. Non-sage shrub and
  Native Sage Steppe split their growth between a grass layer and a shrub layer by RAP's herbaceous share, bringing their live
  carbon down to about 1.5 / 2.0 and 1.4 / 2.4 Mg C/ha (aboveground / roots) at the class's mean NPP, from 3 to 5 times that.
  Annual grass roots die back each year. In the Calaveras test, annual grass live carbon fell from 4.8 to 3.7 Mg C/ha and non-sage
  from 18.4 to 7.4.
- Crop Mix (California): a crop missing from a year of a county's commissioners' report (counted under "unspecified" so growers
  stay private) takes its area interpolated between the years it was reported, or its 2019 area when 2020 is missing. 3,404
  crop-years filled; Calaveras's 2020 crop mix goes from 0.37 to 0.85 of its 2014-2020 level (its walnuts had been left out).

## 1.2.0 - 2026-11-09

Grassland, shrubland, wetland and agriculture carbon rebuilt from data, CO2 fertilization in projections, and library updates.

**Upgrading:** install `lucasCore-1.2.0.ssimpkg` (File > Packages > Install from file in SyncroSim Studio), then update each
library made with 1.0 or 1.1: switch its lucasCore package to 1.2.0 and let SyncroSim update it, or from a command prompt

    SyncroSim.Console.exe --add --package --pkg=lucasCore --ver=1.2.0 --lib=<library.ssim>
    SyncroSim.Console.exe --update --lib=<library.ssim> --backup

(--backup keeps a .ssimbak copy in the library's .backup folder). The update adds the new columns, the agriculture stock, flows and
flow groups, the new Flow Multiplier Types, and the stock-flow rows of a Stock-Flow Definitions scenario; tools/sync-library.R is
no longer needed for that. Results made with 1.1 keep their values; rerun the Build to use the new non-forest carbon. Needs
SyncroSim 3.1.29 or later with ST-Sim 4.5.4.

### Added
- Library updates (ui/LucasCoreUpdates.cs, SyncroSim's .NET update provider): each version's schema and definition changes are applied
  when a library made with an earlier version is opened. Every step checks first, so a library that already has a change is left as
  it is. The 1.1 update (the Study Area options table) moved here from updates/update-1.1000.xml.
- Grassland and shrubland carbon by ecodivision (to-do 39): growth and soil from RAP NPP and gNATSGO, pools and litter from the
  literature; chaparral, non-sage shrub and the sage family grow by years since fire (woody recovery from the literature, the early
  dip from RAP within MTBS fire perimeters).
- Emergent wetlands by ecodivision, fitted in ST-Sim's flow order; estuarine growth recalibrated to the USGS tidal marsh NPP map.
- Cropland and pasture grow, are harvested and decay (to-do 39 step 6): a new Agriculture Sector stock, Net Growth Agriculture and
  Harvest flows, and Crop Yield multipliers from NASS county yields by year.
- Build Options > Site Productivity, three choices (each None by default): Grass and Shrub Productivity (RAP NPP 2014-2023),
  Cropland Productivity (each cell's Cropland Data Layer crops at their county's NASS growth, with a Crop Harvest map, and in
  California the County Agricultural Commissioners' rates and yearly crop mix, Crop Mix) and Tidal Marsh Productivity (the USGS
  tidal marsh NPP map). Data Sources: RAP NPP, Cropland Data Layer and tidal marsh NPP folders, filled by the Data Download.
- Climate Options > Non-Forest Growth: RAP fit (the default), grass and shrub growth from the water year's rain by season, last
  year's rain and temperature, fitted to RAP NPP; PRISM monthly precipitation is downloaded for it.
- CO2 fertilization of growth in projections (stage 11, to-do 46): the Climate page of a Projection Climate scenario chooses a series
  (None / Low / Central / High, Central by default), an optional CO2 ceiling and reference CO2, and a table of its betas. Growth
  is multiplied by 1 + beta ln(CO2 / the CO2 of the historical end year), with CO2 from the SSP (Meinshausen et al. 2020) and beta by
  vegetation type from a literature review; forest betas mix ECM and AM values by each forest type's ECM share of FIA basal area and
  taper with stand age. New CO2 Flow Multiplier Type; a CO2 Betas table on the page, loaded with the chosen series' defaults for the study area's strata and editable; CO2 Fertilization Betas and CO2 Series results.
  The No Climate projection has no CO2 effect.
- tools/make_co2_ecm_share.R (the ECM shares from the FIA DataMart tree tables) and tools/make_co2_default_betas.R (the table the page loads).
- Build result: a Non-Forest Productivity table (each non-forest multiplier by ecodivision and class: cells, share with map data,
  mean, 10th, median and 90th percentile, share at the cap).
- Build Figures: the non-forest productivity maps beside forest site productivity (Figure 4), shrubland years since fire (Figure 2),
  shrubland net growth by years since fire and the other non-forest classes' net growth (Figure 6), burned area by land type
  (Figure 9) and an agriculture panel of Crop Yield and Crop Mix (Figure 10).
- The data home keeps each dataset's download records in records/, so a home copied or restored whole is not downloaded again (to-do 52).

### Changed
- FIA Data in Growth Curve Options defaults to the FIA DataMart. A library set to the USGS condition tables whose files are not set
  reads the DataMart instead and says so in the log (a new library's Build stopped in stage 2).
- TreeMap is kept whole at the top of the data home, like FIA and PRISM, so each new region reads it instead of fetching the 5.4 GB
  zip again.
- Data Download: a dataset that only a browser can fetch (RCMAP 1985 on ScienceBase, which now asks for a captcha) is a step for the
  user, listed at the end of the log, not a failure that stops the run. A stage that stops on a failed check names what failed.
- Stage 11 runs when every climate effect is None, for CO2 alone, and copies the Build's flow multipliers into its result when it
  writes CO2 rows.
- Minimum SyncroSim version raised from 3.1.9 to 3.1.29, the version lucasCore is tested on (3.1.9 was never tested). The README
  names the rsyncrosim version tested with (2.1.13).

### Fixed
- The data home no longer counts a Build's FIA caches or a GIS overview (.ovr) beside a raster as part of a dataset, which made
  the FIA DataMart and the Cropland Data Layer look out of date and download again.
- tools/new-library.R: the LOCA2 lookup no longer breaks when Data Sources Home is set.
- Build Figures: Figure 8's transition types each have a colour and key; a legend too wide for the space beside its panel title
  wraps (Figures 7, 8, 10); the decay and checks charts no longer fail with few rows.
- Stage 8 run alone keeps the Initial Conditions Spatial feed and the dependency's flow spatial multipliers; stage 7 run alone keeps
  the Build's productivity multipliers.

## 1.1.1 - 2026-11-09

Released from v1.1.0 (branch release/1.1.1); main has the same fix.

### Fixed
- Every stage failed with "more columns than column names" on a machine with only a few SyncroSim packages installed. rsyncrosim
  reads the installed-package list by turning runs of spaces into commas, so the commas in the package description added columns.
  The description no longer has commas; tests/unit-package-description.R checks it. Libraries made with 1.1.0 open unchanged.

## 1.1.0 - 2026-11-05

### Added
- Ag Change, a new land-use transition group: Pasture to Cropland and Cropland to Pasture, from the NLCD class changes, historical and projected.
- Projection Run Settings, "Target areas from": each Target group's projected area is what a historical run realized (gains counted as first-time gains only), instead of the area on the historical maps.
- Projection Allocation method 4, Adjacency: places a group by the share of one class around the cell, from a curve read off the annual maps; Ag Change uses it in both directions, with new Pasture and Cropland state attributes.
- Fire pathways for Developed Open Space and Developed Low Intensity.
- Stage 16, Model Record: a Build's FGDC CSDGM record in its own stage.
- Stage 17, Data Release: writes a USGS data release folder from a Build and its runs, with content checks and a review packet.
- Release Information and People pages for data releases.
- A path to mp (the USGS metadata parser) on the Data Sources page.
- RCMAP can be supplied by hand when ScienceBase refuses a script.
- User Guide Appendix B: the USGS data release workflow, worked on Puget Lowlands.
- Repository files for a USGS software release: code.json, LICENSE.md, DISCLAIMER.md, CHANGELOG.md, CONTRIBUTING.md.
- Stages 16 and 17 in the package blueprint; links between the guide and blueprints are relative.

### Changed
- Historical land-use maps follow the transition pathways: a cell is in a group's map only when the pair (class the model holds, mapped class) is one of that group's pathway pairs, and a change the map reverses within 3 years does not count. On Puget Lowlands every land-use group now lands within 3% of its maps (agriculture contraction had been 6.6 times too large).
- Harvest mapped on cells with no harvest pathway is placed on the nearest eligible forest cells in the same unit; minimum harvest ages are kept. Historical harvest on Puget Lowlands rose from 80% to 87% of mapped.
- The soil organic carbon source is named gNATSGO throughout (it was called gSSURGO in places).
- LOCA2: one file is read per period, the one covering the study window.
- tools/sync-library.R adds new transition types and groups, and makes a Carbon Assumptions scenario only with --carbon-assumptions.
- Stage 16 names whoever runs it, from the scenario's Release Information page.
- Model records cite the copy of each dataset the Build read, and say when it came by hand.
- Stratum Sources page redrawn in the style of the Data Sources page.
- Tests and tools take their locations from the script's folder and environment variables instead of paths on the build machine.

### Fixed
- Carbon Method page: the Fill prompt named the grassland tables by their old sheet names.
- Data Release page: "What to write" was cut off.
- Data Release and Release Information pages: Add a run crashed SyncroSim Studio.

## 1.0.1 - 2026-11-02

### Added
- Metadata definitions, data dictionary and input citations.

### Changed
- Stratum Sources polygons come from Data Download; Federal Lands come from PAD-US 4.0.

### Fixed
- Data Sources defaults no longer name folders on the build machine.
- Metadata citations match what Data Download fetches; ecodivisions cite Bailey.

## 1.0.0 - 2026-11-02

First packaged version: stages 0-15, from study area and strata through growth curves, carbon flows, initial conditions,
historical transitions, climate multipliers, projections, figures and Data Download.
