# Fuel treatments: default parameters for LUCAS

Research notes for three forest fuel treatments modelled as transitions on live forest that keep forest type and stand age:

1. Mechanical thinning: thin from below, some merchantable wood sold, slash piled and burned or masticated.
2. Prescribed burn: broadcast underburn.
3. Thin and burn: both.

Scope: conterminous US. Costs are in 2024 USD per hectare. Older values are scaled by annual-average CPI-U (BLS series CUUR0000SA0, as tabulated by the [Minneapolis Fed](https://www.minneapolisfed.org/about-us/monetary-policy/inflation-calculator/consumer-price-index-1913-)): 2003 = 184.0, 2021 = 271.0, 2022 = 292.7, 2024 = 313.7, 2025 = 321.9. Area is converted at 1 ac = 0.404686 ha, so $/ac x 2.4711 = $/ha.

Each number below is labelled with its standing:

- **[source]**: read on a page or in a PDF I opened.
- **[abstract/search]**: from an abstract or search snippet whose full text I could not open.
- **[inference]**: my own derivation or judgement. These are the proposed model defaults, so check them first.

---

## A. Effectiveness and longevity (severity shift)

### A.1 Key evidence

**Davis et al. 2024, Tamm review meta-analysis.** Forest Ecology and Management 561:121885. Full text opened from the [TNC Conservation Gateway PDF](https://www.conservationgateway.org/content/dam/tnc/conservation/cg-documents/a/other/a-meta-analysis-thinning-prescribed-fire-wildfire-effects-subsequent-wildfire-severity-coniferdominated-forests-western-us.pdf); record at [Treesearch 67659](https://research.fs.usda.gov/treesearch/67659).

- Scope: 40 studies, 172 sites, 256 observations, more than 43 fires from 1994 to 2021, 11 to 12 western ecoregions. Forest types are CA mixed conifer, interior mixed conifer and ponderosa/Jeffrey pine, plus a few subalpine and lodgepole observations. Responses include RdNBR/CBI/dNBR, percent area burned at high severity, percent mortality and crown scorch. The effect is reported as a log response ratio converted to percent change. [source]
- Mean reduction in wildfire severity relative to untreated: thin + prescribed burn **72%**, thin + pile burn **62%**, prescribed burn **62%**, thin only **27%** (not significant), prior wildfire 25% (not significant). [source]
- Thin-only observations varied widely; "not treating surface fuels following thinning led to increased wildfire severity compared to controls" in 40% of thin-only observations. [source]
- Treatment age: the mean reduction fell from **66%** for treatments within 10 years to **28%** for treatments older than 10 years (up to 34 years), averaged over treatment and forest types. Only thin + burn was significantly effective after 10 years. [source]
- In the subset with exact treatment ages (0 to 17 years, but 95% of observations were 10 years or younger), there was no detectable decline within the first decade. [source]
- No difference in effect among the three dry forest types, and no significant moderation by fire weather from the 62nd to the 99th percentile of ERC. [source]
- Wet forests: in Cascade and Coast Range wet forests, "some studies suggest that forests are unlikely to benefit". Subalpine effects could not be tested. [source]
- Mediterranean and Australian prescribed-fire effects are shorter-lived, about 2 to 6 years. [source]

**Kalies & Yocom Kent 2016, Tamm review (systematic, not quantitative).** FEM 375:84-95. Opened via [fs.usda.gov/media/218772](https://www.fs.usda.gov/media/218772).

- Scope: 56 studies in 8 western states. Mixed conifer 43%, pine 25%. [source]
- Thin + burn consistently reduced severity, mortality and scorch. Burn alone or thin alone had less effect or none, and thinning alone increased severity in at least two studies. [source]
- Time since treatment beyond about 5 to 19 years was associated with smaller effects in three studies. [source]
- Graham et al. 2009 (CA, mixed conifer), the one study in its table giving a severity-class split: high plus moderate severity was **76% untreated, 57% burn-treated, 38% thin + burn**. [source; data from Kalies Table 1]
- Ritchie et al. 2007 (northeastern CA pine): survival was greatest in thin + Rx, lower in thin only, and near zero untreated. A southwestern Oregon study (Raymond & Peterson 2005, as listed in the table) had mortality of 80 to 100% in thinned-only stands, 53 to 54% untreated, and 5% thin + burn. [source; data from Kalies Table 1]
- Martinson & Omi 2013, as summarised here: canopy volume scorch 100% untreated versus 40% treated. [source]

**Martinson & Omi 2013 meta-analysis.** USDA FS RMRS-RP-103WWW; note it is an RP, not a GTR. [PDF](https://www.nrfirescience.org/sites/default/files/2023-07/rmrs_rp103.pdf).

- Scope: 19 publications, 62 treated-versus-untreated contrasts. [source]
- The best age model splits "recent (<10 years)" surface fuel reduction from older treatments. Surface reduction older than 10 years behaves like no surface treatment. Thinning without recent surface fuel reduction is the weakest conifer category. [source]

**Tubbesing et al. 2019, northern Sierra Nevada strategically placed landscape treatments (American Fire).** FEM 436. [eScholarship PDF](https://escholarship.org/content/qt2c13v0j9/qt2c13v0j9.pdf).

- Share of land burned at more than 90% basal-area mortality: **26% in the untreated control landscape versus 11% in the treated landscape**. This is a landscape-level result, including untreated gaps. [source]

**Prichard et al. 2020, Carlton Complex, WA.** Ecological Applications 30:e02104. [PDF](https://www.fs.usda.gov/media/218460).

- Thin + underburn, underburn only and past wildfire were more effective than thin only and thin + pile burn. [source]
- Under the wind-driven early progressions, all treatment types burned with higher proportions of moderate and high severity. Under milder weather, treated units had much more unburned and low-severity area. [source]
- Use this as a caution that multipliers weaken under extreme weather. Davis 2024 found no significant weather moderation, but Prichard 2020 shows it can happen.

**Cansler et al. 2022, northeastern Washington, 150 fires 2001-2019.** FEM 504. [Abstract](https://umimpact.umt.edu/en/publications/previous-wildfires-and-management-treatments-moderate-subsequent-/).

- Thinning and prescribed burning both reduced burn severity, and prescribed burning was the most effective. Rx areas "usually" burned unburned or at low severity. [abstract/search]
- Prior fire effects were strongest within about 16 years. [abstract/search]
- No numeric treatment-age curve appears in the abstract.

**Safford et al. 2012, California yellow pine and mixed conifer, 12 fires 2005-2011.** FEM 274:17-28.

- Severity and mortality were significantly lower inside treatments in 10 of 12 fires. [abstract/search; PDF link failed]

**Hettema et al. 2026, Southern Rockies Front Range.** FEM 606:123529. [Treesearch PDF](https://research.fs.usda.gov/download/treesearch/81101.pdf).

- Prescribed fire or prior low or moderate fire gave the lowest severity across forest types, even in extreme conditions. [source]
- Treatments without fire had mixed effects, and in spruce-fir and lodgepole forests under extreme conditions they matched untreated areas. [source]
- Time since treatment was a significant predictor (estimate 1.441, p < 0.001). [source]

**Stephens et al. 2009 (Blodgett FFS) and Stephens, Collins & Roller 2012 (fuel treatment longevity, FEM 285:204-212).**

- Treatment longevity "can vary from 5 to 20 years depending on treatment and vegetation type". [source, Stephens 2009, [PDF](https://www.frames.gov/documents/ffs/ffs143_stephens_soils.pdf)]
- A staggered schedule that includes prescribed fire could extend longevity to about 20 years. [abstract, [Treesearch 41713](https://research.fs.usda.gov/treesearch/41713)]

**Hood et al. 2024, Northern Rockies FFS, 20 years.** Ecological Applications e2940. [PDF](https://www.nwfirescience.org/sites/default/files/publications/Ecological%20Applications%20-%202024%20-%20Hood%20-%20Long%E2%80%90term%20efficacy%20of%20fuel%20reduction%20and%20restoration%20treatments%20in%20Northern%20Rockies_0.pdf).

- After 20 years and a mountain pine beetle outbreak, thin + burn would still have the lowest-intensity fire and the highest survival. [source]
- The Rx-only and control stands had higher fuel loads and higher hazard. [source]

**Southeast: Ross et al. 2024, Okefenokee NWR, 2017 West Mims Fire.** Remote Sensing 16:4708. [PDF](https://mdpi-res.com/d_attachment/remotesensing/remotesensing-16-04708/article_deploy/remotesensing-16-04708.pdf).

- Areas burned by Rx 1 month before the wildfire had **88% lower mean dNBR** than unmanaged areas. [source]
- At 38 months the reduction was **17%**, and reductions were "evident for approximately five years". [source]
- The authors recommend 1 to 2 year burn intervals. [source]
- A Southern Fire Exchange summary of 380 Georgia and Florida wildfires reports that the probability of high severity rises with time since fire up to 5 to 6 years. [abstract/search; page returned 403]

**Fernandes 2015 (Current Forestry Reports 1:118).**

- The review is global. Its key quantitative message concerns wildfire extent: treating more than 5% of a landscape per year, with 3 to 4 units of Rx per unit of wildfire reduced. [abstract/search]
- It does not supply a US severity-by-age curve.

### A.2 Interpreting "reduction in severity" as model multipliers [inference]

The model needs multipliers on the conditional probability of each severity class when a treated cell burns. I made these assumptions:

- Davis' percent reduction in continuous severity (or in percent area burned at high severity) is read as roughly a proportional reduction in P(high). The high-severity multiplier is therefore about 1 minus the reduction.
- Medium severity falls less than high. This follows the Graham 2009 split, where high plus moderate fell 25% for Rx and 50% for thin + burn, and the Carlton finding that treated units gain unburned and low area.
- Low severity absorbs the remainder: `m_low = (1 - pH*m_high - pM*m_med) / pL`, with pL, pM and pH the untreated class shares in that cell or stratum. Compute m_low by renormalising in the model rather than hard-coding it. The example values in Table 1 assume an untreated split of low 0.40, medium 0.30, high 0.30, typical of fire-excluded dry conifer.
- Bands. Davis shows a plateau through year 10 and then a drop to about 40% of the effect (28/66). Martinson & Omi break at 10 years. Rx-only loses surface-fuel benefit faster than thin + burn, which was the only treatment still significant after 10 years. So the 0-5 and 6-10 bands are similar, 11-15 is about half the effect, and 16-20 is near zero, except thin + burn, which keeps a small effect.
- Thin only: the central values assume that half the slash is piled and burned (Davis 62%) and half is lopped or masticated (Davis 27%, sometimes worse than untreated). If the model always piles and burns slash, use the thin + burn row scaled to about 0.85 of its effect. If slash is only masticated, use a high-severity multiplier near 0.8 with an upper range above 1.0.

### A.3 Regional applicability [inference unless marked]

- **Dry western conifer: California, interior West, and dry east-side Pacific Northwest.** Use Table 1 directly. Nearly all of the evidence comes from ponderosa/Jeffrey pine, dry and moist mixed conifer, and Douglas-fir/ponderosa forests.
- **Wet Pacific Northwest west-side forests (Douglas-fir/hemlock, coast redwood) and subalpine or lodgepole forests.** Severity is driven by weather, and the evidence is weak or null (Davis 2024; Hettema 2026). Set multipliers to 1.0, or at most m_high 0.8 for 0-5 years with thin + burn. A cleaner default is to not offer treatments in these types.
- **Southern pine (Rx-dominated).** The effect is large but short-lived (Ross 2024). Use annual or short bands: years 0-2 m_high 0.30 (0.12-0.5), years 3-5 m_high 0.75 (0.6-0.9), 6 years and later 1.0. If the model only has 5-year bands, use 0-5 = 0.55 and 6-10 = 0.95. Southern thinning plus burning is assumed to follow the same Rx-driven decay, with slightly longer canopy-structure benefits (m_high 0.9 for 6-10 years).
- **Northeast (pitch pine and oak barrens, oak forests).** There is essentially no wildfire-burned-treatment evidence. Kalies & Yocom Kent note that "virtually no information exists on other fire-adapted forest types such as oak forests" [source]. Borrowing the southern decay curve for Rx and the western curve for thinning is a guess. Wildfire is rare there, so model results are insensitive to this choice.

---

## B. Carbon effects of the treatment itself

CBM pool names follow LUCAS: Merchantable, Other Wood, Foliage, Fine Root, Coarse Root, Snag Stem, Snag Branch, AG Very Fast (litter), AG Fast (fine woody debris), AG Medium (coarse woody debris), Belowground, and Forestry Sector (harvested wood).

### B.1 Mechanical thinning evidence

- **Stephens et al. 2009, Blodgett Forest FFS, Sierra Nevada mixed conifer.** CJFR 39:1538. [PDF](https://www.frames.gov/documents/ffs/ffs143_stephens_soils.pdf).
  - Mechanical thinning removed a mean **31.7 t C/ha of live tree C to the mill** plus **8.8 t C/ha converted to slash and chips left on site** (mastication). Of the live C removed, 78% went to products and 22% was left on site. [source + arithmetic]
  - Limbs and tops were left in the unit, and about 90% of understory trees 2 to 25 cm DBH were masticated. [source]
  - About one third of sawlog C is emitted quickly at the mill (Table 1 lists "Unused" 0.22 of sawlog mass). [source]
  - Mechanical-only treatment emitted less than 1 t C/ha (machinery and milling). [source]
  - Fossil-fuel costs of treatment are about 1 to 3% of the aboveground C stock (Campbell 2012). [source]
- **Foster et al. 2020, same experiment, 14 years.** Ecosphere 11:e03198. [PDF](https://research.fs.usda.gov/download/treesearch/60858.pdf).
  - Pre-treatment live tree C was 166 Mg C/ha. Immediately after treatment, mechanical-only reduced live tree C by **28 Mg C/ha (17%)** and mechanical + burn by **45 Mg C/ha (27%)**. Burn-only had no significant immediate effect on live tree C. [source + arithmetic]
- **North & Hurteau 2011, 19 treated and untreated stands burned in 12 wildfires.** FEM 261:1115. [Abstract via search](https://research.fs.usda.gov/treesearch/41628).
  - Fuels treatment removed **50.3 Mg C/ha, or 34% of live tree C**. [abstract/search]
- **FFS network median basal-area reduction: 30%** (Schwilk et al. 2009, as cited in Stephens et al. 2012 BioScience). [source, [PDF](https://research.fs.usda.gov/download/treesearch/40902.pdf)]
  - Across the 12-site network, mechanical treatment, with or without fire, reduced C by 16 to 32 Mg C/ha in year 1. [source]
- **Campbell et al. 2012 review (WebTable 1).** Frontiers in Ecology and the Environment 10:83. [PDF](https://lpfw.org/wp-content/uploads/2023/03/2012_Campbell-et-al_Can-fuel%E2%80%90reduction-treatments-really-increase-forest-carbon-storage-in-the-western-US-by-reducing-future-fire-emissions.pdf).
  - Aboveground C losses from treatment average about **10% for Rx only, 30% for thin only, and 50% for thin + Rx**. [source]
  - Wildfires in comparable fire-suppressed forests consume on average 12 to 22% of aboveground C. [source]
- **Pile burning.** CONSUME pile algorithm practice: assume **90% of piled biomass is consumed** (Barker et al. 2025, citing CONSUME and Hardy 1996). [source, [PDF](https://www.frontiersin.org/journals/forests-and-global-change/articles/10.3389/ffgc.2024.1496190/pdf)]

### B.2 Prescribed burn evidence

- **Stephens 2009.** Prescribed fires (fall, dry conditions) "consumed >75% of the C stored in litter, duff, and surface wood". In the fire-only treatment this loss was about 14% of total assessed C. [source]
  - Fire only created about 350 snags/ha smaller than 30 cm DBH, with no change in larger snags and no significant change in live tree C. [source]
  - Fire-only released about 38 t C/ha and mechanical + fire about 31 t C/ha. Duff consumption dominated, and skid trails reduced burn coverage in mech + fire. [source]
- **Knapp et al. 2005, Sequoia NP old-growth mixed conifer.** Total dead and down fuel consumption was **88% for late-season** burns and **67% for early-season** burns. Logs were reduced in mass but often not fully consumed. [abstract/search]
- **Foster 2020 and Schwilk 2009.** Rx had no significant immediate effect on live tree C, but it was more effective than mechanical treatment at creating snags, killing seedlings and reducing surface woody fuel. [source / abstract]
- **Safford et al. 2012** recommends prescriptions allowing about **5 to 15% fire-driven canopy tree mortality**. [abstract/search]
- **Emission split of consumed carbon.** Fire-average emission factors from Prichard et al. 2020 (IJWF 29:132, Tables 4 and 5; [PDF](https://research.fs.usda.gov/download/treesearch/61412.pdf)) [source], converted to carbon mass:

  | Region | CO2 (g/kg) | CO (g/kg) | CH4 (g/kg) | C share as CO2 / CO / CH4 |
  |---|---|---|---|---|
  | Western pine and mixed conifer | 1629.5 | 104.0 | 5.05 | **90.2% / 9.0% / 0.8%** |
  | Southeastern pine | 1576.0 | 97.1 | 4.12 | **90.6% / 8.8% / 0.65%** |

  The C shares are my arithmetic. They ignore particulate and NMOC carbon, a few percent of the total.

### B.3 Proposed pool transfers [inference, built from B.1 and B.2]

Shares are fractions of each pool in the treated cell at the time of treatment.

**Mechanical thinning (thin from below)**

- Live removal fraction r = **0.25** (range 0.15-0.40), applied to every live pool: Merchantable, Other Wood, Foliage, Fine Root and Coarse Root. Because the thinning is from below, the removed share of merchantable C is somewhat lower than the share of stems. If pools can take different values, use 0.20 for Merchantable and 0.30 for Other Wood and Foliage.
- Removed Merchantable goes **0.80 to the Forestry Sector** (range 0.6-0.9) and 0.20 stays as AG Medium (cull and unmerchantable boles left or masticated).
- Removed Other Wood and Foliage become slash:
  - Pile and burn (default): 0.90 of slash is consumed and emitted with the B.2 CO2/CO/CH4 split. The remaining 0.10 goes to AG Fast (wood) or AG Very Fast (foliage).
  - Mastication or lop and scatter: Other Wood goes 1.0 to AG Fast, and Foliage goes 1.0 to AG Very Fast.
  - A 50/50 mix of the two is a reasonable national default.
- Roots of removed trees: Coarse Root goes to Belowground (with the CBM split if the model has one) and Fine Root goes to AG Very Fast / Belowground, following the model's standard turnover split.
- Dead pools are otherwise unchanged. A little litter and fine woody debris is disturbed but not removed.

**Prescribed burn**

| Pool | Share consumed (emitted) | Range |
|---|---|---|
| AG Very Fast (litter, and duff if lumped) | **0.80** | 0.6-0.9 |
| AG Fast (fine woody debris) | **0.60** | 0.4-0.8 |
| AG Medium (coarse woody debris) | **0.30** | 0.15-0.5 |
| Snag Branch | 0.30 | |
| Snag Stem | 0.05 | |
| Belowground | 0 | Mineral soil C did not change (Stephens 2009) |

- Live tree mortality m = **0.05** of live biomass (range 0.02-0.15), concentrated in small trees. The killed share of Merchantable and Other Wood goes to Snag Stem and Snag Branch, Foliage to AG Very Fast, and roots to Belowground, as in the model's standard mortality routing.
- Crown scorch consumes about 0.02 of Foliage on surviving trees, which is emitted.
- Consumed C is split 90% CO2, 9% CO and 0.7% CH4 (B.2).
- Southern frequent burns have lower fuel loads per entry but similar consumption fractions. The modelled carbon effect per burn is then small because the pools are small.

**Thin and burn.** Apply the thinning transfers, then the burn transfers to the post-thinning pools.

- The thinning slash that the burn would otherwise consume is the default "piled and burned" share. Do not double count it: if the slash is broadcast-burned rather than piled, route slash to AG Fast and AG Very Fast first, then apply the burn consumption shares.
- The burn after thinning gets a somewhat higher live mortality, 0.05-0.08, because of slash heating and scorch.
- Expected total aboveground C loss is about 0.40-0.50 of aboveground C, consistent with Campbell's 50% and Foster's 27% live C reduction plus surface fuel consumption.

---

## C. Retreatment intervals

| Region / type | Prescribed burn | Thin and burn | Mechanical thinning | Basis |
|---|---|---|---|---|
| California (Sierra and Klamath dry mixed conifer, pine) | 10 (7-15) | Thin every 20 (15-30); maintenance burn every 10 | 20 (15-25) | Stephens 2009: fire-only units reburned after 7 years, and mech + fire would not need reburning for "approximately another decade" [source]. Staggered schedule gives about 20-year longevity [abstract]. Effectiveness halves after 10 years (Davis 2024) [source]. Historical fire return interval 5-20 years (Liang et al. 2018) [source]. |
| Pacific Northwest (dry east-side) | 10 (7-15) | 20, with a burn at 10 | 20 (15-30) | As above. West-side wet forests: no treatment [inference]. |
| Interior West (ponderosa pine, dry mixed conifer, Southwest) | 10 (5-15) | 20 (15-25), with a burn at 10 | 20 (15-30) | Davis and Martinson & Omi 10-year break [source]. Hood 2024: thin + burn still best at 20 years [source]. |
| South (southern pines) | **3 (1-5)** | Thin every 15-20 (plantation thinning cycle), burns every 3 | 15 (10-20) | Ross 2024: effect gone by about 5 years, recommends 1-2 year intervals [source]. Stephens 2012: faster-growing southern forests need more frequent retreatment [source]. |
| Northeast (pitch pine and oak barrens, oak) | 5 (3-8) | 20 thin, burns every 5 | 20 (15-30) | No direct evidence [inference]. |
| All (national default) | 5 for an acreage-weighted mix dominated by the South; 10 for western strata | 20 / 10 | 20 | [inference] |

The intervals are the time to the next entry of the same treatment. In the model, the severity multipliers time out by themselves (Table 1), so a retreatment simply resets years-since-treatment to 0.

---

## D. Costs (2024 USD per hectare)

### D.1 Evidence

**USFS FACTS, 2019-2023, WA/OR/CA hazardous-fuels activities (Barker, Voorhis & Crotty 2025, Frontiers in Forests and Global Change 7:1496190).** [source]

| Item | $/ac | $/ha |
|---|---|---|
| Hand cut, pile and burn (cut 257, pile 450, burn 98) | 805 | 1,989 |
| Machine cut, pile and burn (363 + 311 + 98) | 772 | 1,908 |
| California, hand | 997 | 2,464 |
| California, machine | 1,573 | 3,887 |
| Oregon, hand | 718 | 1,774 |
| Pile burning alone | 98 | 242 |
| Interviews: machine pile and burn | 735 | 1,816 |
| Interviews: hand pile and burn | 1,291 | 3,190 |

- Interview costs were 80% (machine) and 135% (hand) above FACTS.
- FACTS is nominal and incomplete: it excludes $0 records, often omits income-generating activities, and is not a financial system.

**RFF Working Paper 25-03 (Wear, Wibbenmeyer & Zhu 2025), California.** Built from FACTS with a Heckman-corrected cost model. [source, [PDF](https://media.rff.org/documents/WP_25-03.pdf)]

- Mean projected cost: **mechanical thinning $577/ac ($1,426/ha)** and **Rx $170/ac ($420/ha)**.
- The authors say these underpredict high-cost treatments, exclude planning and NEPA costs (they suggest about 50% overhead), and are not net of commercial revenue.
- The dollar year is not stated, so treat the values as about 2023 nominal.

**Calkin & Gebert 2006, USFS western regions** (WJAF 21:217; 297 activities; 2003 USD). [source, [PDF](https://research.fs.usda.gov/download/treesearch/27804.pdf)]

| Treatment | Mean $/ac (2003) | ±1 SD range $/ac (2003) | 2024 $/ha |
|---|---|---|---|
| Rx | 60 | 25-143 | **253** (105-602) |
| Mechanical | 213 | 102-446 | **897** (430-1,879) |

- WUI mechanical treatments cost 62% more.
- Treatment size is the strongest cost driver, with elasticities of -0.11 (Rx) and -0.30 (mechanical).

**Chang et al. 2023 (J. Forestry 121:193), western US stump-to-truck thinning, 20 studies, 2021 USD.** [source, [PDF](https://eri.nau.edu/wp-content/uploads/2024/01/2023_Thinning-cost-in-the-US-West_2023.pdf)]

- Mean whole-tree cost $2,075/ha, or **$2,402/ha in 2024 USD**. Range $758-4,291/ha, or $877-4,967 in 2024 USD.
- These are gross harvest costs before product revenue and before slash disposal.

**CAL FIRE CFIP contractor cap rates, July 2025** (opened the [FY2025 cap-rate document](https://cdnverify.bof.fire.ca.gov/media/f3boeuz4/mgmt-2-b-fy-2025-cfip-cap-rates_adamfk.docx)). [source]

- Pre-commercial thinning light, moderate and heavy: $670, $1,008 and $1,340 per acre. In 2024 USD that is **$1,613, $2,427 and $3,227 per ha**.
- Lop and scatter is included in the practice rate.
- Broadcast burning is not eligible.
- Caps are maximum reimbursable costs, so actual costs can exceed them.

**NRCS EQIP, Washington 2025 payment rates** (Northwest Natural Resource Group summary, [PDF](https://nnrg.org/wp-content/uploads/2025/07/EQIP-CSP-Payment-Comparisons.pdf)). [source]

| Practice | Payment, regular / historically underserved ($/ac) | Implied typical cost, 2024 $/ha [inference] |
|---|---|---|
| 666 pre-commercial thinning, hand tools, light | $354 / $424 | about **$1,140** |
| 384 woody residue (slash) treatment, light | $235 / $282 | about **$755** |
| 383 fuel break | $2,573 / $3,088 | not converted |

- Converting payment to cost: EQIP pays about 75% of the scenario's typical cost to regular participants and up to 90% to historically underserved ones. So cost is about payment / 0.75. That is the scenario's typical cost, not a market bid.
- I could not open state FY2024 EQIP schedules for 338 prescribed burning; the NRCS site timed out.
  - The FY2024 Arkansas RCPP schedule lists 338 forest prescribed burning at $55.62/ac and 666 at $51.88-584.44/ac by scenario. [abstract/search, not opened]
  - CSP (stewardship) rates such as 338 at $11.36/ac are annual enhancement payments, not costs. Do not use them.

**Southern prescribed burning.** [source]

- Auburn and Alabama Extension "Costs & Trends of Southern Forestry Practices" 2024 survey: ground drip-torch burning averaged **$37.78/ac ($93/ha)** over 101,272 acres. Site-prep burns cost 23% more than fuel-reduction burns, and Piedmont burns cost more than Coastal Plain burns. [search summary of [ACES FOR-2190](https://www.aces.edu/blog/topics/forestry/costs-trends-of-southern-forestry-practices-2024/); page certificate rejected]
- 2022 survey: southern region $28.38/ac, or **$75/ha in 2024 USD**, over 39,180 acres. [source, [Texas A&M AgriLife summary](https://agrilife.org/westtexasrangelands/cost-and-trends-of-rx-fire-in-southern-forestry-practices/)]
- These are private industrial and NIPF contractor costs on large tracts, so public-land costs and small-tract costs are higher.

**Northeast** (UMass Northeast barrens fuels project, [Martha's Vineyard page](https://www.umass.edu/nebarrensfuels/ma_barrens/vineyard/index.html); no year stated, assumed about 2005-2010 nominal). [source]

| Treatment | $/ac | $/ha nominal |
|---|---|---|
| Rx in scrub oak and oak woodland | 200-300 | 494-741 |
| Mowing | about 200 | about 494 |
| Pitch pine thinning (no local markets) | 1,500 | 3,707 |
| Slash pile burning | 200 | 494 |

**FFS network revenue.** Product values exceeded total treatment costs by nearly $3,000/ha at some western sites but fell short elsewhere (Stephens et al. 2012, citing Hartsough et al. 2008). [source]

### D.2 Net of revenue

Every cost above is **gross**, before merchantable revenue. RFF explicitly excludes commercial revenue, and FACTS often omits income-generating activities. LUCAS already credits timber revenue on every harvest, so use gross costs here and let the Forestry Sector flow earn revenue. Otherwise revenue is double counted.

### D.3 Proposed defaults [inference]

These are gross implementation costs, excluding NEPA and planning overhead. Add about 15-50% if full program cost is wanted (RFF suggests 50%).

- **Thinning** includes slash treatment (pile and burn or mastication).
- **Thin and burn** is the sum of the two, less about 10% shared mobilisation.

| Region | Basis | Thinning central | Thinning low | Thinning high | Rx central | Rx low | Rx high |
|---|---|---|---|---|---|---|---|
| California | FACTS CA $2,464-3,887; RFF $1,426 (modelled, underpredicts); CFIP $1,613-3,227; Rx: RFF $420, Calkin $253 (105-602), higher in WUI | 2,400 | 1,400 | 4,000 | 450 | 250 | 1,200 |
| Pacific Northwest | FACTS WA/OR $1,774-1,898; EQIP WA thin + slash about 1,900 | 1,900 | 1,100 | 3,200 | 350 | 150 | 900 |
| Interior West | Calkin $897 (430-1,879, a 2003 cost structure that understates current costs); Chang gross harvest $2,402 (877-4,967) | 1,500 | 800 | 3,000 | 250 | 100 | 600 |
| South | Low confidence for thinning: only the RCPP 666 range of $128-1,444/ha (unopened). Rx: survey $75-93/ha | 700 | 250 | 1,500 | 90 | 60 | 250 |
| Northeast | UMass mowing about $490, pitch pine thinning $3,700; Rx $494-741 nominal (about $650-1,000 in 2024 USD if the values are from about 2008) | 2,000 | 500 | 3,700 | 700 | 400 | 1,200 |
| All (national) | Weighted toward the West for thinning and toward the South for Rx area | 1,700 | 600 | 4,000 | 200 | 60 | 1,200 |

---

## E. Net carbon: what to expect

**Stand scale: treatments cost carbon.**

- Campbell et al. 2012: fuel treatments "rarely, if ever" increase forest C storage. C removed in treatment was typically about 3 times the C saved by altering fire behavior. Even strategic treatment needs about 10 treated ha to protect 1 ha from wildfire. Low-severity fire released 70% as much C per area as high-severity fire, because surface fuels dominate emissions. [source]
- North & Hurteau 2011: treatment plus wildfire removed 119% of the C emitted from untreated burned stands. But only 19% of the remaining C in treated stands moved to decomposing pools, versus 70% in untreated stands, so treated stands may come out ahead over the long term. [abstract]
- Foster et al. 2020: all treatments immediately increased *stable* live tree C. But when wildfire risk is included, "mechanical-only or no-treatment controls will maximize expected total carbon stocks" in most contexts examined. [source]
- Zhu et al. 2025 (Ecological Applications 35:e70111, Blodgett, 20 years; [PDF](https://nwfirescience.org/sites/default/files/publications/Ecological%20Applications%20-%202025%20-%20Zhu%20-%20Carbon%20costs%20of%20different%20pathways%20for%20reducing%20fire%20hazard%20in%20the%20Sierra%20Nevada.pdf)) [source]:
  - All treated stands stored less C than the control. Only mech + fire became a net source by year 20 (-60 Mg C/ha).
  - Mean NEP was 5.6-5.8 Mg C/ha/yr in Control and Fire, versus 2.0-2.1 in the mechanical treatments.
  - A simulated wildfire killed 6 to 16 times more live tree C in the control (46% mortality), yet the control kept the highest post-fire C.
- Stephens et al. 2009: in the control, 90% of live tree C had a more than 75% chance of being killed in a severe wildfire, versus low vulnerability in all treatments. They argue treatment is justified for long-term C. [source]
- Kalies & Yocom Kent 2016: treatments "do not necessarily store more carbon after wildfire", but they reduce post-fire emissions and mortality losses. [source]

**Landscape and long horizon, under climate-driven fire: can be a gain.**

- Liang, Hurteau & Westerling 2018 (Frontiers in Ecology and the Environment 16:207; [PDF](https://escholarship.org/content/qt4xz5b6pj/qt4xz5b6pj.pdf)), Sierra Nevada, 90-year LANDIS simulations [source]:
  - Accelerated and distributed restoration reduced cumulative wildfire emissions by **42% and 31%**, including the C cost of repeated Rx.
  - The accelerated scenario stored 6 Tg more C by 2100 and reduced forest loss to non-forest.
- Wiedinmyer & Hurteau 2010 (ES&T 44:1926): wide-scale Rx could reduce western US fire CO2 emissions by 18-25%, and up to 60% in some forest types. The authors note it does not account for cumulative emissions from repeated burning. [abstract/search]

**Expectations for LUCAS results [inference]**

1. Per treated hectare over 20-50 years, expect a **net loss of ecosystem C** relative to untreated. Thin + burn loses the most, Rx the least, and thinning sits in between.
2. Counting the Forestry Sector narrows the thinning loss but rarely reverses it. About a third of sawlog C is emitted quickly, and small-diameter wood goes to short-lived products.
3. A net gain appears only where three things hold together: (a) annual wildfire probability is high (about 1-2% per year or more in treated strata), (b) untreated high-severity fire causes large live C losses or conversion to non-forest, which LUCAS must represent for the benefit to show, and (c) treatments are maintained, because the severity benefit lapses after about 10 years.
4. If LUCAS represents treatment benefits only as a severity shift, without post-fire type conversion or regeneration failure, the net C result will almost always be negative. This matches Campbell 2012, Foster 2020 and Zhu 2025, while Liang 2018's gain depended on reduced forest loss. That is an expected modelling outcome, not a bug.

---

## Summary tables

### Table 1. Severity multipliers by treatment and years since treatment (dry western conifer default)

Values are multipliers on P(severity class | a treated cell burns), relative to untreated, shown as central (range). The low-severity value is the renormalised example assuming an untreated split of L/M/H = 0.40/0.30/0.30; compute it in the model as `(1 - pH*mH - pM*mM)/pL`. All values are [inference] built on Davis 2024, Martinson & Omi 2013, Graham 2009 via Kalies 2016, and Tubbesing 2019.

| Treatment | Years since treatment | High | Medium | Low (example) |
|---|---|---|---|---|
| Thin and burn | 0-5 | 0.28 (0.15-0.45) | 0.60 (0.40-0.90) | 1.84 |
| Thin and burn | 6-10 | 0.32 (0.18-0.50) | 0.65 (0.45-0.90) | 1.77 |
| Thin and burn | 11-15 | 0.60 (0.40-0.80) | 0.80 (0.60-1.00) | 1.45 |
| Thin and burn | 16-20 | 0.85 (0.65-1.00) | 0.95 (0.80-1.00) | 1.15 |
| Prescribed burn | 0-5 | 0.38 (0.20-0.60) | 0.65 (0.45-0.90) | 1.73 |
| Prescribed burn | 6-10 | 0.50 (0.30-0.75) | 0.75 (0.55-0.95) | 1.56 |
| Prescribed burn | 11-15 | 0.75 (0.55-0.95) | 0.90 (0.70-1.00) | 1.26 |
| Prescribed burn | 16-20 | 0.95 (0.80-1.00) | 1.00 | 1.04 |
| Mechanical thinning | 0-5 | 0.65 (0.35-1.15) | 0.85 (0.60-1.10) | 1.37 |
| Mechanical thinning | 6-10 | 0.70 (0.40-1.15) | 0.90 (0.65-1.10) | 1.30 |
| Mechanical thinning | 11-15 | 0.85 (0.60-1.10) | 0.95 (0.80-1.10) | 1.15 |
| Mechanical thinning | 16-20 | 1.00 (0.80-1.10) | 1.00 | 1.00 |
| Any treatment | more than 20 | 1.00 | 1.00 | 1.00 |

Mechanical thinning ranges above 1.0 reflect the 40% of thin-only observations that burned worse than untreated (Davis 2024).

Regional overrides [inference]:

- **South, prescribed burn (and the burn component of thin and burn):**

  | Years since treatment | High | Medium | Low (example) |
  |---|---|---|---|
  | 0-2 | 0.30 (0.12-0.50) | 0.60 | 1.82 |
  | 3-5 | 0.75 (0.60-0.90) | 0.90 | 1.26 |
  | 6 or more | 1.0 | 1.0 | 1.0 |

  With 5-year bands only: 0-5 is high 0.55 and medium 0.75; 6-10 is high 0.95.
- **West-side wet PNW, subalpine and lodgepole:** all multipliers 1.0, or do not offer treatments.
- **Northeast:** Rx as South, thinning as the West. Evidence is absent.

### Table 2. Carbon pool shares moved by each treatment [inference from Section B]

Shares are of the pool's C at treatment.

| Treatment | Source pool | Destination | Share (range) |
|---|---|---|---|
| Thinning | Merchantable | Forestry Sector | 0.25 x 0.80 = **0.20** (0.10-0.35) |
| Thinning | Merchantable | AG Medium (cull left on site) | 0.25 x 0.20 = **0.05** |
| Thinning | Other Wood | Slash, then: piled and burned (emitted) 0.90 and AG Fast 0.10; or masticated, AG Fast 1.0 | **0.25** (0.15-0.40) |
| Thinning | Foliage | Slash, then: emitted 0.90 and AG Very Fast 0.10; or masticated, AG Very Fast 1.0 | **0.25** |
| Thinning | Coarse Root | Belowground (or the model's coarse-root split) | **0.25** |
| Thinning | Fine Root | AG Very Fast / Belowground (model's fine-root split) | **0.25** |
| Thinning | Dead pools | No change | 0 |
| Prescribed burn | AG Very Fast | Emitted | **0.80** (0.60-0.90) |
| Prescribed burn | AG Fast | Emitted | **0.60** (0.40-0.80) |
| Prescribed burn | AG Medium | Emitted | **0.30** (0.15-0.50) |
| Prescribed burn | Snag Branch | Emitted | 0.30 |
| Prescribed burn | Snag Stem | Emitted | 0.05 |
| Prescribed burn | Belowground | No change | 0 |
| Prescribed burn | Merchantable and Other Wood (killed trees) | Snag Stem and Snag Branch | **0.05** (0.02-0.15) |
| Prescribed burn | Foliage | Killed trees to AG Very Fast 0.05; scorch emitted 0.02 | 0.05 + 0.02 |
| Prescribed burn | Coarse and Fine Root (killed trees) | Belowground / AG Very Fast | 0.05 |
| Thin and burn | All pools | Thinning rows, then prescribed burn rows on the remaining pools. Live mortality from the burn 0.05-0.08. Slash default is pile and burn (0.90 emitted). | Aboveground C loss in total about 0.40-0.50 |
| All burning | Emitted C | Split as CO2 / CO / CH4 | 0.90 / 0.09 / 0.007 (Prichard et al. 2020 emission factors) |

### Table 3. Costs by region and treatment (2024 USD per ha, gross of timber revenue, excluding planning overhead) [inference from Section D]

| Region | Thinning central | Thinning low | Thinning high | Rx central | Rx low | Rx high | Thin and burn central | Thin and burn low | Thin and burn high |
|---|---|---|---|---|---|---|---|---|---|
| California | 2,400 | 1,400 | 4,000 | 450 | 250 | 1,200 | 2,600 | 1,500 | 4,700 |
| Pacific Northwest | 1,900 | 1,100 | 3,200 | 350 | 150 | 900 | 2,000 | 1,150 | 3,700 |
| Interior West | 1,500 | 800 | 3,000 | 250 | 100 | 600 | 1,600 | 800 | 3,200 |
| South | 700 | 250 | 1,500 | 90 | 60 | 250 | 700 | 280 | 1,600 |
| Northeast | 2,000 | 500 | 3,700 | 700 | 400 | 1,200 | 2,400 | 800 | 4,400 |
| All | 1,700 | 600 | 4,000 | 200 | 60 | 1,200 | 1,700 | 600 | 4,700 |

Thin and burn is (thinning + Rx) x 0.9. Low-high ranges suit a Beta or PERT draw per iteration, matching the existing management-cost setup.

### Table 4. Retreatment interval, years, central (range) [Section C]

| Region | Prescribed burn | Thin and burn | Mechanical thinning |
|---|---|---|---|
| California | 10 (7-15) | 20 (15-30) thin; burn every 10 | 20 (15-25) |
| Pacific Northwest (dry east-side) | 10 (7-15) | 20 (15-30); burn every 10 | 20 (15-30) |
| Interior West | 10 (5-15) | 20 (15-25); burn every 10 | 20 (15-30) |
| South | 3 (1-5) | 15-20 thin; burn every 3 | 15 (10-20) |
| Northeast | 5 (3-8) | 20; burn every 5 | 20 (15-30) |
| All | 5 (South-weighted) / 10 (West) | 20; burn every 10 | 20 |

---

## Gaps and cautions

- **Severity-class evidence.** Severity-class-specific (high, medium, low) multipliers are thin in the literature. Most syntheses report continuous severity or percent high severity, and the medium and low splits are my construction.
- **Pages I could not open.** Treat the figures from these as provisional:
  - Safford 2012 full text (link failed).
  - Cansler 2022 full text.
  - Fernandes 2015.
  - Knapp 2005.
  - NRCS state EQIP FY2024 schedules for 338 (site timed out).
  - The ACES 2024 PDF (certificate error).
  - The Southern Fire Exchange page (403).
- **Unopened titles.** Hesseln et al., Maggard 2016 and Kobziar et al. were not located. The 2022 and 2024 Auburn southern surveys stand in for Maggard-type data.
- **Northeast and southern thinning costs** are low-confidence.
- **Under extreme, wind-driven fire weather**, treated units can burn as severely as untreated ones (Prichard 2020). The model could optionally relax the multipliers toward 1.0 in extreme fire years.
