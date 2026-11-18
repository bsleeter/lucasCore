# Wetland CH4 literature check

Companion to `literature-ch4.csv` (61 rows: 54 primary, 7 secondary). Values are Mg CH4-C per ha per yr (g CH4 m-2 yr-1 x 0.0075; g CH4-C m-2 yr-1 x 0.01). "Primary" includes abstract-only reads, flagged in the CSV Note column.

The model's emergent values are the two Louisiana tower estimates of Krauss et al. 2016 (11.1 and 47.1 g C m-2 yr-1), one site each.

## Estuarine emergent (model 0.111)

| Source | Salinity | Region | Value |
|---|---|---|---|
| Arias-Ortiz 2024, n=24 | poly/mixoeuhaline | CONUS | 0.014 (median 0.005) |
| Poffenbarger 2011 | polyhaline | US temperate | 0.008 |
| Arias-Ortiz 2024, n=39 | mesohaline, cooler | CONUS | 0.052 (median 0.023) |
| Arias-Ortiz 2024, n=8 | mesohaline, warm | CONUS | 0.161 |
| Poffenbarger 2011 | mesohaline | US temperate | 0.120 |
| SOCCR2 ch. 15 | 5-38 PSU | North America | 0.083 |
| Holm 2016 / Krauss 2016 (tower) | 8-10 psu | Louisiana | 0.104 / 0.111 |
| Poffenbarger 2011 | oligohaline | US temperate | 1.125 |
| Arias-Ortiz 2024, all 108 sites | all | CONUS | mean 0.195, median 0.029 |
| IPCC Table 4.14 | <18 / >18 ppt | default | 0.145 / 0 |

Verdict: 0.111 is a sound mesohaline value. It is 8 to 15 times too high for polyhaline salt marsh and far too low for oligohaline marsh. A single value hides a 100-fold salinity gradient.

## Palustrine emergent (model 0.471)

| Source | Region | Value |
|---|---|---|
| Bansal 2023 (derived) | Prairie Pothole, US | 0.06-0.15 |
| Bridgham 2006, freshwater | CONUS | geometric 0.057; arithmetic 0.24-0.29 |
| IPCC Table 5.4, temperate mineral | default | 0.176 |
| IPCC Table 3.3, temperate peat | default | 0.092-0.216 |
| SOCCR2 ch. 13, nonforested | CONUS | 0.261 mineral; 0.236 peat |
| Knox 2019, temperate towers | global | median 0.274 (IQR 0.10-0.47) |
| Poffenbarger 2011, tidal fresh | US temperate | 0.315 |
| Knox 2015, restored marsh | California Delta | 0.39-0.53 |
| Holm 2016 / Krauss 2016 | Louisiana tidal fresh | 0.467 / 0.471 |
| Chu 2014 | Lake Erie marsh | 0.497 |
| Arias-Ortiz 2024, warm fresh-oligohaline | Gulf-type sites | 1.29 |

Verdict: 0.471 sits at the top of the interquartile range. It fits warm, permanently flooded, productive marsh. It is about 1.8 times the SOCCR2 conterminous factor and 3 to 8 times Prairie Pothole rates.

## Palustrine forested (model 0.53, range 0.008-1.05)

| Source | Region | Value |
|---|---|---|
| Great Dismal Swamp soils (derived) | Mid-Atlantic, drained peat | 0.005-0.028 |
| Krauss & Whitbeck 2012 (derived) | Savannah tidal swamp soils | 0.012 |
| SOCCR2 ch. 13, forested peat | CONUS | 0.089 |
| IPCC Table 3.3, temperate peat | default | 0.092-0.216 |
| Pulliam 1993, low habitats only | Georgia floodplain | 0.17 |
| SOCCR2 ch. 13, forested mineral | CONUS | 0.269 |
| Alford 1997 (secondary) | Louisiana swamp | 0.40 |
| Yu 2008, flooded swamp plot (derived) | Louisiana | about 1.35 |

Verdict: the range is supported, but the central value is about twice the SOCCR2 mineral-soil forested factor and six times the forested-peat factor. Emission is concentrated in the wettest fraction of a floodplain; ridges and transition zones are sinks.

## Estuarine forested (no model value)

| Source | Region | Value |
|---|---|---|
| Al-Haj & Fulweiler 2020, mangrove median | global | 0.012 |
| IPCC Table 4.14, mangrove | default | 0 above 18 ppt; 0.145 below |
| Delwiche 2021, one mangrove tower | Hong Kong | 0.111 |
| Krauss & Whitbeck 2012, tidal swamp soils | Georgia | 0.012 |
| US EPA inventory | US | not estimated |

No annual US mangrove flux was found. A value of 0.01 to 0.03 for saline mangrove is defensible, with 0.1 or more for low-salinity tidal swamp.

## Temperature sensitivity

| Quantity | Published | Q10 | Model |
|---|---|---|---|
| CH4 emission, seasonal (Yvon-Durocher 2014) | 0.96 eV | 4.22 / 3.83 / 3.50 at 0-10 / 10-20 / 20-30 C | 3.83 |
| Respiration (same source) | about 0.65 eV | 2.65 / 2.48 / 2.34 | 2.0 |
| CH4:CO2 ratio (difference, derived) | 0.31 eV | 1.59 / 1.54 / 1.50 | about 1.5 |
| CH4 across sites vs mean annual temperature (Delwiche 2021) | Q10 | 2.57 | - |
| CH4 production, Florida soils (Inglett 2012) | Q10 | 1.4-3.6 | - |
| Anaerobic / aerobic CO2 (Inglett 2012) | Q10 | 1.3-2.5 / 1.4-2.1 | 2.0 |
| Annual CH4:respiration (Knox 2019) | 0.4-7.9%, median 2.8% | rises with temperature | - |

The model's 3.83 is exactly 0.96 eV at 10-20 C. With CO2 at 2.0 the implied ratio Q10 is 1.9, not 1.5; the three numbers cannot all hold. Chang et al. 2021 found seasonal hysteresis in 77% of site-years, so a static Q10 overstates spring and understates autumn flux.

## Inventories

No 2019 Refinement change to IPCC Tables 3.3, 4.14 or 5.4 was found (search only). The EPA inventory applies Table 4.14 to palustrine coastal wetlands and omits CH4 from all estuarine wetlands. SOCCR2 implies a conterminous non-tidal mean of 0.243.

## Gaps

- US mangrove annual CH4 flux (Florida); Everglades marsh annual totals (Yu et al. 2022 gives none).
- Pacific Northwest and interior West fluxes; northern forested peatland sites (Marcell).
- Per-salinity-class medians in Arias-Ortiz 2024 (figure only) and its regional breakdown.
- Poffenbarger 2011 site table and regression; Bridgham 2006 Appendix 1 site rows (table unreadable).
- Wetland-type Q10 values in Turetsky 2014 and Bansal 2023 (supplement); the fitted CH4:CO2 ratio energy in Yvon-Durocher 2014 (paywalled).
- Hemes 2019 Delta totals; Rosentreter 2021 medians; Treat 2018 read directly.
- Stem and knee emissions from swamp trees.
