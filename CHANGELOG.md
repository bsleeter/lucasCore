# Changelog

Changes to lucasCore by version. Version numbers follow [Semantic Versioning](https://semver.org/).

## Unreleased

### Added
- CO2 fertilization of growth in projections (stage 11, to-do 46): the Climate page of a Projection Climate scenario chooses a series
  (None / Low / Central / High, Central by default), an optional CO2 ceiling and reference CO2, and a table of its betas. Growth
  is multiplied by 1 + beta ln(CO2 / the CO2 of the historical end year), with CO2 from the SSP (Meinshausen et al. 2020) and beta by
  vegetation type from a literature review; forest betas mix ECM and AM values by each forest type's ECM share of FIA basal area and
  taper with stand age. New CO2 Flow Multiplier Type; a CO2 Betas table on the page, loaded with the chosen series' defaults for the study area's strata and editable; CO2 Fertilization Betas and CO2 Series results.
  The No Climate projection has no CO2 effect.
- tools/make_co2_ecm_share.R (the ECM shares from the FIA DataMart tree tables) and tools/make_co2_default_betas.R (the table the page loads).

### Changed
- Stage 11 runs when every climate effect is None, for CO2 alone, and copies the Build's flow multipliers into its result when it
  writes CO2 rows.
- Minimum SyncroSim version raised from 3.1.9 to 3.1.29, the version lucasCore is tested on (3.1.9 was never tested). The README
  names the rsyncrosim version tested with (2.1.13).

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
