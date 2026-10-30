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

## Choices for the user

- TreeMap vintage: 2016 is on disk; newer releases exist (to check: years, attributes, download size).
- Multipliers by forest type only, or by type x ecodivision where plots allow (P26 has two ecodivisions).
- Default: Site Productivity off (results as today) or on.

## Notes

- Site class comes from site tree height at age, not from carbon, so it is an independent productivity signal; it still overlaps with
  carbon (taller trees, more carbon), which is the point.
- TreeMap's imputation is uncertain pixel by pixel; averaging m over a cell's pixels smooths it. A check of TreeMap's site class against
  FIA's at the plots' (fuzzed) locations would size the error.
- To-do 10's "age inferred from biomass" would attribute some productivity differences to age; with m in place the inversion should use
  m x curve, so the two stay consistent.
