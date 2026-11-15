# Avoided conversion (land protection): literature review for LUCAS parameters

Compiled 2026-11-14. Evidence tags: **FT** = full text read (PDF text extracted and the cited passage checked); **AB** = abstract or publisher/index record only; **SEC** = second-hand (search snippet, press release, advocacy summary, or a paper citing another); **INF** = my inference or arithmetic. Unit conversions: 1 ha = 2.471 ac; 1 Mg C = 3.667 tCO2e. 2024 USD uses CPI-U annual averages (INF): 2011 to 2024 x1.395, 2016 to 2024 x1.307, 2017 to 2024 x1.280, 2023 to 2024 x1.030. CPI understates land-price growth, so inflated land costs are probably low.

---

## 0. Summary table of proposed parameters

### 0.1 Effectiveness: the share of baseline conversion stopped

LUCAS can apply protection in two ways, and they need different numbers.

- **(a) Per protected cell.** The cell is removed from, or down-weighted in, the suitability surface. Here the per-cell effectiveness `E` applies, and additionality comes out of the model itself, because low-suitability cells would rarely have been drawn anyway.
- **(b) Per strata unit.** The unit's drawn conversion area is reduced. Here the share is `E x (fraction of the unit's baseline conversion that would have landed on the protected land)`. Matching studies say this fraction is usually small, because protected land is low-risk.

| Mechanism | E, per protected cell, development (central; range) | E, per cell, ag expansion (central; range) | Basis | Tag |
|---|---|---|---|---|
| Fee acquisition (public or NGO; GAP 1-2) | 0.90 (0.70-1.00) | 0.95 (0.8-1.0) | Nolte 2019 MA: fee and restrictions avoided 83% +/-27% of development on matched parcels. Hagen 2024: TNC acquisitions avoided conversion | FT / AB; E is INF |
| Conservation easement (perpetual, development rights extinguished) | 0.80 (0.30-1.00) | 0.0 for agricultural easements (cultivation allowed); 0.8 only if the easement bars tillage (grassland or habitat easements) | Nolte 2019: 83% +/-27%, but restriction effects were weak for local and NGO holders. Hagen 2024: TNC easements alone had no detectable effect. Kolarik 2025: about 6% less development, 95% CI -76% to +278%, not significant | FT; E is INF |
| Agricultural conservation easement (ACEP-ALE, PACE, SALC) | 0.80 (0.3-1.0) against development | 0 against cropland expansion, since cropland and pasture remain allowed | Malakoff & Nolte 2023: avoided farmland loss real but "small" in absolute terms | AB; INF |
| Zoning, urban growth boundary, ag zoning | 0.3 (0-0.6) outside the boundary; development is redirected inside, not reduced | 0 | Kline & Alig 1999: no measurable reduction outside UGBs. Kline 2005 and Gosnell 2011: "measurable degree of protection". Butsic 2011: zoning had no effect after correcting for selection (rural WI) | AB; INF |
| Williamson Act contract (10-year rolling) | 0.1 (0-0.3) | 0 (rangeland to vineyard or cannabis conversion occurs on contracted parcels) | Shapero 2022 / SB County StoryMap: about 80% of 214 converted rangeland parcels over 100 ac were under Williamson Act contract | SEC; INF |

**Selection / development pressure (use for option (b), or to check option (a) output).** These are central values for the ratio of true avoided conversion to the naive estimate "protected area x average baseline rate".

| Pressure tier | Avoided share of naive | Basis |
|---|---|---|
| High (peri-urban; top tercile of suitability or within ~25 min of a city) | 0.6-0.9 | Nolte 2019: baseline pressure 0.063-0.078 %/yr near cities and in high-income areas vs 0.006-0.008 %/yr far away. Outcomes on protected land were similar across the gradient, so avoided conversion scales with pressure (FT) |
| Medium | 0.2-0.5 | INF |
| Low (typical portfolio: remote, high, steep) | 0-0.1 | Hagen 2024: pooled TNC effect about 0 (AB). Kolarik 2025: easements were 39% less likely to be developed even before they were placed (FT). Joppa & Pfaff 2009 (AB). Scott 2001 (AB). Moanga 2018: only 5.8% of SCC-acquired area would have converted (FT) |

### 0.2 Leakage: the share of avoided conversion that moves elsewhere

| Conversion type | Central | Range | Spatial scale | Basis |
|---|---|---|---|---|
| Urbanization (housing, commercial) | 0.5 | 0-1.0 | Within the same housing market (county or metro). Near-parcel spillover (<200 m) is about 0, or even positive (protection reduces neighbor change) | Zipp 2017: 57% of conserved open space gave near-zero net local change, because development was reallocated within 0.5 mi (AB). Nolte 2019: no negative spillover, p = 0.50 forest, p = 0.14 development (FT). McDonald 2007: more development near protected land (amenity effect) (AB). CARB uses 3.6% for avoided forest conversion (FT) |
| Agricultural expansion (grassland to cropland) | 0.2 | 0-0.5 | National or commodity market | CAR Grassland default 20% (FT). Wu 2000 CRP slippage 20% (AB). Roberts & Bucholtz: no slippage (SEC). Fleming: 3-11% (SEC via CAR). Murray et al. 2004 forest leakage from "minimal" to about 90% (AB) |

**Model note (INF).** As currently built, LUCAS draws fixed per-unit conversion areas from history and places them by suitability. Protecting cells while holding the drawn area fixed therefore produces **100% within-unit leakage** by construction. To be explicit, avoided conversion needs a demand-reduction term, `(1 - leakage) x E x baseline area on protected cells`. Leakage can stay inside the unit (re-placed by suitability) or be pushed to neighboring units.

### 0.3 Cost per hectare protected (2024 USD)

| Region / land type | Easement (central; range) | Fee (central; range) | Basis | Tag |
|---|---|---|---|---|
| California rangeland | $3,000/ha ($700-9,300) | about 2.5x easement, $7,000/ha (INF) | CRT, 36 appraisals: easement mean $867/ac (2011 USD; range $211-2,693) = $1,210/ac in 2024 = $2,990/ha. Easement averaged 41% of appraised fee value (range 11-69%). 19 CRT purchases: mean $939/ac, median $872 | FT (table columns garbled in extraction; values matched by order); INF conversion |
| California cropland (SALC, CFCP) | $8,000/ha ($3,500-25,000) | $20,000+/ha near cities | DOC farmland projects "just under $2,990/ac" (year unclear) = about $7,400/ha nominal. Calaveras SALC $1,406/ac | SEC; INF |
| California peri-urban fee | n/a | $22,000/ha (Placer, appraised $9,133/ac, 2025) | single project | SEC |
| California WCB (mixed fee and easement) | | about $6,400/ha nominal (about $2,600/ac; $1.2 bn / 460,000 ac over 12 years) | budget and news figures | SEC; INF |
| US agricultural easement, total value (ACEP-ALE general) | $8,200/ha | | ACEP-ALE federal financial assistance $1,271/ac (FY14-18). The federal share is at most 50%, so the total is about 2x, about $2,540/ac in about 2016 USD | FT; INF |
| US grassland easement (ACEP-ALE GSS) | $2,500/ha | | $392/ac federal, x2, x1.307 | FT; INF |
| US state PACE (all) | $9,000/ha | | AFT: $2,437/ac state funds in 2023; about $3,550/ac total (report year unclear) | SEC |
| US wetland easement + restoration (ACEP-WRE, US-held) | $10,800/ha (includes restoration) | | $3,346/ac FA (FY14-18) | FT; INF |
| US working-forest easement (Forest Legacy) | $900-1,300/ha (NE and Northern Forest); West likely higher | | FLP funding about $350/ac in its study areas; Northern Forest $298/ac total price over 1.30 M ac. Idaho: $390/ac federal | SEC |
| Stewardship (easement) | endowment $6,000-16,000 per easement; $430-1,500 per easement per year | | PALTA literature survey: $786/easement/yr. Potomac Conservancy: $6,000 minimum endowment | SEC |
| Legal defense | major disputes average $37,700 (2008 USD; easement median $14,500); about 1 major dispute per 279 easements | | Rissman & Butsic 2010 | FT |

**Cost scaling with pressure (INF).** Easement cost is about `f x FMV`. Use FMV from the Nolte 2020 PLACES raster (ln 2017 USD/ha; Dryad doi:10.5061/dryad.np5hqbzq9). Set f = 0.4 at low pressure (CRT mean 0.41, FT), rising to 0.75-0.9 at high pressure or on cultivated land (Dakota County MN appraisals: 75-90%; grazing land 60%; SEC). Fee cost is about 1.0-1.1 x FMV plus about 5-10% transaction cost (INF), plus a stewardship endowment. Avoided conversion per dollar is hump-shaped: Johnsen 2020 found the best efficiency at appraised easement values of $724-1,725/ac (2011 USD) (FT).

### 0.4 Carbon kept per hectare of avoided conversion

**Recommendation.** Compute this from LUCAS's own stocks. Avoided loss = biomass removed + dead-organic-matter loss + a soil-loss fraction on conversion. Apply the soil fractions below rather than fixed tC/ha.

| Transition avoided | Biomass removed | Soil C lost (fraction of the pre-conversion stock to about 30 cm) | Time to new equilibrium | Basis |
|---|---|---|---|---|
| Any natural or ag cover to Developed (impervious part) | 100% of the impervious fraction | 0.20 (IPCC Tier 1, paved portion); 0.2-0.4 observed | 20 yr IPCC default | IPCC 2006 Vol 4 Ch 8: paved = 0.8 x prior-use factors, "20% of the soil carbon ... lost" (FT). Pouyat 2006: Boston and Syracuse 1.6-fold less SOC after development, about 38% loss (AB) |
| Pervious part of Developed (turf, yards) | partial (trees kept in Developed Open) | about 0 (turf = improved grassland factor, may gain) | | IPCC 2006: turf uses improved-grassland factors; wooded settlement factors = 1 (FT) |
| Developed class weights, using NLCD impervious bins (Open <20%, Low 20-49%, Medium 50-79%, High 80-100%) | biomass loss = impervious fraction + clearing | 0.20 x impervious (IPCC) up to 0.4 x impervious | | INF |
| Grassland or shrubland to Cropland | above-ground about 100% annually | 0.36 +/-0.05 (temperate); 0.59 pasture to crop (global meta-analysis) | 17 yr | Poeplau 2011 (AB); Guo & Gifford 2002 (AB / SEC) |
| Forest to Cropland | about 100% | 0.32 +/-0.20 (temperate); 0.42 native forest to crop | 23 yr | Poeplau 2011 (AB); Guo & Gifford 2002 (AB / SEC) |

**Program yardsticks** (not comparable with LUCAS land carbon unless stated):

| Item | Value | Tag |
|---|---|---|
| CAR Grassland Protocol, avoided grassland to crop | about 1 tCO2e/ac/yr (2.5 tCO2e/ha/yr) order of magnitude; MLRA lookup factors from DayCent; 50-yr crediting; 20% leakage deduction; DFconv up to 50% | SEC (1 t/ac); FT (rest) |
| ACR ACoGS, northern Great Plains (Ahlering 2016) | 35.6 tCO2e/ha over 20 yr, after a 31% leakage and uncertainty deduction | SEC |
| SALC (ag easements), CARB methodology | about 106 tCO2e/ac over 30 yr (20.6 MMT on 194,000 ac), **dominated by avoided vehicle miles, not land carbon**. Soil C counted only on graded area | SEC (totals); FT (method) |
| SALC cost-effectiveness | $10.8/tCO2e implied (CCI: $192.6 M, 17.79 MMT as of Nov 2024); an older coalition figure of about $56/t (2018) | SEC; INF |
| California SCC acquisitions (Moanga 2018) | 9.9 Mg above-ground C per ha on the area that would have converted; **0.58 Mg C/ha averaged over all protected area** | FT; INF |

### 0.5 Scale: realistic protection rates

| Scope | Rate | Tag |
|---|---|---|
| US land trusts | 61 M ac protected by end of 2020, +15 M since 2010, so about 1.5 M ac/yr (0.6 M ha/yr) | SEC; INF |
| US ACEP (NRCS) | 159,605 ac/yr enrolled FY14-18 (ALE 109,487; WRE 50,118) | FT |
| US Forest Legacy | about 90,000-106,000 ac/yr (FY2024: 89,989 ac) | SEC |
| California 30x30 database additions (land) | 631k ac (2022-23); 861k (2023-24); 853k (2024-25); ">1 M" (2025-26). These include re-classification of existing lands, not only new protection | SEC |
| California WCB | 1.16 M ac over 2000-2015 (about 77k ac/yr, fee + easement) | SEC |
| California ag easements | CARB SP22 modeling scenario about 8,000 ac/yr; advocates proposed 24,600 ac/yr; baseline farmland loss about 50,000 ac/yr | SEC |

---

## 1. Effectiveness (detail)

**Nolte, Meyer, Sims & Thompson 2019, Conservation Letters 12:e12649, doi:10.1111/conl.12649 (FT).**
- Massachusetts: 220,187 parcels; land cover 1985-2012; Mahalanobis matching with post-matching regression; state, local and NGO fee and conservation restrictions (CR).
- Protection avoided "about half of forest loss (-55% +/- 30.8%) and about four-fifths of development (-83% +/- 27%)".
- Pressure gradient: protected parcels near cities and in high-income areas faced counterfactual loss of 0.063 +/- 0.015 and 0.078 +/- 0.020 %/yr, against 0.006 +/- 0.009 and 0.008 +/- 0.008 far from cities and in low-income areas. Observed change on protected parcels was "remarkably similar" across the gradient, so the absolute impact is driven by pressure.
- Instruments: both fee and CR significant overall. CR effects on forest loss were significant only at p = 0.08, and weak for local (p = 0.80) and NGO-held (p = 0.87) restrictions.
- Matching retained 70-75% of treated parcels (59-66% of area).
- Caveat: rates are % of parcel area per year, so they are small in absolute terms.

**Hagen, Nolte, Chang, Morgan, Boccaletti & Reddy 2024, Conservation Biology 38:e14225, doi:10.1111/cobi.14225 (AB).**
- 3,179 TNC parcels (Mid-Atlantic, New England and NY, California), 1988-2016, matched comparisons.
- Pooled: "no evidence of avoided conversion".
- Acquisitions avoided conversion; easements did not, except easements on parcels acquired by partners.
- Low land-cover-change accuracy in California.
- **Effect sizes not retrieved** (Wiley returned 403). Flag.

**Kolarik, Cattau, Koehn, Roopsind, Williamson & Brandt 2025, Biological Conservation 308:111234, doi:10.1016/j.biocon.2025.111234 (FT).**
- High Divide (ID/MT): 310,661 ac of easements; LCMAP developed class; difference-in-differences.
- Before implementation, easement pixels were about 39% less likely to be developed (95% CI 22-52%). This is selection.
- Easement effect: about 6% less likely to be developed, 95% CI from 76% less to 278% more, so no detectable effect.
- A naive model would have claimed a 40.9% reduction. This shows how much the counterfactual method matters.

**Malakoff & Nolte 2023, Land Use Policy 132:106814, doi:10.1016/j.landusepol.2023.106814 (AB).**
- New England: 1.97 M parcels; 3,959 farmland easements; 1988-2016.
- Avoided farmland loss 0.0067% +/- 0.0019% of parcel area per year. The abstract calls it "small".
- The abstract's "background loss 0.0027% of total area/yr" seems inconsistent with that figure. The denominator is unclear: **flag, check the full text.**
- Suggests targeting faster-urbanizing counties.

**Moanga, Schroeter, Ackerly & Butsic 2018, Journal of Land Use Science 13(4), doi:10.1080/1747423X.2018.1533043 (FT).**
- 73 California State Coastal Conservancy acquisitions (292,184 ac). The counterfactual comes from appraisal highest-and-best-use plus neighborhood trends.
- 16 of the 73 would have stayed open space. Across the other 57 properties, 13,859 ac (5.82%) would have converted: 6,867 ac to housing, 6,992 ac to vineyards. Sensitivity range 2.9-8.7%.
- Avoided above-ground C: 55,540 Mg, 1.36% of the 4.09 M Mg stored (sensitivity 0.6-3.2%).
- Converted area was mostly grassland and chaparral. Two redwood properties supplied 63% of the avoided C.
- INF: 55,540 Mg / 5,609 ha = 9.9 Mg C/ha on the converted area. Over the protected area of the 57 properties (about 96,000 ha) that is about 0.58 Mg C/ha.

**Zoning, UGBs and Oregon.**
- Kline & Alig 1999, Growth and Change 30:3-22, doi:10.1111/0017-4815.00102 (AB/SEC): no measurable reduction in development outside UGBs within forest and farm zones; development accelerated inside UGBs.
- Kline 2005, Environmental Management 35(4):368-380, doi:10.1007/s00267-004-0054-5 (AB): building-density model 1974-1994; zoning gave a "measurable degree of protection".
- Gosnell, Kline, Chrostek & Duncan 2011, Land Use Policy 28:185-192, doi:10.1016/j.landusepol.2010.05.012 (AB): review concurs.
- **No percent reduction retrieved.** The PNW-RN-548 forecast with and without zoning returned 403. Flag.
- Butsic, Lewis & Ludwig 2011, Land Economics 87(3):412-432 (AB): after correcting for selection bias, zoning had no effect on subdivision in a rural Wisconsin county. DOI not verified (likely 10.3368/le.87.3.412; INF).

**Williamson Act.**
- Shapero et al. 2022, Journal of Land Use Science, doi:10.1080/1747423X.2022.2086311 (AB title only).
- The project StoryMap (SEC) says just over 80% of 214 Santa Barbara County parcels over 100 ac that converted rangeland to vineyard or cannabis were under Williamson Act contract. Contract parcels lost grazing at a lower rate.
- The contracts do not restrict agricultural intensification, and the 10-year rolling term allows non-renewal. No causal estimate was found. **Flag.**

**Siting bias (why most protected land is low-risk).**
- Scott et al. 2001, Ecological Applications 11:999-1007 (AB): reserves lie at higher elevations and on poorer soils; 63% sit on the two lowest soil-productivity classes (SEC). DOI not verified.
- Joppa & Pfaff 2009, PLoS ONE 4:e8273, doi:10.1371/journal.pone.0008273 (AB): across 147 countries, protected areas are biased to high, steep, remote land, and the bias is stronger for strict protection.
- Vukomanovic et al. 2020, Conservation Science and Practice (AB/SEC): housing and impervious surface within 1-50 km of 6,644 US protected areas rose more than random placement predicts (DOI not verified).
- Radeloff et al. 2010, PNAS 107:940, doi:10.1073/pnas.0911131107 (AB): housing growth within 1 km of protected areas ran 20% per decade in the 1990s, against 13% nationally.

Not covered or not found: no peer-reviewed CONUS-wide matching estimate for PAD-US GAP 1-4 against NLCD development was found. Sims et al. (2019) on the local economic impacts of protection does not estimate effectiveness. No Lawler or Wade & Theobald paper estimating avoided conversion was found; Lawler et al. 2014 (PNAS) is a scenario study (SEC).

## 2. Leakage / displacement (detail)

- **Zipp, Lewis & Provencher 2017, Journal of Environmental Economics and Management 81:19-37, doi:10.1016/j.jeem.2016.08.006 (AB).**
  - Wisconsin econometric simulation with land-market feedback.
  - 57% of conserved open space created 1978-2009 produced "close to zero net change" in local development; conservation "mostly redirected development within a half-mile".
  - That implies about 100% local leakage for most of the conserved land (INF).
  - Conditions under which net development rises or falls are discussed in the full text (not read).
- **Nolte et al. 2019 (FT):** unprotected parcels with more nearby protection (200 m radius) showed no extra forest loss (p = 0.50). Development effects pointed the opposite way, toward less development (p = 0.14). The authors call spillovers "largely negligible, and, if they exist, more likely positive". Long-range spillovers were not tested.
- **McDonald et al. 2007, Conservation Biology 21:1526-1536 (AB; DOI not verified):** at two of three US sites, development rates were higher where nearby protected land was greater (amenity attraction).
- **Armsworth et al. 2006, PNAS 103:5403, doi:10.1073/pnas.0505278103 (AB):** in a theoretical land-market model, purchases raise prices and can push development onto valuable unprotected land.
- **Agriculture.**
  - Wu 2000, AJAE 82(4):979-992 (AB): CRP slippage of 20 ac of non-cropland converted per 100 ac retired.
  - Roberts & Bucholtz 2005/2006 (SEC): no convincing slippage.
  - The CAR Grassland Protocol summarizes the range as 0-20% and adopts 20% (FT).
- **Forest carbon:** Murray, McCarl & Lee 2004, Land Economics 80:109-124, doi:10.2307/3147147 (AB): leakage from "minimal" up to about 90% by region and activity.
- **Offset defaults (FT):**
  - CARB / CAR US Forest avoided conversion: SE = -0.036 x (change in actual onsite C - change in baseline onsite C), i.e. **3.6%**.
  - CARB improved forest management: 20% market leakage on reduced harvest.
  - CAR Grassland: **20%** of baseline emissions.

## 3. Permanence (detail)

- **Easement terms.**
  - Most land trust and PACE easements are perpetual. ACEP-ALE easements are permanent, or the maximum duration state law allows. ACEP-WRE offers permanent, 30-year, or term options (SEC; not checked in the 2014-2018 RIA text).
  - CAR Grassland requires a qualified conservation easement or Project Implementation Agreement for 100 years after the last credit. Project life is up to 150 years: a crediting period of up to 50 years plus 100 years of permanence (FT).
  - The CARB forest protocol's avoided conversion must use an easement or a transfer to non-federal public ownership (FT).
- **Violations and disputes (Rissman & Butsic 2010, Conservation Letters, doi:10.1111/j.1755-263X.2010.00136.x; FT).**
  - Survey of 205 land trusts (2008): 47% had experienced any legal challenge or violation; 11% had a major one (over $5,000 non-staff cost).
  - 43 major cases cost $1.6 M in total, averaging $37,700. Median cost was $14,500 for easements and $25,300 for owned land.
  - Frequency: one major case per 279 easements and one per 174 owned properties (cumulative, not annual).
  - On average, major cases surfaced 7 years after protection.
  - Outcomes: 14 won, 21 settled, 1 lost, 11 unresolved. 64% of the trusts had no stewardship endowment.
- **Terrafirma (LTA insurer), 2025 trends briefing (FT of the PDF).**
  - Claims rose from 1.9 to 16.7 per 1,000 insured parcels per year (2013 to 2024).
  - Serious claims (over $5,000) rose from 0.5 to 1.4 per 1,000 per year (2013 to 2022).
  - More than $9.2 M paid on more than 350 claims, March 2013 to October 2025.
  - Several cases exceeded $1 M to defend, more than half of them in California.
  - Claims are not losses of protection.
- **Extinguishment / condemnation rates:** no systematic US rate was found. **Data gap.**
- **Proposed for LUCAS (INF):** a reversal (loss of protection) probability of 0.05%/yr (range 0-0.2%/yr) for perpetual easements and fee land. For Williamson Act contracts, treat the 10-year term as non-permanent, with roughly 1-3%/yr non-renewal, which is not verified.

## 4. Costs (detail)

- **Nolte 2020, PNAS 117:29577, doi:10.1073/pnas.2012865117; data doi:10.5061/dryad.np5hqbzq9 (FT, read via PMC).**
  - FMV maps trained on 6.01 M sales (2000-2019, 1 ac or larger), 2017 USD.
  - PLACES explains 73% of the variance in 335 appraised Colorado (GOCO) easement values and 67-72% for public fee acquisitions.
  - Earlier proxies underestimate cost: Withey by 3.5x, Johnson by 2.2x, assessor values by 2.1x or more; floodplains within 25 min of a city by 6.6x. Lawler et al. budgets were underestimated by 31.8-37.5x.
  - **No per-hectare medians were published in the text.** Use the raster directly in LUCAS.
- **Le Bouille, Fargione & Armsworth 2023, Biological Conservation (FT title and abstract; DOI not found).** Model of about 36,000 conservation acquisitions in CONUS (TNC, TPL, agencies). Agricultural and urban land values predict variation in acquisition cost but are poor stand-ins for it.
- **ACEP (USDA ACEP Regulatory Impact Analysis, Jan 2021; FT).**
  - FY2014-18: about $1.75 bn financial plus technical assistance, about $1.3 bn of it financial assistance (FA).
  - Weighted FA $1,588/ac. ALE $782/ac overall ($1,271/ac general ALE; $392/ac grasslands of special significance). WRE $3,346/ac, which includes title work and restoration.
  - The ALE federal share is at most 50% of FMV.
- **Forest Legacy (SEC):** FLP funding about $350/ac in the economic-contribution study areas; Northern Forest $298/ac over 1.30 M ac in 56 projects; up to 75% federal share.
- **California (SEC unless noted).**
  - CRT appraisals (Johnsen 2020, UC Berkeley dissertation, escholarship 23n6w1vh; FT, with garbled tables): mean easement value $867/ac (2011 USD), range $211-2,693. Easement averaged 41% of fee value (range 11-69%). Purchase prices for 19 CRT easements: mean $939/ac, median $872. ES value is uncorrelated with appraised value. The choice of counterfactual changes valuations by an average of 648%.
  - DOC farmland projects: about $2,990/ac. SALC Calaveras: $1,406/ac. WCB: about $2,600/ac mixed (INF from $1.2 bn / 460k ac). Placer peri-urban fee appraisal: $9,133/ac (2025).
- **Stewardship (SEC):** $786/easement/yr average (range $431-1,500, PALTA literature survey); $200-500/yr (Potomac Conservancy, $6,000 minimum endowment); $100-500/yr monitoring only (Maryland Environmental Trust).
- **Per-hectare stewardship (INF):** with average easement sizes of about 54 ha (Rissman & Butsic) to 1,500 ha (CRT), annual stewardship is $0.5-15/ha/yr. That is small next to acquisition cost except on small peri-urban parcels.

## 5. Carbon accounting (detail)

- **IPCC 2006 Vol 4 Ch 8 (Settlements), section 8.3.3.2 (FT).** On the paved portion, FLU x FMG x FI = 0.8 x the previous land use, i.e. 20% of soil C lost. Turfgrass uses improved-grassland factors; cultivated parts use no-till factors; wooded parts use factors of 1. The 2019 Refinement chapter (checked) updates biomass defaults only.
- **Poeplau et al. 2011, Global Change Biology 17:2415, doi:10.1111/j.1365-2486.2011.02408.x (AB).** Temperate zone, 95 studies and 322 sites. Deforestation to cropland: -32 +/- 20%, new equilibrium in about 23 yr. Grassland to cropland: -36 +/- 5%, about 17 yr.
- **Guo & Gifford 2002, Global Change Biology 8:345, doi:10.1046/j.1354-1013.2002.00486.x (AB / SEC).** Pasture to crop -59%; native forest to crop -42%.
- **Pouyat, Yesilonis & Nowak 2006, Journal of Environmental Quality 35:1566, doi:10.2134/jeq2005.0215 (AB).** Urban SOC 5.49-7.83 kg/m2 per total area; Boston and Syracuse 1.6-fold less SOC after development. In warm, dry regions urban soils can gain C through irrigation (SEC), which matters for California.
- **The 30-50% figure in the request.** Evidence supports about 20% (IPCC, paved area) to about 40% (northeastern US observations) on sealed soil, near 0% on pervious turf, and about 30-40% for grassland or forest to cropland (INF synthesis).
- **CARB US Forest Projects protocol, avoided conversion (2015 version, FT).**
  - Eligibility: private land; significant threat of conversion shown by appraisal of the higher and better use; conservation easement or non-federal public transfer.
  - Baseline: either planning documents, or default total conversion (mining or agriculture 90%, recreation 80%, commercial or industrial 95%), amortized over 10 yr (9.0%/yr, 8.0%/yr, 9.5%/yr). For residential, total conversion = min(100, 3 ac x parcels / project area) (column alignment reconstructed from garbled text).
  - The baseline is modeled over 100 years.
  - Avoided-conversion discount (ACD): ACD = 1 if the alternative-use FMV premium (VA/VP - 1) is 0.4 or less, 0 if it is 0.8 or more, and linear in between, ACD = [0.80 - (VA/VP - 1)] x 2.5. **Semantics flag:** I read ACD = 1 as a full discount, but how the protocol applies it was not confirmed. Check eq 5.11 and the text around it.
  - Leakage 3.6%.
- **CAR Grassland Protocol v2.1, 2020; 2023 errata package (FT).**
  - Performance standard: county "cropland premium" (cropland over pasture rental rate). Above 100%: eligible. 40-100%: eligible with discount DFconv, at most 50%. Below 40%: ineligible without an appraisal. A suitability threshold is also required.
  - Baseline: DayCent per-MLRA SOC and N2O factors, in tCO2e/ac/yr, for 10-year blocks over 50 years.
  - Leakage 20%. Permanence 100 years after crediting.
  - **No per-acre factor values were in the package.** The parameters file is available on request. Flag.
- **Verra (SEC).** VM0009 (Avoided Ecosystem Conversion) is consolidated into the VM0048 REDD framework. The only live module, VMD0055, covers unplanned deforestation, so I found no current Verra route for US temperate avoided conversion. VM0045 is improved forest management, not avoided conversion. **Flag: confirm with Verra.**
- **ACR ACoGS (Avoided Conversion of Grasslands and Shrublands):** Ahlering et al. 2016, Ecosphere (DOI not verified): 35.6 tCO2e/ha over 20 yr after a 31% deduction for leakage and uncertainty (SEC).
- **SALC.**
  - CARB Agricultural Lands Conservation quantification methodology, Oct 13, 2022 (FT text; equations are images and were not readable).
  - Benefits are VMT avoided (rural minus urban household VMT), utility use, and SOC on graded area. The baseline counts dwelling units from extinguished development rights, using zoning or commute-time "risk of conversion" categories (residential, high-density rural residential, low-density rural residential, rural at-risk). No explicit leakage deduction: development is assumed to move to urban sites, which is the source of the VMT benefit.
  - CCI (SEC): $192.6 M implemented and 17,785,770 MTCO2e as of 2024-11-30, i.e. $10.8/t (INF).
  - CalCAN (SEC): about 194,000 ac, 166 easements, 20.6 MMT over 30 yr. An earlier MALT figure: 90,000 ac and 47 MMT (Jan 2019).
- **California NBS / NWL targets (SEC).** The April 2024 AB 1757 targets **deliberately do not set avoided-conversion targets**, because avoided conversion is hard to verify and can leak. They set conservation targets instead (7.6 M ac conserved, per the 2025 progress report). CARB's SP22 modeling scenario used about 8,000 ac/yr of ag easements and no conversion out of agriculture.

## 6. Scale (detail)

- PAD-US: GAP 1-2 cover about 316 M ac (12.9%) of US lands and inland waters (SEC). USGS warns against computing trends by differencing versions, because changes mix new protection with data improvements (SEC). NCED: about 22 M ac in about 100,000 easements (SEC, undated).
- Land Trust Alliance 2020 Census: 61 M ac by end of 2020, +15 M since 2010 (SEC). The 2025 census figures were not retrieved (403).
- ACEP: FY14-18 enrolled 798,023 ac in 2,171 easements (FT). ACEP-ALE closed 836,968 ac in 2014-2024 (SEC).
- Forest Legacy: FY2024 completed 89,989 ac (SEC).
- California 30x30 conserved land: 24.4% (May 2023), 25.2% (Sep 2024), 26.1% (Jun 2025), 27.1% (Sep 2026) (SEC).
- WCB: 1.16 M ac over 2000-2015 (SEC).
- **Suggested LUCAS scenario rates for California (INF).**
  - Low: 20,000 ha/yr of new easement or fee land, roughly the historical WCB plus land trust non-federal pace.
  - Medium: 80,000 ha/yr.
  - High: 200,000 ha/yr, roughly the 30x30 database additions (an upper bound, since they include re-classification).
  - Targeted ag easements specifically: 3,000-10,000 ha/yr.

## 7. Open questions and flags

1. **Effect sizes not retrieved:** Hagen 2024 regional and mechanism estimates (California especially); Malakoff & Nolte 2023 relative effect (and the 0.0027% denominator); Kline / PNW-RN-548 zoning counterfactual; Williamson Act causal effect. All of these sat behind 403 pages or paywalls.
2. **Effectiveness value E:** this is my mapping from parcel-level matching results to a per-cell suppression factor. In a suitability-driven model, E near 0.8-0.9 plus explicit low-pressure siting should reproduce the low program-level additionality. Validate by rerunning historical protection (PAD-US establishment dates) against NLCD 1985-2023, the same matching LUCAS already uses for strata.
3. **Leakage is the dominant uncertainty for urbanization.** Values range from 0 locally (Nolte) to about 100% within a housing market (Zipp; LUCAS's fixed-demand design). The CARB 3.6% figure is policy, not evidence. Report results at 0, 50 and 100% leakage.
4. **Agricultural easements do not stop grassland to cropland or rangeland to vineyard conversion.** Do not credit ag expansion avoided under ag easements unless the easement restricts tillage (CAR Grassland, Grassland Reserve, ACEP-ALE GSS).
5. **SALC GHG numbers are mostly avoided VMT.** Do not compare SALC $/tCO2e with LUCAS land-carbon $/tCO2e.
6. **Costs:** most per-acre figures are program averages of uncertain year, inflated by CPI (which understates land inflation). For spatial costs, use the Nolte PLACES FMV raster x easement fraction f.
7. **Unverified DOIs:** Scott 2001; McDonald 2007; Wu 2000; Butsic 2011; Ahlering 2016; Vukomanovic 2020; Le Bouille 2023. CPI factors are from memory.
8. **IPCC 2019 Tier 1 cropland FLU values** (long-term cultivated, about 0.69-0.80 by climate) were not checked here. LUCAS's existing soil-carbon flows may already encode them.
9. **Extinguishment rates:** no systematic US data was found. The permanence parameter rests on inference.
10. **CARB avoided-conversion table:** the column order in Table 5.3 was reconstructed from garbled text, and the ACD semantics need confirming against the protocol (eq 5.11).
