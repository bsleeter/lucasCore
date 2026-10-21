# Strata and study area sources

- `presets.csv`: every polygon source a library starts with. `tools/new-library.R` writes each as a row of the project's Stratum
  Sources sheet, and fills the stsim Secondary and Tertiary Strata lists with every unit of every source: "<Prefix>: <name>",
  Id = Number x 100,000,000 + the source's own id (src/strata.R). Each scenario then picks, without touching project data:
  - its study area: Study Area sheet, one row per unit of any source (blank = all of CONUS)
  - its secondary and tertiary strata: Build Options (blank = States and Federal Lands, the CONUS 1km model)
- `ecodivisions-list.csv`: FIA ecodivision names by Id, copied from `defaults/stsim/stsim_Stratum.csv` so the ecodivision units carry
  the primary strata's names (the ecodivision shapefile names Id 2601 both "Mediterranean" and "Mediterranean Mountains").
- `states-list.csv`, `counties-list.csv`, `federal-lands-list.csv`, `gap-status-list.csv`: the names of sources whose polygons do not
  carry them; `*-crosswalk.csv`: text values to ids for sources keyed by a text field.

A custom source: add a Stratum Sources row with an unused Number (10-20) and a Prefix, then run
`tools/new-library.R <library> --rebuild-strata`. Existing unit ids keep their meaning, so scenario data stays valid.
The universal lists hold 6,221 units (2026-10-21): 3,108 counties, 2,413 HUC8, 405 HUC6, 128 pyromes, 85 EPA Level III ecoregions,
49 states, 19 ecodivisions, 9 federal managers, 5 GAP classes.
