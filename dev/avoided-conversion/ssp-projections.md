# SSP-consistent demand for LUCAS urbanization and agricultural expansion: ICLUS, RPA 2020, county population projections

Compiled 2026-11-14. Evidence tags: **FT** = full text read (PDF text extracted, or the whole data page or metadata record read); **AB** = abstract, catalog summary or landing page only; **SEC** = second-hand (search snippet, a paper or page citing another); **INF** = my inference or arithmetic. 1 million acres (Macres) = 4,047 km2 = 404,686 ha.

Documents read in full: the ICLUS v2 technical report (EPA/600/R-16/366F, 134 p.); the 2020 RPA Land Resources chapter (Riitters et al. 2023, WO-GTR-102 Chap. 4); the RDS-2023-0026 metadata record; the EPA GCX ICLUS Downloads page; the Hauer 2019 paper (PMC); the Wear & Prestemon 2019 paper (PMC, summarized). Other sources were read as catalog pages only (data.gov, RDS catalog, Zenodo).

---

## 0. Summary table

| | **EPA ICLUS v2.1.1** (current) | **USFS RPA 2020 land use** (Mihiar, Lewis & Coulston) | **Hauer 2019** county SSP population | **Zoraghein & O'Neill 2020** gridded SSP population |
|---|---|---|---|---|
| Scenarios | SSP2-RCP4.5 and SSP5-RCP8.5, each with GISS-E2-R and HadGEM2-ES climate in the migration model (4 runs). v2.1 adds SSP2 and SSP5 "nocc" runs with no climate in migration (FT, downloads page) | 4 RPA scenarios x 5 GCMs = 20 futures. LM = RCP4.5-SSP1, HL = RCP8.5-SSP3, HM = RCP8.5-SSP2, HH = RCP8.5-SSP5. GCMs: CNRM-CM5 (wet), HadGEM2-ES365 (hot), IPSL-CM5A-MR (dry), MRI-CGCM3 (least warm), NorESM1-M (middle) (FT) | SSP1-5 (FT) | SSP2, SSP3, SSP5 (AB, Zenodo) |
| Years / step | 2000/2010 base to 2100, **decadal** maps. The demographic model runs annually (FT, report; AB, NCA4 page) | 2012-2020 calibration step, then 2020-2070 in **10-year** steps (FT) | 2020-2100, **5-year** steps (FT) | 2010 base, 2020-2100, **10-year** steps (AB) |
| Spatial unit | 90 m raster, CONUS. Demand is set per ICLUS geographic unit (GU; 2,256 metro/micro areas and rural counties), and allocation runs county by county (FT, report) | County (5-digit FIPS), CONUS, private land only. Companion 90 m spatial realizations exist (RDS-2023-0015) (FT/AB) | County, all U.S. including AK and HI (FT) | 1 km grid, state-by-state downscaling, EPSG:102003 (AB) |
| Classes / variables | 19 US-NLUD land use classes. Seven are dynamic: exurban low, exurban high, suburban, urban low, urban high, commercial, industrial (FT) | Forest, crop, pasture, range, urban/developed. 6x6 matrices of **gross** transitions plus start and end totals, in **hundreds of acres** (FT) | Population by 18 age groups x 2 sexes x 4 race groups (FT) | Total, urban and rural population counts per cell (AB) |
| Format | Land use: ESRI File Geodatabase zips per scenario x GCM. v2.1 regional pages list GeoTIFF. Population: geodatabase (2.1.1) or shapefile (NCA4 page). Trend tables: xlsx (FT/AB) | JSON and R .rds (multi-dimensional array), plus a variable dictionary csv (FT) | OSF archive and NASA SEDAC (FT/SEC) | GeoTIFF in two zips (2.7 GB and 390 MB) (AB) |
| Where | epa.gov/gcx/iclus-downloads; S3 links in section 1.4 (FT) | doi:10.2737/RDS-2023-0026 (FT) | doi:10.17605/OSF.IO/9YNFC (FT); SEDAC doi:10.7927/dv72-s254 (SEC) | doi:10.5281/zenodo.3756179 (AB) |
| License | CC0 1.0 per data.gov (AB). A data.gov record for v2.1 also says "No license information was provided" (SEC) | U.S. Government data; "can be used without additional permissions or fees", cite the DOI (FT) | Article is CC BY 4.0; data license not stated (FT) | CC BY 4.0 (AB) |
| Use as county developed-area target? | Yes, decadal, with a class crosswalk. Only two SSPs. The base map is not NLCD | Yes. Gives decadal county gross transitions into urban by source class, and transitions into crop and pasture. Not NLCD-defined | Indirectly (population to land conversion) | Indirectly; also usable as a spatial "where" layer |

---

## 1. EPA ICLUS (Integrated Climate and Land-Use Scenarios)

### 1.1 Version history (FT, epa.gov/gcx/about-gcx-integrated-land-use and the Downloads page)

| Version | Date | Content |
|---|---|---|
| v1.2 | Nov 2009 (external review draft) | ArcGIS tools and data for modeling housing density |
| v1.3 | Sep 2010 (final) | Interactive tool and user manual; SRES scenarios A1, A2, B1, B2 and a base case (BC) |
| v1.3.1 | May 2011 | Update (no change notes published) |
| **v1.3.2** | 15 Jul 2013 | The v1 data now offered: county population (shapefile), classified housing density (ESRI GRID, a1/a2/b1/b2/bc), raw housing density (USGS Geo Data Portal THREDDS), percent impervious surface (ESRI GRID). Used for NCA3 |
| v2 (report) | Draft Apr 2016; final report released 12 Jan 2017 (EPA/600/R-16/366F) | New demographic and allocation models. The report demonstrates SSP1-RCP4.5 (FIO-ESM) and SSP5-RCP8.5 (HadGEM2-AO). No v2.0 download is currently listed on the Downloads page (FT) |
| **v2.1** | 18 Sep 2019 | Land use for SSP2 and SSP5 "nocc" (no climate change in migration), in CONUS and seven NCA4-region zips. Demography switched from Census projections to Wittgenstein Centre rates. Used for NCA4 (FT/AB) |
| **v2.1.1** | 22 May 2020 | Population, plus land use for SSP2-RCP4.5 and SSP5-RCP8.5, each with HadGEM2-ES and GISS-E2-R driving the climate-amenity term in migration (FT). The data.gov records carry "first published 2017-02-28, updated 2018-02-28", which conflicts with the 2019/2020 dates on the Downloads page (AB). **Flag:** EPA publishes no formal change log for v2.1 to v2.1.1. INF: the only visible difference is that climate enters the migration model |

### 1.2 v2 / v2.1.1 model (FT, EPA/600/R-16/366F unless noted)

**Demographic model.**
- Cohort-component model plus a domestic-migration model. It projects **county-level population annually from 2010 to 2100**.
- Migration is a negative-binomial gravity/spatial-interaction model across 2,256 GUs. The GUs are metropolitan and micropolitan statistical areas plus stand-alone rural counties.
- Migration is calibrated on 1991-2000 IRS county-to-county flows. Predictors: population density, prior growth rate, developable area, network travel time (roads plus fixed transit), and climate amenities. The amenities are January and July humidity-adjusted temperature and JJA and DJF precipitation, as a 10-year running mean of GCM output.
- Each year, flows are rescaled to fixed shares of national migration by metro/micro/rural type (for example, MSA-to-MSA = 70%).
- The report's runs use 2010 Census base data. SSP5 uses Census Bureau (2000) high fertility, high domestic migration and medium immigration. SSP1 uses medium fertility, high domestic migration and medium immigration.
- From v2.1 on, fertility and mortality come from the Wittgenstein Centre Data Explorer (AB, data.gov). The 2100 U.S. population is 455 million under SSP2 and more than 730 million under SSP5 (AB, data.gov).
- The report finds that the SSP (fertility and migration) matters far more than the climate amenity: regional population differences are up to 4% (FT).

**Spatial allocation model.**
- v1 used **SERGoM** (Theobald 2005). In v2 SERGoM is replaced by "a deterministic demand-allocation approach, similar to SERGoM" (FT).
- **Demand:** eight GAMs, one per developed class plus road capacity, relate ln(pixel density) to ln(population density) per GU. They are fitted on 2000 and 2010 data, and adjusted R2 ranges from 0.55 (exurban low) to 0.89 (suburban). Decadal demand per GU equals the modeled count at t minus the count at t-1, anchored to each GU's 2010 residual. **GUs projected to lose population get no new demand**, so their land use is frozen (FT).
- **Transitions:** regional (7 ICLUS regions) multinomial GAM probabilities by antecedent class and an 8-class accessibility-capacity surface. The probabilities come from observed 2000-2010 US-NLUD changes (FT).
- **Allocation:** county by county, in the order industrial, commercial, urban high, urban low, suburban, exurban high, exurban low. New uses are placed as patches drawn from each region's observed 2000-2010 patch library. Residential patches are also weighted by cost-distance to commercial land. Demand that cannot be placed carries over to the next step. There is no "undevelopment", and a pixel can only move to a higher-intensity use (FT).
- **Time step:** decadal, 2020-2100 (FT).
- **Resolution:** 90 m, CONUS (FT).

**Base land use: US-NLUD (Theobald 2014)**
- 90 m maps for 2000 and 2010 "based on the 2011 NLCD and many other detailed data on land use" (FT). Developable area comes from PAD-US 2012 (FT).

**Classes (Table 2 of the report, FT).** Residential density in dwelling units per acre (DUA):

| Code | Class |
|---|---|
| 0-2 | Natural water; reservoirs and canals; wetlands |
| 3 | Recreation and conservation (protected) |
| 4-7 | Timber, grazing, pasture, cropland |
| 8 | Mining and barren |
| 9 | Parks and golf courses |
| 10 | Exurban low: 0.02-0.1 DUA (1 unit per 10-50 ac) |
| 11 | Exurban high: 0.1-0.4 DUA |
| 12 | Suburban: 0.4-1.6 DUA |
| 13 | Urban low: 1.6-10 DUA (1.6 DUA = 3.95 units/ha, the Census 1,000 people/mi2 urban threshold) |
| 14 | Urban high: more than 10 DUA |
| 15 | Commercial |
| 16 | Industrial |
| 17 | Institutional (static) |
| 18 | Transportation (static) |

**National results** (FT, report runs: SSP1-RCP4.5 and SSP5-RCP8.5, not the v2.1.1 SSP2 run).
- By 2100, "developed" land rises by more than 80% over 2010 to more than 1.6 million km2 under SSP5, and by nearly 50% to more than 1.3 million km2 under SSP1.
- Under SSP5-HadGEM2-AO, urban land is up more than 200% by 2050 and more than quadruples by 2100.
- The GCM has "no discernible effect" on national totals.
- **Flag (INF):** ICLUS "developed" includes the exurban classes. About 0.9 million km2 of 2000 exurban (Theobald 2005, AB) is mostly forest, pasture or grass in NLCD. It is not comparable to NLCD Developed, which covers about 0.45 million km2 CONUS. Use ICLUS changes, not levels.

### 1.3 v1 (for reference)
- Bierwagen, B.G., Theobald, D.M., Pyke, C.R., et al. 2010. National housing and impervious surface scenarios for integrated climate impact assessments. *PNAS* 107(49):20887-20892. doi:10.1073/pnas.1002096107 (SEC; abstract via PMC3000269).
- v1 projected county population (cohort-component plus migration) and converted it to housing units. SERGoM then distributed the units to **1 ha** cells by past patterns and road travel time. Impervious surface was produced at 1 km. Decadal steps to 2100, SRES A1, A2, B1, B2 and BC (SEC/AB).
- Report: U.S. EPA 2009, *Land-Use Scenarios: National-Scale Housing-Density Scenarios Consistent with Climate Change Storylines* (final), https://assessments.epa.gov/iclus/document/&deid=203458 (FT link). Report number EPA/600/R-08/076F (SEC, unverified).
- Theobald, D.M. 2005. Landscape patterns of exurban growth in the USA from 1980 to 2020. *Ecology and Society* 10(1):32 (SERGoM) (AB). DOI 10.5751/ES-01390-100132 (SEC, unverified).

### 1.4 Downloads and documentation (FT, epa.gov/gcx/iclus-downloads)

- v2.1.1 population: https://dmap-prod-oms-edc.s3.amazonaws.com/ORD/NCEA/ICLUS_v2.1.1/population/ICLUS_v2_1_1_population.zip
- v2.1.1 land use, SSP2-RCP4.5 with HadGEM2-ES: `.../ICLUS_v2.1.1/land_use/ICLUS_v2_1_1_land_use_conus_ssp2_rcp45_hadgem2_es.zip`. The GISS-E2-R file is `..._ssp2_rcp45_giss_e2_r.zip`.
- v2.1.1 land use, SSP5-RCP8.5: `..._ssp5_rcp85_hadgem2_es.zip` and `..._ssp5_rcp85_giss_e2_r.zip`, under the same prefix: https://dmap-prod-oms-edc.s3.amazonaws.com/ORD/NCEA/ICLUS_v2.1.1/land_use/
- v2.1 (nocc): https://dmap-prod-oms-edc.s3.amazonaws.com/ORD/NCEA/ICLUS_v2.1/SSP2/ICLUS_v2.1_land_use_conus_ssp2_nocc.zip and `.../SSP5/ICLUS_v2.1_land_use_conus_ssp5_nocc.zip`
- v1.3.2: https://edg.epa.gov/data/Public/ORD/NCEA/county_pop.zip and `bhcs_iclus_{a1,a2,b1,b2,bc}.zip`. Raw housing density: https://cida.usgs.gov/thredds/catalog/ICLUS/files/housing_density/catalog.html (**flag:** the CIDA THREDDS host may be retired; not checked).
- v2 technical report, EPA/600/R-16/366F (2017): https://ordspub.epa.gov/ords/eims/eimscomm.getfile?p_download_id=530694 (landing page https://assessments.epa.gov/iclus/document/&deid=322479).
- data.gov records: "iclus-v2-1-1-land-use-projections-for-ssp2-and-rcp4-5-pathways", "...-ssp5-and-rcp8-5-pathways", "iclus-v2-1-1-population-projections". Contact: P. Morefield, EPA.
- **Flag:** I found no ScienceBase copy. The Downloads page labels v2.1.1 as geodatabase, while the NCA4 regional pages say GeoTIFF of about 1.6 GB. Confirm after download. I did not check whether each zip holds one raster per decade.

### 1.5 Crosswalk to NLCD Developed (INF unless tagged)

NLCD Developed classes are defined by impervious fraction: Open < 20%, Low 20-49%, Medium 50-79%, High 80% or more. ICLUS classes are defined by land use and housing density. There is no one-to-one mapping.

| ICLUS v2 class | Likely NLCD equivalent |
|---|---|
| Urban high, commercial, industrial | Medium and High |
| Urban low | Low and Medium |
| Suburban | Open and Low, with a large non-developed share (lawns, woodlots) |
| Exurban high / exurban low | Mostly **not** NLCD developed (forest, pasture, grass), with a small Open share |
| Transportation (static) | Open and Low |
| Institutional, parks and golf (static) | Open |

The report itself builds its urban-core weights from these classes and uses NLCD 23/24 to separate suburban and institutional areas (FT). This confirms that a large part of suburban is not NLCD Medium/High.

**Recommended crosswalk:** derive one empirically.
1. Overlay the ICLUS 2010 base raster on NLCD 2011 (or the Annual NLCD 2010 map that LUCAS uses) at 90 m.
2. Per ICLUS region or per county, tabulate P(NLCD class | ICLUS class).
3. Apply those shares to the ICLUS decadal **gains** to get NLCD-equivalent new developed area by county.

Only the shares of conversions **from** undeveloped ICLUS classes (codes 3-9) into codes 10-16 represent new land conversion. Transitions within developed classes (for example exurban to suburban) are densification. They are NLCD-developed gain only to the extent that the crosswalk share rises.

**Validation:** I found no published validation of ICLUS v2 against NLCD or observed post-2010 development (search only). The report's own testing is a chi-square comparison of 2000 and 2010 US-NLUD class shares, not hindcasting (FT). Known issues:
- (a) The v2.0 demography predates the 2010s slowdown in growth and housing.
- (b) Transition probabilities are frozen at 2000-2010, which includes the housing boom.
- (c) There is no development in GUs that lose population, whereas NLCD shows development in declining counties.
- (d) The base map is US-NLUD, not NLCD.

---

## 2. USFS 2020 RPA Assessment land-use projections

### 2.1 Data product (FT, RDS-2023-0026 metadata)
- Mihiar, C.M.; Lewis, D.J.; Coulston, J.W. 2023. *County-level land-use projections for the conterminous United States, 2020-2070, used in the 2020 RPA Assessment.* Forest Service Research Data Archive. **doi:10.2737/RDS-2023-0026**. Published 2023-06-21, metadata updated 2023-09-12.
- Files: `county_landuse_projections_RPA.json`, `county_landuse_projections_RPA.rds`, `data_variable_descriptions.csv`, and `Supplements/process_steps_diagram.pdf`.
- Classes: cr (crop), ps (pasture), rg (range), fr (forest), ur (urban/developed), with t1 and t2 totals.
- Content: **gross** 6x6 transition matrices (source x destination) per county, time step and scenario. Units are **hundreds of acres**.
- Steps: 2012-2020 calibration, then 2020-2030 through 2060-2070.
- The total land base is held constant. Only transitions observed historically are allowed. Developed land is irreversible.
- **Only non-federal private land changes.** CRP, water, "other rural" and public land are held constant (FT, chapter 4).
- The metadata warns that county values omit their full variation, are "not predictions", and should be aggregated to state or regional scale (FT).

### 2.2 Model
- **Paper:** Mihiar, C.M., Lewis, D.J. 2023. An empirical analysis of US land-use change under multiple climate change scenarios. *J. Agricultural and Applied Economics Association*. **doi:10.1002/jaa2.82** (FT citation; paper not read; cited as "in review" in chapter 4).
- **Method:**
  - (a) Net returns to crop, forest and urban use are modeled as functions of climate (PRISM), population and income.
  - (b) Discrete-choice transition models are fitted per starting use on NRI plot data with repeated observations, 2000-2012, private land.
  - (c) The models are simulated with MACAv2 downscaled climate and the Wear & Prestemon (2019) county population and income projections (FT, metadata and chapter 4).
- It is policy-neutral. Wear's earlier RPA land model (2010 Assessment) is superseded.
- **Urban definition:** the NRI "developed" category (chapter 4: "'developed' includes the NRI developed class", FT). INF/SEC: NRI developed = large urban and built-up areas (10 ac or more), small built-up areas (0.25-10 ac) and rural transportation land. This is broader than NLCD Medium/High, and it includes roads and lots that NLCD may call Open or not developed. The underlying NRI plot data are confidential (FT).

### 2.3 RPA 2020 Land Resources chapter numbers
Source: Riitters, K., Coulston, J.W., Mihiar, C., Brooks, E.B., et al. 2023. Ch. 4, Land Resources, in GTR WO-102, pp. 4-1 to 4-37, doi:10.2737/WO-GTR-102-Chap4; PDF https://www.fs.usda.gov/research/publications/gtr/gtr_wo102/gtr_wo102_Chap4.pdf. All figures FT.

- Developed land in 2020: **97.7 Macres** (Table 4-10).
- Net developed gain 2020-2070: **+41.3 Macres (HL-hot, +42.4%) to +57.0 Macres (HH-least warm and HH-wet, +58.3%)** (Table 4-9). The 20-future mean is +50.7 Macres (+51.9%).
  - INF: that is 167,000-231,000 km2 in total, or about 0.83-1.14 Macres/yr (3,300-4,600 km2/yr).
  - **Flag:** one paragraph of the text says "43.9 to 57.0".
- By region (2020-2070):

  | RPA region | Developed gain (Macres) |
  |---|---|
  | South | 18.4-25.0 |
  | North | 10.6-14.0 |
  | Rocky Mountain | 6.4-8.9 |
  | Pacific Coast | 5.9-9.9 |

- **Forest** is the largest source of new developed land, at an average of 46%. The mean gross forest-to-developed transfer is 23.2 Macres. Across futures, forest-to-developed ranges from 19.8 Macres (HL-hot) to 26 Macres (HH-least warm).
- Net forest change: -7.6 to -15.0 Macres.
  - **Flag:** the text gives the 50-year forest loss as 10.7-15.0 Macres, but Table 4-9 cells go as low as -7.6. Mean -12.4 Macres (-3.0%).
- Crop: net -18.4 to -28.3 Macres, mean -21.8 Macres (-6.1%). **Crop declines net in all 20 futures.** Pasture: mean -9.2 Macres (-7.7%). Range: mean -7.3 Macres (-1.8%).
- Pasture to forest (17.2-18.2 Macres) is the largest source of new forest.
- Sensitivity: higher warming lowers development, and higher population and income raise it. Development is more sensitive to socioeconomics than to climate.
- Historical context (NRI): about 1.2 Macres/yr were newly developed in the 1980s, about 2.0 Macres/yr in 1992-1997, then the rate declined after 2000 (Fig. 4-3). The 2010 RPA projected +39-69 Macres for 2010-2060.
- **Comparison with ICLUS:** the chapter does not compare to ICLUS (none found in the text).
  - INF: RPA's +42-58% over 50 years is lower than ICLUS SSP1's roughly +50% over 90 years, once ICLUS's exurban growth is counted. The two are not comparable without the crosswalk.

### 2.4 Spatial realizations
- Brooks, E.B., Coulston, J.W., Riitters, K.H., Wear, D.N. 2023. *Spatial realizations of county-level land use projections for the conterminous United States, 2020-2070, used in the 2020 RPA Assessment.* **doi:10.2737/RDS-2023-0015** (AB).
- 90 m rasters: a 2020 base map ("Basemap_Byte", 94 MB zip) plus 2,000 projections (20 futures x 5 decades x 20 allocation cases with different degrees of spatial randomness). Each scenario zip is about 10.2 GB.
- Method: Brooks et al. 2020, *PLoS ONE*, doi:10.1371/journal.pone.0240097 (AB).
- Also distributed through Ag Data Commons. The class list is not on the catalog page (unverified).
- A related tree and impervious cover product (2020 and 2070, 3 futures) is **doi:10.2737/RDS-2022-0085** (AB).

### 2.5 RPA population and income
- Wear, D.N., Prestemon, J.P. 2019. *Socioeconomic data for Forest Service 2020 RPA Assessment.* **doi:10.2737/RDS-2019-0041** (AB).
- Content: county population and personal income for CONUS, with 2010 observed and 2015-2070 projected at 5-year steps, for all five SSPs. One 6 MB zip, plus a scenario summary document.
- Paper: Wear & Prestemon 2019, *PLoS ONE* 14(7):e0219242, doi:10.1371/journal.pone.0219242 (FT, summarized).
- Method: fixed-effects spatial panel models (Queen contiguity lags) of population and per-capita income, jointly determined. Calibrated on 1970-2010 at 5-year steps. Time effects are adjusted so national totals match the IIASA SSP population and GDP-growth paths.
- **Flag:** the base year is 2010, so the 2015 and 2020 values are projections, not observations. Zoraghein is not part of the RPA population work.

---

## 3. County and gridded population projections

| Product | Years / step | Variables | Method | Download | License |
|---|---|---|---|---|---|
| **Hauer 2019** | 2020-2100 / 5 yr; SSP1-5 | Population by 18 age groups x sex x 4 race groups (White NH, Black NH, Hispanic, Other NH) | Hamilton-Perry cohort-change ratios and differences (blended), ARIMA(0,1,1)-projected, in Leslie matrices; 1990-2015/16 NCHS bridged-race data in rectified boundaries; controlled to SSP national age-sex totals. **No explicit migration or climate.** Hindcast 2000-2015 median county APE 2.4% (5 yr), 4.8% (10 yr), 7.7% (15 yr); tends to over-project (FT) | OSF doi:10.17605/OSF.IO/9YNFC (FT); SEDAC "Georeferenced U.S. County-Level Population Projections, Total and by Sex, Race and Age, Based on the SSPs, 2020-2100", first published 2021-03-16, updated 2025-07-17, doi:10.7927/dv72-s254 (data.gov also lists 10.7927/escf-qp41; **flag**) (AB/SEC); R code on GitHub | Paper CC BY 4.0; data terms not stated |
| **Zoraghein & O'Neill 2020** | 2020-2100 / 10 yr; SSP2, 3, 5 | Total, urban and rural population per 1 km cell | Gravity-based downscaling (population_gravity model), calibrated per state, of state SSP projections from Jiang, O'Neill, Zoraghein & Dahlke 2020 (ERL; doi 10.1088/1748-9326/aba5b1, SEC, unverified) | Zenodo doi:10.5281/zenodo.3756179, v0.1.0, 2.7 GB + 390 MB (AB). Paper: *Sustainability* 12(8):3374 (doi 10.3390/su12083374, INF from URL) | CC BY 4.0 |
| **RPA (Wear & Prestemon 2019)** | 2015-2070 / 5 yr; SSP1-5 | County population and personal income | Section 2.5 | doi:10.2737/RDS-2019-0041 | U.S. Gov., free |
| **ICLUS v2.1.1 population** | 2010-2100 (decadal output per NCA4 page; annual model) | County population | Section 1.2; climate-amenity migration | S3 link in section 1.4 | CC0 |
| **Census Bureau 2023 National Projections** | 2022/23-2100 / annual; Main plus Low, High and Zero immigration | Nation only. Detailed by age, sex, race, Hispanic origin and nativity to 2060; by age, sex and nativity to 2100. Main series peaks near 370 M (~2080) and reaches 366 M in 2100. High: 435 M. Low: 319 M | Cohort-component; released 9 Nov 2023 | census.gov/data/datasets/2023/demo/popproj/2023-popproj.html | Public domain |
| **California DOF P-2/P-3** | 2020-2070 / annual (July 1) | County population; P-3 has single-year age x sex x race/ethnicity | Cohort-component, state demographer. 2024 Baseline; latest Vintage 2026 (2026-03-13) re-benchmarked to estimates | dof.ca.gov/forecasting/demographics/projections/ (SEC) | Public |
| Other state demographers | Varies (e.g. WA OFM GMA 2017 county projections, MD, DE) | County population, often with low/med/high series | Varies | State sites | Varies |

Note (INF): no SSP-consistent county product uses post-2020 Census data except where it is re-benchmarked. Hauer and RPA start from 2010-2016 data and do not reflect the 2020-2024 immigration and fertility changes. The Census 2023 Main series (366 M in 2100) is far below the ICLUS SSP2 figure (455 M) and below most SSP2 national totals.

---

## 4. Using these in LUCAS

LUCAS currently draws annual county urbanization and agricultural-expansion areas from the NLCD 1985-2023 record (the "historical target" H_c, a distribution per county) and places them by suitability. All three options below keep NLCD-based H_c and use the external product only as a **relative multiplier**. This cancels most definitional differences (NRI or US-NLUD vs NLCD) (INF).

How other studies turn population into area (tags as noted):
- ICLUS v1/SERGoM converts people to housing units by household size, then to housing density cells (SEC).
- ICLUS v2 uses a log-log GAM linking class pixel density to population density per GU. INF: the land-per-person elasticity is below 1 at high density.
- FORE-SCE (Sohl et al. 2014, *Ecol. Appl.* 24(5):1015-1036, doi:10.1890/13-1245.1; data doi:10.5066/P95AK9HP; 250 m, annual 1992-2100, SRES A1B, A2, B1, B2) took ecoregion demand from downscaled IMAGE/SRES storylines, adjusted with expert input (AB/SEC).
- Earlier LUCAS work (Sleeter et al. 2019, *GCB* 25:3334, doi:10.1111/gcb.14677; Wilson, Sleeter & Cameron 2016 ERL and 2017 *PLoS ONE*) used low, BAU and high urbanization and ag scenarios built from the 1992-2012 historical change distribution (AB/SEC). **Flag:** I could not verify whether any LUCAS paper scaled urbanization explicitly by population projections.

### Option A: population-driven scaling (Hauer 2019 or RPA population, by SSP)

- **Model.** Land per new resident, per county: k_c = (NLCD developed gain, 1990-2020) / (Census population gain, 1990-2020), estimated over the same window and smoothed. Then:

  `target_c,t = max(floor_c, k_c x dP_c,t,SSP) x d_t`

  - d_t is an optional densification trend (for example k falling 0.5-1%/yr, INF).
  - floor_c is the 10th-25th percentile of H_c, because NLCD shows development even in counties with flat or falling population (second homes, roads, commercial).
- **Alternative (ratio form).** `target_c,t = H_c x (dP_c,t / dP_c,hist)^b`, with b of about 0.7-1 (a sub-linear land-population elasticity, consistent with ICLUS's log-log demand; INF). Shrink small or negative denominators toward the state value.
- **Pros:** SSP1-5 are all available. Hauer goes to 2100, RPA to 2070. It is transparent, and it can be calibrated and tested on NLCD (for example, fit on 1985-2005 and predict 2006-2023).
- **Cons:** Hauer has no explicit migration, and its errors grow over time and in the West. The ratio form is unstable where historical growth is near zero. It ignores income, which matters in the RPA model.
- **Data:** Hauer (OSF/SEDAC) or RDS-2019-0041. Census county intercensal estimates 1990-2023 (tables, to compute k_c). Annual NLCD developed by county (already in LUCAS).

### Option B: RPA county urban transitions as a relative multiplier (recommended primary for 2020-2070)

- **Model.** `target_c,t = H_c x U_c,decade(t),s / U_c,2012-2020`, where U is the RPA gross transition into "ur" (summed over sources) per year.
  - To limit county noise, pool the ratio to the state or a cluster of counties, as the metadata advises.
  - Use the RPA **source-class shares** (fr, cr, ps, rg to ur) to re-weight which LUCAS source states urbanization draws from, if LUCAS distinguishes them.
- **Pros:**
  - It covers four SSP-RCP pairs and five GCMs, so climate uncertainty is included.
  - It is an econometric model calibrated on 2000-2012 behaviour, so it captures the post-2000 slowdown.
  - The by-source gross transitions match LUCAS's transition structure.
  - It is official and citable, and free.
  - The 90 m realizations (RDS-2023-0015) offer an optional "where" layer.
- **Cons:**
  - It ends in 2070.
  - Only private land changes.
  - NRI developed is not the same as NLCD.
  - The calibration step (2012-2020) is itself a projection.
  - Public-land development is zero.
  - County values are noisy.
  - "Other" land (barren, shrub outside rangeland, wetland) is not modeled. INF: LUCAS's shrub and grass states map to NRI range only partly.
  - Beyond 2070, extend with Option A ratios.
- **Data:** RDS-2023-0026 (the JSON or .rds file, a few MB; INF).

### Option C: ICLUS v2.1.1 county developed-area change
- **Model.**
  1. For each decade and scenario, tabulate per county the pixels converted from ICLUS codes 3-9 into codes 10-16.
  2. Weight them by the empirical P(NLCD developed | ICLUS class) crosswalk (section 1.5). Optionally also count densification gains (exurban to suburban and above) by the change in crosswalk share.
  3. Use the result as a ratio to the ICLUS 2000-2010 observed conversion (US-NLUD), then multiply by H_c.
  4. Divide by 10 for annual values.
- **Pros:** It runs to 2100 and is spatially explicit at 90 m (usable as a suitability prior). Population and allocation are consistent within one model. Its density classes help separate Developed Open/Low from Medium/High.
- **Cons:**
  - Only SSP2-RCP4.5 and SSP5-RCP8.5 (plus nocc).
  - Base and transition behaviour are frozen at the 2000-2010 boom.
  - Counties losing population get zero demand.
  - The class crosswalk is heavy, because exurban dominates.
  - Large rasters (about 1.6 GB per scenario; geodatabase or GeoTIFF unconfirmed).
  - Unvalidated against NLCD.
- **Data:** the four v2.1.1 zips, the 2010 base (in the zips, unverified), and NLCD 2011 for the crosswalk.

### Agricultural expansion
- **RPA is the only SSP-consistent county source** found.
  - Use gross transitions **into crop** (from ps, rg, fr) and **into pasture**: `ag_target_c,t = H_ag,c x G_into-crop,c,t,s / G_into-crop,c,2012-2020`.
  - RPA projects net crop **decline** in all futures, while gross crop gains continue. The national pasture/range-to-crop totals from Table 4-10 could not be reliably extracted from the PDF layout. Read them from the data, not the chapter.
- **Caveats:**
  - Chapter 4 says 91% of new cropland from "other" originated from CRP in 2000-2012, but CRP is held constant in the projections. Expansion from CRP release is therefore excluded (FT).
  - NRI crop is not the same as NLCD Cultivated Crops (NRI pasture vs NLCD Hay/Pasture). The ratio approach is again needed.
- ICLUS has no agricultural expansion: agriculture only loses land to development.
- FORE-SCE (SRES, 250 m) provides scenario ag demand but is not SSP-based.
- INF: GCAM-USA or Demeter-type SSP downscalings exist, but I did not research or verify them.

### Spatial "where" (optional)
- Use RPA 90 m realizations or ICLUS 90 m class rasters as a multiplier on the LUCAS suitability surface. One way: the fraction of the 20 RPA realizations in which a cell converts by decade.
- Or use Zoraghein & O'Neill 1 km urban-population growth as a covariate. INF: this needs resampling to the LUCAS grid and a check that it does not double-count accessibility already in the suitability model.

---

## 5. Flags and unverified items
1. **ICLUS v2.1 to v2.1.1 change:** there are no EPA release notes. The dates conflict between data.gov (2017/2018) and the Downloads page (2019/2020). The format conflicts too (geodatabase vs GeoTIFF). The per-decade layer structure inside the zips is unverified.
2. **ICLUS scenario mismatch:** the v2 report demonstrates SSP1-RCP4.5 (FIO-ESM) and SSP5-RCP8.5 (HadGEM2-AO). The distributed v2.1/2.1.1 data are SSP2 and SSP5 with GISS-E2-R and HadGEM2-ES. The report's national numbers therefore do not describe the SSP2 files.
3. **ICLUS "developed" includes exurban** (0.02-0.4 DUA). Do not compare its levels to NLCD. No published ICLUS-NLCD validation was found.
4. **RPA text vs table:** the developed-gain lower bound appears as 41.3 Macres (Table 4-9) and as 43.9 Macres (text). The forest-loss range appears as 10.7-15.0 Macres (text) while Table 4-9 cells go to -7.6. My table extraction is from a garbled multi-column layout, so verify the values against RDS-2023-0026.
5. **RPA urban = NRI developed,** inferred from the chapter's wording. NRI's definition (built-up plus rural transportation) is from general knowledge (SEC), not verified in the metadata.
6. **Hauer SEDAC DOI:** two DOIs appear on data.gov (10.7927/dv72-s254 and 10.7927/escf-qp41). The SEDAC page returned 403, and no updated Hauer version was found.
7. **Zoraghein & O'Neill and Jiang et al. 2020 DOIs** were not checked at the publisher.
8. **Wear & Prestemon** have a 2010 base, so 2015 and 2020 are projected. RPA land use is driven by these, not by Hauer. Mixing Hauer population (Option A) with RPA land (Option B) in one scenario set is inconsistent. Pick one population source per scenario.
9. **Bierwagen 2010 and EPA 2009** were read only as abstracts and citations. The v1 report number EPA/600/R-08/076F is unverified.
10. **Earlier LUCAS population-driven urbanization:** not verified (abstracts only). The CA water-demand papers used historical-rate scenarios.
11. None of the products reflect post-2020 demographic data except the Census 2023 national series and CA DOF Vintage 2026. SSP2 national totals (ICLUS 455 M in 2100) are well above Census Main (366 M).
