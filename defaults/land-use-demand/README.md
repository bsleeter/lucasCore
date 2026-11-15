# Land Use Demand tables

The five published sources behind Projection > Land Use Change (stage 9, `src/land-use-demand.R`), each reduced to what the stage
reads. They ship with the package, so no Data Download is needed. The multipliers are not in these files: stage 9 computes them
(the mean across climate models, pooling by county, metropolitan area or state, interpolation between steps, the cap).

`tools/make_land_use_demand_tables.R <folder of the published files>` makes every table here; `made-from.csv` records the file each
was made from, its MD5 checksum and the date. `tests/unit-land-use-demand.R` checks that each table gives the same ratios as its
published file when that file is in the Data Sources folder.

A path set on the Data Sources page is read instead of the table (the published file, or another edition in the same layout).

| Table | What it holds | Source | Reduced how |
|---|---|---|---|
| `rpa-county-urbanization.csv` | New urban land a year (km2) by county and step (2012-2020 and five decades to 2070), a column for each of the 20 futures (5 climate models x 4 RCP-SSP pairs) | Mihiar, Lewis and Coulston 2023, *Land use projections for the 2020 RPA Assessment*, USFS Research Data Archive, https://doi.org/10.2737/RDS-2023-0026 (`county_landuse_projections_RPA.rds`) | Of the 6 x 6 transition matrices, the land entering urban from cropland, pasture, rangeland and forest, summed; hundreds of acres to km2, divided by the step's years; 6 significant digits |
| `rpa-timber-harvest.csv` | Total timber harvest (1000 m3) of the six U.S. regions, 2020-2070 every five years, for the four RPA scenarios | Johnston, Guo and Prestemon 2023, *RPA forest products market data for U.S. RPA regions and the world*, 2nd Edition, https://doi.org/10.2737/RDS-2022-0073-2 (`Ch7_LM_v2.csv`, `Ch7_HM_v2.csv`, `Ch7_HL_v2.csv`, `Ch7_HH_v2.csv`) | The rows Measurement = Timber harvest level, Product = total timber, for the six U.S. regions, as published, with a Scenario column |
| `iclus-county-new-developed.csv` | Land entering ICLUS classes 12-16 (suburban, urban, commercial, industrial; km2) by county and decade, 2010-2100, a column per run (SSP2-RCP4.5 and SSP5-RCP8.5 x GISS-E2-R and HadGEM2-ES) | U.S. EPA 2020, *Integrated Climate and Land-Use Scenarios (ICLUS) v2.1.1 land use projections*, https://www.epa.gov/gcx/iclus-downloads | The four 90 m map sets (6.6 GB) tabulated by 2022 TIGER county (`src/iclus.R`) |
| `hauer-county-population.csv` | County population by year (2020-2100, five-year steps), a column per SSP | Hauer 2019, *Population projections for U.S. counties by age, sex, and race controlled to shared socioeconomic pathway*, Scientific Data 6:190005; data https://doi.org/10.17605/OSF.IO/9YNFC (`SSP_asrc.csv`), licensed CC BY 4.0 | Summed over age, sex and race to county totals; 3 decimals |
| `census-county-population.csv` | County resident population on 1 July 2010 and 2020 | U.S. Census Bureau, county population totals 2010-2020, vintage 2020 evaluation estimates (`co-est2020-alldata.csv`), https://www2.census.gov/programs-surveys/popest/datasets/2010-2020/counties/totals/ | The county rows (SUMLEV 50) and the columns the stage reads |

The RPA, ICLUS and Census sources are works of the U.S. Government. Hauer's projections are redistributed here under their CC BY 4.0
licence (https://creativecommons.org/licenses/by/4.0/); the totals are a derivative of the published table, changed as described above.
