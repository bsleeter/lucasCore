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
| `settings.csv` | Loss when placed in use (8% of solid wood, none of paper), parameter draws, interval; the share of land-clearing wood that becomes roundwood (0.5, lucasCore's assumption, see below) | Stockmann et al. 2012; HWP-C vR; lucasCore |
| `uncertainty.csv` | Triangular multipliers (90% bounds) on each parameter group, by period for the older data; the land-clearing share's (0 to 1 in full) | Stockmann et al. 2012 Table 9, as HWP-C vR holds them; lucasCore |
| `state-harvest-history.csv` | Harvest by year, thousand board feet (Scribner), and the board feet per cubic foot of the year, for California (1904-2021), Oregon (1906-2022) and Washington (1906-2019) | Loeffler et al. 2019, Morgan et al. 2021, Nichols et al. 2020, as HWP-C vR holds them |
| `regional-harvest-history.csv` | The spin-up's harvest history: each Smith region's removals by wood type and year, 1906-2016 (1906-2019 on the Pacific), million cubic feet. Only its shape is used: the stage scales it to the run's own removals | Built from the files in `transcribed/` and the state histories; see below |

`transcribed/` holds tables typed from their sources: three from page images, three from clean PDF text. The script reads the first
four as inputs; the tests read the last two.

| File | Source | Check |
| --- | --- | --- |
| `lumber-by-census-region-1905-1954.csv` | USDA Forest Service, Historical Forestry Statistics of the United States, 1749-1956, Table 15 (lumber production by Census region; Steer 1948 and the Census). 1948 has a total only; 1951-53 give New England and Middle Atlantic as one figure | Every row adds to its printed total within 2 (rounding) |
| `rpa-removals-by-region-1952-1997.csv` | Haynes 2003 (PNW-GTR-560) Table 16, growing-stock removals by RPA region and wood type (from Powell et al. 1993 and Smith et al. 2001) | Softwood regions add to the US row within 1. Hardwood regions fall short of the US row by 2-11 in the source itself (checked against the page) |
| `rpa-harvest-by-subregion-1952-1996.csv` | Haynes 2003 Table 13, harvest by subregion and wood type (all sources) | Subregions add to the printed totals within 0.01 |
| `frus2017-removals-by-subregion-1976-2016.csv` | Oswalt et al. 2019 (Forest Resources of the US 2017, GTR WO-97) Table 35, growing-stock removals by subregion and wood type, 1976, 1996, 2006, 2016, thousand cubic feet | Subregions add to the region and US rows within 1 |
| `frus2017-us-roundwood-1952-2016.csv` | Oswalt et al. 2019 Table 41, US roundwood harvested from all sources by wood type, 1952-2016, thousand cubic feet (the national check's harvest level) | Softwood and hardwood add to the total |
| `epa-ghgi-2021-hwp.csv` | US Inventory 1990-2019 (EPA 2021) Tables 6-9 and 6-10: harvested wood stock and stock change, products in use and SWDS, MMT C (the national check's target) | Products in use and SWDS add to the total within 1 |

## lucasCore's choices

- **Regions.** Smith's Fig. 1 defines the regions on a map; the state lists were read from it (2026-11-11). Ohio is in the Northeast
  with Pennsylvania and West Virginia; Wyoming is in Rocky Mountain South; the Dakotas, Nebraska and Kansas are Northern Prairie States.
  Oregon and Washington are split at the Cascade crest by ecodivision: Marine (240) and Marine Mountains (2401) are PNW West, the rest
  PNW East.
- **Harvest history.** The stage scales each region's series to the run's own removals over the run's first decade, so only the
  series' shape matters, and each region takes the nearest published one:
  - 1952-1997: the RPA region's growing-stock removals (Haynes Table 16) times the subregion's share of its harvest (Table 13), linear
    between the survey years (1952, 1962, 1970, 1976, 1986, 1991, 1996/97). Northern Lake and Northern Prairie States both take North
    Central (no finer series), and the Rocky Mountains of Table 16 include the Great Plains. Hardwood in the West is one series.
  - 1906-1951: lumber production of the nearest Census region (New England plus Middle Atlantic for NE, Lake for NLS, Central for
    NPS, South Atlantic for SE, South for SC, Rocky Mountain for RMN and RMS), spliced so its 1950-54 mean equals the 1952 removals,
    and split by wood type as in 1952. Lumber stands for all products, so the early pulpwood share is understated.
  - Pacific: the state inventories' own harvest, 1906-2019: California for PSW; Oregon plus Washington for PNW West and East, split by
    Table 13's subregion shares. Against Haynes in the survey years, Oregon plus Washington moves with PNW West (correlation 0.94, at
    about 0.65 of its level: Scribner board feet to cubic feet and harvest versus removals), California less closely with Pacific
    Southwest (0.61, ratios 0.74-0.99).
  - 1998-2016 outside the Pacific: the 1997 value times the change of the Forest Resources of the US 2017 Table 35 subregion from 1996
    to 2006 and 2016, linear between (Northeast, North Central, Southeast, South Central; Rocky Mountain total for RMN and RMS). Only
    the change is taken, as the two sources' levels differ by subregion (FRUS / Haynes 0.85-1.14 in 1976 and 1996/97). A run whose
    first decade reaches past 2016 there cannot be scaled; the model stops and says so.
- **Land clearing.** No USFS table gives the share of the wood cut in land clearing that becomes products: TPO reports only the
  unutilized part ("other removals", growing stock removed by cultural operations or timberland clearing, Oswalt et al. 2019 Table
  40) and counts the utilized part in roundwood products without saying where it came from. lucasCore assumes half (settings.csv),
  with a triangular draw over 0 to 1; the rest is emitted in the year cleared. To replace when a source turns up.
- **What enters.** The run's flow to Forestry Sector is what left the site: logging residue stays in ST-Sim's own pools, so Smith's
  share of growing stock removed as roundwood (Table 5) is not applied again. The carbon includes bark (FIA's merchantable wood and
  bark); bark goes with the mill residue and is burned with energy capture. Smith's industrial roundwood and fuelwood ratios are used
  as shares of the wood, so the carbon is conserved: the roundwood Smith adds from other sources (tops, cull, dead trees) is not
  counted, unless the run's own flows move it.
- **Fuel.** Table D6's "Fuel and other emissions" and fuelwood are emitted with energy capture in the year produced, as in HWP-C.
  Smith's Table 6 splits that residue between "energy" and "emitted"; the stored carbon is the same either way.
- **Timing.** Carbon enters a pool at the end of its year and decays from the next, so t years after production exp(-ln 2 t / h)
  is left, as in Smith's Table 8. Recovered products go back in use (half-life 2.6 years) and are then discarded again.
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

## A different wood products future (the Wood Products page, lucasCore 1.5.1)

The tables above describe wood use as published. The Wood Products page can change a few things from a start year on, at once or
along a straight-line ramp, to explore other futures (`wp_levers` in `src/wood-products.R`). They are scenario choices, not
estimates: no file here holds them, and with none set the model runs the tables as they are. Each acts on top of the parameter
draws and only moves carbon between paths.

| Parameter | Default | What changes |
| --- | --- | --- |
| Shift to long-lived products | 0 | That share of the carbon bound for paper and for end uses with a half-life of 12 years or less (packaging, other manufacturing, manufactured housing, rail, other uses, other industrial products) goes to end uses of 67 years or more (housing, non-residential buildings), in the year's building mix of the solid wood (softwood lumber's where a harvest makes none). It is solid wood from there on (8% lost when placed in use). Furniture and repair and remodeling (30 years) are left as they are |
| Product lifetime multiplier | 1 | Every half-life in use is multiplied, for everything in use from the start year (earlier products too) |
| Extra share burned for energy | 0 | That share of the industrial roundwood is burned with energy capture in the year harvested, on top of bark, fuelwood and mill residue. No fossil fuel displacement is credited |
| Discarded wood recovered, discarded paper recovered | the last year of `discard-fates.csv` (0.09, 0.50) | The recovered share takes the value; the other fates keep their proportions in what is left |
| Discards burned for energy | 0 (Skog 2008) | The share of discarded wood and paper burned with energy capture takes the value; the other fates keep their proportions |

Landfill and dump half-lives and the landfill share that never decays are not offered: they are physical values, varied in the
draws only.

## Checks made when the tables were written (2026-11-11)

- Smith's Table 8 (share of each product still in use 1-100 years after production) is rebuilt from Table D2's end uses and Table D3's
  half-lives to within 0.001 for softwood lumber, hardwood lumber, softwood plywood and OSB at 1, 10, 50 and 100 years: the decay is a
  sum of exponentials, one per end use, with no loss in use (the 8% loss is HWP-C's).
- The discard fates match Skog 2008 Tables 6a and 6b, except paper to landfills in 2005: 30% here, 31% in Skog (HWP-C rounds so the
  fates sum to 1).
- Every product's end-use ratios sum to 1 in every year; Table D6 fractions sum to 1 (within 0.002, rounding) for every region, wood
  type and log size.

## Checks of the model (`src/wood-products.R`, 2026-11-12)

- `tests/unit-wood-products.R`: by-hand cases; carbon conserved in every draw. Against Smith's Table 8 (2002, central values, no loss
  in use), softwood lumber, softwood plywood and other products are within 0.02. Hardwood lumber, OSB and panels are within 0.06,
  because McKeever's 2002 end uses replace Smith's Table D2. Against Smith's Table 6, the share of industrial roundwood in use at
  production is within 0.01 in all 23 rows, and within 0.08 ten years on (end uses by year, and paper's plain 2.6-year decay).
- `tests/unit-wood-products-national.R`: the regional histories scaled to the US roundwood harvest (Table 41) and run from 1906.
  Against the Inventory, the stock is 0.93-0.98 of its value in 1990, 2005 and 2016, and the stock change 0.97-1.03 (1990, 2005,
  2015, 2016). SWDS is 1.00-1.02. Products in use are 0.87-0.90, as the Inventory's housing starts in 1800.

## Not here yet

- **Land-clearing utilization:** a published share, to replace the assumption above.

## References

- Anderson, N.; Young, J.; Stockmann, K.; et al. 2013. Regional and forest-level estimates of carbon stored in harvested wood products
  from the United States Forest Service Northern Region, 1906-2010. Gen. Tech. Rep. RMRS-GTR-311.
- HWP-C vR: the Harvested Wood Products Carbon model in R, from the USFS versions, with CAL FIRE, Oregon Department of Forestry and
  Groom Analytics. https://github.com/jeremygroom/HWP-C-vR (commit b629edd).
- Haynes, R.W., tech. coord. 2003. An analysis of the timber situation in the United States: 1952 to 2050. Gen. Tech. Rep.
  PNW-GTR-560.
- McKeever, D.B. 2009. Estimated annual timber products consumption in major end uses in the United States, 1950-2006. FPL-GTR-181.
- Oswalt, S.N.; Smith, W.B.; Miles, P.D.; Pugh, S.A. 2019. Forest resources of the United States, 2017. Gen. Tech. Rep. WO-97.
- U.S. EPA 2021. Inventory of U.S. greenhouse gas emissions and sinks: 1990-2019. Chapter 6, Land use, land-use change, and forestry.
- Skog, K.E. 2008. Sequestration of carbon in harvested wood products for the United States. Forest Products Journal 58(6): 56-72.
- Smith, J.E.; Heath, L.S.; Skog, K.E.; Birdsey, R.A. 2006. Methods for calculating forest ecosystem and harvested carbon with standard
  estimates for forest types of the United States. Gen. Tech. Rep. NE-343.
- USDA Forest Service. Historical forestry statistics of the United States, 1749-1956 (statistics through 1957; copy from the USDA
  NAL ESMIS archive, forestprodstat). The publication series and number are to confirm from a library record.
- Stockmann, K.D.; Anderson, N.M.; Skog, K.E.; et al. 2012. Estimates of carbon stored in harvested wood products from the United States
  Forest Service Northern Region, 1906-2010. Carbon Balance and Management 7: 1.
