# TreeMap: forest type, stand age and site productivity from one map

Plan, 2026-10-29. Combines to-do 10 (TreeMap for forest type group and stand age) and to-do 35 (site productivity scaling of forest
growth). Not started; nothing in the package has changed.

## Why one plan

TreeMap (USFS, 30 m) gives every forest pixel an imputed FIA plot. Through the plot's FIA condition (DataMart COND, already read by
stage 2) the same pixel carries a forest type (FORTYPCD), a stand age (STDAGE) and a site class (SITECLCD, potential growth in cu ft/ac/yr,
1 = 225+ to 7 = 0-19). One join gives all three, consistently with each other and with the FIA plots the growth curves are fitted to.

## Today

- Forest type: LANDFIRE EVT or the USFS NFCMS forest type groups (Build Options: Forest Type Map), stage 5.
- Stand age: NASA CMS Forest Age 1990 (Data Sources: StandAgeFile), shifted to the start year, stage 5.
- Growth: one live carbon curve per forest type x ecodivision (stage 2). Every cell of a type, ecodivision and age grows the same; only
  the climate flow spatial multipliers (stages 7 and 11) vary it in space.

## Evidence so far

- To-do 10 (2026-10-26, dev/treemap/01-p26-compare.R): TreeMap 2016 type agrees with the Build's USFS groups on 61% of P26 forest
  cells (EVT 69%) and adds a Douglas-fir group; 1985 age median 81 vs CMS 73, cell-by-cell correlation 0.07. 82% of pixels joined to a
  condition with 31 states' COND (all 48 are now on disk).
- Site class (2026-10-29, TreeMap plots in CA/OR/NV with a site class, 6,757 plots): live carbon against age, with and without site
  class, by forest type group. Site class matters a lot, in the expected order:

  | Group | R2 age only | R2 age + site class | Carbon / curve at site class 2 / 3 / 4 / 5 / 6 |
  |---|---|---|---|
  | California mixed conifer (370) | 0.13 | 0.50 | 1.84 / 1.43 / 0.94 / 0.60 / 0.40 |
  | Douglas-fir (200) | 0.52 | 0.70 | 1.64 / 1.26 / 0.96 / 0.73 / 0.39 |
  | Fir/spruce/mtn hemlock (260) | 0.23 | 0.35 | 1.90 / 1.48 / 1.09 / 0.86 / 0.73 |
  | Ponderosa pine (220) | 0.19 | 0.30 | - / 1.52 / 1.73 / 0.99 / 0.81 |
  | Western oak (920) | 0.20 | 0.38 | 1.67 / 1.77 / 1.48 / 1.26 / 0.86 |
  | Lodgepole pine (280) | 0.41 | 0.44 | weak |
  | Tanoak/laurel (940) | 0.37 | 0.45 | weak |

  A quick model (log carbon on a quadratic in log age), not stage 2's curves; phase 0 redoes it on those.

## Phase 0 results (2026-10-29): go

- **(a) Site class against stage 2's own curves** (dev/treemap/02-site-class-curves.R; the fitting plots exactly as carbon_data filters
  them, 195,775 conditions, each plot's live carbon / the P26 Build's carbon curve for its type, ecodivision and age; site class on
  every plot). The multiplier m (mean ratio in the class / the type's mean ratio) falls with site class in nearly every type. P26's
  ecodivisions, site class 2 to 6: California mixed conifer M260 1.59 / 1.30 / 0.94 / 0.60 / 0.52 (1,328 plots); fir/spruce/mtn
  hemlock M260 1.72 / 1.40 / 0.97 / 0.74 / 0.59; Douglas-fir M260 1.51 / 1.13 / 1.09 / 0.86 / 0.67; ponderosa M260 1.98 / 1.34 /
  1.32 / 0.92 / 0.82 (0.43 at 7); western oak M260 2.33 / 1.67 / 1.50 / 1.39 / 0.85. Site class explains 12-24% of the variance of
  log(carbon / curve) in these types (stage 2's curves already carry the ecodivision; the quick 0.13 -> 0.50 above was age alone).
  No effect where nearly every plot is one class (pinyon/juniper: all 7, so m = 1). Small or mixed groups are noisy and
  non-monotone (tanoak/laurel 1.44 / 0.75 / 1.38 / 0.34): the shrinkage step is needed. Two traps for the implementation: match a
  plot to the type whose own group it is first (Western White Pine's curve pools 12 western groups), and carbon_data drops the plot
  ids (a version that keeps them). Output: dev/treemap/out/site-class-ratios.csv.
- **(c) TreeMap coverage on P26** (dev/treemap/03-p26-coverage.R): 21.0 M TreeMap forest pixels (18,917 km2); with all 48 states'
  COND every pixel's plot joins a forested condition whose type matches TreeMap's, and every one has a site class (stand age on
  94.5%). Site class mix: 1 1%, 2 5%, 3 25%, 4 25%, 5 25%, 6 8%, 7 11%. 89% of pixels come from CA/OR/NV plots; the rest are plots
  TreeMap imputed from other states (ID 5%, WA 3%; mostly Douglas-fir types 201/267), whose site class is still that plot's own.
  6,377 distinct plots.
- **(b) Flow Multiplier Types in ST-Sim** (dev/treemap/04-multiplier-types.R, test library lucasCore-suitability, Placer 1 km,
  1985-1987 from scenario 48; the project there now has the types Climate and Site Productivity). A Site Productivity row of 2 on
  "Net Growth Forest: Total" beside the Build's climate rows gave forest growth 2.003 / 2.002 x the climate-only run with the climate
  rows untyped (an old Build) and 1.9997 / 1.9991 x with them typed Climate; had climate been dropped it would be 2.07 / 2.06 x (mean
  climate multiplier 0.964 / 0.970). The two types multiply, and untyped rows still work beside typed ones. The runs draw fire and
  harvest at random with no seed, so runs differ by up to 0.5% (first-year decay flows); the checks use that tolerance.

## Design

**Multiplier.** For each forest type (and ecodivision where the plots allow), m(site class) = mean of observed live carbon / the stage 2
curve at the plot's age, over the fitting plots in that site class, divided by the same over all fitting plots. So the plot-weighted
mean is 1 and the curves stay right on average. Classes with few plots shrink toward their neighbours (or 1); the range is capped
(about 0.3-2.5).

**Map.** Pixel -> TreeMap plot -> its condition's site class -> m for the cell's forest type and ecodivision. Model cell = mean over its
pixels of that forest type. Pixels with no matched condition or no site class count as 1 (share logged).

**Growth.** A static flow spatial multiplier on the forest growth flows. Growth inputs scaled by m and first-order turnover give live
carbon m x curve(age) at every age, so the multiplier means "this cell's curve is m times the type's". It works beside the climate
multiplier through ST-Sim's **Flow Multiplier Types** (user, 2026-10-29): multipliers of different types multiply in each cell. The
project-level types (defaults/stsim/stsim_FlowMultiplierType.csv, today only "Net Growth Uncertainty") gain **Climate** and **Site
Productivity**; stages 7 and 11 write their rows with FlowMultiplierTypeId = Climate (today they leave it blank), the productivity
rows get Site Productivity. Stages cannot write project sheets, so the new types reach libraries through the package defaults: new
libraries get them, existing ones through tools/sync-library.R (P26 included, before its next Build).

**Initial stocks.** Stage 8 reads live and dead carbon from the curves by age; scale live and dead organic matter by m (all their
inputs are proportional to live carbon and decay is first order), not the deep soil (gSSURGO). Otherwise a good site would start with
average carbon and grow fast.

**One join.** src/treemap.R: TreeMap raster + attribute table (CN = PLT_CN) -> FIA condition (the forested condition whose FORTYPCD
matches TreeMap's, else the largest), as dev/treemap/01 does. Used by type, age and productivity.

## Steps

0. **Spikes (dev/, read only).** (a) The site class ratios against stage 2's own curves for P26's types, per ecodivision; (b) ST-Sim:
   a Climate and a Site Productivity flow spatial multiplier on the same growth flow multiply (a tiny test library), and a blank-type
   row (old Builds) still works beside them; (c) TreeMap -> condition coverage on P26 with all 48
   states' COND. Go/no-go and the shrinkage rule come from (a).
1. **Data.** Data Sources: TreeMap folder (raster, attribute table). src/fia.R reads SITECLCD (cache key bump). src/treemap.R with the
   join and its checks.
2. **Type and age (to-do 10).** Build Options: Forest Type Map = TreeMap; Stand Age Source = TreeMap (CMS stays the default; GAMI and
   inferred-from-biomass stay later options). Stage 5. FORTYPCD -> group through defaults/growth/forest-type-crosswalk.csv.
3. **Multipliers (stage 2).** Site class kept on the fitting plots; output sheet Site Productivity (type x ecodivision x site class:
   plots, raw ratio, value used); checks: plot-weighted mean 1, monotone with site class where plots allow.
4. **Map (stage 5).** Build Options: Site Productivity = None | TreeMap site class. Multiplier raster on the model grid; checks: every
   forest cell has a value, the cap, the area-weighted mean per type x ecodivision near 1 (it need not be exactly 1: the landscape
   need not match the plots).
5. **Growth flows.** Flow Multiplier Types Climate and Site Productivity in the package defaults and sync-library; stages 7 and 11
   tag their rows Climate; the stage that maps m (5) writes one static Site Productivity flow spatial multiplier on the forest growth
   flow group.
6. **Initial stocks (stages 4 and 8).** Live and dead organic matter x m. Check: cell initial live carbon against TreeMap's CARBON_L
   aggregated to the cell, with and without m (with m should fit better).
7. **UI.** Build Options entries (with notes); a Build Results page Site Productivity (the table, by type and ecodivision); a stage 12
   map of the multiplier.
8. **Tests.** Unit (join, normalisation, cap, shrinkage) in plain R first; then the Placer demo library (never the P26 guide library):
   Build with and without, initial carbon and growth by site class; then a P26 Build + Historical comparison (initial total carbon
   should change little; its pattern and the age-carbon spread more).
9. **Docs.** Guide (Build Options, Build Results page, figure), methods paper, docs/ui-improvements.md items 10 and 35.

## Choices (user, 2026-10-29)

- TreeMap vintage: **2016** (on disk) for now. Others: 2014 (RDS-2019-0026), 2020 (on the USFS raster gateway; archive id probably
  RDS-2025-0031, unconfirmed), 2022 (RDS-2025-0032). The year is a function argument in src/treemap.R, so a later vintage is a file
  name, not a redesign.
- Multipliers by **forest type x ecodivision** where plots allow, else the type's.
- Site Productivity **off by default** (results as today until switched on).

## Progress

- **Step 1 (data), 2026-10-29, schema-free part done.** src/treemap.R: fia_sites() (every forested condition's type, group, stand
  age and site class from all states' COND, cached as fia-sites.rds in the DataMart folder; 897,304 conditions, 48 states, builds in
  seconds; also what stage 2 needs for the site class of its fitting plots, and small enough for the demo bundle's tables-only mode),
  treemap_crop(), treemap_plots() (TreeMap's type, else the largest condition) and treemap_coverage(). tests/unit-treemap.R: 8 checks
  pass, P26 reproduces phase 0 (21.0 M pixels, 6,377 plots, all joined with a site class, stand age 94.5%).
  Left for step 2, so libraries are synced once: the **Data Sources: TreeMap Folder** column, with the Build Options columns
  (Forest Type Map and Stand Age Source = TreeMap, Site Productivity) - new columns in existing sheets need tools/sync-library.R (or a
  package version bump with an update) before an older library opens.
- **Step 2 (type and age), 2026-10-30, done** (ac971f3). Columns: Data Sources **TreeMap Folder**; Build Options **Stand Age
  Source** (NASA CMS default | TreeMap) and **Site Productivity** (None default | TreeMap site class; read in step 4); Forest Type
  Map gains TreeMap. Stage 5: TreeMap's groups map to forest types as Growth Inputs map FIA groups (own group first); groups no type
  fits take their neighbours' type and are logged (Placer: 960 other hardwoods 1.8%, 999 nonstocked); ages = plot STDAGE minus
  (inventory year - start year), averaged over the cell, 0 or less = unknown (filled from neighbours). Page: Build Options' Land
  cover group has a Stand age list. tools/sync-library.R takes --reference=<library> (dev/libs/sync-reference.ssim, made by
  tools/new-library.R; the starter was not rebuilt). Test (tests/phaseZ17-treemap-type-age.R, test library synced): base and TreeMap
  stage 5 runs pass; same forest cells; 86% type agreement with EVT; 1985 age median 81 (TreeMap) vs 66 (CMS), correlation 0.12.
  The guide's Build Options figure and text need the new list once the user decides the default stays CMS.
- **Step 3 (multipliers in stage 2), 2026-10-30, done.** src/siteproductivity.R: site_plots() (each fitting plot, as carbon_data
  filters them, now with plt_cn/condid kept, joined to fia_sites()'s site class and divided by its type x ecodivision curve at its
  age; a plot goes to its own group's type first) and site_multipliers() (type level: class mean / type mean, shrunk with 20
  pseudo-plots toward the type's plot-weighted linear trend across classes, so thin classes 1 and 7 are not pulled back toward 1;
  cells with >= 30 plots: own class values shrunk toward the type's; fewer: the type's; normalised to a plot-weighted mean of 1, then
  capped 0.3-2.5). Stage 2 writes **Build Results > Site Productivity** (OutputSiteProductivity: ecodivision, state class, site class,
  plots, raw ratio, multiplier, basis) when Build Options asks for it, after fitting or after copying the curves (copy_curves() now
  returns the copied sheets: outputs reach the library only when the run ends). Tests: tests/unit-site-productivity.R (10 checks) and
  tests/phaseZ18-site-productivity-stage2.R (copy 2.9 min, fit 14.7 min, off: all pass; 182,929 fitting plots, 133 of 532 cells
  with their own values; mixed conifer M260 1.54 / 1.59 / 1.26 / 0.97 / 0.61 / 0.53 / 0.33 for site classes 1-7).
- **Step 4 (cells), 2026-10-30, stage 5 half done.** The Build runs stage 5 before stage 2, so stage 5 cannot read the multipliers.
  It writes what TreeMap knows per cell instead: **Build Results > Site Class Shares (TreeMap)** (OutputSiteClassMap), seven maps of
  the share of the cell's TreeMap pixels in site class 1-7 (the plot's site class, whatever the type map). Stage 8, which runs after
  stage 2, turns them into the multiplier: sum over classes of share x the cell's type x ecodivision multiplier (with step 5's flow
  multiplier and step 6's initial stocks). Test tests/phaseZ19-site-class-shares.R (EVT types, CMS ages): passes; shares add to 1 in
  every cell with pixels; 99.1% of Placer's forest cells covered (the rest get 1); mix 1% / 5% / 25% / 25% / 24% / 6% / 15%.
- **Steps 4-6 (stage 8), 2026-10-30, done.** Stage 8, after stage 2: cell multiplier = sum over site classes of stage 5's share x
  stage 2's multiplier for the cell's type x ecodivision (no TreeMap pixels: 1; non-forest: 1); forest cells' starting live and dead
  carbon x multiplier (deep soil not); the map becomes a flow spatial multiplier on "Net Growth Forest: Total" with Flow Multiplier
  Type **Site Productivity**. Stages 7 and 11 tag their climate rows **Climate** (when the library has the type); stage 11 carries the
  Build's Site Productivity row into a Projection Climate scenario (its own rows would hide the Build's; src/shared.R
  dependency_multipliers()). The two types are in defaults/stsim/stsim_FlowMultiplierType.csv, and tools/sync-library.R step 4 adds
  them to existing libraries (P26 still needs that run before Site Productivity can be switched on there). Test
  tests/phaseZ20-site-productivity-build.R (two Builds of stages 5, 2, 3, 4, 7, 8, off and on, and 1985-1987 historical runs): all
  pass; every forest cell's starting live carbon = its multiplier x the off Build's (1e-7); forest multipliers mean 1.03 (10% 0.81,
  90% 1.27); starting forest live carbon x 1.040; historical forest growth x 1.030. Not tested: stage 11's carry-over (a projection).
- **Step 7 (UI), 2026-10-30, pages done.** Build Options: a **Growth** group with the Site productivity list (None / TreeMap site class)
  and a note on what each stage does with it. Build Results > Site Productivity: ui/SiteProductivityView.cs, pick an ecodivision and
  Multiplier / Plots / Raw Ratio; a row per forest type, a column per site class, the type's plots and Basis; multipliers tinted
  green above 1, orange below. Compiled into lucasCoreUI.dll; not yet seen in Studio. Site Class Shares stays a plain raster list.
  User checked both pages in Studio: they look right. **Stage 12 figure "Site productivity"** (src/figures.R, after the initial carbon
  maps, drawn only when the Build has the Site Productivity flow multiplier): (a) the forest cells' multiplier, brown below 1 and green
  above; (b) the cell's mean FIA site class from stage 5's shares. Stage 12 finds the files in its dependencies' folders when it is its
  own scenario. Test tests/phaseZ21-site-productivity-figure.R (stage 12 alone on the on and off test Builds): all pass; the off Build
  draws no such figure. Copy of the figure: dev/treemap/out/site-productivity-figure.png. The multiplier is relative to the cell's
  own forest type, so the same site class can map differently in two types.
- **Projection carry-over, 2026-10-30, tested.** The first test found stage 11 carried nothing: inside a run, dependency(scn) is empty
  (the result scenario lists no dependencies; they are on its parent). Fixed with src/shared.R run_dependencies() (the parent's
  dependencies), used by dependency_multipliers() and stage 12's file lookup; stage 11 now fails if Build Options has Site Productivity
  on but no dependency has its multiplier. Test tests/phaseZ22-site-productivity-projection.R: a Projection Climate result on each test
  Build (on, off), then a 3-year projection on each from Projection Setup (hand-over test, 122 on Build 47): all pass. The on climate
  result has Climate rows plus one Site Productivity row, its map in its own folder and equal to the Build's; the projection's forest
  growth on / off is 1.024, 1.022, 1.017 in 2024-2026 (forest-area mean multiplier 1.031; the projection starts from Build 47's
  historical run, whose stocks were not scaled).

## Notes

- Site class comes from site tree height at age, not from carbon, so it is an independent productivity signal; it still overlaps with
  carbon (taller trees, more carbon), which is the point.
- TreeMap's imputation is uncertain pixel by pixel; averaging m over a cell's pixels smooths it. A check of TreeMap's site class against
  FIA's at the plots' (fuzzed) locations would size the error.
- To-do 10's "age inferred from biomass" would attribute some productivity differences to age; with m in place the inversion should use
  m x curve, so the two stay consistent.
