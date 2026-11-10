# Changelog

Changes to lucasCore by version. Version numbers follow [Semantic Versioning](https://semver.org/).

## 1.2.1 - 2026-11-10

Grass and shrub live carbon fitted to field biomass, and California's crop mix filled where a county's report leaves a crop out.

**Upgrading:** install `lucasCore-1.2.1.ssimpkg`. There are no schema changes from 1.2.0, so a 1.2 library needs no update; switch
its lucasCore package to 1.2.1 (`SyncroSim.Console.exe --add --package --pkg=lucasCore --ver=1.2.1 --lib=<library.ssim>`).
The changes are in the package defaults, so rerun the Build to use them; results made with 1.2.0 keep their values.

### Changed
- Grassland and shrubland (to-do 55): growth stays on RAP NPP for every class, and each class's turnover is now fitted so its live
  stocks match field biomass (aboveground and roots, from a literature review). Chaparral's wood turnover is 0.08 a year (was
  0.03), which puts mature Mediterranean chaparral growth at about 2.5 Mg C/ha/yr with its stocks unchanged. Non-sage shrub and
  Native Sage Steppe split their growth between a grass layer and a shrub layer by RAP's herbaceous share, bringing their live
  carbon down to about 1.5 / 2.0 and 1.4 / 2.4 Mg C/ha (aboveground / roots) at the class's mean NPP, from 3 to 5 times that.
  Annual grass roots die back each year. In the Calaveras test, annual grass live carbon fell from 4.8 to 3.7 Mg C/ha and non-sage
  from 18.4 to 7.4.
- Crop Mix (California): a crop missing from a year of a county's commissioners' report (counted under "unspecified" so growers
  stay private) takes its area interpolated between the years it was reported, or its 2019 area when 2020 is missing. 3,404
  crop-years filled; Calaveras's 2020 crop mix goes from 0.37 to 0.85 of its 2014-2020 level (its walnuts had been left out).

## 1.2.0 - 2026-11-09

Grassland, shrubland, wetland and agriculture carbon rebuilt from data, CO2 fertilization in projections, and library updates.

**Upgrading:** install `lucasCore-1.2.0.ssimpkg` (File > Packages > Install from file in SyncroSim Studio), then update each
library made with 1.0 or 1.1: switch its lucasCore package to 1.2.0 and let SyncroSim update it, or from a command prompt

    SyncroSim.Console.exe --add --package --pkg=lucasCore --ver=1.2.0 --lib=<library.ssim>
    SyncroSim.Console.exe --update --lib=<library.ssim> --backup

(--backup keeps a .ssimbak copy in the library's .backup folder). The update adds the new columns, the agriculture stock, flows and
flow groups, the new Flow Multiplier Types, and the stock-flow rows of a Stock-Flow Definitions scenario; tools/sync-library.R is
no longer needed for that. Results made with 1.1 keep their values; rerun the Build to use the new non-forest carbon. Needs
SyncroSim 3.1.29 or later with ST-Sim 4.5.4.

### Added
- Library updates (ui/LucasCoreUpdates.cs, SyncroSim's .NET update provider): each version's schema and definition changes are applied
  when a library made with an earlier version is opened. Every step checks first, so a library that already has a change is left as
  it is. The 1.1 update (the Study Area options table) moved here from updates/update-1.1000.xml.
- Grassland and shrubland carbon by ecodivision (to-do 39): growth and soil from RAP NPP and gNATSGO, pools and litter from the
  literature; chaparral, non-sage shrub and the sage family grow by years since fire (woody recovery from the literature, the early
  dip from RAP within MTBS fire perimeters).
- Emergent wetlands by ecodivision, fitted in ST-Sim's flow order; estuarine growth recalibrated to the USGS tidal marsh NPP map.
- Cropland and pasture grow, are harvested and decay (to-do 39 step 6): a new Agriculture Sector stock, Net Growth Agriculture and
  Harvest flows, and Crop Yield multipliers from NASS county yields by year.
- Build Options > Site Productivity, three choices (each None by default): Grass and Shrub Productivity (RAP NPP 2014-2023),
  Cropland Productivity (each cell's Cropland Data Layer crops at their county's NASS growth, with a Crop Harvest map, and in
  California the County Agricultural Commissioners' rates and yearly crop mix, Crop Mix) and Tidal Marsh Productivity (the USGS
  tidal marsh NPP map). Data Sources: RAP NPP, Cropland Data Layer and tidal marsh NPP folders, filled by the Data Download.
- Climate Options > Non-Forest Growth: RAP fit (the default), grass and shrub growth from the water year's rain by season, last
  year's rain and temperature, fitted to RAP NPP; PRISM monthly precipitation is downloaded for it.
- CO2 fertilization of growth in projections (stage 11, to-do 46): the Climate page of a Projection Climate scenario chooses a series
  (None / Low / Central / High, Central by default), an optional CO2 ceiling and reference CO2, and a table of its betas. Growth
  is multiplied by 1 + beta ln(CO2 / the CO2 of the historical end year), with CO2 from the SSP (Meinshausen et al. 2020) and beta by
  vegetation type from a literature review; forest betas mix ECM and AM values by each forest type's ECM share of FIA basal area and
  taper with stand age. New CO2 Flow Multiplier Type; a CO2 Betas table on the page, loaded with the chosen series' defaults for the study area's strata and editable; CO2 Fertilization Betas and CO2 Series results.
  The No Climate projection has no CO2 effect.
- tools/make_co2_ecm_share.R (the ECM shares from the FIA DataMart tree tables) and tools/make_co2_default_betas.R (the table the page loads).
- Build result: a Non-Forest Productivity table (each non-forest multiplier by ecodivision and class: cells, share with map data,
  mean, 10th, median and 90th percentile, share at the cap).
- Build Figures: the non-forest productivity maps beside forest site productivity (Figure 4), shrubland years since fire (Figure 2),
  shrubland net growth by years since fire and the other non-forest classes' net growth (Figure 6), burned area by land type
  (Figure 9) and an agriculture panel of Crop Yield and Crop Mix (Figure 10).
- The data home keeps each dataset's download records in records/, so a home copied or restored whole is not downloaded again (to-do 52).

### Changed
- FIA Data in Growth Curve Options defaults to the FIA DataMart. A library set to the USGS condition tables whose files are not set
  reads the DataMart instead and says so in the log (a new library's Build stopped in stage 2).
- TreeMap is kept whole at the top of the data home, like FIA and PRISM, so each new region reads it instead of fetching the 5.4 GB
  zip again.
- Data Download: a dataset that only a browser can fetch (RCMAP 1985 on ScienceBase, which now asks for a captcha) is a step for the
  user, listed at the end of the log, not a failure that stops the run. A stage that stops on a failed check names what failed.
- Stage 11 runs when every climate effect is None, for CO2 alone, and copies the Build's flow multipliers into its result when it
  writes CO2 rows.
- Minimum SyncroSim version raised from 3.1.9 to 3.1.29, the version lucasCore is tested on (3.1.9 was never tested). The README
  names the rsyncrosim version tested with (2.1.13).

### Fixed
- The data home no longer counts a Build's FIA caches or a GIS overview (.ovr) beside a raster as part of a dataset, which made
  the FIA DataMart and the Cropland Data Layer look out of date and download again.
- tools/new-library.R: the LOCA2 lookup no longer breaks when Data Sources Home is set.
- Build Figures: Figure 8's transition types each have a colour and key; a legend too wide for the space beside its panel title
  wraps (Figures 7, 8, 10); the decay and checks charts no longer fail with few rows.
- Stage 8 run alone keeps the Initial Conditions Spatial feed and the dependency's flow spatial multipliers; stage 7 run alone keeps
  the Build's productivity multipliers.

## 1.1.1 - 2026-11-09

Released from v1.1.0 (branch release/1.1.1); main has the same fix.

### Fixed
- Every stage failed with "more columns than column names" on a machine with only a few SyncroSim packages installed. rsyncrosim
  reads the installed-package list by turning runs of spaces into commas, so the commas in the package description added columns.
  The description no longer has commas; tests/unit-package-description.R checks it. Libraries made with 1.1.0 open unchanged.

## 1.1.0 - 2026-11-05

### Added
- Ag Change, a new land-use transition group: Pasture to Cropland and Cropland to Pasture, from the NLCD class changes, historical and projected.
- Projection Run Settings, "Target areas from": each Target group's projected area is what a historical run realized (gains counted as first-time gains only), instead of the area on the historical maps.
- Projection Allocation method 4, Adjacency: places a group by the share of one class around the cell, from a curve read off the annual maps; Ag Change uses it in both directions, with new Pasture and Cropland state attributes.
- Fire pathways for Developed Open Space and Developed Low Intensity.
- Stage 16, Model Record: a Build's FGDC CSDGM record in its own stage.
- Stage 17, Data Release: writes a USGS data release folder from a Build and its runs, with content checks and a review packet.
- Release Information and People pages for data releases.
- A path to mp (the USGS metadata parser) on the Data Sources page.
- RCMAP can be supplied by hand when ScienceBase refuses a script.
- User Guide Appendix B: the USGS data release workflow, worked on Puget Lowlands.
- Repository files for a USGS software release: code.json, LICENSE.md, DISCLAIMER.md, CHANGELOG.md, CONTRIBUTING.md.
- Stages 16 and 17 in the package blueprint; links between the guide and blueprints are relative.

### Changed
- Historical land-use maps follow the transition pathways: a cell is in a group's map only when the pair (class the model holds, mapped class) is one of that group's pathway pairs, and a change the map reverses within 3 years does not count. On Puget Lowlands every land-use group now lands within 3% of its maps (agriculture contraction had been 6.6 times too large).
- Harvest mapped on cells with no harvest pathway is placed on the nearest eligible forest cells in the same unit; minimum harvest ages are kept. Historical harvest on Puget Lowlands rose from 80% to 87% of mapped.
- The soil organic carbon source is named gNATSGO throughout (it was called gSSURGO in places).
- LOCA2: one file is read per period, the one covering the study window.
- tools/sync-library.R adds new transition types and groups, and makes a Carbon Assumptions scenario only with --carbon-assumptions.
- Stage 16 names whoever runs it, from the scenario's Release Information page.
- Model records cite the copy of each dataset the Build read, and say when it came by hand.
- Stratum Sources page redrawn in the style of the Data Sources page.
- Tests and tools take their locations from the script's folder and environment variables instead of paths on the build machine.

### Fixed
- Carbon Method page: the Fill prompt named the grassland tables by their old sheet names.
- Data Release page: "What to write" was cut off.
- Data Release and Release Information pages: Add a run crashed SyncroSim Studio.

## 1.0.1 - 2026-11-02

### Added
- Metadata definitions, data dictionary and input citations.

### Changed
- Stratum Sources polygons come from Data Download; Federal Lands come from PAD-US 4.0.

### Fixed
- Data Sources defaults no longer name folders on the build machine.
- Metadata citations match what Data Download fetches; ecodivisions cite Bailey.

## 1.0.0 - 2026-11-02

First packaged version: stages 0-15, from study area and strata through growth curves, carbon flows, initial conditions,
historical transitions, climate multipliers, projections, figures and Data Download.
