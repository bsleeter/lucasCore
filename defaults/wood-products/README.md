# Harvested wood products (to-do 59)

The parameters of the wood products stage: what happens to the carbon harvest moves to the Forestry Sector stock. The method is the
USFS one, the IPCC production approach as the HWP-C calculator applies it (Stockmann et al. 2012; Anderson et al. 2013) on Smith et al.
2006's regional factors. Every file is written by `tools/make_wood_products.R` from the two downloads it names. Rerun it rather than
editing the files.

| File | What | Source |
| --- | --- | --- |
| `regions.csv` | Smith's ten regions, the states in each, and the merged regions each table uses | Smith 2006 Fig. 1 (a map; the state lists are lucasCore's reading of it, see below) |
| `growing-stock.csv` | By region and forest type group: softwood share of growing stock, sawtimber share of softwood and of hardwood, specific gravity. A blank type is the regional average | Smith 2006 Table 4 (the West rows copied to RMN, RMS, PWE, PSW where they have no row of their own); Table D8 |
| `forest-type-crosswalk.csv` | lucasCore forest type groups (upland and forested wetland classes) to Smith's | lucasCore |
| `roundwood-factors.csv` | By roundwood region, wood type and log size: industrial roundwood to growing-stock ratio, bark to wood, share of growing stock removed as roundwood, fuelwood ratio | Smith 2006 Table 5 (Johnson 2001) |
| `primary-products.csv` | Roundwood carbon to primary products by region, wood type and log size; "Fuel and other emissions" is mill residue burned | Smith 2006 Table D6 (2002 data) |
| `end-use-ratios.csv` | Primary products to end uses by year, 1906-2019 (constant before 1950) | McKeever 2009, McKeever and Howard 2011, as HWP-C vR holds them |
| `end-use-half-lives.csv` | Half-life in use of each end use | Smith 2006 Table D3, as HWP-C vR holds them |
| `discard-fates.csv` | Discarded wood and paper: burned, recovered, composted, to landfills, to dumps, by year 1906-2019 | Skog 2008 Tables 6a and 6b, as HWP-C vR holds them |
| `swds.csv` | Dump half-life, landfill share that never decays, landfill half-life of the rest, half-life of recovered products | Skog 2008 Table 7; HWP-C vR (recovered) |
| `settings.csv` | Loss when placed in use (8% of solid wood, none of paper), parameter draws, interval | Stockmann et al. 2012; HWP-C vR |
| `uncertainty.csv` | Triangular multipliers (90% bounds) on each parameter group, by period for the older data | Stockmann et al. 2012 Table 9, as HWP-C vR holds them |
| `state-harvest-history.csv` | Harvest by year, thousand board feet (Scribner), and the board feet per cubic foot of the year, for California (1904-2021), Oregon (1906-2022) and Washington (1906-2019) | Loeffler et al. 2019, Morgan et al. 2021, Nichols et al. 2020, as HWP-C vR holds them |

## lucasCore's choices

- **Regions.** Smith's Fig. 1 defines the regions on a map. The state lists are the RPA / FORCARB regions, checked against the forest
  types of Table 4: Northern Prairie States has ponderosa pine, so the Black Hills (South Dakota, Nebraska) are NPS, and Rocky Mountain
  North has hemlock-Sitka spruce (northern Idaho). Oregon and Washington are split at the Cascade crest by ecodivision: Marine (240) and
  Marine Mountains (2401) are PNW West, the rest PNW East. To check against the map.
- **Gaps in Table D6.** Smith gives no hardwood row for Rocky Mountain, PNW East or Pacific Southwest. Those regions take Smith's own
  "West, HW, All" row, the region Fig. 1 defines as RMN, RMS, PWE and PSW. The HWP-C regional templates fill the same gaps differently
  (Rocky Mountain and PNW East hardwood 100% to fuel, Pacific Southwest from the California inventory), so their primary product
  ratios are not used. Where Table D6 has one "All" row for a wood type, sawlogs and pulpwood share it.
- **End uses of lumber and plywood from pulpwood.** HWP-C sends them all to "other, n/a" (12 years), a placeholder. Every product takes
  the end uses of its sawtimber rows; OSB, made only from pulpwood, takes its pulpwood rows. Hardwood plywood goes to "other, n/a" as in
  HWP-C (McKeever's end uses cover softwood plywood).
- **Forest types with no Smith group** (exotic, other western, tropical) take the regional average sawtimber shares and specific
  gravity, all softwood or all hardwood as the class name says.
- **Half-lives.** Smith 2006 Table D3, as the USFS regional reports and HWP-C use (single-family housing 100 years). The Inventory's
  calibrated values (Skog 2008 Table 8: housing 78 years before 1940, rising 1.97 years per 20-year period after) are not used.
- **Methane.** As in HWP-C, landfill and dump decay counts as CO2 without energy capture. The Inventory reports landfill methane in
  the waste sector.

## Checks made when the tables were written (2026-11-11)

- Smith's Table 8 (share of each product still in use 1-100 years after production) is rebuilt from Table D2's end uses and Table D3's
  half-lives to within 0.001 for softwood lumber, hardwood lumber, softwood plywood and OSB at 1, 10, 50 and 100 years: the decay is a
  sum of exponentials, one per end use, with no loss in use (the 8% loss is HWP-C's).
- The discard fates match Skog 2008 Tables 6a and 6b, except paper to landfills in 2005: 30% here, 31% in Skog (HWP-C rounds so the
  fates sum to 1).
- Every product's end-use ratios sum to 1 in every year; Table D6 fractions sum to 1 (within 0.002, rounding) for every region, wood
  type and log size.

## Not here yet

- **Harvest history for the spin-up** outside California, Oregon and Washington: a regional series from 1906 (RPA growing-stock
  removals by region, 1952-2016, Oswalt et al. 2019 Table 35 and earlier editions; a national series before that).
- **Land-clearing utilization:** the share of growing stock cut in land clearing that becomes roundwood (TPO "other removals", Oswalt
  et al. 2019 Table 40).
- **National check:** the Inventory's HWP stock change, reproduced from a national harvest series to a few percent.

## References

- Anderson, N.; Young, J.; Stockmann, K.; et al. 2013. Regional and forest-level estimates of carbon stored in harvested wood products
  from the United States Forest Service Northern Region, 1906-2010. Gen. Tech. Rep. RMRS-GTR-311.
- HWP-C vR: the Harvested Wood Products Carbon model in R, from the USFS versions, with CAL FIRE, Oregon Department of Forestry and
  Groom Analytics. https://github.com/jeremygroom/HWP-C-vR (commit b629edd).
- McKeever, D.B. 2009. Estimated annual timber products consumption in major end uses in the United States, 1950-2006. FPL-GTR-181.
- Skog, K.E. 2008. Sequestration of carbon in harvested wood products for the United States. Forest Products Journal 58(6): 56-72.
- Smith, J.E.; Heath, L.S.; Skog, K.E.; Birdsey, R.A. 2006. Methods for calculating forest ecosystem and harvested carbon with standard
  estimates for forest types of the United States. Gen. Tech. Rep. NE-343.
- Stockmann, K.D.; Anderson, N.M.; Skog, K.E.; et al. 2012. Estimates of carbon stored in harvested wood products from the United States
  Forest Service Northern Region, 1906-2010. Carbon Balance and Management 7: 1.
