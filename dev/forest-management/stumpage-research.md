# Default timber stumpage prices for LUCAS harvest revenue (2024 USD per m3)

Purpose: default stumpage prices, in USD per m3 of FIA merchantable stem volume, for

    revenue (USD/ha) = merchantable volume (m3/ha) x removal share x stumpage (USD/m3)

Stumpage is what the landowner receives for standing timber: the delivered log price minus logging, hauling and profit. Regions are California, Pacific Northwest, Interior West, South and Northeast, plus an All national default. Prices are split into softwood and hardwood.

Research date: November 2026. Data years are 2023 to 2025. Unless noted, all values are 2024 USD.

Labels used below:
- **[source]**: a number taken straight from a cited document.
- **[calc]**: arithmetic on source numbers.
- **[inference]**: my own judgement, such as a product mix, a volume weight or a range bound. Check these first if the defaults matter.

---

## 1. Conversion factors

| Quantity | Factor used | Notes |
|---|---|---|
| 1 CCF (100 ft3) | 2.832 m3 | exact |
| 1 MBF Scribner (West, sawtimber) | **5.4 m3** (range 4.5 to 6.5) | Taken from USFS FY2024 cut-and-sold reports, which give both MBF and CCF for the same sales. Sawtimber sold was 181,376 MBF = 346,198 CCF in Region 1 (1.91 CCF/MBF = 5.40 m3), 427,381 MBF = 821,079 CCF in Region 6 (1.92 CCF/MBF = 5.44 m3), and 78,301 MBF = 156,752 CCF in Region 3 (2.00 CCF/MBF = 5.67 m3) [calc]. Large old-growth logs run about 4.5 m3/MBF. Small second-growth logs run 6 to 7 m3/MBF because Scribner under-scales small logs. |
| 1 MBF International 1/4 (East, hardwood sawtimber) | **4.7 m3** (range 4.3 to 5.2) | [inference]. The International 1/4 rule over-runs much less than Scribner, so it converts to fewer m3 per MBF. |
| 1 MBF Doyle | 6 to 8 m3 | Doyle badly under-scales small logs. Penn State gives Doyle price = 1.695 x International 1/4 price ([PSU Q4 2024](https://extension.psu.edu/pennsylvania-timber-market-report-fourth-quarter-2024)). Not used here, because the southern prices are per ton. |
| 1 standard cord (128 ft3 stacked) | 2.3 m3 solid, inside bark (about 2.5 m3 with bark) | [inference], standard rule of thumb |
| Green short tons per m3, southern pine | **1.10 t/m3** | Green specific gravity of about 0.47 at about 110% moisture content gives about 0.99 metric t per m3 of wood. That is 1.09 short tons, and bark adds a little more [inference]. NC State gives 2.68 tons per cord of pine pulpwood: 2.68 / 2.4 m3 = 1.1 t/m3 [calc] ([NC 2024 report](https://content.ces.ncsu.edu/north-carolina-standing-timber-price-report-2024)). |
| Green short tons per m3, eastern hardwood | **1.15 t/m3** | NC State gives 2.9 tons per cord of hardwood: 2.9 / 2.4 = 1.2 [calc]. I rounded down to 1.15 [inference]. |
| Green short tons per m3, spruce-fir and white pine (Northeast) | **0.95 t/m3** | Lower green density [inference] |
| CPI-U, 2023 to 2024 | x 1.0295 | Annual averages 304.702 and 313.689 (BLS) |
| CPI-U, 2020 to 2024 | x 1.212 | 258.811 to 313.689 |

Southern ton prices (Timber Mart-South) are per green short ton, weighed with bark. Western prices are per MBF net Scribner. FIA merchantable volume is net, inside-bark bole volume from a 1-ft stump to a 4-inch top on trees 5 in DBH and larger. One m3 of FIA volume includes pulp-sized top logs, which earn pulp prices. That is why every region needs a blended price.

---

## 2. South (Timber Mart-South and state extension reports)

### Data (2024, USD per green ton)

| Product | Value | Source |
|---|---|---|
| Pine sawtimber, South-wide | about $26/ton through 2022 to 2024, falling over $2 (9%) in Q3 2024 to the lowest level since 2020 (about $24) | UGA, from TimberMart-South ([UGA 2025 outlook](https://fieldreport.caes.uga.edu/publications/AP130-3-13/timber-situation-and-2025-outlook/)) [source] |
| Pine chip-n-saw, South-wide | $17 to $18/ton, Q3 2024 | same [source] |
| Pine pulpwood, South-wide | $7 to $8/ton, stable through 2024 | same [source] |
| Hardwood sawtimber, South-wide | about $35/ton (recent high, Q3 2024) | same [source] |
| Hardwood pulpwood, South-wide | $7 to $8/ton | same [source] |
| North Carolina 2024, mean of 4 quarters | pine sawtimber $30.69, chip-n-saw $20.65, pine pulp $6.88, mixed hardwood sawtimber $26.86, oak sawtimber about $41, hardwood pulp $5.42 | NC State Extension, from TMS ([NC 2024 report](https://content.ces.ncsu.edu/north-carolina-standing-timber-price-report-2024)) [source; mean is calc] |
| Alabama Q4 2024 | pine sawtimber $23.05, oak sawtimber $51.59, mixed hardwood sawtimber $42.93, pine pulp $4.87, hardwood pulp $7.38 | from search summaries of state TMS reports; not opened directly |
| Mississippi Q4 2024 | pine sawtimber $20.61 | [MSU Q4 2024](https://extension.msstate.edu/sites/default/files/document/topics/mississippi-timber-2024-q4-report.pdf) |
| Florida Q3 2024 | pine pulp about $14, chip-n-saw about $22, sawtimber about $26 | [UF IFAS Q3 2024](https://programs.ifas.ufl.edu/media/programsifasufledu/florida-land-steward/events-calendar/Timber-Price-Update,-3rd-Qtr-2024.pdf) |
| South Carolina Q1 2024 | pine pulp $8.12, pine sawtimber $24.15 | [Clemson](https://blogs.clemson.edu/fnr/stumpage-price-trends-in-south-carolina-and-climate-smart-forestry/) |

### Softwood (southern yellow pine)

- **Mix assumed [inference]:** 40% sawtimber, 25% chip-n-saw and 35% pulpwood by volume. This is a typical 25 to 35 year plantation final harvest. Thinnings and younger stands are mostly pulpwood.
- **Central [calc]:** 0.40 x 25 + 0.25 x 18 + 0.35 x 8 = $17.3/ton. At 1.10 t/m3 that is **$19/m3**.
- **Low [calc/inference]:** a pulp-heavy mix (25/25/50) at low-state prices (sawtimber $20, chip-n-saw $15, pulp $5) gives $11.25/ton x 1.05 = **$12/m3**.
- **High [calc/inference]:** a sawtimber-heavy mix (50/25/25) at high-state prices (NC sawtimber $32, chip-n-saw $22, pulp $12) gives $24.5/ton x 1.15 = **$28/m3**.
- Pine sawtimber stumpage alone is $20 to $32/ton, which is $22 to $35/m3. Pine pulpwood is $5 to $14/ton, which is $5 to $15/m3.

### Hardwood (oak, mixed hardwood, yellow-poplar, gum)

- **Mix assumed [inference]:** 35% sawtimber and 65% pulpwood. A large share of southern hardwood volume is low-grade pulp or pallet wood.
- **Central [calc]:** 0.35 x 33 + 0.65 x 7 = $16.1/ton. At 1.15 t/m3 that is **$18/m3**.
- **Low [calc]:** 0.25 x 25 + 0.75 x 4.5 = $9.6/ton x 1.10 gives **$11/m3**.
- **High [calc]:** 0.5 x 45 + 0.5 x 9 = $27/ton x 1.2 gives **$32/m3**. Oak-dominated stands can exceed this.

---

## 3. Pacific Northwest (Oregon and Washington)

### Data

| Item | Value | Source |
|---|---|---|
| WA Dept of Revenue stumpage value tables, Western WA, Jan to Jun 2024 and Jul to Dec 2024 ($/MBF net Scribner, before harvest adjustments) | Douglas-fir: 497 to 585 (first half) and 487 to 606 (second half) across value areas 1 to 5 and 9. Western hemlock and other conifer: 247 to 333 and 226 to 302. Western redcedar: about 1,160 to 1,173 and 999 to 1,013. Ponderosa pine: 149 to 163 and 145 to 159. Red alder: 497 to 511 and 369 to 383. Other hardwood: 156 to 170 and 78 to 92. Black cottonwood: about $1 to 6. Chipwood: $13 to 15/ton, then $1/ton. | [WSR 24-14-009](https://lawfilesext.leg.wa.gov/law/WSRPDF/2024/14/24-14-009.pdf) [source] |
| Same, Eastern WA (value areas 6 and 7) | Douglas-fir/larch: 360 to 374 (first half) and 308 to 322 (second half). Hemlock, true fir, spruce and lodgepole: 256 to 270 and 225 to 239. Ponderosa pine: 149 to 163 and 145 to 159. Redcedar: 879 to 893 and 735 to 749. Small logs: $12 to 16/ton. | same [source] |
| Oregon Board of Forestry (state forest) lands, FY2024 average sold stumpage, all species | $588/MBF (FY2023: $520). FY2025 was $66/MBF lower. | [CFTLC annual report 2024](https://oregon.gov/odf/Documents/forestresources/cftlc-annual-report-2024.pdf), via search summary [source] |
| Oregon Common School Forest Lands, FY2024 | $518/MBF average sold; $563/MBF average harvested | [CSFL annual report 2024](https://www.oregon.gov/odf/Documents/forestresources/csfl-annual-report-2024.pdf), via search summary [source] |
| WA DNR trust-land auctions, 2024 | monthly board-sale averages of $231 to $374/MBF; FY2025 year-to-date $379/MBF as of November 2024 | [DNR June 2024 results](https://dnr.wa.gov/publications/psl_ts_jun24_auctionresults.pdf) and other monthly PDFs [source] |
| USFS Region 6, FY2024 sawtimber sold | about $87/MBF | [R6 Q4 FY2024 cut and sold](https://www.fs.usda.gov/sites/default/files/2024-q4-cut-sold-r06.pdf) [source]. The report warns that it understates unit values, because Good Neighbor sale volume is counted without its value. Federal restoration sales are not representative of private stumpage. |

The WA DOR tables are the closest thing to a published private-land stumpage price in the region. They are built from reported private and state sales, as tax values before deductions for logging conditions.

### Softwood

- **Species mix [inference]:** About 80% of PNW harvest is westside: 65% Douglas-fir, 30% hemlock/fir and 5% cedar. The other 20% is eastside: 40% Douglas-fir/larch, 35% true fir/hemlock/lodgepole and 25% ponderosa pine.
- **Sawlog price [calc]:** westside 0.65 x 540 + 0.30 x 280 + 0.05 x 1,000 = $485/MBF. Eastside 0.40 x 330 + 0.35 x 240 + 0.25 x 155 = $255/MBF. Region: 0.8 x 485 + 0.2 x 255 = $439/MBF. At 5.4 m3/MBF that is $81/m3 of sawlog.
- **Product mix [inference]:** 90% sawlog and 10% pulp/chip at about $3/m3. Chipwood and small logs are $1 to 16/ton.
- **Central [calc]:** 0.9 x 81 + 0.1 x 3 = $73/m3, rounded to **$70/m3** because second-growth logs often convert at more than 5.4 m3/MBF.
- **Low:** about $330/MBF (WA DNR auction averages and eastside values) at 6.0 m3/MBF and 90% sawlog gives **$45/m3**. Eastside-only stands, with ponderosa pine at about $150/MBF, can fall to $25 to 30/m3.
- **High:** ODF state forest at $588/MBF and 5.0 m3/MBF gives $118 for sawlog only. With 92% sawlog that is **$105/m3**. Westside Douglas-fir areas 3 and 4 at about $600/MBF are similar.

### Hardwood (mostly red alder; also bigleaf maple and cottonwood)

- **Mix [inference]:** 80% alder sawlog at about $440/MBF (mean of the two 2024 halves) and 20% other hardwood at about $120/MBF gives $376/MBF. At 5.7 m3/MBF (small alder logs) that is $66/m3. With 20% of volume as pulp at $3/m3: **central $53, about $50/m3**.
- **Range [inference]:** $30 (second-half 2024 alder at $369 plus more low-grade volume) to **$80/m3** (first-half 2024 alder at about $500 and a high sawlog share).

---

## 4. California (CDTFA Harvest Values Schedules)

### Data (CDTFA-401-HVSI, Table G green timber, tractor logging, $/MBF net Scribner)

Values are listed as Jan to Jun 2024 / Jul to Dec 2024. TVA is the timber value area.

| Species | TVA 1 to 2 (North Coast) | TVA 3 (Central Coast) | TVA 4 to 8 (interior: Klamath, Cascade, Sierra) | TVA 9 (southern) |
|---|---|---|---|---|
| Redwood (3 log-size classes) | 810 to 1,170 / 810 to 1,160 | 660 to 820 | n/a | n/a |
| Douglas-fir | 280 to 350 / 290 to 350 | 10 to 20 | 250 to 450 / 250 to 430 | n/a |
| Hem/fir (white fir, red fir, grand fir, hemlock, spruce) | 120 to 140 / 130 to 150 | n/a | 90 to 220 / 120 to 240 | 70 |
| Ponderosa pine (includes Jeffrey, sugar and white pine) | 10 | 10 | 100 to 160 / 130 to 180 | 20 to 80 |
| Incense cedar | 50 to 150 | n/a | 190 to 200 | 160 |

Sources: [1H 2024 schedule](https://www.cdtfa.ca.gov/taxes-and-fees/timber-yield-tax/Timber-Harvest-Values-1H-2024.pdf) and [2H 2024 schedule](https://www.cdtfa.ca.gov/taxes-and-fees/timber-yield-tax/Timber-Harvest-Values-2H-2024.pdf) [source]. The values in this table were read from PDF text extraction, which garbled the column layout. Each species row was matched to its value row by order; check it against the PDF before use.

Deductions apply: $100/MBF for cable/skyline yarding, $350/MBF for helicopter, $50 to 150/MBF for small total volume, and $30/MBF for under 5 MBF/acre. Table 1 (miscellaneous, 2H 2024) gives: miscellaneous conifer $60/MBF, small sawlogs $160/MBF, hardwood peeler and sawlogs $20/green ton, hardwood fuelwood $20/cord, and chips, biomass and topwood $0/ton. These Table 1 values come from the raw text order and should be checked against the PDF.

Cross-check: Humboldt County's 2023 crop report gives timber production of 230,207 MBF worth $102.7M, which is $446/MBF [calc]. That is a coast, redwood-heavy mix, and is consistent with Table G ([Humboldt 2023 crop report](https://flyacv.com/DocumentCenter/View/133862/2023-Humboldt-County-Crop-Report), via search summary).

CA harvest was about 1.6 billion board feet in 2023, with about 82% from private land ([UM BBER](https://bber.umt.edu/FIR/HarvestCA.aspx)).

### Softwood

- **Statewide species mix [inference]:** redwood 20%, Douglas-fir 25%, true fir 25%, pines 20%, incense cedar 10%.
- **Sawlog price [calc]:** 0.2 x 900 + 0.25 x 330 + 0.25 x 180 + 0.2 x 140 + 0.1 x 190 = $355/MBF. Minus about $35 for typical cable and small-sale deductions [inference], that is about $320/MBF. At 5.4 m3/MBF that is $59/m3. With 10% non-saw volume at $0 (chips are $0 in Table 1), the **central is $53, rounded to $50/m3**.
- **Low:** an interior Sierra mixed-conifer stand (30% fir, 30% pine, 25% Douglas-fir, 15% cedar) gives $207/MBF, which is $34/m3 after the non-saw share. With cable or small-volume deductions it falls to **$25/m3** [calc/inference].
- **High:** a North Coast redwood/Douglas-fir stand (60/40) gives $672/MBF, which is $112/m3. Rounded: **$110/m3** [calc].
- Most LUCAS California forest is interior mixed conifer, while most harvest value comes from the coast. If the model applies one price to all California forest area, consider the $35 to 40 interior value instead of $50 [inference].

### Hardwood (tanoak, black oak, madrone, live oak)

- Market is minimal. Table 1 gives sawlog-grade hardwood at $20/ton, about $22/m3. Fuelwood is $20/cord, about $9/m3. Most volume has no market.
- **Mix [inference]:** 20% sawlog, 50% fuelwood, 30% no value gives **central about $8/m3**, low $0, high $22.

---

## 5. Interior West (ID, MT, WY, NV, UT, CO, AZ, NM; east-side Rockies)

### Data

| Item | Value | Source |
|---|---|---|
| Idaho Dept of Lands endowment sales, FY2024 (Jul 2023 to Jun 2024), sawlog $/MBF, sale value / volume [calc] | Douglas-fir/larch $227 (79,265 MBF); grand fir, hemlock and subalpine fir $189 (124,205 MBF); ponderosa pine $110 (17,485 MBF); lodgepole $233; spruce $139; western white pine $135; cedar $706 (45,675 MBF). All MBF products: $77.35M / 275,790 MBF = $280/MBF. Southern Idaho ton sales: mixed sawlogs $19.12/ton. | [IDL 06 Stumpage Prices FY24](https://www.idl.idaho.gov/wp-content/uploads/sites/2/2024/09/06_stumpage_prices_FY24.pdf) [source] |
| IDL six-month trailing average | $285 (December 2023), falling to $200 to 211 (July to November 2024) | IDL monthly board memos (e.g. [Dec 2024](https://content.govdelivery.com/attachments/IDLANDS/2024/12/17/file_attachments/3106840/2-Trust%20Lands%20-%20Timber%20Sales.pdf)), via search summary [source] |
| Montana Dept of Revenue regression stumpage, from DNRC winning bids ($/MBF) | FY2024: Northwest $202.96, Southwest $147.24, Central $170.63, East $46.23. FY2025: $193.58, $142.32, $158.52 and -$4.85. Ten-year Olympic average: NW $212, SW $168, Central $172. | [MT DOR TY2027 Stumpage Value Report](https://revenuefiles.mt.gov/files/Resources/Government/Forest-Land-Taxation-Advisory-Committee/Handouts-and-Attachments/TY2027-Stumpage-Value-Report.pdf) [source]. The East column was read from garbled PDF text, so its alignment is uncertain. |
| USFS FY2024 sawtimber sold, value / volume | Region 1 (Northern) $61.84/MBF ($32.40/CCF). Region 2 (Rocky Mountain) about $15.60/MBF. Region 3 (Southwestern) about $20.52/MBF. | [R1](https://www.fs.usda.gov/sites/default/files/2024-q4-cut-sold-r01.pdf) and [R3](https://www.fs.usda.gov/sites/default/files/2024-q4-cut-sold-r03.pdf) Q4 cumulative reports; R2 at the same URL pattern (`2024-q4-cut-sold-r02.pdf`) [source]. The report itself says not to use it for unit values, because Good Neighbor volume is counted without value. R2 and R3 values were read from garbled PDF text. Treat them as a lower bound: federal fuels and restoration sales in CO, AZ and NM. |

### Softwood

- **Central [inference/calc]:** About $170/MBF, which is typical of Montana and Idaho state and private sales excluding cedar. Montana and Idaho produce most of the region's harvest. At 5.5 m3/MBF that is $31/m3. With 20% non-saw volume (pulp, posts and poles, biomass) at about $1/m3, that gives about $25/m3. Ponderosa pine and lodgepole stands in CO, UT, AZ and NM are much lower.
- **Low:** USFS Region 2 and 3 sawtimber at $15 to 21/MBF gives **$3/m3**. In parts of eastern Montana and the Southwest, stumpage is near zero or negative: costs exceed log value.
- **High:** IDL north Idaho all-product average of $280/MBF at 5.4 m3/MBF, about **$50/m3**. Cedar-rich stands can go higher.

### Hardwood (aspen, cottonwood)

- No regular market source was found. On federal land, aspen generally sells at minimum or nominal rates.
- **[inference]:** central $3/m3, low $0, high $10.

---

## 6. Northeast (New England, NY, PA, mid-Atlantic, and Lake States if your region includes them)

### Data

| Item | Value | Source |
|---|---|---|
| Maine Forest Service, stumpage paid to landowners in 2024, statewide averages | **Sawlogs $/MBF:** spruce-fir $108, white pine $208, hemlock $69, cedar $81, red pine $67, sugar maple $251, red oak $293, yellow birch $204, white birch $223, red/white maple $183, ash $231, beech $115, aspen $76, white oak $236. **Pulpwood $/ton:** spruce-fir $4, white pine $2, hemlock $3, mixed hardwood $7, aspen $9, red pine $4. **Studwood $/ton:** spruce-fir about $22. **Biomass:** about $1/ton. | [MFS 2024 Stumpage Price Report](https://lldc.mainelegislature.org/Open/Rpts/hd9757_m2m348_2024.pdf) [source]. Read from garbled PDF text; I checked each value against its min-max range and the prior-year column. |
| Maine 2023 (for comparison) | Sawlogs: spruce-fir $143, white pine $229, hemlock $50, sugar maple $274, red oak $285, yellow birch $259. Pulpwood: mixed hardwood $9, spruce-fir $5. Studwood: spruce-fir $25. | [MFS 2023 report](https://lldc.mainelegislature.org/Open/Rpts/hd9757_m2m348_2023.pdf) [source] |
| Pennsylvania, Q4 2024, private stumpage, $/MBF International 1/4, regional averages | Northern red oak $333 to 497; white oak $489 to 659; mixed oak $277 to 395; black cherry $213 to 510; hard maple $349 to 405; soft maple $221 to 289; yellow-poplar $164 to 360; ash $100 to 195; miscellaneous hardwood $98 to 194; hemlock $75 to 119; white pine $46 to 114. Pulpwood: hardwood $0.7 to 2.2/ton (private), $1.3 to 7.5/ton (Bureau of Forestry); softwood $1.7 to 2.4/ton. | [Penn State Q4 2024](https://extension.psu.edu/pennsylvania-timber-market-report-fourth-quarter-2024) [source] |
| Minnesota public agencies (Lake States context) | Aspen $30.14/cord in 2020, which is $36.5/cord in 2024 USD [calc], or about $16/m3. All-species hardwood pulpwood and sawbolt $26.73/cord in 2021 (about $31 in 2024 USD). | [MN DNR stumpage review 2021](https://files.dnr.state.mn.us/forestry/timber_sales/stumpage/stumpage-review-report-2021.pdf) and the 2020 report [source]. I did not find a 2024 report. |

The New Hampshire DRA stumpage lists ([NH DRA](https://www.revenue.nh.gov/mun-prop/property/stumpage-values.htm)) returned HTTP 403 and were not used. The Wisconsin DNR base rates ([WI DNR](https://dnr.wisconsin.gov/sites/default/files/topic/TimberSales/RecommendedBaseStumpageRates.pdf)) were not extracted.

### Softwood (spruce-fir, white pine, hemlock, red pine, cedar)

- **Sawlog mix [inference]:** 50% spruce-fir at $108, 40% white pine at $208 and 10% hemlock at $69 gives $144/MBF. At 4.7 m3/MBF that is $31/m3. The Maine report's log rule is not stated in what I extracted. If it is Scribner (5.4 m3/MBF), the value is $27/m3.
- **Product mix [inference]:** 35% sawlog, 15% studwood at $22/ton x 0.95 t/m3 = $21/m3, and 50% pulp at $3.5/ton x 0.95 = $3.3/m3.
- **Central [calc]:** 0.35 x 31 + 0.15 x 21 + 0.5 x 3.3 = $15.5, rounded to **$16/m3**.
- **Low:** Pennsylvania hemlock and white pine at $46 to 119/MBF, mostly pulp, gives about **$7/m3**.
- **High:** a white-pine-sawlog-dominated stand (70% sawlog at $208/MBF, rest pulp) gives about **$32/m3**. For Lake States red pine and aspen-pine stands, $15 to 25/m3 is plausible [inference].

### Hardwood (maples, oaks, birches, cherry, beech, aspen, yellow-poplar)

- **Sawlog average [inference]:** about $260/MBF, blending Maine's northern hardwoods (about $200) with Pennsylvania's oak and cherry (about $330). At 4.7 m3/MBF that is $55/m3 of sawlog.
- **Product mix [inference]:** 35% sawlog and 65% pulp, firewood or biomass at about $6/ton x 1.15 = $7/m3. Many northeastern hardwood stands are low grade, and beech and red maple make up a large share.
- **Central [calc]:** 0.35 x 55 + 0.65 x 7 = $24, rounded to **$22/m3**.
- **Low:** Maine beech and red maple, 20% sawlog at $120/MBF, the rest pulp at $2 to 3/ton, gives about **$7/m3**.
- **High:** Pennsylvania oak and cherry, 50% sawlog at $450/MBF, gives about **$50/m3**. Veneer-quality stands are far higher ($500 to 800/MBF for veneer) but are not a sensible default.
- Lake States aspen pulpwood (about $16/m3) falls inside this range.

---

## 7. All (national default)

**Volume weights [inference]:** Weights are approximate shares of US harvest volume (USFS TPO).
- Softwood: South 60%, PNW 25%, Interior West 6%, California 5%, Northeast 4%.
- Hardwood: South 65%, Northeast (with Lake States) 30%, PNW 4%, others 1%.

**Results [calc]:**
- Softwood: 0.60 x 19 + 0.25 x 70 + 0.06 x 25 + 0.05 x 50 + 0.04 x 16 = **$33/m3**. Low about $15, high about $60.
- Hardwood: 0.65 x 18 + 0.30 x 22 + 0.04 x 50 + 0.01 x 5 = **$20/m3**. Low about $9, high about $40.

If you would rather weight by forest area than by harvest, the softwood default drops to about $25/m3, because Interior West and interior California hold large low-value areas [inference].

---

## 8. What "softwood" and "hardwood" mean by region

- **South.** Softwood is southern yellow pine: loblolly, slash, shortleaf and longleaf. Hardwood is oaks, sweetgum, yellow-poplar, hickory, gums and bottomland species. Sawtimber is priced well above pulp: about 3x for pine and 4 to 6x for hardwood.
- **Pacific Northwest.** Softwood is Douglas-fir, western hemlock, true firs, spruce and western redcedar on the westside, and Douglas-fir/larch, ponderosa pine, lodgepole and grand fir on the eastside. Hardwood is mostly red alder (a sawlog market), plus bigleaf maple and cottonwood. Cottonwood is nearly worthless as stumpage. Across species, softwood runs from about $150/MBF (eastside pine) to over $1,000/MBF (cedar).
- **California.** Softwood is redwood, Douglas-fir, true firs, the ponderosa/Jeffrey/sugar pine group and incense cedar. Hardwood is oaks, tanoak and madrone, with almost no sawlog market.
- **Interior West.** Softwood is Douglas-fir/larch, grand and subalpine fir, lodgepole, ponderosa pine, spruce and some cedar and white pine in north Idaho. Hardwood is aspen and cottonwood, with little market. Pinyon-juniper is not merchantable timber.
- **Northeast.** Softwood is spruce-fir, white pine, hemlock, red pine and cedar. Hardwood is northern hardwoods (sugar and red maple, yellow and white birch, beech), oaks, black cherry, ash, yellow-poplar and aspen. Grade spread is large: a hardwood sawlog sells for 20 to 100 times the per-ton value of pulpwood.

## 9. Caveats for the model

1. **Removal share and value.** Selection and light-selection cuts often remove lower-grade stems, which gives a lower price per m3. Some selection systems do the opposite and take the best stems. The same per-m3 price for all harvest types is a simplification [inference].
2. **Age dependence.** Young stands are mostly pulp. A single blended price overstates the value of early thinnings and understates old sawtimber. If the model can index by age, use about the pulp price below about 20 years (South) or 40 years (other regions). Use the sawlog price for older stands [inference].
3. **2024 was a weak year.** Pine sawtimber was at a 4-year low, Maine spruce-fir sawlogs fell about 25% from 2023, Idaho and Montana fell to 10-year lows, and Pacific Northwest values declined in the second half of 2024. The ranges should cover the variation from year to year.
4. **Extraction quality.** The CDTFA, Maine, Montana and USFS values were read from PDF text whose columns were garbled. I matched them using the row order, the min-max ranges and the prior-year columns. Spot-check the summary values against the PDFs before committing defaults.

---

## Summary table (2024 USD per m3 of merchantable stem volume)

| Region | Wood | Central USD/m3 | Low | High | Basis |
|---|---|---|---|---|---|
| California | Softwood | 50 | 25 | 110 | CDTFA 2024 Table G (redwood, Douglas-fir, fir, pine, cedar) weighted by an assumed statewide mix, net of deductions; 90% sawlog; 5.4 m3/MBF. Low is interior Sierra, high is North Coast redwood. |
| California | Hardwood | 8 | 0 | 22 | CDTFA Table 1: hardwood sawlog $20/ton, fuelwood $20/cord; mostly no market (inference) |
| Pacific Northwest | Softwood | 70 | 45 | 105 | WA DOR 2024 stumpage tables (westside Douglas-fir about $540/MBF, hemlock about $280; eastside lower); ODF state forest FY2024 $588/MBF; WA DNR auctions $330 to 380; 90% sawlog; 5.4 m3/MBF |
| Pacific Northwest | Hardwood | 50 | 30 | 80 | WA DOR 2024 red alder $369 to 511/MBF and other hardwood $78 to 170; 80% sawlog; 5.7 m3/MBF |
| Interior West | Softwood | 25 | 3 | 50 | MT DOR FY2024 regression ($147 to 203/MBF), IDL FY2024 ($110 to 233 by species, $280 all products), USFS R2/R3 about $16 to 21 (low); 80% saw; 5.5 m3/MBF |
| Interior West | Hardwood | 3 | 0 | 10 | Aspen and cottonwood, nominal federal rates (inference) |
| South | Softwood | 19 | 12 | 28 | Timber Mart-South 2024: pine sawtimber about $25/ton, chip-n-saw $18, pulp $8; mix 40/25/35; 1.10 t/m3 |
| South | Hardwood | 18 | 11 | 32 | TMS 2024 hardwood sawtimber about $33/ton, pulp $7; mix 35/65; 1.15 t/m3 |
| Northeast | Softwood | 16 | 7 | 32 | Maine 2024 (spruce-fir $108, white pine $208/MBF; studwood $22/ton; pulp $2 to 4/ton); PA Q4 2024; mix 35 saw / 15 stud / 50 pulp; 4.7 m3/MBF, 0.95 t/m3 |
| Northeast | Hardwood | 22 | 7 | 50 | Maine 2024 hardwood sawlogs $115 to 293/MBF; PA Q4 2024 oak and cherry $213 to 659/MBF (International 1/4); pulp about $6/ton; mix 35/65 |
| All | Softwood | 33 | 15 | 60 | Harvest-volume-weighted regional values (South 60%, PNW 25%, IW 6%, CA 5%, NE 4%) (inference) |
| All | Hardwood | 20 | 9 | 40 | Harvest-volume-weighted (South 65%, NE 30%, PNW 4%, other 1%) (inference) |
