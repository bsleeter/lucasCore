# Changelog

Changes to lucasCore by version. Version numbers follow [Semantic Versioning](https://semver.org/).

## 1.1.1 - 2026-11-09

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
