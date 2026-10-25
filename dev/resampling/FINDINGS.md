# Area-preserving resampling of land cover (to-do item 8) - P26 findings, 2026-10-25

The Build gives each 150 m cell the most common (modal) 30 m Annual NLCD class. On P26 that keeps 31% of NLCD's developed area and
makes developed cells flicker from year to year. Scripts in this folder test alternatives on the same aggregation blocks the Build
uses, without changing the package:

- `01-class-shares.R`: per year, the modal class plus each cell's developed, agriculture and forest shares and its most common
  developed and non-developed classes (`cache/shares_<year>.tif`). Its modal layer equals the Build's `NLCD_1985.tif` and
  `NLCD_2023.tif` in all 1,215,085 cells.
- `02-compare-methods.R`: builds each method's yearly maps and scores them (`compare-methods.csv`).
- `03-carbon-effect.R`: the 1985 cells a method turns developed, and the first-order change in initial carbon (run 9's 1985 Total
  Ecosystem map).

## Results (P26, 1985-2023)

30 m reference: developed 876 km² in 1985, 1,108 km² in 2023 (net +232); agriculture 50 km²; forest 18,900 km².

| Method | Developed 1985 (km², % of 30 m) | Net growth 1985-2023 (km², % of 30 m) | First-time development (km²) | Developed lost to flicker (km²) | Forest 1985 (% of 30 m) |
| --- | --- | --- | --- | --- | --- |
| modal (the Build today) | 275 (31%) | 147 (63%) | 295 | 230 | 105% |
| modal, stays developed | 275 (31%) | 295 (127%) | 295 | 0 | 105% |
| threshold 0.3 | 1,000 (114%) | 302 (130%) | 456 | 166 | 102% |
| threshold 0.4 | 552 (63%) | 246 (106%) | 332 | 96 | 104% |
| threshold 0.4, stays developed | 552 (63%) | 332 (143%) | 332 | 0 | 104% |
| area match per county, yearly | 876 (100%) | 232 (100%) | 399 | 218 | 102% |
| area match, stays developed | 876 (100%) | 399 (172%) | 399 | 0 | 102% |
| **area match, additions only** | **876 (100%)** | **245 (105%)** | **245** | **0** | **102%** |

- Every year-by-year method flickers: cells near any cut-off switch in and out. Holding cells developed stops it but locks in every
  false gain, so growth is inflated.
- **Area matching with additions only** fixes both: in 1985 each county's cells with the largest developed shares become developed
  until the county's 30 m developed area is met; each later year adds the next-largest shares to reach that year's 30 m area, and
  never removes any. It matches the 30 m area in 1985 and grows by 105% of the 30 m growth (2023: 1,121 against 1,108 km²; the 13 km²
  excess is counties whose 30 m area shrank in some year, which a no-loss rule cannot follow). No flicker, so first-time development
  equals net growth.
- Intensity classes come out close to NLCD's 30 m areas: open space 574 km², low 267, medium/high 35 (30 m, from the modal shares
  kept: about 600, 241 and 35). Modal has 132, 118 and 25.
- Agriculture stays at 100% of the 30 m area (modal 104%); forest drops from 105% to 102% of the 30 m area.

## Carbon (first-order, 1985)

Area matching turns 603 km² developed that modal leaves natural: 521 km² forest (190 Mg C/ha on average), 71 km² shrubland, and
small areas of other classes. At developed land's 104 Mg C/ha that lowers P26's initial total ecosystem carbon by about 4.4 Tg C of
486 (-0.9%). Threshold 0.3 gives -5.1 Tg C, threshold 0.4 -1.9 Tg C. These cells are partly developed at 30 m; modal counts them as
all forest and area matching as all developed, but over the study area area matching gets the developed area right, which modal does
not.

## What it changes for projections

Stage 9 sets urbanization rates from first-time gains. Modal gives 295 km² over 1986-2023 (7.8 km²/yr), inflated by flicker gains;
area matching with additions gives 245 km² (6.4 km²/yr), the 30 m growth.

## Open questions before adopting it

- The matching unit: counties (P26's secondary strata) here. It should be the strata level the Build has in all cases, or the
  projection target level (to-do item 7).
- Only developed land is matched. Agriculture also flickers (stage 10 has an agriculture flicker window); the same rule could apply.
- Stage 5 would need the years processed in order (each year depends on the last), which is fast: the comparison ran in minutes.
- A full test: a P26 Build and historical run with this method, compared on carbon, transitions against the record, and figures.

## Every class, 1985 (04-class-areas-1985.R, class-areas-1985.csv)

Area match fixes developed land, which was most of modal's error: the area in the wrong class drops from 997 km² (3.6% of P26's
27,339 km²) to 501 km² (1.8%). Developed open 600 km² at 30 m: modal 132, area match 574; low 240: 118 and 267; medium 33: 24 and 33.
The rest keeps modal's bias toward each area's dominant class, since only developed land is matched: evergreen forest 103% of 30 m
(modal 105%), shrub/scrub 95% (97%), grassland 79% (80%), woody wetlands 59% (61%), deciduous forest 60% (60%), barren 91% (91%).
Matching every class per county (allocation to class totals, developed with additions only) would remove most of the remaining
501 km²; woody wetlands (294 Mg C/ha) matter most for carbon. Not tested yet.

## All classes matched (05-class-counts.R, 06-match-all.R, 07-carbon-all.R; match-all.csv, match-all-classes.csv)

Each year starts from the year before (1985 from the modal map). Developed land is placed first, additions only, to each county's 30 m
area; then every other class is balanced to its county 30 m area by moving cells from classes over their target to classes under it,
largest gain in 30 m share first, and only to a class the cell has pixels of.

| P26 | Modal | All classes matched |
| --- | --- | --- |
| Area in the wrong class, 1985 (km² of 27,339) | 997 | 28 |
| Area in the wrong class, 2023 | 920 | 65 |
| Area in the wrong class, mean of 1985-2023 | 1,078 | 47 |
| Developed 1985 -> 2023 (30 m: 876 -> 1,108) | 275 -> 422 | 876 -> 1,121 |
| First-time development / developed lost to flicker | 295 / 230 | 245 / 0 |
| A->B->A reversals, 1986-2023 | 917 | 183 |
| Gross change, cells changing class, 1986-2023 (30 m pixels: 21,553) | 22,275 | 12,987 |

- Every class is within 0-2% of its 30 m area in 1985 and 2023 (modal: evergreen forest 105%, grassland 80%, woody wetlands 61%,
  deciduous forest 60%), except developed high (63-72%, 3-5 km²) and the 2023 split of developed low and medium (about 113% each).
  Cells a class could not be filled for: about 14 km² a year.
- Gross change is lower than at 30 m because matching follows each county's net change: changes that offset within a county (A to B
  here, B to A there) cancel. Right for urbanization (no reversion); it would undercount agriculture's gross gains and losses (tiny in
  P26). Fire and harvest transitions come from MTBS / LANDFIRE / LCMS, not from these maps, so they are unaffected.
- Initial carbon (first order, each changed cell given its new class's mean density in its county): 1,088 km² change class and P26's
  1985 total ecosystem carbon drops 8.0 Tg C of 486 (-1.65%): forest to developed -5.2, forest to shrubland -1.9, forest to grassland
  -0.7. That is modal's forest surplus (990 km²) removed.
- Not yet covered: the state class splits within NLCD classes (forest type from EVT, shrub and grass types from RCMAP, wetland types
  from C-CAP) are still each cell's most common type; they could be matched the same way within each NLCD class.
