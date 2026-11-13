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
  | National Parks | PadusUnitsFile | PAD-US 4.0 state geodatabases, a GeoPackage of its own (padus4-units.gpkg): layer nps_units, the National Park Service's fee land by unit name (Unit_Nm), mapped to ids by nps-units-crosswalk.csv (added 2026-11-12, user: a single park as the study area; refuges and DoD installations to follow as more layers) |
  | FWS Refuges, DoD Installations, National Forests, Wilderness, BLM National Conservation Lands | PadusUnitsFile | The same GeoPackage, layers fws_units (FWS fee land), dod_units (military installation boundaries: Mang_Name DOD, Des_Tp MIL, which PAD-US keeps as Proclamation boundaries), usfs_units (Forest Service fee land), wilderness (Des_Tp WA, any manager) and blm_ncl (BLM conservation designations), each by Unit_Nm through its own crosswalk (added 2026-11-13, to-do 59). A name the crosswalk leaves out is not read: FWS keeps designation types NWR, NCA and RMA without hatcheries, USFS NF and NG, BLM NM, NCA and WSA |
  | Tribal Lands | TribalLandsFile | Census TIGER/Line 2022 AIANNH, layer tribal_lands of tribal-lands.gpkg: federally recognized reservations and their off-reservation trust land, and state reservations (CLASSFP D2, D3, D4, D5, D8); dissolved by AIANNHCE, the id (added 2026-11-13) |
  | Metropolitan Areas | CountiesFile | The Counties polygons, each county mapped to its metropolitan statistical area (OMB July 2023 delineation) by msa-crosswalk.csv and dissolved; Id = CBSA code (added 2026-11-13) |

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

- `nps-units-list.csv`, `nps-units-crosswalk.csv`: the National Parks units (Id 9999 = Not National Park Service land), written by
  `tools/make_nps_units.R` from the PadusUnitsFile GeoPackage. Ids are stable: a rerun keeps every id and gives new units the next
  ones; names that differ only in accents share one.
- `fws-refuges-*`, `dod-installations-*`, `national-forests-*`, `wilderness-*`, `blm-ncl-*` (list and crosswalk; Id 9999 = none),
  `tribal-lands-list.csv` (Id = AIANNHCE; 99999 = none) and `msa-list.csv`, `msa-crosswalk.csv` (county GEOID to CBSA code; 99999 =
  not in a metro): written by `tools/make_unit_lists.R` from the PadusUnitsFile and TribalLandsFile GeoPackages and the OMB July 2023
  delineation table (list1_2023.xlsx). Ids are stable as for the National Parks. Connecticut: the delineation uses the 2022 planning
  regions, the Counties preset the old counties; each old county takes the metro of the planning region holding most of it
  (Litchfield and Windham are not in a metro; Waterbury-Shelton has no county of its own and is not listed).

A custom source: add a Stratum Sources row with an unused Number (18-20; 1-17 are the presets) and a Prefix, then run
`tools/new-library.R <library> --rebuild-strata`. Existing unit ids keep their meaning, so scenario data stays valid.
The universal lists hold 10,235 units (2026-11-13): 3,108 counties, 2,413 HUC8, 405 HUC6, 128 pyromes, 85 EPA Level III ecoregions,
49 states, 19 ecodivisions, 9 federal managers, 5 GAP classes, 385 National Park units, 717 FWS refuges, 677 DoD installations,
172 national forests and grasslands, 802 wilderness areas, 334 tribal lands, 538 BLM National Conservation Lands units and 382
metropolitan areas (each source also lists its "none" unit).
