# Strata and study area sources

- `presets.csv`: every polygon source a library starts with. `tools/new-library.R` writes each as a row of the project's Stratum
  Sources sheet, and fills the stsim Secondary and Tertiary Strata lists with every unit of every source: "<Prefix>: <name>",
  Id = Number x 100,000,000 + the source's own id (src/strata.R). Each scenario then picks, without touching project data:
  - its study area: Study Area sheet, one row per unit of any source (blank = all of CONUS)
  - its secondary and tertiary strata: Build Options (blank = States and Federal Lands, the CONUS 1km model)
- Where the polygons come from (2026-11-02): every preset but FIA Ecodivisions has a blank File and a `DataSource`, the Data Download
  dataset that fetches its polygons into Data Sources Home, national, at the top (study-area/<folder>; src/download-sources.R):
  | Preset | DataSource | Source |
  | --- | --- | --- |
  | States | StatesFile | Census TIGER/Line 2009 tl_2009_us_state |
  | Counties | CountiesFile | Census TIGER/Line 2022 (redistricting) tl_rd22_us_county |
  | HUC6, HUC8 | WatershedsFile | USGS WBD national GDB: its WBDHU6 and WBDHU8 layers, in one GeoPackage |
  | EPA Level III Ecoregions | EcoregionsFile | EPA Level IV ecoregions us_eco_l4_no_st (dissolved to Level III by the preset) |
  | Pyromes | PyromesFile | USFS RDS-2020-0020 Pyromes_CONUS_20200206 |
  | Federal Lands | PadusFile | PAD-US 4.0 state geodatabases: layer federal_fee, the fee land owned by a federal agency or a tribe (Own_Name; tribal = BIA). Until 2026-11-02 the National Atlas fedlanp010g (2014), which the CONUS 1km tertiary strata used |
  | GAP Status | PadusFile | PAD-US 4.0 state geodatabases: layer gap_status (GAP_Sts, no Proclamation boundaries; the most protected status where areas overlap) |

  A File set on the Stratum Sources page wins when it exists on the machine; a blank File, or one the machine lacks (a library made
  on another computer), reads the home (src/strata.R, strata_path). A Data Download fetches these first, since its region is the
  Study Area units' polygons. Before this the presets named files in a folder only the build machine had.
- `huc6-list.csv`, `huc8-list.csv`, `epa-l3-list.csv`, `pyromes-list.csv`: the unit lists of the sources whose names were built from
  their polygons, written by `tools/strata-from-home.R` from the shipped universal list, so a new library needs no polygons.
- `ecodivisions/EcoDivisions_Dissolve.shp`: the dissolved FIA ecodivisions (ECOMAP 2007 divisions; fields ecodiv, StrtmId, StrtmNm),
  shipped because ECOMAP 2025 renumbers the divisions. The FIA Ecodivisions preset points here, and a blank Data Sources:
  Ecodivision File reads it (src/shared.R, PACKAGE_SOURCES). A relative File in presets.csv is read from this folder.
- `ecodivisions-list.csv`: FIA ecodivision names by Id, copied from `defaults/stsim/stsim_Stratum.csv` so the ecodivision units carry
  the primary strata's names (the ecodivision shapefile names Id 2601 both "Mediterranean" and "Mediterranean Mountains").
- `states-list.csv`, `counties-list.csv`, `federal-lands-list.csv`, `gap-status-list.csv`: the names of sources whose polygons do not
  carry them; `*-crosswalk.csv`: text values to ids for sources keyed by a text field.

A custom source: add a Stratum Sources row with an unused Number (10-20) and a Prefix, then run
`tools/new-library.R <library> --rebuild-strata`. Existing unit ids keep their meaning, so scenario data stays valid.
The universal lists hold 6,221 units (2026-10-21): 3,108 counties, 2,413 HUC8, 405 HUC6, 128 pyromes, 85 EPA Level III ecoregions,
49 states, 19 ecodivisions, 9 federal managers, 5 GAP classes.
