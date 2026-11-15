# Post-fire rangeland restoration: parameters for LUCAS

Literature review, November 2026. Scope: the planned post-fire seeding, sagebrush planting and annual grass control actions on the shrubland classes (Great Basin and California tests).

Evidence tags on every number:
- **FT**: full text read (text extracted from the PDF).
- **AB**: abstract or publisher/USGS summary only.
- **SEC**: second-hand (news, extension, a search snippet, or another paper citing it).
- **INF**: my inference or a derived value, not stated in any source.

Cost conversion: CPI-U annual averages (2016 = 240.0, 2019 = 255.7, 2020 = 258.8, 2024 = 313.7). The factors are 2016 to 2024 = 1.31, 2019 to 2024 = 1.23 and 2020 to 2024 = 1.21. The CPI values are from my own knowledge and were not re-checked online (flag). 1 acre = 0.4047 ha, so $/ac x 2.471 = $/ha.

---

## 1. Summary table (proposed parameters)

All success shares are **incremental cell-level probabilities** that the treated cell enters the target class, compared with the existing no-treatment trajectory (see flag F1 on double counting with fitted return rates). Values are INF unless the cited anchor is quoted directly.

| Action | Source classes | Target class on success | Window (yr since fire) | Success: central (range) | Effect duration | Cost, 2024 USD/ha: central (low-high) | Key anchors |
|---|---|---|---|---|---|---|---|
| 1a. Aerial/broadcast seeding (grass, forb, sagebrush) | Disturbed Sage, Disturbed Native Sage Steppe | Native Sage Steppe | 0-1 (fall/winter after fire; sagebrush seed must go out the first winter) | 0.15 (0.05-0.35). By R&R class: High 0.25 (0.15-0.4), Moderate 0.15 (0.05-0.25), Low 0.05 (0-0.15) | Permanent if it establishes. First-year seedling mortality is up to 50%, so judge success at year 2-3 | GB 120 (90-200); CA 150 (110-250) | Knutson 2014 FT; Germino 2018 AB; Arkle 2022 AB; Munson 2020 FT (costs) |
| 1b. Drill seeding (native perennial grass mix, often with sagebrush broadcast) | Disturbed Sage, Disturbed Native Sage Steppe (flat, accessible ground) | Native Sage Steppe | 0-1 | 0.25 (0.1-0.45). High 0.4 (0.25-0.55), Moderate 0.25 (0.1-0.35), Low 0.08 (0-0.2). Only native-only mixes count toward Native Sage Steppe | Permanent if it establishes | GB 200 (150-350); CA 250 (180-400) | Knutson 2014 FT; Pyke et al. JFSP 09-S-02-1 FT; Munson 2020 FT |
| 2. Sagebrush seedling planting (plugs, tubelings, container stock) | Disturbed Sage, Disturbed Native Sage Steppe, and seeded cells | Native Sage Steppe (sagebrush cover returns faster) | 1-3 | Plant survival 0.3 (0.15-0.7). Cell-level success 0.35 (0.15-0.6) when planted at >= 2 plants/m2 in patches | Permanent; about 15% cover in 3-4 yr in good years | Per planted ha: 2,500 (1,500-5,000). Usually applied to 5-20% of a burn as islands | Dettweiler-Robinson 2013 AB; Davies 2013 AB; Pyke 2020 AB; WRI 6059 SEC |
| 3a-i. Imazapic (pre-emergent, aerial) on burned invaded steppe | Disturbed Invaded Sage Steppe (and Disturbed Sage with high cheatgrass) | Stays disturbed. Conversion probability and reburn conversion lowered while active | 0-2 | Cheatgrass cover cut 30-65% in yr 1-2 | 1-2 yr (range 1-5) | 75 (40-150) | Courkamp 2022 FT; Munson 2015 AB; Pyke 2014 SEC; FRESC page SEC; Munson 2020 FT |
| 3a-ii. Indaziflam (+ imazapic or rimsulfuron tank mix) on burned invaded steppe | Same | Same | 0-3 | Cheatgrass cover cut 80-98% | 3-4 yr (range 2-5) | 160 (120-220) | Courkamp 2022 FT; Montana State extension SEC; UNL CropWatch SEC |
| 3a-iii. Rimsulfuron alone | Same | Same | 0-1 | Short | 1 yr (1-2) | 60 (40-100) (INF) | FRESC page SEC |
| 3b. Herbicide + seeding on converted annual grassland (two-entry: herbicide, then seed 1 yr later; or seed, then herbicide) | Grassland: Annual | Perennial grass, or Native Sage Steppe if sagebrush is seeded or planted | Any year since conversion | Two-entry: 0.3 (0.1-0.5). Single entry (spray and seed together): 0.05 (0-0.15). Mostly drives perennial grass; sagebrush rarely | Permanent if perennials pass about 1.5-6 plants/m2. Below that, reverts to annuals within about 5 yr | GB 330 (220-550); CA 400 (260-650) | Davies 2014 AB; Davies 2015 AB; Davies 2024 AB; Munson 2015 AB; Munson 2020 FT |
| 3b'. Indaziflam alone on annual grassland with residual perennials | Grassland: Annual with remnant bunchgrass | Perennial grass | Any | 0.25 (0.1-0.4), only where perennials remain | 3-5 yr control; perennial gain inconsistent | 160 (120-220) | Courkamp 2022 FT |
| Chaparral post-fire seeding | Disturbed chaparral | none | none | 0 (no benefit; reduces native herb cover) | n/a | 60-120 historically (not recommended) | Beyers 2004 AB; Keeley 2006 SEC |
| Non-sage shrub (salt desert, blackbrush, Mojave) seeding | Disturbed non-sage | Non-sage shrub | 0-1 | 0.03 (0-0.1) | n/a | as 1a | Knutson 2014 FT (low-elevation failure); INF |

Region notes: "GB" is the Great Basin (NV, OR, ID, UT, and NE California in Lassen/Modoc). California sagebrush in Lassen and Modoc should use GB success values with a 1.2-1.3x cost multiplier (INF; labor and contract costs, no CA-specific source found). No CA-specific ES&R cost records were found.

---

## 2. Establishment success

### 2.1 Knutson et al. 2014 (BLM ES&R seedings, 88 sites) [FT]
Knutson, K.C., Pyke, D.A., Wirth, T.A., Arkle, R.S., Pilliod, D.S., Brooks, M.L., Chambers, J.C., Grace, J.B. 2014. Long-term effects of seeding after wildfire on vegetation in Great Basin shrubland ecosystems. *J. Appl. Ecol.* 51:1414-1424. doi:10.1111/1365-2664.12309

- 88 sites seeded after fires in 1990-2003, sampled 8-21 yr after seeding (mean age 12.8 aerial, 12.3 drill). Sites were on loamy soils that had burned only once since 1970, so this is a best-case soil set. [FT]
- Native perennial grass: seeding generally did **not** raise cover over burned-unseeded (BX) areas. Drill seeding raised native deep-rooted perennial grass cover only when competitive non-natives were left out (18% vs 9%, BS vs BX). [FT]
- Non-native perennial grass cover rose with mean annual precipitation, steeply above about 28 cm (aerial) and above about 23 cm at the median age (drill). [FT]
- *Artemisia tridentata*: seeding did not raise shrub cover or density. Sagebrush cover **did not exceed 5% in any of the 50 ES&R seedings** where it was sown. [FT]
- Annual grass: drill seeding lowered annual grass cover only at higher elevations (above about 1300 m). Mean annual grass cover at 1000 m was over 60% regardless of treatment. In drill sites, non-native annual forb cover was about one third lower in seeded areas. [FT]
- Elevation threshold: perennial establishment was more likely above about 1350-1400 m and in wetter sites. At low, dry sites "management objectives are unlikely to be met with seeding alone." [FT]
- Mapping: the incremental effect of seeding on transition to a sagebrush class is near zero within 8-21 yr. The incremental effect on a perennial-grass state is positive only at higher elevation or precipitation, and only with native-only drill mixes. This is the basis for the low central success values.

### 2.2 Pyke, Pilliod, Chambers, Brooks, Grace. JFSP final report 09-S-02-1 (chronosequence) [FT]
- Nearly 100 ES&R sites: 61 drill, 27 aerial, 12 both. [FT]
- Drill seeding cut fuel continuity, by raising perennial grass cover and suppressing annual grass and litter, **only above about 1500 m**. Aerial seeding had no effect on fuel load or continuity. [FT]
- Sage-grouse habitat (313 seeded plots, 101 projects): no seeded plot met all breeding overstory guidelines, about 50% met understory (perennial grass) guidelines, and 98% failed winter habitat guidelines. "Reestablishing sagebrush cover will require more than 20 years." [FT]
- The report states that about 2 million ha burn each year in the Great Basin (NIFC 2001-2012). This looks high and may mix acres and hectares (flag). A USGS 2014 release says about 1 million acres per year.

### 2.3 Arkle et al. 2014 [AB]
Arkle, R.S., Pilliod, D.S., Hanser, S.E., Brooks, M.L., Chambers, J.C., Grace, J.B., Knutson, K.C., Pyke, D.A., Welty, J.L., Wirth, T.A. 2014. Quantifying restoration effectiveness using multi-scale habitat models: implications for sage-grouse in the Great Basin. *Ecosphere* 5(3):art31. doi:10.1890/ES13-00278.1
- Predicted sage-grouse occupancy on treated plots was 0.07-0.09, the same as burned-untreated. Seeded areas met native grass criteria about half the time. 97% of treated acres are in historic sage-grouse habitat. [AB/SEC via USGS release]

### 2.4 Germino et al. 2018, Soda megafire [AB]
Germino, M.J., Barnard, D.M., Davidson, B.E., Arkle, R.S., Pilliod, D.S., Fisk, M.R., Applestein, C. 2018. Thresholds and hotspots for shrub restoration following a heterogeneous megafire. *Landscape Ecology* 33:1177-1194. doi:10.1007/s10980-018-0662-8 (the volume and pages are from my memory, flag)
- 2,171 plots over a 113,000 ha burn, first year after fire. Sagebrush **established in 50% of aerially seeded plots, more than 12x the frequency in unseeded plots** (so unseeded was about 4%, INF). [AB]
- Thresholds: establishment rose above about 1200 m and on cooler microtopography and "fertile islands". It fell linearly with exotic annual grass cover and peaked at about 40% perennial bunchgrass cover. [AB]
- Caution: this is first-year occupancy (presence), not persistence or cover.

### 2.5 Arkle et al. 2022 [AB]
Arkle, R.S., Pilliod, D.S., Germino, M.J., et al. 2022. Reestablishing a foundational species: limitations on post-wildfire sagebrush seedling establishment. *Ecosphere* 13(8):e4195. doi:10.1002/ecs2.4195
- 460 post-fire sagebrush populations. No seedlings in 69% of plots in years 1-2 after fire. Occupancy fell by as much as 50% between year 1 and year 2. [AB]
- Aerial seeding raised seedling occupancy **3.4x in low R&R areas** compared with similar unseeded locations. Conditions favoring establishment (fertile islands plus a nearby surviving plant) occurred in only about 13% of post-fire locations. [AB]
- Reconciling with Germino 2018 (INF): about 50% year-1 occupancy in seeded plots, times about 0.5 survival to year 2, times further attrition to reproductive adults, gives about 0.1-0.25 of seeded area holding a persistent sagebrush cohort. That is consistent with Knutson's near-zero cover effect at 8-21 yr on older, less favorable projects.

### 2.6 Shriver et al. 2018 [AB]
Shriver, R.K., Andrews, C.M., Pilliod, D.S., Arkle, R.S., Welty, J.L., Germino, M.J., Duniway, M.C., Pyke, D.A., Bradford, J.B. 2018. Adapting management to a changing world: warm temperatures, dry soil, and interannual variability limit restoration success of a dominant woody shrub in temperate drylands. *Global Change Biology* 24:4972-4982. doi:10.1111/gcb.14374 (pages from memory, flag)
- 771 plots in 177 wildfire sites. Sagebrush occurrence is linked mainly to **cool temperatures and wet soils in the first spring after seeding**. Winter snowpack, not total precipitation, drives spring soil moisture. There is strong interannual variability. [AB]
- The quantitative establishment probabilities by year are in the paper and its data release (Shriver and Bradford 2018, USGS data release, 1979-2016 predictions). **Not obtained (flag).** Use them to make success a function of first-spring weather if the model supports climate-dependent transitions.

### 2.7 Brabec et al. 2015 [AB]
Brabec, M.M., Germino, M.J., Shinneman, D.J., Pilliod, D.S., McIlroy, S.K., Arkle, R.S. 2015. Challenges of establishing big sagebrush (*Artemisia tridentata*) in rangeland restoration: effects of herbicide, mowing, whole-community seeding, and sagebrush seed sources. *Rangeland Ecol. Manage.* 68:432-435. doi:10.1016/j.rama.2015.07.001
- **No emergence of seeded sagebrush** at the experimental site. Outplanted seedlings from local sources had about 30% or more higher initial survival than sources moved about 320-800 km (typical seed-transfer distances). [AB]
- Related: Brabec, Germino, Richardson 2017 (*J. Appl. Ecol.*) links subspecies and cytotype freezing tolerance to post-fire survival [AB/SEC]. It supports subspecies-specific seed sourcing: Wyoming vs mountain big sagebrush.

### 2.8 Barnard et al. 2019; Applestein et al. 2021; Simler-Williamson et al. 2022 [AB]
- Barnard, D.M., Germino, M.J., Arkle, R.S., et al. 2019. Soil characteristics are associated with gradients of big sagebrush canopy structure after disturbance. *Ecosphere* 10(6):e02780. doi:10.1002/ecs2.2780. Post-fire and post-seeding stands that re-established in 1986-2013. Canopy structure varies with soils. No numeric recovery values in the abstract. [AB]
- Applestein, C., Caughlin, T.T., Germino, M.J. 2021. Weather affects post-fire recovery of sagebrush-steppe communities and model transferability among sites. *Ecosphere* 12(4):e03446. doi:10.1002/ecs2.3446. Initial post-fire weather explained only about 1% more variance in sagebrush density than the prior 5-yr weather. [AB]
- Applestein, Caughlin & Germino (JFSP report, 2020): isolated sagebrush patches contribute little seed to large burns, so aerial seeding is needed to overcome seed limitation. [SEC]
- Simler-Williamson, A.B., Applestein, C., Germino, M.J. 2022. Interannual variation in climate contributes to contingency in post-fire restoration outcomes in seeded sagebrush steppe. *Conserv. Sci. Pract.* 4:e12737. doi:10.1111/csp2.12737. Thousands of seedings from 1984-2005. Sagebrush growth was higher in cool, wet springs, but weather effects were small next to fixed site characteristics. [AB/SEC]

### 2.9 Sagebrush planting [AB/SEC]
- Dettweiler-Robinson, E., Bakker, J.D., Evans, J.R., et al. 2013. Outplanting Wyoming big sagebrush following wildfire: stock performance and economics. *Rangeland Ecol. Manage.* 66:657-666. doi:10.2111/REM-D-12-00114.1 (pages from memory). About 10,500 post-fire plants, Hanford Reach (WA), 2001-2007. **Survival to year 3: 21% overall, container stock 30%, bare-root 17%.** Most mortality is in year 1. Container stock or hydrogel-dipped bare-root minimized cost per survivor. [AB]
- Davies, K.W., Boyd, C.S., Nafus, A.M. 2013. Restoring the sagebrush component in crested wheatgrass-dominated communities. *Rangeland Ecol. Manage.* 66:472-478. doi:10.2111/REM-D-12-00145.1. **About 70% survival of planted seedlings at year 3**, even without grass control. Broadcast-seeded sagebrush largely failed. [SEC from search snippet of the abstract]
- Davies, K.W., Boyd, C.S., Bates, J.D., Hamerlynck, E.P., Copeland, S.M. 2020. *Rangeland Ecol. Manage.* 73:1-8. doi:10.1016/j.rama.2019.07.005. Planted seedlings fully recovered sagebrush density, and cover rose over up to 9 yr. Seeding established almost no sagebrush. [SEC]
- Pyke, D.A., Shriver, R.K., Arkle, R.S., et al. 2020. Postfire growth of seeded and planted big sagebrush: strategic designs for restoring Greater Sage-grouse nesting habitat. *Restoration Ecology* 28:1495-1504. doi:10.1111/rec.13264. 26 seeded and 20 planted sites. Planted plants reached 30 cm height 1 yr earlier than seeded ones. Under average weather, **about 3 (planted) or 4 (seeded) years to 15% canopy cover at >= 2 plants/m2**. It recommends high-density planted patches inside lower-density seedings. [AB; the 3-4 yr figure is SEC via an indexing site, flag]
- Davies et al. JFSP 13-1-06-1 (2017): planting succeeded in Nevada and Oregon Wyoming big sagebrush. Fall 2013 seeding gave <0.01 plants/m2. [SEC]
- Utah State Extension (Rasmussen et al. 2024): tubeling first-year survival about 17-21%, wildlings about 90%. Cost about $1.47 per tubeling and $3.00 per wildling; per surviving plant at year 3, $7.95 vs $3.68 (mountain big sagebrush, former dryland pasture, not post-fire). [SEC]

### 2.10 Resistance and resilience (R&R) mapping
- Chambers, J.C., Bradley, B.A., Brown, C.S., et al. 2014. Resilience to stress and disturbance, and resistance to *Bromus tectorum* L. invasion in cold desert shrublands of western North America. *Ecosystems* 17:360-375. doi:10.1007/s10021-013-9725-5. [AB]
- Chambers, J.C., Pyke, D.A., Maestas, J.D., et al. 2014. Using resistance and resilience concepts to reduce impacts of invasive annual grasses and altered fire regimes on the sagebrush ecosystem and greater sage-grouse. USDA FS RMRS-GTR-326. [AB]
- Chambers, J.C., Beck, J.L., Bradford, J.B., et al. 2017. Using resilience and resistance concepts to manage persistent threats to sagebrush ecosystems and greater sage-grouse. *Rangeland Ecol. Manage.* 70:149-164. doi:10.1016/j.rama.2016.08.005. [AB]
- Classes come from soil temperature and moisture regimes. Low R&R is warm/dry (mesic-aridic: Wyoming big sagebrush, salt desert). High R&R is cool/moist (frigid-xeric and cryic: mountain big sagebrush). [AB/SEC]
- **No source found that reports seeding success probabilities by R&R class (flag).** My per-class values (INF) come from: (a) Knutson's thresholds (>1350-1500 m, >28 cm precipitation), which correspond roughly to moderate-high R&R; (b) Germino's >1200 m threshold; (c) Arkle 2022's finding that the relative seeding gain is largest in low R&R. That is relative to near-zero unseeded establishment, so it is still a low absolute level. Wyoming big sagebrush is about equal to low-moderate R&R, and mountain big sagebrush to high R&R.

---

## 3. Annual grass control

### 3.1 Duration and size of suppression
- Courkamp, J.S., Meiman, P.J., Nissen, S.J. 2022. Indaziflam reduces downy brome density and cover five years after treatment in sagebrush-grasslands with no impact on perennial grass cover. *Invasive Plant Sci. Manag.* 15:122-132. doi:10.1017/inp.2022.21 [FT]
  - Two sites near Pinedale, WY, at 2,250 m (mountain big sagebrush, high R&R). Indaziflam at 51, 73 and 102 g ai/ha; imazapic at 123 g ai/ha.
  - **Indaziflam at 73 or 102 g/ha: cheatgrass held at 4.8 plants/m2 and 1.3% cover at 45 months after treatment.** Re-application at 45 months added little by 57 months.
  - **Imazapic: no effect on density or cover beyond 21 months.** Imazapic control "often declines after 1 yr, and reinvasion is typical."
  - Cheatgrass seedbank life is about 5 yr. Indaziflam typically gives 3 or more years of control (citing Sebastian et al. 2016, 2017; Clark et al. 2020).
  - Perennial grass rose at some treatments only early (<= 33 months). Effects were inconsistent.
  - The authors warn that the small-plot result may not hold at large scales. The max grazing-label single rate is 73 g ai/ha (Rejuvra).
  - The paper also cites Swanson et al. (2018): native dominance declined after fire on all of 51 paired sites where pre-fire cheatgrass cover was above 15%. It cites Bradley et al. (2018): cheatgrass cover is above 15% on about 30% of the Intermountain West. And it cites Smith et al. (2021): cheatgrass-dominated area grew 8x in the Great Basin since 1990. [FT, citing others = SEC for those numbers]
- USGS FRESC, "Longevity of herbicides targeting exotic annual grasses": rimsulfuron plots were reinvaded after 1-2 yr. Imazapic resisted reinvasion for 4-5 yr at three sites (from 2016). Indaziflam suppressed medusahead up to 3 yr in the Boise foothills, with no gain from re-application. Imazapic worked there only when applied twice. [SEC, USGS project page]. Publications: Kluender, Germino, Lazarus, Matthews 2024 (patchy response to post-fire indaziflam and imazapic); Lazarus & Germino 2022. DOIs not retrieved (flag).
- Munson, S.M., Long, A.L., Decker, C., Johnson, K.A., Walsh, K., Miller, M.E. 2015. Repeated landscape-scale treatments following fire suppress a non-native annual grass and promote recovery of native perennial vegetation. *Biol. Invasions* 17:2487-2499 (pages from memory). doi:10.1007/s10530-015-0847-x. **Imazapic cut cheatgrass cover about 30% and density >50%**, but it harmed seeded species early. Best was seeding first, then herbicide 3 yr later. [AB]
- Pyke et al. 2014 (*Rangeland Ecol. Manage.*, region-wide Wyoming big sagebrush fuels study): imazapic cut cheatgrass cover by at least 63% for 3 yr and reduced some perennial grass and forb cover. [SEC, search snippet; flag]
- Applestein, C., Germino, M.J., Fisk, M.R. 2018. Vegetative community response to landscape-scale post-fire herbicide (imazapic) application. *Invasive Plant Sci. Manag.* 11:127-135. Second-fall application was less effective where pre-spray annual cover was above 42% (litter blocks soil contact). Apply in the first winter after fire. [AB]
- Montana State Extension 2021: indaziflam plots had <1% cheatgrass cover at 2 yr vs 54% and 39% untreated. Perennial grass was 57%/44% treated vs 20%/24% untreated. [SEC]
- ARS (Burns/Reno) poster: imazapic activity about 1 yr; indaziflam up to 4 yr; residual activity of 2-3 yr may limit perennial grass seeding. [SEC]

**Parameter choice (INF):** imazapic suppression 2 yr (1-5), cover reduction 50% (30-65%). Indaziflam 4 yr (3-5), 90% (80-98%). Rimsulfuron 1 yr (1-2).

### 3.2 Does seeding with herbicide raise success?
- Simultaneous imazapic and seeding (single entry) largely failed: <0.5 seeded bunchgrasses/m2 because of non-target herbicide injury. Seeding 1 yr after imazapic gave 6.5 plants/m2 in year 2. Source: Davies, K.W., Madsen, M.D., Nafus, A.M., Boyd, C.S., Johnson, D.D. 2014. Can imazapic and seeding be applied simultaneously to rehabilitate medusahead-invaded rangeland? *Rangeland Ecol. Manage.* 67:650-656. doi:10.2111/REM-D-14-00019.1 [AB]
- Davies, K.W., et al. 2015 (native vs introduced seeding after burning and imazapic; *Rangeland Ecol. Manage.*): native bunchgrass at 1.5 plants/m2 was too low to hold off medusahead and was reverting to annual grass. Introduced species did better. [AB/SEC; DOI not retrieved, flag]
- Davies et al. 2024 long-term follow-up (*Rangeland Ecol. Manage.* 92, doi:10.1016/j.rama.2023.10.001): large perennial bunchgrass cover >16x and density >4x control, 11 yr after seeding. [AB]
- Spring burn followed by imazapic, then seeding: 17% perennial bunchgrass cover by year 3 (*Rangeland Ecol. Manage.* 93, doi:10.1016/j.rama.2024.01.002). [AB]
- Munson et al. 2020 (Utah WRI, 2004-2018): herbicide (imazapic) followed by drill seeding had a larger positive effect on seeded perennial grass cover than other treatment combinations. That effect grew with herbicide spending. Cheatgrass did not change over time on herbicide plus mechanical sites. [FT]
- Knutson 2014: on low, dry sites, "intensive restoration methods such as invasive plant control and/or repeated sowings" are required. [FT]
- Herbicide protection pods (activated carbon seed coatings) let seeding go with imazapic (Clenet, Davies, et al.). [AB]

**Parameter choice (INF):** two-entry herbicide plus seeding success 0.3 (0.1-0.5). Single entry 0.05. Indaziflam residual of 2-3 yr blocks grass seeding inside its window, so model indaziflam plus seeding as seeding at year 2-3 after spraying, or limit it to sites with residual perennials.

### 3.3 Do treatments reduce later fire or conversion?
- Drill seeding cut fuel continuity only above about 1500 m. Aerial seeding had no effect on fuels (Pyke et al. JFSP 09-S-02-1). [FT]
- Kulpa et al. (Elko County, NV; Utah State extension summary): seeded areas had 4.3x perennial grass cover, and unseeded areas had 8.6x exotic annual grass cover. [SEC]
- Urza et al. (pinyon-juniper prescribed burns): seeding perennials lowered invasibility at low-resistance sites. Native mixes beat non-native mixes. [AB/SEC]
- **No study found that directly measures reburn probability or conversion rate on seeded or herbicide-treated vs untreated burns (flag).** INF: in the model, (a) apply the herbicide effect as a multiplier on the reburn-driven conversion probability, equal to (1 - cover reduction), for the suppression years only; (b) treat successful seeding as removing the cell from the disturbed, convertible pool (by moving it to Native Sage Steppe), rather than lowering fire probability directly.

---

## 4. Carbon

| Quantity | Sagebrush steppe | Cheatgrass | Notes | Source |
|---|---|---|---|---|
| Aboveground C, field plots (NV) | 160-670 g C/m2 | 22-94 g C/m2 | 3 paired sites, N-central NV | Bradley 2006 [FT] |
| Mean aboveground C loss on conversion | -440 +/- 180 g C/m2 (4.4 Mg C/ha) for sagebrush; -110 +/- 50 for salt desert shrub | | Field plus literature mean | Bradley 2006 [FT] |
| Regional loss | 8 +/- 3 Tg C to date (20,000 km2); 50 +/- 20 Tg C at risk (150,000 km2) | | | Bradley 2006 [FT] |
| Net C uptake difference | about 22 +/- 12 g C/m2/yr less under annual grass | | Summer NCE 0.50 vs 0.14 g C/m2/day | Bradley 2006 [FT], citing Prater et al. |
| Topsoil (0-10 cm) | no consistent difference | | | Bradley 2006 [FT] |
| Aboveground biomass C (synthesis) | 89 +/- 27 g C/m2 | 40 +/- 4 g C/m2 | -55% | Nagy 2021 [AB] |
| Belowground biomass C | 238 +/- 60 g C/m2 | 90 +/- 17 g C/m2 | -62% | Nagy 2021 [AB] |
| Litter C | 32 +/- 12 g C/m2 | 154 +/- 12 g C/m2 | higher under cheatgrass | Nagy 2021 [AB] |
| Net biomass + litter loss | -76 g C/m2 (0.76 Mg C/ha); 16 Tg C Great Basin | | | Nagy 2021 [AB] |
| Soil C | no significant change in total soil C; topsoil higher under cheatgrass; deep-soil losses >5 yr after fire | | | Nagy 2021 [AB] |
| Soil C (deep cores, 1,174 samples) | | -42% to -49%, mostly deep horizons | Not additive with fire; a "floor" | Maxwell et al. 2024 [AB] |
| Soil OC and N vertical distribution | | possible loss below 60 cm | 7 sites, cores to 90 cm | Rau 2011 [AB] |

Citations:
- Bradley, B.A., Houghton, R.A., Mustard, J.F., Hamburg, S.P. 2006. Invasive grass reduces aboveground carbon stocks in shrublands of the Western US. *Global Change Biology* 12:1815-1822. doi:10.1111/j.1365-2486.2006.01232.x
- Nagy, R.C., Fusco, E.J., Balch, J.K., et al. 2021. A synthesis of the effects of cheatgrass invasion on US Great Basin carbon storage. *J. Appl. Ecol.* 58:327-337. doi:10.1111/1365-2664.13770 (critiqued by a Boise State re-analysis: climate covariates change results and there is no deep-soil effect [SEC])
- Maxwell, T.M., Quicke, H.E., Price, J., Germino, M.J. 2024. Annual grass invasions and wildfire deplete ecosystem carbon storage by >50% to resistant base levels. *Commun. Earth Environ.* 5:669. doi:10.1038/s43247-024-01795-9. Stocks in Mg/ha were not obtained; the Dryad data are at doi:10.5061/dryad.d2547d88k (flag). The USGS release says about 17-20 Tg C, linked to >1 million acres of sagebrush degraded per year. The units (stock vs per year) are ambiguous across summaries (flag).
- Rau, B.M., Johnson, D.W., Blank, R.R., Lucchesi, A., Caldwell, T.G., Schupp, E.W. 2011. Transition from sagebrush steppe to annual grass (*Bromus tectorum*): influence on belowground carbon and nitrogen. *Rangeland Ecol. Manage.* 64:139-147. doi:10.2111/REM-D-10-00063.1

Perennial (native or seeded) grass state: no paired value found (flag). INF: aboveground C about 50-120 g C/m2 (between cheatgrass and sagebrush). Belowground C is close to sagebrush in the top 30 cm because of fibrous roots, but lower at depth.

### Time for restored sites to reach native levels
- Perennial grass cover: years 2-5 after a successful seeding (Davies 2014: 6.5 plants/m2 by year 2; spring-burn plus imazapic: 17% cover by year 3). [AB]
- Sagebrush canopy cover:
  - Planted or seeded at >= 2 plants/m2: about 15% cover in 3-4 yr in average weather (Pyke 2020). [AB/SEC]
  - Unassisted Wyoming big sagebrush: no full recovery within 66 yr across 112 sites in 24 studies (FEIS review). Cooper, Lesica & Kudray (2011, Montana) estimate well over 100 yr. Eastern Oregon: 115 yr at the earliest. [SEC]
  - Mountain big sagebrush: about 30 yr (Montana; Ziegenhagen & Miller 2009 give 25-35 yr for Oregon, from memory, flag). [SEC]
- Shinneman, D.J., McIlroy, S.K. 2016. *Int. J. Wildland Fire* 25:933-945 (from memory): Wyoming and basin big sagebrush recovery takes several decades in the northern Columbia Basin. [SEC]
- Soil C: no recovery-rate data found (flag). Maxwell 2024's "floor" result suggests deep soil C does not rebuild on restoration time scales. INF: use the biomass recovery curve of the Native Sage Steppe class and keep soil C at the converted value for at least 30 yr.
- The model's 0.028/yr return from age 8 implies a mean of about 36 yr before return. That fits mountain big sagebrush, but it is fast for Wyoming big sagebrush (INF).

---

## 5. Costs per hectare

### 5.1 Itemized records
| Item | Value (as reported) | Price year | 2024 USD/ha | Source |
|---|---|---|---|---|
| Aerial seeding operation (Utah WRI) | $29.5-33.6/ha | 2016 | 39-44 | Munson 2020 Table 2 [FT] |
| Seed mix with aerial (chaining or mastication plus aerial) | $43-69/ha | 2016 | 57-91 | Munson 2020 [FT] |
| Drill seeding operation | $57.2/ha | 2016 | 75 | Munson 2020 [FT] |
| Seed mix with drill | $73.2/ha | 2016 | 96 | Munson 2020 [FT] |
| Herbicide (imazapic) application, as used before drill seeding | $110/ha | 2016 | 144 | Munson 2020 [FT] |
| Imazapic product only | $6-9/ac | about 2020 | 18-27 | UNL CropWatch [SEC] |
| Indaziflam (Rejuvra) product at 5 fl oz/ac | about $42/ac | 2020 | 125 | UNL CropWatch [SEC] |
| Indaziflam product (Montana trial) | $46.45/ac | about 2021 | about 125 | Montana State Ext. [SEC] |
| EQIP 315 Herbaceous Weed Treatment, chemical aerial (payment rate, state unclear) | $29.11/ac | FY2024 | 72 (payment, not cost) | NRCS STAC 2024 [SEC] |
| EQIP 315 chemical ground / spot | $41.02 / $30.96 per ac | FY2024 (NV) | 101 / 77 | NRCS NV STAC 2024 [SEC] |
| EQIP 550 Range Planting | not found | | | flag |
| Horse Valley Fire ESR (UT) seed mix, 1,131 ac aerial (+494 ac chaining) | $59,393 seed (11,762 lb) | FY2019 | 90-130 seed only | Utah WRI project 4753 [SEC] |
| Same project, total budget | $143,288 | FY2019 | 260-380 per ha seeded (incl. chaining) | WRI 4753 [SEC] |
| Sagebrush tubelings, field planting plus stock | $1.50 + $2.00 per plant | 2023-24 | $3.5/plant; 1,750-5,250/ha at 500-1,500 plants/ha (INF) | WRI 6059 [SEC] |
| Tubeling vs wildling cost | $1.47 vs $3.00/plant; $7.95 vs $3.68 per surviving plant | about 2024 ($15/h labor) | | USU Extension [SEC] |
| Soda Fire (ID/OR, 2015, about 280,000 ac burned) | $67M planned over 5 yr; $14M spent by spring 2016, about half on seed | 2015-16 | INF about 600/ha burned across all treatments | Spokesman-Review, Boise State Public Radio [SEC] |
| BLM "about $60/ac" to rid burned areas of cheatgrass and rebuild sagebrush and grasses | $60/ac | undated | about 150-200 | news quote [SEC, weak] |

### 5.2 Derived central values (INF)
- **Aerial seeding** (operation plus seed): 2016 WRI is $73-103/ha, or $95-135 in 2024. Sagebrush-heavy native ES&R mixes cost more (bluebunch wheatgrass went from $4-5 to $20/lb in 2012, HCN 2015 [SEC]). Central **$120/ha, range 90-200**.
- **Drill seeding**: $130/ha in 2016, or $170 in 2024, plus the native premium. Central **$200/ha, range 150-350**. Cost rises with slope; drills cannot work steep or rocky ground (Meldrum et al. 2025 [AB]).
- **Imazapic, aerial**: product $18-27/ha plus aerial application about $25-40/ha (INF), or $45-65/ha. The WRI figure ($144) and EQIP ground rate ($101) are higher. Central **$75/ha, range 40-150**.
- **Indaziflam, aerial**: product about $125/ha plus application, or $150-170/ha. Central **$160/ha, range 120-220**.
- **Herbicide plus drill seeding (two-entry) on annual grassland**: 75 + 200 + about 55 for a second mobilization (INF), giving **$330/ha, range 220-550**.
- **Sagebrush planting**: **$2,500 per planted ha, range 1,500-5,000**. Planted as patches, so the cost per burned hectare depends on the patch share.
- **Scale**: per-acre costs drop nonlinearly with treatment size and have risen in real terms in recent decades. Seeding costs per area rose about 600% from 1981 to 2010 (Southwest BLM; Copeland et al. 2018, *Restoration Ecology* 26:311-322, doi:10.1111/rec.12574 [AB]).
- **Missing**: Meldrum, J., Huber, C., Monroe, A., Tarbox, B.C., Jeffries, M.I., Pilliod, D., Aldridge, C.L. 2025. Costs of land treatments on public lands in the western United States. *Rangeland Ecol. Manage.* 100:99-110. doi:10.1016/j.rama.2025.03.004. This paper has empirical per-acre models for aerial seeding, drill seeding, seedling planting and weed control from 1,701 LTDL records. **The full tables were not accessible; this is the best source to replace my central values (flag).** Companion work: Monroe et al. 2026, *Rangeland Ecol. Manage.*, doi:10.1016/j.rama.2026.07.004 [AB], with data release doi:10.5066/P13LOV2A. Drill seeding always cost more than aerial, and cost-effectiveness rose with pre-disturbance sagebrush cover.
- **Taylor et al.**: Taylor, M.H., Rollins, K., Kobayashi, M., Tausch, R.J. 2013. The economics of fuel management: wildfire, invasive plants, and the dynamics of sagebrush rangelands in the western United States. *J. Environ. Manage.* 126:157-173. doi:10.1016/j.jenvman.2013.03.044. It covers pre-fire fuel treatments. A related Markov-chain paper (AgEcon) found post-fire revegetation cheaper than none once suppression costs are counted. [SEC; no $/ha extracted, flag]

---

## 6. Area treated historically

- BLM ES&R plus Burned Area Rehabilitation, national: **about 300 projects per year, averaging 1.6 million acres (about 650,000 ha) of treatments** of all types (seeding, weed treatment, closures, fencing). [FT, BLM HQ-220 handout, March 2021]
- BLM post-wildfire seedings, national: **about 380,000 acres (about 154,000 ha) per year** (2021 BLM presentation). [SEC, search snippet; flag]
- Seed use: the national seed warehouse system goes through about 2-3 million lb per year (2024 interview) [SEC]. An older Western Great Basin figure is >7 million lb in one year (undated) [SEC].
- DOI Burned Area Rehabilitation: about $10M in FY2024 (this is not the full ES funding). [SEC]
- Single large fires:
  - Soda (2015): about 156,600 ac seeding planned; 17,257 ac drilled and 27,426 ac aerial imazapic by May 2016. [SEC]
  - Martin (NV, 2018, about 435,000 ac burned): about 141,000 ac broadcast seeded, about 22,000 ac drilled, about 31,000 ac aerial imazapic. [SEC]
- LTDL, Great Basin: more than 9,000 confirmed treatments over 75 yr, 58% seedings by count (Pilliod, D.S., Welty, J.L., Toevs, G.R. 2017. Seventy-five years of vegetation treatments on public rangelands in the Great Basin of North America. *Rangelands* 39:1-9. doi:10.1016/j.rala.2016.12.001). [AB; the area series in the full text was not accessible, flag]
- Great Basin burned area: about 1 million acres per year (USGS 2014 release) [SEC]; the JFSP report says 2 million ha (flag).
- INF: if most of the 154,000 ha per year of BLM post-fire seeding falls in the Great Basin sagebrush biome, against about 400,000-800,000 ha burned, then **roughly 20-40% of burned BLM sagebrush area is seeded**. With incremental sagebrush success of about 0.1-0.2, past seeding explains **about 2-8% of burned area returning**. So the fitted 0.028/yr return already includes a small seeding share. That is not enough to bias the return rate much, but avoid counting success on top of a cell's baseline return probability.

---

## 7. Chaparral and non-sage shrubs (brief)

- Beyers, J.L. 2004. Postfire seeding for erosion control: effectiveness and impacts on native plant communities. *Conservation Biology* 18:947-956. doi:10.1111/j.1523-1739.2004.00495.x
  - Fewer than half of the reviewed studies showed reduced sediment movement with seeding. [AB]
  - Seeded grasses that grow enough to affect erosion displace native species, including shrub and tree seedlings. [AB]
- Beyers et al. (1998) and Keeley et al. (1981), southern California chaparral: ryegrass (*Lolium*) reduced native herbaceous cover and richness ("fire annuals"), rarely raised cover in the first, erosion-critical winter, and had little consistent effect on shrub seedling density. [SEC]
- Keeley, J.E. 2006. Fire management impacts on invasive plants in the western United States. *Conservation Biology* 20:375-384. doi:10.1111/j.1523-1739.2006.00339.x. Post-fire seeding introduces non-natives and is ineffective. [SEC; volume and pages from memory, flag]
- Recommendation (INF): no chaparral seeding action. If one is wanted as a scenario contrast, success = 0 and herbaceous native loss is not modeled. The existing chaparral return (0.25/yr, window 8) needs no treatment.
- Non-sage shrubs (salt desert shrub, low-elevation types below about 1300 m and below 23-28 cm precipitation): Knutson's low-elevation results show seeding rarely establishes, and annual grass cover stays above 60% at 1000 m regardless of seeding [FT]. INF success 0.03 (0-0.1). Treat it as optional.

---

## 8. Open questions and flags

- **F1, double counting.** Literature success values are seeded vs unseeded differences (Knutson BS vs BX; Germino 12x). Use them as incremental probabilities on top of the class's baseline return, or lower the baseline slightly (about 2-8%, INF).
- **F2, no R&R-specific success rates.** The per-class values are INF from elevation and precipitation thresholds. A possible source is the Shriver 2018 data release, which has establishment probability by site-year for 1979-2016 and could be overlaid on R&R maps.
- **F3, sagebrush vs grass outcome.** Seeding mostly yields perennial grass (often non-native). "Success to Native Sage Steppe" overstates sagebrush return. Consider either (a) a Perennial Grass (seeded) class with its own slow sage return, or (b) defining Native Sage Steppe success as on a sagebrush trajectory, with a return rate set by subspecies.
- **F4, establishment timing.** Germino and Arkle measure years 1-2 presence, and occupancy halves by year 2. Knutson measures 8-21 yr cover. The model success share should match persistence at about 5 yr or more, so use the lower values.
- **F5, herbicide on conversion.** There is no direct evidence that herbicide or seeding lowers reburn or conversion probability. The proposed multiplier is INF.
- **F6, cost sources.** Meldrum et al. 2025 (LTDL cost models) and the NRCS EQIP 550 Range Planting rates by state were not retrieved. Current central costs mix Utah WRI 2016 records, product prices and single-project budgets.
- **F7, carbon.** There are no paired stocks for the perennial grass state, Maxwell 2024 stocks in Mg/ha were not obtained, and soil C recovery after restoration is unknown. Nagy 2021 and Maxwell 2024 disagree on total soil C (no change vs -42 to -49%).
- **F8, bibliographic details.** Volume and pages marked "from memory" were not checked online: Germino 2018, Shriver 2018, Dettweiler-Robinson 2013, Munson 2015, Shinneman & McIlroy 2016, Keeley 2006, Ziegenhagen & Miller 2009.
- **F9, burned area.** The JFSP report's 2 million ha per year conflicts with about 1 million acres per year elsewhere.
- **F10, not reviewed.** Davies plug and herbicide work on burned (not crested wheatgrass) Wyoming big sagebrush; California sagebrush (Lassen/Modoc) ES&R records; Taylor et al. cost-effectiveness figures; LTDL area time series. All are worth a follow-up with library access.
