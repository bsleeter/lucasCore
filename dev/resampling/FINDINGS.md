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
