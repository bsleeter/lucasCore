# Default per-hectare costs for post-disturbance management actions (provisional)

Researched 2026-11-13 for the Management Actions defaults (replanting, site preparation, salvage logging).
These are **editable, provisional defaults**. Treat every number as a planning value, not a quote.

## Conventions

- 1 ha = 2.471 ac, so $/ha = $/ac x 2.471.
- **Central estimates are in 2024 USD.** Older values were scaled with CPI-U annual averages (approximate):
  2004 to 2024 x1.66, 2019 to 2024 x1.23, 2020 to 2024 x1.21. Values published for 2024 to 2026 are used as-is, with no deflation.
- **NRCS EQIP payment rates are not costs.** The regular EQIP rate is about 75% of the scenario's estimated cost, and the historically-underserved (HU) rate is about 90%. The WA and PA HU/regular ratios are both 0.833 = 75/90, which fits this. I converted payment to cost as payment / 0.75. This conversion is my inference.
- **CAL FIRE CFIP cap rates are reimbursement ceilings, not averages.** The landowner pays anything above the cap, and is reimbursed actual cost when it comes in below. Treat them as roughly the "typical to upper-typical" contractor cost in California.
- "Replanting" below means **seedlings plus planting labor only**. Site preparation is costed separately, so the model can combine them.

---

## 1. Replanting (seedlings + planting), per hectare planted

| Region | Central (2024 $/ha) | Range ($/ha) | Typical density | Basis |
|---|---|---|---|---|
| **National default** | **1,200** | 600 to 3,000 | 500 to 1,500 trees/ha | Fargione et al. 2021 national figure, minus the site-prep share; see below |
| Pacific Northwest | 1,300 | 950 to 3,600 | ~950 trees/ha (383 TPA, industrial); post-fire often lower | 2019 PNW industry survey; WA EQIP 612 |
| California | 1,500 | 800 to 2,500 (extreme all-in: up to ~15,800) | historically 740+ trees/ha (300+ TPA); now often 250 to 500 trees/ha, clumped | CFIP caps; Fargione (USFS CA figure) |
| Interior West / Rockies | 1,200 | 700 to 2,000 | ~500 to 750 trees/ha | Fargione "West" median; Montana project |
| Southwest (AZ/NM) | 1,200 | 700 to 2,000 | ~500 trees/ha (200 TPA) | Inferred from "West"; container stock, low survival |
| South / Southeast | 800 | 650 to 1,100 | ~1,500 trees/ha (608 TPA) | Auburn 2024 cost survey |
| North / Northeast | 1,800 | 1,000 to 3,500 | ~1,000 to 1,500 trees/ha | Fargione "East" median; PA EQIP 612 |

**Key sources**

- **Fargione et al. 2021**, "Challenges to the reforestation pipeline in the United States", *Frontiers in Forests and Global Change* 4:629198. https://www.frontiersin.org/journals/forests-and-global-change/articles/10.3389/ffgc.2021.629198/full
  - The numbers come from a June 2020 survey of 70 foresters, in **2020 USD**.
  - **Coverage: all-in.** Seedlings, site prep, planting, and post-planting treatments until free-to-grow.
  - Regional medians:
    - South: $788/ha (IQR $662 to $1,006)
    - West: $1,058/ha ($862 to $1,290)
    - East: $2,098/ha ($1,282 to $4,319)
  - California: $2,347/ha ($950/ac), a USFS figure.
  - National area-weighted average: $1,262/ha.
  - USFS cost split (pers. comm., Balloffet): 50% planting crew, 29% site prep, 15% seedlings, 6% administration and surveys.
  - **How I used it:** I removed the 29% site-prep share and inflated x1.21. Example: national $1,262 x 0.71 x 1.21 ≈ $1,080/ha, rounded to $1,200.
  - The paper attributes higher Eastern costs to hardwood seedlings, and higher Western costs to container stock.
- **Alabama Cooperative Extension, "Costs & Trends of Southern Forestry Practices 2024"** (FOR-2190; Forest Landowner survey), **2024 USD**. https://www.aces.edu/blog/topics/forestry/costs-trends-of-southern-forestry-practices-2024/
  - Hand planting of pine, all methods: $200.64/ac.
  - Seedlings: $0.19 each for hand planting, $0.12 each for machine planting.
  - 608 seedlings/ac. Hand planting plus seedlings ≈ $316/ac ≈ **$781/ha**.
  - Machine planting: $190.34/ac plus 614 x $0.12 ≈ $264/ac ($652/ha).
  - **Coverage:** industrial and private loblolly-type pine regeneration, not post-fire planting specifically.
- **CAL FIRE CFIP cap rates, grants approved after 1 Jul 2025**, contractor labor, per acre. Source: BOF memo mgmt-2-b. https://bof.fire.ca.gov/media/f3boeuz4/mgmt-2-b-fy-2025-cfip-cap-rates_adamfk.docx
  - "Trees & Planting": Light $338, Moderate $504, Heavy $670 per acre. That is **$835 / $1,245 / $1,656 per ha**.
  - Tree shelters: $416/ac extra ($1,028/ha).
- Supporting sources:
  - **PNW industry survey, 2019** (Opalach, Western Forestry & Conservation Assn.). https://old.westernforestry.org/wp-content/uploads/2019/12/2019-PNW-Vegetation-Management-Presentation_2pm_Opalach.pdf
    - Clearcut units: planting $148/ac plus seedlings $172/ac at 383 TPA. That is $320/ac (2019$), about **$970/ha in 2024$**.
  - **WA NRCS EQIP 2025 sample rates** (NNRG). https://nnrg.org/wp-content/uploads/2025/07/EQIP-CSP-Payment-Comparisons.pdf
    - 612 "Reforestation, hand planting, protected" pays $1,103/ac (regular). Implied cost ~$1,470/ac ≈ **$3,630/ha**.
    - This includes seedling protection, so I used it as the PNW upper end.
  - **PA NRCS FY2026 published cost list** (Bulletin PA 440-26-06). https://nrcs-prod.azureedge.us/sites/default/files/2026-04/PA_Bulletin%20440-26-06%20PA%20Published%20Cost%20List%20and%20Payment%20caps%20for%20FY%2026%20EQIP%20%20CSP_edited.pdf
    - 612 small seedlings without protection: $1.16 per seedling (payment). Implied cost ~$1.55 per seedling.
    - With protection: $6.23 per seedling (payment).
    - At 1,000 to 1,500 seedlings/ha that is about $1,550 to $2,300/ha unprotected, the Northeast basis.
  - Montana Public Radio, on a USFS-contracted post-fire whitebark pine planting: about $700/ac, with seedlings at $2.15 each. https://www.mtpr.org/post/after-wildfires-burned-area-rehab-means-more-tree-planting
    - This is anecdotal. It shows high-elevation, container-stock projects at about $1,700/ha.
  - CalMatters (Jul 2026), citing a draft California reforestation strategy: reforestation "can cost up to $6,400 an acre" (~$15,800/ha). https://calmatters.org/environment/2026/07/wildfires-california-forest-reforestation-seed/
    - **Unclear coverage.** It is presumably all-in, including site prep, release, and replants. Treat it as an extreme ceiling, not a default.

**Flags**

- No USFS FACTS or REPLANT-report per-acre unit cost was found. The FY25 REPLANT report (https://www.fs.usda.gov/sites/default/files/fy25-replant-report.pdf) gives only totals:
  - Trust-fund obligations: $72.6M (FY23), $204.1M (FY24), $85M (FY25).
  - 699,748 ac of reforestation activities over FY23 to FY25.
  - These cannot be turned into a $/ha planting cost, because the activity acres mix planting, seeding, site prep for natural regeneration, and other work.
- The Southwest value is inferred. I found no SW-specific cost source.
- Post-fire planting on National Forests tends to cost more than private or industrial planting, because of access, steep ground, container stock, and smaller contracts. Expect public post-fire costs near the upper half of each range.

---

## 2a. Site preparation: pile and burn (machine or hand piling, then burning), per hectare

| Region / method | Central (2024 $/ha) | Range ($/ha) |
|---|---|---|
| **Default (machine pile + burn)** | **1,800** | 1,000 to 3,000 |
| Hand pile + burn | 3,200 | 1,350 to 5,000 |
| California, machine | 2,900 | 1,850 to 4,000 |
| Oregon / Washington, machine | 1,000 to 1,350 | 700 to 2,000 |
| South (broadcast burn, no piling) | 100 | 50 to 250 |

**Key sources**

- **Barker et al. 2025**, "Assessing costs and constraints of forest residue disposal by pile burning", *Frontiers in Forests and Global Change*, 10.3389/ffgc.2024.1496190. **2024 USD.** https://www.frontiersin.org/articles/10.3389/ffgc.2024.1496190/full
  - The numbers come from interviews with National Forest managers in CA, OR, and WA (dry mixed conifer and ponderosa pine).
  - Machine pile and burn: $735 ± 464/ac = **$1,817 ± 1,146/ha**.
    - WA $1,347/ha; OR $1,003/ha; CA $2,944/ha.
    - Of that, piling is $1,417/ha and burning $399/ha.
  - Hand pile and burn: $1,291 ± 717/ac = **$3,190/ha**.
    - WA $3,076/ha; OR $2,621/ha; CA $4,025/ha.
  - Cost drivers: road access (road density) and terrain (elevation and slope). Machines cannot work slopes above about 30%.
  - **Coverage:** piling plus burning of activity or fuel residue. Cutting is excluded; adding it gives machine $2,397/ha and hand $3,880/ha.
- **USFS FACTS, 2019 to 2023, as summarized in Barker et al. 2025:**
  - Machine pile and burn: $409/ac = **$1,011/ha** (CA $1,841/ha; OR $686/ha; WA $830/ha).
  - Hand pile and burn: $548/ac = **$1,354/ha**.
  - The paper finds FACTS understates the interview costs by 80% (machine) and 135% (hand). That is why I used FACTS values as the lower bound.
- **Alabama Extension 2024** (above): site-prep prescribed burning, ground ignition, $40.72/ac (~$100/ha).
  - This is broadcast burning, not piling. Southern piling (shear-rake-pile) was not reported in 2024; the "all mechanical" average was $159.82/ac.

**Flags**

- These are mostly **fuels-treatment** pile-and-burn costs in live stands. Post-fire site prep that piles fire-killed material and resprouting shrubs is assumed to cost about the same.
- No source specific to post-fire site prep was found. Heavy post-fire brush, such as 5 to 10 year-old chaparral or ceanothus, could cost more.
- CFIP does not reimburse broadcast burning. CFIP also caps follow-up "mechanical or handwork" at $670 to $1,340/ac, which is consistent with the range above.

---

## 2b. Site preparation: mechanical (mastication / brush removal), per hectare

| Region | Central (2024 $/ha) | Range ($/ha) |
|---|---|---|
| **Default (West)** | **2,200** | 1,000 to 3,500 |
| California | 2,500 | 1,650 to 3,300 |
| Pacific NW / Interior West | 2,200 | 1,000 to 3,500 |
| South / Southeast | 400 | 250 to 750 |
| North / Northeast | 600 | 450 to 1,650 |

**Key sources**

- **CAL FIRE CFIP cap rates (FY2025)**, "Site Preparation Mechanical": Light $670/ac, Moderate $1,008/ac, Heavy $1,340/ac. That is **$1,656 / $2,491 / $3,311 per ha**. Same URL as above.
  - The same caps apply to "Release, Mechanical" and to "Follow-up Mechanical or Handwork".
  - CFIP also lists equipment rates from California EQIP FY2024 for owned equipment (fuel and maintenance, labor excluded). Forestry mulcher, flail shredder, or hydro-axe: $118.61/hr; labor $34.20/hr.
- **WA NRCS EQIP 2025 sample rates** (NNRG, above), per acre:
  - 490 "Mechanical, Shredding, Light vegetation": $741/ac payment. Implied cost ~$988/ac ≈ **$2,440/ha**.
  - 490 "Hand site prep, individual spots, light": $278/ac payment (≈ $920/ha cost).
  - 314 "Brush management, hand tools, medium": $189/ac payment (≈ $620/ha cost).
- **PA NRCS FY2026 cost list** (above), 490 Mechanical, payments per acre:
  - Light $133.64, Moderate $177.13, Heavy $228.91.
  - Heavy with chemical: $497.33.
  - "Removal and disposal of brush and trees >6 in": ~$2,043 (regular).
  - Implied cost: about **$440 to $750/ha**, up to ~$1,650/ha with herbicide.
- **Alabama Extension 2024**: mechanical site prep, all types, $159.82/ac = **$395/ha**. Drum chopping, one pass, $107/ac.
- Older mastication benchmark: USFS RMRS (Halbrook et al. 2006, Priest River ID) and RMRS-RN-20 (2004). https://www.nrfirescience.org/sites/default/files/2023-07/rmrs_2006_halbrook_j001.pdf
  - Masticator average about $530/ac (range $335 to $1,395/ac). That is ≈ $2,170/ha in 2024$ (range $1,370 to $5,700).
  - Dry-forest trials cited there: $400 to $850/ac.
  - The cost falls with unit size and rises with slope above 20%, and with fuel loads above about 25 t/ac.

**Flags**

- The CFIP caps and the WA EQIP rate agree well, at about $2,400 to $2,500/ha for moderate western brush.
- Southern and Northeastern costs are much lower because terrain is flatter, vegetation lighter, and units larger. This is a strong regional difference.
- Mastication of mature post-fire shrub fields on steep ground can exceed $3,500/ha.

---

## 3. Salvage logging after wildfire, net per hectare

Salvage is often **revenue-positive for the landowner**, but the result is highly variable. It depends on:

- species and market (in California, pine stumpage is currently near zero);
- merchantable volume per hectare;
- yarding system (ground, cable, or helicopter);
- haul distance;
- **delay** (value falls quickly after the fire).

**Default:** net **+1,000 $/ha** (net revenue, entered as a negative cost). Plausible range: **-1,500 $/ha** (net cost) to **+5,000 $/ha** (net revenue). 2024 to 2026 USD.

**Components**

- **Logging plus haul cost:** $160 to $350 per MBF. At 12 to 50 MBF/ha (5 to 20 MBF/ac) that is roughly **$4,000 to $8,600/ha at 10 MBF/ac**.
  - Source: **Oregon State Univ. Extension EM 9553 (Aug 2025)**, "To salvage or not to salvage after wildfire?" https://extension.oregonstate.edu/catalog/em-9553-salvage-or-not-salvage-after-wildfire
    - Ground-based logging: $110 to $200/MBF. Cable: $185 to $300+/MBF. Trucking: about $50/MBF.
    - Example log price: $700/MBF. Example volume categories: 5, 10, or 15+ MBF/ac.
    - Douglas-fir defect after fire grows from year 1 to year 5. Cracks reach 6.5% of volume in year 1 and 40% by year 5. Stain is 22% by year 3. Decay is 16% by year 5.
- **Net stumpage (revenue after logging and haul):** California CDTFA Harvest Values Schedule, Table S (salvage timber), effective Jul to Dec 2026, $/MBF, tractor logging. These are taxable harvest values, a stumpage proxy. https://www.cdtfa.ca.gov/formspubs/cdtfa401hvsi.pdf
  - Ponderosa pine: $1 to $40.
  - True fir (hemlock-fir): $40 to $130.
  - Douglas-fir: $150 to $250.
  - Incense cedar: $30 to $100.
  - Redwood: $390 to $840.
  - Deductions: $100/MBF for skyline logging, $350/MBF for helicopter logging, and $50 to $150/MBF for small volumes.
  - Green-timber values for the same species are about 25 to 35% higher. Where few salvage sales exist, the rules set salvage at 75% of green.
  - **Implied net per hectare, at 25 MBF/ha (10 MBF/ac):**
    - pine-dominated: ~$0 to $1,000/ha;
    - mixed conifer (fir and pine): ~$1,000 to $3,000/ha;
    - Douglas-fir in north California: ~$3,700 to $6,200/ha.
    - On cable ground, subtract ~$2,500/ha, which turns pine and fir stands net-negative.
- **Delay penalty:** about **25% of salvage revenue is lost per year of delay**.
  - Source: Prestemon et al. 2006, "Wildfire, timber salvage, and the economics of expediency", *Forest Policy and Economics* 8:312-322 (Bitterroot NF, 2000 fires). https://research.fs.usda.gov/treesearch/22345
  - The OSU defect table (above) supports the same rate. Most value is gone 3 to 5 years after the fire.
- **Empirical outcomes:** CAL FIRE / Board of Forestry Emergency Salvage Logging Monitoring Report (Jan 2024), non-industrial landowners (n = 26). https://bof.fire.ca.gov/media/pasdnhnl/full-14-bof-emergency-report-final-01222024.pdf
  - 65% reported some profit, 23% broke even, and 12% had an outright loss.
  - Post-salvage cleanup and replanting costs often fell on the owner.
- **Other per-volume benchmark:** Snag-retention study (*Western Journal of Applied Forestry* 24(2):67). https://www.sciencegate.app/document/10.1093/wjaf/24.2.67
  - Net revenue above $70/m³ right after the fire, and above $60/m³ three years after.
  - The setting is likely the Pacific Northwest and the dollar year is late 2000s.

**Flags**

- No source reports net salvage $/ha directly. The per-hectare values above are **my arithmetic**: volume per hectare times net $/MBF.
- The 5 to 20 MBF/ac volume assumption is the largest uncertainty. High-severity patches in dense mixed conifer can carry 20 to 40 MBF/ac; pine or juniper woodland may carry almost no merchantable volume.
- Federal accounting differs from landowner net. National Forest salvage has sale preparation, NEPA, administration, and road costs, and can be net-negative to the Treasury even when the purchaser profits. Advocacy analyses of the 2002 Biscuit Fire salvage reported net losses (GAO-06-967 discusses this). https://www.gao.gov/assets/a251548.html
- The South and East have different markets. Pine salvage after fire there is mostly pulpwood and chip-n-saw with low stumpage, so roughly break-even is a reasonable default. No southern source was found.
- Suggestion: model salvage as **net = volume x (stumpage) − fixed cost**, with stumpage declining about 25% per year since fire. This is more defensible than a single fixed $/ha value.

---

## Summary of defaults (2024 USD per hectare)

| Action | Central | Low | High | Regional note |
|---|---|---|---|---|
| Replanting (seedlings + planting) | 1,200 | 600 | 3,000 | South ~800; PNW ~1,300; CA ~1,500; IW/SW ~1,200; NE ~1,800 |
| Site prep: pile and burn (machine) | 1,800 | 1,000 | 3,000 | CA ~2,900; OR/WA ~1,000 to 1,350; hand piling ~3,200; South broadcast burn ~100 |
| Site prep: mechanical / mastication | 2,200 | 1,000 | 3,500 | CA ~2,500 (CFIP); South ~400; NE ~600 |
| Salvage logging (net to landowner) | +1,000 revenue | -1,500 (net cost) | +5,000 revenue | Douglas-fir high; CA pine ~0; cable ground often negative; −25%/yr delay |
