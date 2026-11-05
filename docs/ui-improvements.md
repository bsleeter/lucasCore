# UI improvements

Ideas for the lucasCore pages in SyncroSim Studio, collected during the P26 user-guide walkthrough. Newest last.

## Priorities (2026-11-02)

The open items in order. Item numbers are ids and do not change; this table is the order. The rule from 2026-10-25 still holds: items
that change the model itself (its inputs or results) come first, and anything built on P26's results (metadata, the
guide's numbers and figures) after them, so it is redone only once. Within that, quick usability fixes go first.

| Order | Item | Changes results? | Why here | Depends on |
| --- | --- | --- | --- | --- |
| ~~1~~ | ~~22 Automatic spatial tiles~~ DONE 2026-10-29 | No | Small and self-contained; users otherwise need to know the region to pick Tiles | - |
| ~~2~~ | ~~35 TreeMap: forest type, stand age, site productivity (with 10)~~ DONE 2026-10-30 | Yes, as options (off by default) | Code, pages, figure, tests and P26 sync done | - |
| ~~3~~ | ~~34 Minimum harvest ages~~ DONE 2026-10-30 | Yes (projections; stage 6 start ages) | FIA values lowered to the study area's mapped cuts; selection at least 10 yr under clearcut | 35's age source |
| ~~1~~ | ~~32 Carbon open science issues~~ DONE 2026-10-30 | Yes | Stem turnover fitted to FIA background mortality (snags now match); duff bound harmless; California event shares hold nationally | - |
| ~~1~~ | ~~37 P26 rerun and guide refresh~~ DONE 2026-10-31 | Its own results | Build [53], Historical [54], projections [65]-[67], Compare [71]; guide numbers, figures and grabs; GitHub snapshot rebuilt | 34, 32 |
| ~~5~~ | ~~12 Data Download stage~~ DONE 2026-11-02 | No (P26 from downloaded data matches [53] where the data are the same) | Phases 1-6, region folders, write-once, editions, national paths; guide 1.6 and blueprints | 35 |
| 1 | 14 FGDC metadata | No | User order 2026-11-02: first. Plan (a working document, not in this repository) (phases 0-6; decisions settled 2026-11-02: CSDGM first, one release per Build, maps every year, model archive always, ScienceBase folder by hand; Phase 0 done with the user 2026-11-02; Phase 1 built 2026-11-02: defaults/metadata definitions, data dictionary, citations, src/metadata.R, tests/unit-metadata-definitions.R; citation questions in the plan); lineage from the home's manifest and each Build's Data Sources Used | 12 (done) |
| 3 | 39 Grassland, shrubland and wetland carbon: options beyond today's crude method | Yes | User order 2026-11-02: third, with the other open science items (user: explore additional options).  Step 1 (rates on a page) and the diagram view done; the diagram shows emergent wetland rates settling far above their starting pools; suspect values (emergent wetland growth 31, irrigated grass 9.19 Mg C/ha/yr), root turnover splits; the science options (user to decide) | - |
| open science, user to place | 46 CO2 fertilization | Yes, as an option (off by default) | Added 2026-11-04. Growth has no CO2 response, and its size is similar to the climate penalty in the projections | - |
| 3 | 43 Historical harvest 12% short: minimum ages in the historical period | Yes (historical harvest, start ages) | Options offered 2026-10-31, user to decide: apply the minimum ages only in projections, or resample start ages from the median | 34 |
| 4 | 42 Fill prompt names the grassland tables by their old names | No | A wording fix in the Carbon Method page | - |
| ~~any~~ | ~~45 Stratum Sources polygons from Data Download~~ DONE 2026-11-02 | No | Others could not run stage 1 | 12 |
| later | 47 Example libraries by region and resolution | No (each holds its own results) | Added 2026-11-04, replaces 13. Best built after the open science items, since each carbon change dates them | 14, restore test |
| any | 48 Say gNATSGO, not gSSURGO, throughout the package | No numbers, some text in outputs | Added 2026-11-04. Best before a data release, since the wording reaches run logs and the SoilSource column | - |
| any | 49 Test national mode end to end | No | Added 2026-11-04. Never run end to end; fills about 175 GB overnight | 12 (done) |

Done since the 2026-10-25 order: 6, 7, 8, 9, 11a, 12, 15-25, 28-30, 32, 34, 35, 37, 40, 41 (item 27 removed by the user; item 13, the Calaveras demo bundle, removed by the user 2026-11-04; which library serves as the demo is undecided, not Puget, which has no fire, and the user will come back to it; items 26, 31, 33, 36, 38 and 44 removed by the user 2026-11-04, their text is in git history).
Pushed: everything through the v1.0.1 release (2026-11-02: strata polygons and no build-machine paths; v1.0.0 the same day); the repo is public, so push only when the user asks.

1. **Data Sources page** - DONE 2026-10-24. Custom view (`ui/DataSourcesView.cs`) groups the paths by category (study area, land
   cover, forest inventory, disturbance and fire, climate, soils and terrain, infrastructure and ownership), links each to its download
   page, adds a Browse button and a found/missing mark per path. Categories, dataset names and links: `defaults/library/data-sources.csv`.
   Datasets in the USFS Research Data Archive link to the archive and name their RDS id; deep links still to add.
2. **Data Sources: show the default paths** - DONE 2026-10-23. LibrarySetup writes the package's default paths into a new project
   (`defaults/library/project/lucasCore_DataSource.csv`).
3. **Build Options: rename "Run a projection"** - DONE 2026-10-24, by removing it: the projection end year is in Projection > Run
   Settings, and the Build no longer knows about projections.
4. **A projection's climate was fixed in the Build** - DONE 2026-10-24. Stage 7 is historical only; stage 11 (Projection Climate)
   makes the LOCA2 multipliers in its own scenario on the Build result, and projections depend on it after the Projection Setup
   (`tools/new-projection-climate.R`, `tools/new-projection.R --climate`).
5. **Every custom page: wrap and scroll** - DONE 2026-10-24. `Fit` (ui/LucasView.cs) sets every wrapping label and row to the width the
   window leaves it, on every resize; pages scroll vertically. Build Options and Data Sources use it too. The Study Area unit picker
   already filled its window.
6. **Build Figures in Studio's Images viewer** - DONE 2026-10-29, differently: not the Images layout but a figure viewer page
   (`ui/FigureView.cs`) on Build Figures, Run Figures and Compare Figures - a drop-down of figures, Previous/Next and arrow keys, the
   PNG fitted to the page, its caption, Open full size, Save as, Save all; stays enabled on result scenarios. Guide 9.1. Original plan: Stage 12's PNGs are only a table of files (Build Results > Build Figures) plus a
   folder export. SyncroSim 3.1 has an Images viewer (Add Image, side by side, across scenarios) fed by a package `<layout type="Image">`;
   no installed package uses it, so the shape comes from the Map layout and SyncroSim's own strings. Likely needs: a project lookup
   "Build Figure" (the 17 titles, as package `<record>`s), a BuildFigureId filter column plus Iteration/Timestep on OutputBuildFigure
   (stage 12 writes 1 and the start year), the Image layout with one filtered item, and sync-library filling the lookup in existing
   libraries (stages cannot write project sheets). Verify in Studio on the Placer test library: layout errors do not show in the console.
7. **Spatial multiprocessing chosen in the Build** - DONE 2026-10-26, pages checked in Studio (user chose stage 9's packing: units packed into N tiles of
   about equal area). Build Options has Spatial Tiles (count) and Spatial Tiles Strata (level), on the Build Options page's "Spatial
   multiprocessing" group; stage 1 writes the mask (Build-Tiles.tif) into the Build result's core_SpatialMultiprocessing, so the
   historical run and projections inherit it. Packing is `pack_tiles` in shared.R (stage 9 uses it too; it reproduces P26 Setup
   [17]'s 5-tile mask exactly). Run Settings: blank tiles follow the Build (stage 9 sets Target strata to the Build's level and
   writes the same mask); its own count/level override; unticked with a tiled Build = 1 = a one-tile mask, so the projection runs as
   one job. Existing Builds get tiles by re-running the Build (stage 1 writes them; a result holds only what its run wrote), or keep using Run Settings' own tiles. Test:
   tests/phaseW2-build-tiles.R. Guide 1.4 still to update. Original design note: A spatial run is split
   only by System > Spatial Multiprocessing, a tile mask raster (ST-Sim's "Split by Secondary Strata" is for non-spatial runs). Today
   a user must find a mask in the Build result's `.data` folder or rely on stage 9's projection tiles. Planned:
   - Build Options: a checkbox **Enable spatial multiprocessing**, then a selector of the strata level the tiles follow (Primary,
     Secondary or Tertiary, from the Build's own strata; P26 would use Secondary = Counties).
   - The Build writes the mask (whole units of that level) into its result's core_SpatialMultiprocessing, so the historical run and
     every projection on the Build inherit it with nothing to browse to.
   - **Rule: Transition Targets must use the same strata level**, or a target unit split between tiles no longer adds up. The Build
     records the level; stage 9 (Projection Setup) sets every Target group's strata to it, as its Spatial Tiles option already does,
     and the Projection Transitions page shows the level as fixed when tiles are on. Historical runs use spatial multipliers, not
     targets, so they are unaffected.
   - Open: one tile per unit (simple; 17 uneven county jobs for P26) or units packed into N tiles of about equal area (stage 9's
     balancing code, moved to shared.R). Projection Options' Spatial Tiles fields would then default to the Build's choice.
   - Guide: section 1.4 says to leave library multiprocessing off (right for Builds); tiled runs need it on, with jobs ~ tiles.
8. **Area-preserving resampling of land cover** - DONE 2026-10-26 (marked complete by the user), built as a choice (page checked in Studio) (user: "pick either method from the Build menu").
   Build Options: Land Cover Resampling = Modal (default; blank in older Builds) or Area-matched (every class matched to its 30 m area
   per secondary stratum unit, developed additions only: 06-match-all.R's method, now `src/landcover-match.R`; reproduces its P26
   maps cell for cell, 1.7 min for 39 years). Stage 5 counts each class's 30 m pixels per cell (parallel over years), matches the
   years in order and writes the matched maps as the annual NLCD, so state classes and stage 6/9/10 transitions all follow them; it
   logs the area in the wrong class (matched vs modal) and checks that developed land never reverts. Test:
   tests/phaseZ4-landcover-resampling.R. Still open: a full P26 Build + historical run with Area-matched to compare carbon,
   transitions and figures; the state class splits within NLCD classes (forest type, shrub/grass, wetland types) are still modal.
   Exploration notes (2026-10-25): Best method:
   **area matching per county with additions only** (1985: each county's cells with the largest developed shares become developed until
   its 30 m area is met; later years add the next-largest shares, never remove). P26: developed 876 km2 in 1985 (100% of 30 m; modal
   31%), net growth 105% of 30 m, no flicker (modal loses 230 km2), intensity classes close to 30 m; initial carbon -4.4 Tg C (-0.9%);
   urbanization rate 6.4 km2/yr instead of 7.8. Every year-by-year threshold flickers; "stays developed" variants inflate growth.
   **All classes matched** (user, 2026-10-25: match every class): developed as above, then every other class balanced to its county
   30 m area, each year from the year before. Area in the wrong class 997 -> 28 km2 (1985), mean 1,078 -> 47 km2 over 1985-2023; every
   class within 0-2% of 30 m; reversals 917 -> 183 km2; initial carbon -8.0 Tg C (-1.65%, modal's 990 km2 forest surplus removed).
   Gross change follows county net change (offsetting changes cancel). Next: decide; match the state class splits (EVT forest type,
   RCMAP, C-CAP) within each NLCD class the same way; choose the matching unit (item 7); then a full P26 Build + historical run test.
   Original note (user, 2026-10-24: accept the modal undercount for now). The 150 m modal
   NLCD keeps 31% of P26's 30 m developed area (22% of open space 21, 49% of low 22, 72% of medium/high): 79% of developed pixels lie in
   cells under half developed, mostly single-pixel roads (5 of a cell's 25 pixels). It also makes developed cells flicker year to year.
   Options to test: class-priority or threshold rules (a cell is developed above some fraction), area-matching allocation (rank cells by
   fraction until the 30 m area is met), or a finer grid. Each must keep the state class map and the transitions derived from the same
   maps ([[coherence over area]]), and be judged on carbon as well as area.
9. **FIA plot data instead of the prebuilt USGS tables** - DONE 2026-10-26 (46a42a2; ac74e26 CONUS check: 99.99% of the USGS
   conditions, live carbon and volume 99-100%; stage 2 curves within 1% at the median). Growth Curve Options > FIA Data = FIA DataMart
   (state CSVs), read by src/fia.R with a cache (fia-conditions.rds) and 48 state down dead factors; stages 2 and 3 both use it, and
   the measured dead wood calibration (19) reads COND_DWM_CALC from the same folder. The P26 guide Build uses DataMart. The package
   default stays the USGS .Rds (FiaSource 1), user decision 2026-10-29. Original request (user, 2026-10-25). Stages 2-4 fit growth curves, carbon parameters
   and decay calibration from two condition-level tables the user supplied (Data Sources: FIA Condition Carbon and Merchantable Volume,
   `USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds`, and FIA Condition Disturbance and Treatment Codes,
   `USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds`). Another user has no such files. Planned: read the FIA DataMart directly
   (the state COND, PLOT and TREE tables, or FIADB SQLite), filtered to the study area's states and the inventory years, and derive the
   same fields the .Rds tables carry (condition carbon by pool, merchantable volume, stand age, forest type group, DSTRBCD/TRTCD). Keep the
   .Rds route as an option, and check that the derived tables reproduce its P26 and CONUS curves before switching the default.
10. **TreeMap for forest type group and stand age** - TO DO (user, 2026-10-25; PLANNED 2026-10-29 together with site productivity: see item 35 and docs/treemap-plan.md). Today the forest type comes from LANDFIRE EVT or the USFS
   NFCMS forest type group maps (Build Options: Forest Type Map), and stand age from NASA CMS Forest Age 1990 (Data Sources:
   StandAgeFile). Add TreeMap (USFS, 30 m imputed FIA plots; its plot IDs carry FORTYPCD and stand age) as a third Forest Type Map
   option and as a stand age source, so type and age come from one consistent map. Needs: a Data Sources path for the TreeMap raster
   and its attribute table, a FORTYPCD -> forest type group crosswalk (defaults/growth/forest-type-crosswalk.csv may cover it), the
   vintage (TreeMap 2016 / 2020 / 2022) set against the Build's start year, and a comparison with EVT/NFCMS and CMS age on P26.
   **Progress 2026-10-26:** TreeMap 2016 (RDS-2021-0074) is in Data Sources/TreeMap/Data. Its attribute table has the plot visit (CN =
   FIA PLT_CN) and FORTYPCD but **no stand age**: age comes from FIA DataMart COND (item 9's files) by PLT_CN, the forested condition
   matching TreeMap's FORTYPCD, else the largest. dev/treemap/01-p26-compare.R on P26 (with 31 states' COND joined, 82% of pixels):
   forest type agrees with the Build's USFS forest type groups on 61% of forest cells (EVT 69%; TreeMap = EVT 74%); TreeMap adds a
   Douglas-fir group (4% of P26 forest) that neither has. 1985 age: median 81 vs CMS 73, mean 89 vs 81, but cell-by-cell correlation
   0.07. The user expects initial age to be an important source of uncertainty, so stand age becomes a **Stand Age Source** choice:
   NASA CMS 1990 (today), TreeMap, and **GAMI** (user's choice for the third option, 2026-10-26): Global Age Mapping Integration v2.0,
   Besnard et al., GFZ Data Services doi 10.5880/GFZ.1.4.2023.006, 100 m forest age for 2010 and 2020 from >40,000 inventory plots,
   biomass/height and Landsat disturbance history, with 20 realizations (an uncertainty range for initial age). GFZ's server refused
   connections on 2026-10-26; file list and sizes still to get. Next: a three-way P26 comparison (CMS, TreeMap, GAMI) and the first-order
   change in 1985 carbon from each, then the Build Options choice in stage 5.
   **Fourth option, stand age inferred from biomass + disturbance history (user's idea, 2026-10-26).** Invert each cell's live carbon
   curve (stage 2, forest type x ecodivision) at its mapped live carbon at the map date T, then shift to the start year; cells disturbed
   between the start year and T (MTBS stand-replacing fire, LCMS / LANDFIRE harvest and clearing) are young at T because of a
   disturbance the model simulates itself, so their start-year age comes from elsewhere (undisturbed neighbours, or FIA's age
   distribution for the type). Limits: near the curve's asymptote carbon no longer identifies age (cap and draw old ages from FIA's
   distribution); the curves are type x ecodivision means, so inferred age partly measures site productivity (for a carbon model
   partly a feature: the start-year live carbon matches the map by construction); per-pixel biomass errors of 30-50% become large age
   errors on the steep part of the curve; TreeMap's carbon layer is not independent of its age. Candidate map: **NBCD 2000** (NACP
   Aboveground Biomass and Carbon Baseline Data V2, Kellndorfer et al. 2013, ORNL DAAC doi 10.3334/ORNLDAAC/1161): CONUS circa 2000 at
   30 m (canopy height, live aboveground dry biomass, carbon stock), 66 mapping zones of six GeoTIFFs each plus a 240 m CONUS biomass
   mosaic and a zone shapefile; V2 adds shrubland (NLCD 52). T = 2000 keeps the shift to 1985 at 15 years. The data folder needs a NASA
   Earthdata login (the user downloads the P26 zones; file sizes and P26's zone numbers still to find from the zone shapefile).
   Alternatives: ESA CCI Biomass (100 m, 2010, 2017-2021, with per-pixel uncertainty). Test on P26 in dev/: inferred ages against CMS,
   TreeMap, GAMI and, most usefully, FIA plot ages at the plots' (fuzzed) locations from the DataMart files; if it holds up, it becomes
   Stand Age Source = Inferred from biomass.
   **NFCMS carbon products** (the source of the NFCMS forest type and productivity tiles and the CMS age maps already in Data
   Sources): (a) NFCMS 1990-2010, ORNL DAAC doi 10.3334/ORNLDAAC/1829 (Williams, Hasler et al.): 30 m aboveground woody biomass, total
   live biomass, total ecosystem carbon, coarse woody debris and NEP for 1990, 2000, 2010, plus its inputs (disturbance year and type
   from NAFD and MTBS, years since stand-replacing disturbance = its stand age, NBCD 2000 biomass, forest type group, productivity
   class); carbon from an inventory-constrained CASA model starting from NBCD 2000. 207 GeoTIFFs, 118.9 GB CONUS (only the PSW region's
   1990 layers needed for P26); NASA-hosted, probably an Earthdata login. (b) NFCMS v3.0, USFS RDS-2025-0019: 30 m forest extent,
   type and carbon stocks with a 2020 baseline (t CO2e/acre), 1990-2020 conversion, projections to 2050 and 2070; regional maps plus a
   CONUS mosaic, no login. Uses: NFCMS 1990 total live biomass / total ecosystem carbon as an **independent check of the Build's initial
   carbon** (cell by cell and in total, whatever the age source), and a 1990 biomass map for the inference above (5-year shift). Since
   NFCMS itself already combines NBCD biomass with disturbance history, inverting lucasCore's own curves mainly buys consistency with
   the model's curves; the P26 test shows how much the ages change.
11. **LOCA2 climate: scan the user's folder, or download** - (a) DONE 2026-10-26, verified in Studio by the user; (b) the download part moves to
   item 12. `ui/Loca2Lists.cs` scans Data Sources: LOCA2 Folder by new-library.R's rule (a member counts when its historical folder
   and at least one SSP folder each hold pr, tasmax and tasmin `*.monthly.nc`). LibrarySetup fills a new project's three lists from
   the scan, falling back to the shipped CSVs when the folder is missing or empty (its Detail says which). Projection Climate has a
   **Rescan LOCA2 folder** button: rows are matched by name, new runs added, rows whose runs are gone kept and marked "none found in
   the LOCA2 folder" (a scenario may point at them; their models drop out of the page's lists). Checked outside Studio: the scan of
   the developer's folder reproduces the shipped CSVs exactly; incomplete members are skipped. Original note (user, 2026-10-25): The project's Climate Scenarios, Models and
   Replicates lists in a Studio library come from fixed CSVs (defaults/library/project/lucasCore_Climate*.csv, exported from the
   developer's LOCA2 folder: 3 SSPs, 10 models, 6 members), so the Projection Climate page can offer runs a user lacks and hides runs
   they add. tools/new-library.R already scans `<gcm>/<member>/<ssp>/{pr,tasmax,tasmin}/*.monthly.nc`; stage 11 already fails with
   the runs that do exist. Planned: (a) LibrarySetup scans Data Sources: LOCA2 Folder when the library is made (fallback: the shipped
   CSVs) and a "Refresh LOCA2 lists" action rescans later; (b) a download tool: the user picks SSPs, models and members (or "the 10
   used by default"), it fetches only the monthly pr/tasmax/tasmin files for the study area's extent from the LOCA2 archive (UCSD; URL and access
   method to confirm), writes them in that folder layout, then refreshes the lists. Size, resumable downloads and a checksum matter;
   the full CONUS monthly set is large.
12. **Data Download stage: fetch the Data Sources for a region** - DONE 2026-11-02 (all pushed, through 2967086). PHASE 6: P26 from
   nothing, Build result 13 in dev/libs/"LUCAS P26 Northern Sierra Nevada Data Download.ssim": 74/74 checks, 44 min vs 57 for [53];
   NLCD, ever-forest, wetland, harvest and NLCD transitions identical to [53] after the grid_blocks fix (blocks were anchored on each
   file's own extent); the rest differ only where the data changed (NFCMS v3, published RCMAP, gNATSGO, newer FIA). HOME LAYOUT
   (user: a second region must never overwrite the data another library read): By region writes regions/<name> (name from the Study
   Area units), FIA, PRISM, LOCA2 and FPA-FOD whole at the top; write-once through staging; a Build reads each blank dataset from the
   smallest region whose manifest covers its study area; the download buffer is at least a Counties/States modal fill distance + 1 km;
   tools/data-home.R --to-region moved the P26 home. EDITIONS (user rule: a library keeps the edition it first read): Fetch new
   editions puts a new version in <folder>/editions/<tag>/; the project's Data Source Editions sheet, set only on the Data Sources
   page, picks it. NATIONAL PATHS: MRLC NLCD zips, LANDFIRE full-extent zips, all gNATSGO tiles (a national home is about 175 GB,
   overnight). Also: Data Sources Used output (every Build stage: datasets read, where from, checksums); NLCD WCS tile corners fixed
   (a thin last tile row landed a row high); the Data Sources page finds regions and shows marks whole; dataset rows on the Data
   Download page say how each comes and its P26 size; LOCA2 Rescan reads the home. Guide section 1.6 (Figures 1.15-1.21) and both
   blueprints updated. Plans: (a working document, not in this repository). History below.
   PLANNED 2026-10-31: implementation plan at
   (a working document, not in this repository) (every one of the 27 Data Sources researched: 10 clipped by the source - NLCD WCS,
   LANDFIRE LFPS, NIFC REST, C-CAP and gNATSGO windowed reads; 12 whole files clipped after; 1 Earthdata login; 4 with no public
   source - EVT 2001, the RCMAP class map, the two USGS FIA tables). Phase 1 fixes package problems the research found: NLCD now
   published only as C1V2 (code hard-codes C1V0), PRISM normals renamed, NIFC field FIRE_YEAR_INT, wrong FSim id and forest type group
   link in data-sources.csv, ECOMAP 2025 renumbers the divisions (ship the 2007 file). PHASE 1 DONE 2026-10-31: shared.R nlcd_file (C1V0 first, else C1V2),
   read_fire_perimeters (FIRE_YEAR_INT or FIRE_YEAR_, 9999 dropped; stages 8, 9, 10), growth.R prism_normal (legacy .bil, else
   prism_<var>_us_25m_<yyyy>_avg_30y); the ecodivisions ship in defaults/strata/ecodivisions (blank EcodivisionFile = the package copy,
   presets.csv relative); data-sources.csv gained Access (package/service/file/login/user), DatasetId, Version and Doi, with the
   FSim id (RDS-2016-0034-3) and forest type link (NFCMS v3, RDS-2025-0019) corrected; the page marks user-supplied rows. Existing
   files resolve exactly as before (plain-R tests). PHASE 2 CODE DONE 2026-10-31: src/datahome.R (home places from data-sources.csv
   HomePath, home_create, manifest.csv / files.csv readers and writers, manifest_covers), read_data_sources reads a blank path's home
   place before the package.xml default (optional = TRUE for NCCPI), defaults/download/endpoints.csv (method, clip, login, endpoint,
   product, size per source), tools/data-home.R (check or --create a home folder), and the Data Sources page's home row (Browse, Make
   folders, "✓ home" marks, manifest status). A hand-laid home of links (dev/libs/home-test) finds 26 of 27 (NCCPI is fetched). The
   DataSourcesHome column went into package.xml the same day; P26 (guide), P26 Demo, lucasCore-suitability and the two sync references
   were synced with sync-library --columns-only (reference dev/libs/schema-ref-20261031.ssim); the older dev libraries were already
   20-40 columns behind and were left. PHASE 3 (2026-10-31): stage 15 Data Download (src/15-data-download.R, engine src/download.R,
   handlers src/download-sources.R, page ui/DataDownloadView.cs, tools/new-data-download.R; sync-library --schema-only adds the
   stage). 11 sources: NFCMS v3 forest types, TreeMap, FSim, LCMS and forest ownership are read inside their remote zips (GDAL
   /vsizip//vsicurl/) and only the region is written; FIA DataMart (48 states), MTBS (ScienceBase), FPA-FOD, PRISM (HTTP mirror;
   the web service blocks repeats), LOCA2 (UCSD west regional cut, member per model) and SILVIS WUI (states touched) are fetched,
   resumed and clipped. P26 Check only: about 5.2 GB to fetch. The legacy PRISM 4 km normals are gone (current normals only), and
   NFCMS v3 ships no .vat.dbf. TESTED: plain R, P26 2019-2020 into an empty home: FSim, forest ownership, LCMS, MTBS,
   TreeMap (and its .vat.dbf) and PRISM identical to the build machine's files over the region; NFCMS v3 differs from the local tiles
   on 8.7% of PSW cells (the newer edition: a Build on "USFS forest type groups" from a download would change); a rerun skipped all
   11. TreeMap is fetched whole (5.4 GB in about 90 s): its remote read broke. Through SyncroSim (dev/libs/download-test.ssim):
   Check only for P26 (about 18 GB with the full LOCA2 model list), a real run and a rerun that skipped. LOCA2 PICKER (2026-11-01,
   user: typed model names were a problem): defaults/download/loca2-catalog.csv (tools/loca2-catalog.R crawls UCSD: 27 models, 108
   model-members, 329 runs) gives the page ticks for scenarios, models and the members the ticked models have; same three columns.
   ACCESS-ESM1-5, CanESM5 and MPI-ESM1-2-LR have no monthly files in the west cut, so their runs come from the CONUS tree. Defaults:
   one LOCA2 run; a rerun asking for more runs or years (handlers with have()) fetches only the missing files. PHASE 4 (2026-11-01;
   user decisions: NLCD C1V2 for all years, gNATSGO soc0_999 for soil carbon, LFPS jobs with an email): ten datasets clipped by their
   source, each needing a Study Area: NLCD by WCS 1.0.0 tiles on the 30 m grid; EVT 2016, FRI, elevation, roads and disturbance by
   LFPS jobs (Output_Projection=5070 + 30 m = LANDFIRE's own grid; without it LFPS reprojects to an Albers centred on the box); the
   disturbance attribute tables ship in defaults/landfire/disturbance (LFPS returns none); the email lives in the home folder's
   settings.csv (page box under How), not in the scenario, so no schema change; fire perimeters from the six NIFC decade services
   (the All Years View now holds only 342 perimeters from 2020 on); C-CAP read in place (COG); gNATSGO soil carbon and NCCPI from
   Planetary Computer 10 m tiles. TESTED P26 into an empty home (about 12 min): C-CAP, EVT, FRI, elevation, roads and disturbance
   2019-20 identical to the build machine's files; NLCD 2019 C1V2 vs C1V0 differs on 0.001% of cells; gNATSGO vs gSSURGO equal on
   93% of shared cells (r 0.98; gSSURGO's extra 7% are zeros, which stage 5 treats as missing); perimeters 11,668 vs 10,783 (a newer
   edition: years differ both ways, 2024 added); a rerun skipped all ten. PHASE 5 (2026-11-01): coverage checks: read_data_sources
   remembers the datasets it took from the home folder and each Build stage (1, 5-10) calls home_coverage(<its grid>) once; a home
   dataset whose manifest region does not hold the grid (less one cell) stops the stage naming the dataset, the region it was
   downloaded for and what to do; hand-placed files (no manifest row) and set paths are not checked; stage 10 also checks its fitting
   region; stage 9's FPA-FOD kernel reach (3 x bandwidth, past the 10 km default buffer) only warns. NASA CMS forest age: the 1990
   FIA-region tiles touching the region (boxes from NASA CMR), an Earthdata token (EARTHDATA_TOKEN, else the page's masked box,
   kept in settings.csv) sent with the first request only, the signed redirect fetched resumably, checked against the DAAC sha256,
   clipped and mosaicked; no token = "needs login", not a failure. TESTED: unit test of the check (P26 passes, P26 + 20 km and P29
   stop, hand-placed passes); stage 1 in dev/libs/download-test2.ssim on P29 and Placer stops with the message, on P26 passes the
   check; stage 15 without a token marks stand age "needs login"; with the user's token (2026-11-01, download-test.ssim scenario 9)
   4 tiles (PSW, RMN, RMS, PNW; 1.6 GB in 19 s) passed sha256 and the P26 mosaic is identical to the build machine's cms_age_1990.tif
   on all 37.6 million cells (INT2U as NASA ships it; the local copy is FLT4S). DATA DECISIONS (user, 2026-11-01, all as recommended): forest ownership stays circa 2017 until a crosswalk to the 2022 classes is built and tested; NFCMS v3 accepted (the only edition), TreeMap stays 2016 (2022 offered later, tested on P26); national copies deleted after clipping (Keep national copies ticks them back); NIFC decade-service perimeters accepted (edition in the manifest); LANDFIRE disturbance 2023 and 2025 keep the provisional tables (codes match the final rasters; 2025 final table is the same text; no final 2023 table is published); the two USGS FIA tables stay user-supplied. EVT 2001 AND RCMAP (user, 2026-11-01: "stick to published and available data"): EVT 2001 removed (Evt2001File hidden, its crosswalk rows and source CSV gone; "EVT 2001 (retired)" keeps its list position); Forest Type Map 1 = LANDFIRE EVT with the 2016 gaps (not forest, incl. recently disturbed) from the cell's other pixels, else neighbours; new 4 = gaps from the USFS forest type groups (P26 ever-forest cells: 95-96% keep the EVT 2001-based type either way; Placer stage 5 runs: options 1 and 4 agree on 97.7% of forest cells). RCMAP = USGS's published 1985 vegetation state (Rigge et al. 2025, Ecological Potential ver. 2.0, doi 10.5066/P13OMU52; same 11 classes as the unpublished 2001 "test2" prototype it replaces), package default <Data Sources>/RCMAP/1985_vegetation_state; downloaded whole (883 MB) and clipped (P26 clip identical to the published file); western US only, so outside it the download says "not needed" and stage 5 takes grass/shrub types from NLCD. TO DO (design agreed with the user,
   2026-10-25; not started).
   Supersedes the download half of item 11 (LOCA2 becomes one dataset here; 11's list scan/refresh stays). Today the Data Sources page
   (ui/DataSourcesView.cs) links each dataset's download PAGE (defaults/library/data-sources.csv: landfire.gov/data, mrlc.gov/data,
   the USFS archive index, ...), and the user fetches and points to every file by hand.
   - **Its own stage in its own scenario** ("Data Download"), not part of the Build pipeline: SyncroSim's run machinery gives progress,
     run log, Stop and the Run Monitor for downloads that take hours, and it does not tie up Studio. Run once per region; one download
     serves many Builds (download California, build P26, P29, ...). Rerunning skips complete datasets and resumes partial files.
   - **Region**: reuse the Study Area page (kind of unit + units) on the download scenario, plus a buffer (Data Download option, e.g.
     5-10 km) for neighbourhood and edge effects (adjacency, distance to roads, perimeters crossing the boundary). The download region
     does NOT have to match a Build's study area, only contain it.
   - **Containment check**: the stage writes a manifest in the home folder (download extent, per-dataset source, vintage, clipped or
     national, date, size/checksum). Stage 1 checks the Build's study area, and stage 10 its Suitability Fitting Region, and the fire
     stages (6, 9) the pyromes they use, against it, and fail with a clear message ("the download covers California; P26's fitting
     region extends into Nevada"). Datasets downloaded whole (national) always pass.
   - **Paths: home folder convention** (chosen over a dependency-supplied paths sheet, because stages cannot write project sheets and
     Data Sources is a project sheet): Data Sources gains a **Data Sources Home** field; a blank path resolves to `<home>\<standard
     subfolder>` (read_data_sources and the view's found/missing marks), and the stage writes exactly that layout. No paths need filling
     in; the red crosses turn green when the files exist. (Alternative kept in reserve: the stage writes a scenario-level paths sheet
     into its result and a Build that depends on it uses those paths over the project's - more flexible, but a dependency on every Build.)
   - **Per-dataset download method** (a manifest replacing the page links): direct file/zip (MTBS mosaics, FPA-FOD, FSim, forest
     ownership, FIA DataMart tables); web service clipped to the region (LANDFIRE LFPS for EVT, disturbance, FRI, elevation, roads; NIFC
     perimeters via ArcGIS REST; PRISM web service; gNATSGO NCCPI via the Planetary Computer STAC; LOCA2 with a picker for SSPs, models
     and members - pr/tasmax/tasmin monthly only); login required (NASA CMS stand age at ORNL DAAC needs an Earthdata account: the user
     signs in, the stage never handles credentials); manual (gSSURGO, the USFS forest type raster gateway may stay links). URLs and
     access methods to confirm for each.
   - **Output table** (Data Download result): dataset, source, vintage, clipped or national, extent, files, size, status (done / skipped /
     needs a manual step and where).
   - **Robustness**: resumable downloads, size or checksum checks so a half-finished file never counts as present, clear messages for
     login/manual datasets. CONUS-wide sets are tens to hundreds of GB; clipping is the default wherever a service allows it.
   - Downloads and clipping in R (terra, as the stages already do), so it is an ordinary Rscript stage.
14. **FGDC metadata for the model and its outputs** - PLANNED 2026-10-31 as a metadata and data release generator following USGS
   FSP (SM 502.7 and 502.8 as reissued 2026-06-01): implementation plan at (a working document, not in this repository) (one
   content model, CSDGM writer, model record, stage 15 Data Release, Release Information page, mp and content checks, review packet,
   phases 0-6 ending in a P26 trial release; decisions settled 2026-11-02 (CSDGM first, one release per Build, maps every year, archive always, ScienceBase by hand); Data Release is stage 17; Phase 0 needs the Center data manager).
   Phase 1 (definitions, data dictionary, citations) done 2026-11-02. Phase 2 (model record) done 2026-11-02: `src/metadata-record.R`
   (facts from a Build result, the content model, the CSDGM writer, mp), `tools/model-record.R "<library>" --build=<id>`, record defaults,
   keywords and Use Constraints notes in `defaults/metadata`, `tests/unit-metadata-record.R`; P26 Build 53 passes mp with no errors or
   warnings, but it predates Data Sources Used, so its lineage is inferred from the home: test the lineage again on the next P26 Build.
   Stage 16 - Model Record (2026-11-03, the user's call: its own stage, not part of Build Figures) writes it in a scenario on the Build result:
   the Build's run log exists only once the Build has ended, so it cannot be in the Build's pipeline. Stage 1 logs the R version and git
   commit for the record. Tested on a copy of Puget Lowlands result 6: 0 mp errors, same XML as the tool.
   Phase 3 (2026-11-03): Stage 17 - Data Release, `src/release.R`, `src/17-data-release.R`, `tools/data-release.R`, `ui/DataReleaseView.cs`,
   `tests/unit-release.R` (43 checks), `tests/phaseZ-data-release.R`. The writer passes on P26 from the tool (runs 54, 65, 66, 67: 7 records, mp 0 errors, 0 warnings).
   Stage tested end to end on Puget Lowlands 2026-11-03. Phase 4 (2026-11-03): Release Information page and project People list (`ui/ReleaseInformationView.cs`, sheets Person, ReleaseInformation, ReleaseOriginator), `rl_read_info`, release status Draft/Provisional/Approved (a blank fails the last two), `tests/phaseZ-release-information.R` on a copy of Puget (15 checks); the guide has section 7.5.
   Phase 5 (2026-11-03): content checks and the `review/` packet, `src/release-review.R`, `defaults/metadata/review-checklists.csv` (USGS checklists 2.8 and 2.6, word for word), `tests/unit-release-review.R` (46 checks: each fault must be caught). Metadata identifier made optional (the checklist says the ScienceBase team assigns it). Phase 6 (P26 trial release and a mock review) is next.
   Existing libraries need tools/sync-library.R --schema-only for the new sheets. The 2026-10-25 scope below
   still holds. TO DO (user, 2026-10-25). Completed runs need FGDC-compliant metadata (CSDGM,
   FGDC-STD-001-1998, as USGS data releases use; XML), in two layers:
   - **Model metadata** (thorough, one record per model): what the model is and how it was built. Identification (title, abstract,
     purpose, originators, citation, keywords, use constraints), extent and time period (study area bounding coordinates, 1985-2023
     and the projection years), spatial reference and resolution, **lineage**: every input dataset as a source citation (from the Data
     Sources page and item 12's manifest: source, vintage, URL, clipped or national) and every stage as a process step (what it does,
     its key options, the date it ran, the result scenario id), software versions (SyncroSim, stsim, lucasCore), and the entity and
     attribute definitions of the model's classifications (state classes, transition groups and types, stock and flow groups, strata).
     Could be written by the Build (a stage or a step of stage 12) or by the outputs stage below from the Build result.
   - **Output metadata stage** (its own scenario, like Run Figures): accepts one or more result scenario ids (historical runs,
     projections, Run Figures), exports the delivered products and writes one metadata record per product: tabular outputs (state class,
     transition, stock and flow tables as CSV, with every column defined: units, domains, the iteration/timestep meaning) and spatial
     outputs (state class, age, transition and stock maps as GeoTIFF: raster info, bounding coordinates, value attributes and the class
     lookup). Each record cites the model metadata as its lineage source and adds the run's own settings (years, iterations, climate
     run, Projection Setup, multiprocessing tiles).
   - **User fields** on a Metadata Options page (project or scenario level): originator, point of contact, publisher, distribution and
     access constraints, citation/DOI, keywords (with thesauri), so the stage fills everything else automatically.
   - **Validation**: run the USGS metadata parser (mp) on every record and report errors in the stage's checks; consider an ISO 19115
     export later from the same content.
15. **Run Settings page: two bugs** - FIXED 2026-10-25 (b: the strata names now come from the dependencies' Build Options when the scenario has none) (found setting up the P26 Projection Setup). (a) The stand-alone run list was empty: it read Project.Scenarios, which holds no results (they are in Project.Results); now reads Project.Results and rereads when the drop-down opens. It was also
   built once when the page loads (ProjectionRunView.LoadDataFeed), so a historical run that finishes while the scenario is open is
   missing until the tab is closed and reopened: rebuild the list when the drop-down opens. (b) The tile strata labels read Build Options
   from the scenario's own sheet, so a Projection Setup (Build Options from its Build dependency) shows the defaults ("Secondary:
   States") instead of the Build's ("Secondary: Counties" for P26): read the dependency's Build Options, or the strata names the Build
   wrote. Also note: the page has no Start Year (ProjectionStart.StartYear exists but is not shown; blank = the historical end).
16. **Run Settings: small text fixes** - FIXED 2026-10-25. The run list shows the id twice ("[14] [14] P26 ... Historical Run ([5] @
   ...)"): a result's DisplayName already starts with its id, so list DisplayName alone. The stand-alone hint still says to make the run
   with tools/new-historical.R --historical-only --bookend-maps; say instead that the run needs state class, age and stock maps for
   its last year (age maps are on by default from 25 October 2026).
17. **Run Figures: a comparison set for several futures** - DONE 2026-10-29 as its own stage, 14 Compare Runs (src/14-compare-runs.R,
   src/compare-figures.R), in its own scenario on the Build result: the Compare Runs page picks runs from a drop-down with a Baseline
   tick, colour and label; 9 figures plus a carbon table (stocks, NPP, NEP, LULC losses, NBP) and a land change table (fire, harvest,
   urbanization, forest and developed area change), as the user asked. Run Figures picks its run from a drop-down. Monte Carlo bands
   and the sign-agreement maps are not in yet. Guide 7.4. Original plan (user, 2026-10-25): Today's Run Figures describe one run (a projection
   is joined to its historical run). Comparing futures (normal climate, SSP2-4.5, SSP5-8.5, or different land-use rules) needs its own
   set, built on dev/figures/compare-futures.R. Planned, in stage 13: the Run Figures page takes several runs, each with a label, plus a
   reference run (default: the first); one run = today's set, several = the comparison set. Contents: (1) total ecosystem carbon and its
   cumulative change since the projection start, one line per future, history once; (2) NPP, Rh and NBP per year plus cumulative NBP;
   (3) carbon by pool at the end year, grouped bars; (4) transitions per year by family per future (a check: identical when futures
   share a Projection Setup); (5) end-year carbon difference maps against the reference; (6) mean NPP difference maps over the last
   decade; (7) a summary table per future (end carbon, cumulative NBP, NPP mean and spread, burned and harvested area, differences from
   the reference). With Monte Carlo iterations: means with bands, and maps of the mean difference with its sign agreement.
18. **Spin-up and decay calibration choices in the UI** - DONE 2026-10-28 through item 21 (Spin-up, Decay Calibration Settings, Carbon
   Method pages); mature age per forest type is still one value. Original request (user, 2026-10-26): The dead-matter calibration (stage 3) and spin-up
   (stage 4) rest on assumptions a user should be able to see and set, in a Carbon Options group (or its own page): (a) the calibration
   targets - FIA's measured down woody material pools (coarse and fine woody debris, litter, duff, standing dead) or the condition
   table's modelled down dead and litter; (b) the stand ages fitted - mature stands only, from a minimum age (60 years by default; the
   user expects it to vary by forest type eventually), excluding conditions with a recorded fire or harvest in the past N years; (c) the
   spin-up's last disturbance - high-severity fire (default, as the old LUCAS spin-up), clearcut, or a mix; (d) the **fire return
   interval** of the spin-up cycles - today each cell's LANDFIRE FRI_REPLAC (stage 5), to be shown and overridable (per forest type or
   a single value); (e) the pool groupings matched to FIA (src/dom.R FIA_DOM), at least documented on the page. Young stands are a
   check on the disturbance flows (fire and harvest event flows), not a calibration target. Design and dev results: dev/nfcms and
   dev/fia FINDINGS.md.
19. **Dead organic matter calibration from measured FIA data** - DONE 2026-10-27 (Carbon Method "FIA measured dead wood", the default). PROPOSED 2026-10-26 (user asked for the write-up). Calibrate decay to FIA's
   measured down woody material pools in mature stands, fix snag fall from remeasured dead trees, use fire as the spin-up's last
   disturbance, and fit the high-severity fire and clearcut event flows to plots after those events. Proposal, results on P26 and
   implementation plan: docs/dom-calibration-proposal.md; evidence: dev/fia (scripts 05-15) and dev/nfcms. UI choices: item 18.
   IMPLEMENTING 2026-10-27 (user go-ahead): Carbon Options 4 "Measured dead wood" (new default; falls back to 1 without the DataMart
   folder) - src/fia.R fia_dead_wood (all 48 states' COND_DWM_CALC + remeasured snags, cached fia-deadwood.rds), src/calibrate.R
   dwm_targets / snag_fall_rates / cal_fit_measured (regional snag, down log, fine woody debris; litter and duff by type), src/dom.R
   (five decay groups, fixed snag fall, ST-Sim row precedence in disturbance_matrices, fire_snag_rows), fitted fire and clearcut rows
   in defaults/stockflow/event-pathways.csv, defaults/spinup/fire-snag-share.csv, stage 4 reads the event rows stage 3 wrote,
   OutputDecayCalibration columns, decay figure. Test: tests/phaseZ7-measured-dom.R. DLL rebuild needed for the Carbon Options page.
20. **Turnover and DOM rate table a user can view and override** - DONE 2026-10-29 (the read-out is item 30, Carbon Rates). Since 2026-10-28 through item 21 the rates can be set
   (Live Turnover, Dead Organic Matter Parameters, Fixed Decay Multipliers, Disturbance Flows); still open is one view of the rates a
   region and forest type actually run with, and their source. Original request (user, 2026-10-27): Pick a region (ecodivision) and forest
   type from lists and see the rates the model runs with, laid out by pool: each live pool's turnover rate and its split (foliage -> AG
   very fast; branch -> snag branch / AG fast; stem -> snag stem; fine root -> AG / BG very fast; coarse root -> AG / BG fast), and each
   DOM pool's total loss rate with its split between the next pool and emission to the atmosphere (snags: fall, decay, emission). Show
   the source of each value (CBM default, calibrated, measured) and let the user enter their own. First populated for P26
   (dev/fia/16-rate-table.R -> dev/fia/out-cal-clearcut/rate-table.csv: CBM, current stage 3 and proposed calibration per type). Live
   turnover is not calibrated today (CBM ecozone x species defaults). Related: items 18, 19.
   2026-10-27 (user): include the region's mean temperature and the CBM Q10s (2.65 leaf litter and duff, 2.0 the others, 1 deep soil),
   viewable and editable; the high-severity fire and clearcut transfer shares; the key growth curve values. Scope: DOM decay is
   REGIONAL (ecodivision; one set for every type), live turnover, snag fall, fire snag share and growth are per forest type. P26 test
   (06 with LUCAS_POOLED=1, dev/fia/out-cal-regional): one regional decay set cuts the misfit from CBM by 93-95% vs 97-98% per type;
   down logs, fine woody debris and snags fit about as well, litter and duff by type do not (forest floor measured 4 Fir/Spruce vs 9-10
   the others). Tables: dev/fia/out-cal-clearcut/rate-table-{region,type,events}.csv (16-rate-table.R).
   DECIDED 2026-10-27 (user): regional decay for snags, down logs and fine woody debris; leaf litter and duff decay per forest type
   (hybrid fit: 3.0% of CBM's misfit left vs 2.5% per type, 7.1% fully regional). The sheet lists litter and duff decay with the type.
21. **Carbon assumptions a user can see and change** - DONE 2026-10-28 (steps 1-6 plus the Carbon Method page with presets; progress in
   docs/carbon-assumptions.md); the Growth inputs sheet was not built. Request (user, 2026-10-27): "a user needs the ability to change or specify any of
   the assumptions made which allow us to run the carbon calibration steps", starting with the CBM crosswalk (today a package file,
   one row per forest type, not editable, not regional). Inventory of every assumption, where it lives, and the proposed Carbon
   Assumptions sheets (CBM Crosswalk as in lucasBuilder 2.0.4, Live Turnover, DOM Parameters, Decay Calibration Settings, Disturbance
   Flows, Spin-up, Growth inputs; filled with package defaults like the Land Cover Crosswalks): docs/carbon-assumptions.md. Takes in
   items 18 and 20. Step 1 (CBM Crosswalk) done 2026-10-27 (tests/phaseZ8); step 2 (Dead Organic Matter Parameters) done (tests/phaseZ9); step 3 (Live Turnover) done (tests/phaseZ10); step 4 (Spin-up) done 2026-10-28 (tests/phaseZ11); step 5 (Disturbance Flows + Fire Snag Share) done 2026-10-28 (tests/phaseZ12); step 6 (Decay Calibration Settings + Fixed Decay Multipliers, to-dos 18 and 20 override) done 2026-10-28 (tests/phaseZ13).

22. **Automatic spatial tiles** - DONE 2026-10-29 (user: choosing Build Options > Tiles needs prior knowledge of the region). Spatial
    Tiles **0 = automatic** (Build Options and Run Settings; blank still = one job, so existing libraries are unchanged): ticking "Split
    runs into tiles" now writes 0 and the box shows auto; a typed number still wins. Rule (src/shared.R auto_tiles): a tile holds whole
    units, so a run cannot finish before its largest unit and more than ceiling(1 / its share) tiles cannot help; pack 1 to that many
    tiles and take the fewest within 5% of the best finish, capped by the units and the cores (P26: Plumas 19.8% -> 5, as found by
    trial; Placer's tertiary units with one at 52% -> 2, where floor(1 / share) would have said 1). Stage 1 (and stage 9 for a
    projection's own) logs the largest unit and its share, the tiles used, the best speed-up, estimated peak memory (1.5 GB + 10 KB per
    cell per job, 24 Oct P26 measurements) with the jobs a 32/64 GB machine holds, and plain warnings when more tiles cannot help or one
    unit holds over half the land; with tiles off it says what automatic would choose. Pages: Build Options and Run Settings notes.
    Tests: tests/unit-auto-tiles.R (13 checks incl. P26 -> 5), tests/phaseZ16-auto-tiles.R (stage 1 on lucasCore-suitability, three
    cases). Guide 3.3 step updated. The UI DLL needs a rebuild with Studio closed.
23. **Deep Soil reset at the projection start** - FIXED and rerun 2026-10-29 (eeea87c; found by the user plotting DOM: Soil). Stage 9 took the
    projection's starting stocks from the Build's initial stock maps, which have no Deep Soil (it starts at zero), so every projection
    dropped 1.09 Tg C in 2023. Stage 9 now also carries any pool the historical run mapped at its end year. P26 Projection Setup and
    the three projections are being rerun by the user, then their Run Figures and Compare Runs.
24. **Stage 13 hand-over check** - DONE 2026-10-29 (12a2de9: exact, 1e-6; new runs pass, the pre-fix run fails), after the reruns (user, 2026-10-29: "We want the hand off to be exact"). The check allows
    0.5%; tighten it to an exact match (within rounding) or remove it - user's choice. The guide's sentence about it is already gone.
25. **Guide: P26 numbers after the reruns** - DONE 2026-10-29 (ids, 7.2-7.4 numbers, Figures 7.8-7.11 and 7.28-7.31, six re-grabs). Update 7.2 (projection start 443.2 -> 444.3 Tg C), the 7.3 timings if they change,
    7.4's tables and figures, and Appendix A where it quotes projection results.
28. **Mature age per forest type** - DONE 2026-10-29 (Carbon Assumptions: Mature Age by Forest Type; docs/carbon-assumptions.md). Was (left over from 18/21): Decay Calibration Settings has one mature age (60) and one
    disturbance-free window (30 yr) for every type; stands reach a steady dead-wood level at very different ages (oak woodland and
    lodgepole sooner, fir/spruce and mixed conifer later). Add an optional per-forest-type (and per-ecodivision) row, blank = the
    single value; log the mature plots per type.
29. **Growth Inputs sheet** - DONE 2026-10-29 (Carbon Assumptions: Growth Inputs; user growth curves not in - copy curves from another library). Was (step 7 of item 21, never built): The growth assumptions still fixed in the package: FIA forest type
    group -> state class and growth class (defaults/growth/forest-type-crosswalk.csv), merchantable carbon density and deciduous share
    (defaults/growth/merch-carbon-density.csv), the coarse/fine root split (Li et al. 2003, hard-coded in src/carbon.R), and optional
    user volume or carbon curves (lucasBuilder's Merchantable Volume Curve). A Carbon Assumptions sheet filled with the defaults, as the
    other six.
30. **Rate read-out** - DONE 2026-10-29 (Build Results: Carbon Rates, stage 3, with an ecodivision and forest type page). Was (the open half of item 20): Stage 3 writes the resolved rates per ecodivision x forest type (live turnover
    and splits, each dead pool's base rate x temperature effect x multiplier, emitted vs passed on, snag fall, fire and clearcut shares,
    mean temperature, Q10, key growth curve values) with each value's source (CBM default, calibrated, measured, user); a read-only page
    on the Build result with ecodivision and forest type drop-downs shows them.
32. **Carbon open science issues** - DONE 2026-10-30 (raised 2026-10-27): snags short in 96 cells even at the lowest snag decay (inputs or fall
    rate; user offered to look); duff multiplier at its 20 bound in 19 cells; the fitted fire/clearcut transfers and fire snag shares
    are California-fitted but applied everywhere.
    **Diagnosed 2026-10-30** (dev/fia/22-snag-shortfall.R, 23-stem-mortality.R; outputs dev/fia/out-z7). (1) Snags: the "96 cells"
    were the cells with snag decay at its lower bound, not the short ones; of the 193 cells with measured targets the spin-up's mature
    snags are under 0.8 x measured in 72, 14 of them at the bound (mostly interior-West mountains: lodgepole, fir/spruce, aspen).
    Cause: the mortality input, not the fall rate. With decay ~0, snags ~ mortality / fall, and the model's stem mortality is CBM's
    stem turnover (one rate per type, its CBM ecozone, never fitted). FIA remeasured mature conditions, 11 western states, non-fire
    mortality per year of live aboveground carbon: snag-OK cells 0.0079 vs CBM 0.0052 (1.5x), short cells 0.0124 vs 0.0045 (2.7x);
    across cells snag ratio vs FIA / CBM r = -0.67; lodgepole TSM 4.3x, aspen TSM 4.8x, fir/spruce TSM 3.5x. Cause of death does not
    separate them (insect 14% vs 16% of standing dead; 64-70% unknown). (2) Duff at 20: all 19 cells are Exotic Hardwoods (one
    per-type fit, 445 plots nationally, measured duff ~0.3-0.4 Mg C/ha) - harmless, leave. (3) California-fitted event shares: not
    yet assessed. Proposed fix for (1): fit stem turnover to FIA's non-fire mortality of mature stands (per type, per type x
    ecodivision where >= 30 remeasured conditions), all 48 states, as the package's Live Turnover values; growth curves stay (gross
    growth = curve increment + turnover), the DOM decay refits; awaiting the user's choice.
    **Design (user, 2026-10-30):** do A now; later B models only extreme, stand-replacing insect/disease events as discrete spatial
    events (sources: LANDFIRE Annual Disturbance insect/disease types, ADS/IDS, LCMS slow loss/stress, Meddens & Hicke beetle maps),
    the rest stays background mortality. To avoid counting the same deaths twice, A's background can leave out stand-replacing
    conditions. dev/fia/24-stand-replacing-share.R (40,310 remeasured mature western conditions, median period 10 yr): non-fire loss
    >= 50% of live carbon in 3.6% of conditions, >= 70% in 1.1%; they hold ~20% (>= 50%) / 7% (>= 70%) of the mortality carbon, about
    the same in snag-short and snag-OK cells. Background without them is still 2.2x CBM in the short cells (0.0100 vs 0.0045; all
    mortality 0.0124), so the shortfall is mostly chronic mortality, not outbreaks; the outbreak-heavy cells are lodgepole and aspen
    TSM and lodgepole Marine Mountains (34-38% of mortality stand-replacing, insects 60-90% of it). Threshold: 70% (user).
    **Option A DONE 2026-10-30.** tools/calibrate-stem-turnover.R: all 48 states, 187,152 remeasured mature conditions (stand age
    >= 60), the 1.2% that lost >= 70% to non-fire causes left out; background non-fire mortality / live aboveground carbon per year ->
    defaults/carbon-assumptions/fia-measured/live-turnover.csv (StemTurnover only; 28 types + 123 type x ecodivision rows with >= 30
    conditions). FIA / CBM 1.1-1.2x (Douglas-fir, pinyon/juniper), ~2-2.5x most types East and West, 3.4-4.2x lodgepole, aspen.
    Trees under 5 in. (not tallied as snags) change the rates by only 2-5% (--min-dia, default 0). Stage 3: an empty Live Turnover
    sheet with the FIA measured dead wood method takes these rows (Fill copies them). Test tests/phaseZ24-stem-turnover.R (532 cells,
    stages 3-4 on Build 47): all pass; mature snags model / measured median 0.89 -> 1.00 (plot-weighted 0.83 -> 0.95), cells under
    0.8 72 -> 62 (snag decay is shared by an ecodivision's types), snag multipliers at the lower bound 96 -> 30, median snag
    multiplier 1.72 -> 7.72 (more input with the measured fall rate leaves decay to take the rest; FIA's snag carbon already holds
    broken tops and lower density); pools' medians 0.84-0.99 of measured; live carbon still the stage 2 curves. P26 mixed conifer
    snags 0.65 -> 1.05, down logs 0.69 -> 0.96; fir/spruce snags 0.41 -> 0.80. Also found: the ecodivision shapefile has a second
    M260 polygon named "Mediterranean" (the package uses codes; both tools now map names by code; harvest-age.csv changed one count).
    **(3) Assessed 2026-10-30, no change** (dev/fia/25-event-shares-national.R, all 48 states: DWM visits 0-5 yr after a
    stand-replacing event paired with the visit before, as 08 did for M260). Fire (913 pairs, nearly all western): snags gained
    0.49-0.61 of the live wood before in every western ecodivision with >= 10 pairs vs 0.59 in M260 (M340 0.38 on 34 pairs; Subtropical
    0.06, southeastern low-carbon stands, likely salvaged); down logs gained ~0 everywhere; forest floor kept 0.18-0.29 vs 0.18.
    Clearcut (1,000 pairs): snags left 0.00-0.04 and median down logs gained 0.00-0.05 of the wood before everywhere, as M260 and the
    model (0.02); only the means differ (Subtropical 0.74, Warm Continental 2.8: a few site-preparation piles); forest floor kept
    0.42-1.1 (M260 0.66). The M260 fits stand; regional overrides stay possible in Disturbance Flows and Fire Snag Share. Item 32 DONE.
34. **Calibrate the minimum harvest ages** - TO DO (scoped 2026-10-29, user: matters for projections, where cut cells must meet it; method
    not chosen yet). Today defaults/transitions/pathways/harvest.csv gives Forest Clearcut one AgeMin per forest type, copied from the
    CONUS 1 km build (20-161 yr: mixed conifer 92, redwood and Other Western Softwood 161); the selection types have none. Stage 9 uses
    it for eligibility, and stage 6 raises the start age of every historically clearcut cell to it, so it also changes the initial ages,
    initial carbon and historical results. Quick check on California FIA remeasured plots (prior-visit STDAGE on conditions cut between
    visits: 788 cuts, 133 clearcut-like with basal area loss >= 75%): mixed conifer 10th pct 45, median 85 (so 92 blocks over half);
    ponderosa 36/75; fir/spruce/mtn hemlock 70/95; Douglas-fir 39/63; redwood about 44/60-70; private land cuts youngest.
    Options: (a) FIA age at harvest, a low percentile per type, California plus OR/WA/NV for thin types, selection from partial cuts,
    optionally by owner; (b) growth-curve CMAI (NFMA 95% rule) from stage 2's curves as the fallback; (c) stage 6's AgeBlockedArea
    share as the check, not a fit (the age map was adjusted, so fitting to it is circular). Build: tools/calibrate-harvest-age.R, an
    optional Minimum Harvest Age page (like Mature Age) read by stages 6 and 9, unit test, test-library run comparing blocked share
    and initial carbon. P26 needs a Build and Historical rerun to pick it up.
    **Analysis 2026-10-30** (dev/harvest/04-harvest-age-fia.R, outputs in dev/harvest/out): CA, OR, WA, NV, ID remeasured conditions
    cut between visits, paired with the previous visit (age at cut = previous STDAGE + years to the treatment year): 3,415 cuts, 851
    clearcut-like (live basal area loss >= 75%), 1,045 partial (10-75%). Clearcut-like, 10th pct / median (n), today's AgeMin, share
    of clearcuts it blocks: mixed conifer 49/92 (64), 92, 50%; Douglas-fir 37/54 (393), 40, 16%; Hemlock/Sitka 41/56 (100), 46, 20%;
    ponderosa 50/83 (96), 61, 18%; fir/spruce/mtn hemlock 55/80 (67), 61, 16%; alder/maple 35/51 (47), 37, 17%; lodgepole 54/83 (20),
    61, 20%; tanoak 46/59 (14), 46, 14%; western oak 43/84 (10), 50, 20%. Redwood: no clearcut-like cuts, partial 49/85 (18), AgeMin
    161. Private land cuts younger (Douglas-fir median 50 private vs 79 public; mixed conifer 84 vs 111). Partial cuts, 10th pct /
    median: mixed conifer 59/93, ponderosa 55/88, Douglas-fir 35/71, fir/spruce 51/93. Option (b), CMAI of P26's merchantable volume
    curves (Mediterranean Mountains): mixed conifer 51 (NFMA 95% 39), ponderosa 33, Douglas-fir 32, fir/spruce 42, redwood 39,
    tanoak 60, western oak 70: close to the FIA 10th percentile in mixed conifer and Douglas-fir, younger elsewhere.
    Reading: today's AgeMin is too high mainly in mixed conifer (P26's main type: blocks half the clearcuts) and the 161-yr types
    (redwood, other western softwood); elsewhere it blocks 15-20%.
    **DONE 2026-10-30** (user decisions the same day). (1) Package values, computed once: tools/calibrate-harvest-age.R over all 48
    FIA DataMart states (27,427 cuts: 11,056 clearcut-like, 16,371 partial) -> defaults/transitions/harvest-age.csv (124 rows: per
    forest type, plus type x ecodivision where >= 30 cuts; < 20 cuts -> CMAI of P26 result 47's merchantable volume curves) and the
    AgeMin column of pathways/harvest.csv; selection capped at clearcut. (2) Second view, dev/harvest/05-lcms-cut-age.R: LCMS tree
    removal x NASA CMS 1990 age in P26 at 30 m (1,797 km2 of first cuts): medians as FIA (mixed conifer 94 vs 92) but 10th percentiles
    10-30 yr younger (mixed conifer clearcut 34, selection 39); FIA's values would block 10-34% of P26's mapped cuts. (3) Stage 6
    settles them: each FIA value lowered to the study area's own (10th percentile of stage 5 age at each harvest's first cut on a cell
    not yet clearcut, where the type has >= 1 km2 of mapped cuts), then the page's rows, then selection <= clearcut - 10 and >= 5
    (thinning comes before final harvest; FIA and the maps both put partial cuts' young tail at or above clearcut's). Type x
    ecodivision values become stratum pathway rows (no blank row for that type). The start-age rule now covers selection too, with
    a cell reset once its chance of an earlier clearcut reaches 0.5. Build Results > Minimum Harvest Ages (OutputHarvestAge) lists
    FIA, study area, used and basis. Page: Minimum Harvest Age (feed HarvestAge: options sheet HarvestAgeOptions - study area maps
    on, minimum mapped area 1 km2, selection offset 10, floor 5 - and the override rows; Add the package values / Remove all rows).
    Test tests/phaseZ23-harvest-age.R (Placer 1 km, stage 6 on a stage 5 result): all pass. Mixed conifer clearcut 49 (Placer's
    1 km map gives 51: cell ages smooth the young tail the 30 m analysis shows), selection 39; fir/spruce clearcut 30 (maps),
    western oak 38 (maps); 369 start ages raised (median 12 yr); 5% of clearcut and 3% of selection expected area below the minimum;
    a 1985-2023 historical run cuts 87 km2 clearcut (Build 47's old ages: 70; LCMS 90) and 127 km2 selection (153; LCMS 137).
    **Fix 2026-10-30:** the study-area value counts only cuts after the age map's year (NASA CMS 1990; TreeMap 2016): the map
    already shows a stand cut before then as young, so its 1986-1990 cuts looked like cuts of very young stands (P26 fir/spruce
    clearcut came out 10 yr at 150 m, vs 34 from the 30 m cuts after 1990). Placer 1 km (dev/harvest/06-age-year-check.R): mapped
    values rise 13-17 yr (mixed conifer 51 -> 63, fir/spruce 30 -> 43, western oak 38 -> 55; mapped area about halves); used
    clearcut minimums fir/spruce 30 -> 43, western oak 38 -> 55, mixed conifer stays FIA 49.
    Page checked in Studio (user, 2026-10-30). Not done: P26 needs a Build + Historical rerun to pick it up (initial ages and carbon change);
    guide section for the page.
35. **TreeMap: forest type, stand age and site productivity from one map** - DONE 2026-10-30 (planned 2026-10-29; user: use TreeMap; combines item 10;
    full plan in docs/treemap-plan.md). **Phase 0 done 2026-10-29: go** (site class moves carbon at age around stage 2's own curves, mixed conifer m 1.59 -> 0.52 from site class 2 to 6; every P26 TreeMap pixel gets a site class with all 48 states' COND; Climate and Site Productivity flow multiplier types multiply in ST-Sim, untyped climate rows still work; details in the plan). Choices (user): TreeMap 2016, multipliers by type x ecodivision, Site Productivity off by default. **Step 1 schema-free part done** (src/treemap.R, tests/unit-treemap.R); **Step 2 done 2026-10-30** (ac971f3: TreeMap as Forest Type Map and Stand Age Source in stage 5; new columns need tools/sync-library.R --reference=dev/libs/sync-reference.ssim). P26 synced 2026-10-30. **Step 3 done** (site class multipliers in stage 2, Build Results > Site Productivity). **Step 4 stage 5 half done** (site class share maps). **Steps 4-6 done** (stage 8: cell multiplier, Site Productivity flow multiplier, scaled initial stocks; stages 7/11 tag Climate). **Step 7 pages done** (Build Options: Growth > Site productivity; Build Results > Site Productivity page). **Stage 12 Site productivity figure done** (pages checked in Studio). **Projection carry-over tested** (fixed: stages read dependencies from the run's parent). **P26 synced for the multiplier types 2026-10-30** (Climate, Site Productivity; sync-library read the one-column CSV wrong, fixed). Guide 3.3 updated (Build Options grab, Stand age and Growth steps).
    **Why.** Every cell of one forest type, ecodivision and age grows on the same curve; only the climate multipliers (stages 7 and 11)
    vary growth in space. TreeMap (USFS, 30 m) gives each forest pixel an imputed FIA plot; through the plot's FIA condition the pixel
    carries forest type (FORTYPCD), stand age (STDAGE) and site class (SITECLCD, 1 = 225+ to 7 = 0-19 cu ft/ac/yr), consistent with
    each other and with the plots the growth curves are fitted to. So one join also finishes item 10.
    **Evidence.** 6,757 TreeMap plots in CA/OR/NV with a site class, live carbon on age with and without site class: mixed conifer R2
    0.13 -> 0.50 (carbon / curve 1.84 at site class 2 to 0.40 at 6), Douglas-fir 0.52 -> 0.70 (1.64 to 0.39), fir/spruce/mtn hemlock
    0.23 -> 0.35, ponderosa 0.19 -> 0.30, western oak 0.20 -> 0.38; weak in lodgepole and tanoak. A quick fit, not stage 2's curves.
    **Design.** (1) Multiplier m per forest type (and ecodivision where plots allow) and site class = mean observed live carbon / the
    stage 2 curve at plot age, over the fitting plots in that class, divided by the same over all fitting plots: plot-weighted mean 1,
    so the curves stay right on average; small classes shrink toward neighbours or 1; capped about 0.3-2.5. (2) Map: pixel -> plot ->
    site class -> m for the cell's type and ecodivision; model cell = mean over its pixels of that type; unmatched pixels = 1 (share
    logged). (3) Growth: a static flow spatial multiplier on the forest growth flows, with ST-Sim **Flow Multiplier Types** (user):
    the project types (defaults/stsim/stsim_FlowMultiplierType.csv, today only Net Growth Uncertainty) gain **Climate** and **Site
    Productivity**, which multiply in each cell; stages 7 and 11 tag their rows Climate (today blank). Stages cannot write project
    sheets, so the types come with the package defaults and tools/sync-library.R (P26 before its next Build). Scaled growth with
    first-order turnover gives live carbon m x curve(age). (4) Initial stocks: stage 8 scales live and dead organic matter by m, not
    the deep soil. (5) One join, src/treemap.R (TreeMap CN = PLT_CN -> the forested condition matching TreeMap's FORTYPCD, else the
    largest), used by type, age and productivity.
    **Steps.** 0 spikes in dev/ (read only): site class ratios on stage 2's curves for P26 types per ecodivision (go/no-go, shrinkage);
    a Climate and a Site Productivity multiplier on one growth flow multiply, and blank-type rows from old Builds still work; TreeMap
    coverage on P26 with all 48 states' COND. 1 data: Data Sources TreeMap folder; src/fia.R reads SITECLCD (cache key bump);
    src/treemap.R. 2 type and age (item 10): Build Options Forest Type Map = TreeMap, Stand Age Source = TreeMap (CMS stays default),
    stage 5. 3 stage 2: Site Productivity output sheet (type x ecodivision x site class: plots, raw ratio, value used); checks
    plot-weighted mean 1, monotone where plots allow. 4 stage 5: Build Options Site Productivity = None | TreeMap site class; the
    multiplier raster; checks every forest cell has a value, the cap, area-weighted mean near 1. 5 growth flows: the two multiplier
    types; stages 7 and 11 tag Climate; one static Site Productivity row. 6 initial stocks (stages 4 and 8) x m; check cell live
    carbon against TreeMap CARBON_L with and without m. 7 UI: Build Options entries with notes, a Build Results page Site Productivity,
    a stage 12 map. 8 tests: plain-R unit tests (join, normalisation, cap, shrinkage), then the Placer demo library (never the P26
    guide library), then a P26 Build + Historical comparison. 9 docs: guide, methods paper.
    **User choices.** TreeMap vintage (2016 on disk; newer releases exist); multipliers by type only or type x ecodivision; Site
    Productivity default on or off.
    **Other sources considered.** NFCMS Forest Productivity (PSW_ForestProductivity.tif, 30 m, values 0-10, legend unknown); gSSURGO
    forest productivity tables (not on disk); LANDFIRE has no productivity layer (canopy height / stand age as a site index proxy is
    a possible check only).
37. **P26 rerun and guide refresh** - DONE 2026-10-31. The first historical rerun (result 52) lost half its fire and urbanization:
    stage 6 wrote harvest-age pathways per ecodivision for two forest types, and ST-Sim then dropped those classes' blank-stratum
    pathways. Fixed (58ed57b, 737328c; user rule: strata are used everywhere or nowhere, so with any ecodivision harvest age every
    pathway is written per ecodivision; test phaseZ23). Reruns: Build [53] (57 min, 74 checks pass, 442 Tg C), Historical [54]
    (1986-2023: fire 12,124 km2 vs 12,412, urbanization 244 vs 245, harvest 2,101 vs 2,392, 12% short: about 8 points placement
    limits, the rest the minimum ages, see item 43; carbon 441.6 -> 474.5 (2019) -> 451.6 Tg C), Setup [57], Climate [58]/[59],
    projections [65] No Climate 452.2, [66] ssp585 447.3, [67] ssp245 446.0 Tg C in 2050, Compare [71]. Guide: numbers, run times,
    16 run figures, new sections 3.6 Minimum Harvest Age and the Carbon Assumptions pages, 4.2 headings renumbered, Studio grabs
    retaken (6.6-6.13 and chapter 8 kept on purpose: user, 2026-10-31), GitHub snapshot rebuilt (c398241, 0ce1c25).
    Was: Item 34 changed stage 6 (minimum harvest ages from FIA and the study
    area's mapped cuts, selection at least 10 yr under clearcut, start ages raised for selection too), so P26's start ages, initial
    carbon and historical harvest change; item 32 may change the carbon too, so rerun once after it. Steps: the P26 Build and the
    Historical run in the user's guide library (the user runs them, or asks Claude to); then the guide's P26 numbers and figures
    (initial carbon 439 Tg C, run times, Build figures, Historical Transition Summary, projections), and a guide section on the
    Minimum Harvest Age page with a grab (the options, the rows, Build Results > Minimum Harvest Ages). Site Productivity stays off in
    the walkthrough.
    **2026-10-30: the user is running the P26 Build and Historical run in Studio** (item 32 done: stem turnover changed too). Checks
    after: the Build's Validation all Pass; stage 3's log "Live Turnover: ... rows from the package" (if it says "from Carbon
    Assumptions", P26's Carbon Assumptions scenario has its own Live Turnover rows, which win: Fill on the Carbon Method page replaces
    them); stage 6's "Minimum harvest ages" lines and Build Results > Minimum Harvest Ages; Initial Stock Summary total carbon (was
    439 Tg C); in the Historical run, realized clearcut and selection area against the Historical Transition Summary's LCMS area.
    Also (2026-10-30, after items 32 and 39): stage 3's "Grassland, Shrubland and Wetland Carbon: no rows (the package values)" line;
    Non-sage shrub cells start with the fixed pools. Then Claude pulls the numbers and figures for the guide.
39. **Grassland and shrubland carbon: expose the rates, then improve the science** - TO DO, top priority (user, 2026-10-30: before
    the P26 rerun; the rates came from IBIS simulations, "not very tractable"; at least make them visible and overridable, open to
    better science). **Today** (all package tables from the CONUS 1 km build, copied by stage 3 and stage 8): Net Growth one value per
    class (defaults/stockflow/nonforest-net-growth.csv, Mg C/ha/yr: natural perennial grass 2.31, annual 0.95, irrigated perennial
    9.19, chaparral 3.84, sage/other shrub 0.97-0.99); growth split, live turnover and dead pool decay/emission per class
    (nonforest-multipliers-grassland-shrubland.csv, the CBM pool structure in nonforest-pathways.csv); initial pools per class
    (defaults/initialstocks/grassland-shrubland.csv, from the build's spin-up; soil 92 Mg C/ha natural grass, 24 sage, 75
    chaparral; gSSURGO is used only where a class's soil is 0, never for grass or shrub). All 288 class x flow values are the same
    in every one of the 19 ecodivisions; the only spatial and yearly variation is the climate multiplier (Miami NPP, precipitation)
    on non-forest growth. Nothing is calibrated to observations and nothing is on a page. Alternatives under discussion with the
    user (2026-10-30).
    **Step 1 (expose) DONE 2026-10-30** (user: "Expose only for now"; then "the same design for wetlands"). Carbon Assumptions >
    Grassland, Shrubland and Wetland Carbon (feed NonForestCarbon, ui/NonForestCarbonView.cs): Non-Forest Growth (Ecodivision, Class,
    Age, Net Growth) and Non-Forest Rates (Ecodivision, Class, Age, Flow, Value); Fill / Reset loads every value that does not change
    with age (presets defaults/carbon-assumptions/<method>/nonforest-growth.csv 11 rows, nonforest-rates.csv 434 rows: 9 grass/shrub
    and 2 emergent wetland classes, the forested wetlands' rates; their 300-age growth curve and growth split are not listed but can
    be set with rows); the Carbon Method page's Fill and tools/carbon-assumptions.R fill them too. Stage 3 starts from the package
    tables and applies rows the more specific last (class; + age; + ecodivision; + both); checks growth splits add to 1 at every age,
    emergent wetlands' shares out of each pool's total loss ("AG Very Fast ->" etc.) add to 1, rates in 0-1; logs the differences.
    Starting pools stay the package tables (stage 8): a changed rate acts from the first year, not on the initial stocks. Test
    tests/phaseZ25-nonforest-carbon.R: all pass (empty = the package's 65,246 rates and 11,609 net growth values exactly; class,
    ecodivision and age rows land only where meant). FIXED 2026-10-30 (dev/nonforest/01-nonsage-fix.R): Shrubland: Non-sage's eight
    turnover rates were Post Fire Shrub's shifted down one row (in the CONUS build's own file too); now Post Fire Shrub's, and its
    starting pools rebuilt by an ordered annual simulation (foliage 1.71 -> 0.86, fine roots 1.26 -> 0.65, soil 26.7 -> 21.3). Was:
    (fine roots -> AG very fast 0.01, merchantable -> snags 0.51, other wood -> AG fast 0.0045, where the other shrubs have ~0.26,
    0.0045, 0.33); emergent wetland net growth 31 Mg C/ha/yr; irrigated perennial grass 9.19 - to review with the science step.
    Page checked in Studio (user, 2026-10-30). Libraries made before need tools/sync-library.R --reference=dev/libs/sync-reference-20261030.ssim (the Age columns); the
    suitability test library is synced. Next (user to decide): the science options (gSSURGO soil calibration, RAP growth,
    literature rates).
    **Diagram view DONE 2026-10-31** (user: ecologist's view, rates by default with a flux toggle, total NPP, the full steady-state
    budget, no atmosphere pool). The page's Tables/Diagram switch (ui/NonForestBudget.cs, NonForestDiagram.cs) draws one class with
    the values stage 3 uses and solves its steady state. With the package rates it lands on P26's starting pools for grass and shrub
    (chaparral live 7.0 / dead 33.8 / soil 75.3 vs 7.0 / 29.8 / 74.6; natural perennial 4.5 / 24.8 / 92.1 vs 4.5 / 22.4 / 91.8), so
    those starting tables are the rates' equilibrium. NOT for emergent wetlands: Palustrine Emergent's rates settle to live 36 and dead
    49 Mg C/ha against starting pools of 4.9 and 17.4 (soil 621 vs 609), so the starting pools or the rates (31 Mg C/ha/yr net
    growth?) came from different inputs - for the science step. Also seen in the diagram: every grass and shrub class sends coarse
    root turnover half to AG fast (above ground), and annual grass half its fine root turnover to AG very fast.
    Diagram follow-up DONE 2026-10-31 (8a7fc0c, user): CO2 and water leave each pool as arrows (curving up to the atmosphere,
    sideways to water), sized by flux; guide Figure 3.17. Left as is (user): BG slow's "water" label sits on the curve to deep soil.
40. **Live Turnover, Spin-up and Fixed Decay Multipliers pages show the values used** - DONE 2026-10-31 (f0faf72; user: "nothing here
    as a methodological change, just making the UI more friendly"). The three sheets hold overrides only, so they opened empty with no
    hint of what empty means. Live Turnover: pick a forest type and ecodivision; each rate with the value stage 3 uses (CBM through
    CBM Crosswalk and Growth Inputs, FIA stem turnover, or the sheet), where it comes from, and an editable row; the first value typed
    on an empty page writes the 151 package FIA rows first (a sheet with rows uses only its rows). Spin-up: each ecodivision and
    forest type with the newest Build result's LANDFIRE interval (else the provisional defaults) and the sheet's values beside it.
    Fixed Decay Multipliers: the newest Build result's calibrated multipliers, fixed ones shaded, "Fix the selected value". Fill still
    writes only the FIA stem rows: CBM rates written as rows would stop following CBM Crosswalk. Guide 3.7, Figures 3.15, 3.18, 3.19.
41. **Run pickers listed no runs** - FIXED 2026-10-31 (7490ca0). Compare Runs, Run Figures and the projection's historical-run
    drop-down read Project.Results, which holds only the toolbar's active results: with none active they listed nothing ("not an
    ST-Sim run of this project", Add a run dead). They now gather every scenario's own Results (ui/StsimRuns.cs).
42. **Fill prompt: old names for the grassland tables** - TO DO (found 2026-10-31). The Carbon Method page's Fill prompt lists
    "Non-Forest Growth, Non-Forest Rates" (ui/CarbonOptionsView.cs Sheets); the page is Grassland, Shrubland and Wetland Carbon. Say
    "Grassland, Shrubland and Wetland Carbon (growth and rates)"; the guide's Figure 3.9 caption explains the old names until then.
43. **Historical harvest 12% short: the minimum ages in the historical period** - TO DO, user to decide (offered 2026-10-31). In
    Historical [54] harvest reached 2,101 of LCMS's 2,392 km2: about 8 points are cuts the model cannot place (one transition per cell
    per year, classes without a harvest pathway), the rest cuts the minimum harvest ages (item 34) keep out of stands that regrew too
    little after an earlier clearcut. Options: apply the minimum ages only in projections (the record's cuts are fixed history), or
    resample start ages from the median rather than raising them to the minimum; either changes start ages and initial carbon, so it
    goes with a rerun.
45. **Stratum Sources polygons from Data Download** - DONE 2026-11-02 (user: "a major omission"; nobody without the build machine
    could run stage 1 or a Data Download for a study area: every preset but the ecodivisions named a file under the build machine).
    Data Download fetches them first, national, at the top of the home (study-area/): StatesFile (TIGER 2009), CountiesFile (TIGER
    2022), WatershedsFile (WBD national: HU6 and HU8 layers to one GeoPackage, from a 2.8 GB zip), EcoregionsFile (EPA Level IV),
    PyromesFile (RDS-2020-0020), PadusFile (PAD-US 4.0 state geodatabases, 49 files: layers gap_status and federal_fee). Federal
    Lands now comes from PAD-US 4.0 federal and tribal fee land (user, 2026-11-02; was the 2014 National Atlas fedlanp010g). The
    presets' File is blank and presets.csv names each one's DataSource; a File that exists wins, else the home (src/strata.R
    strata_path, src/shared.R strata_from_home), recorded in Data Sources Used. HUC6, HUC8, EPA L3 and pyromes ship ListFiles, so a
    new library needs no polygons. Also fixed: the Studio template's FIA Ecodivisions File (an F: path); tools/new-data-download.R
    could not set Data Sources Home in a new library (its blank row reads as no row; a second row was silently dropped). Tests:
    tests/unit-strata-home.R, tests/phaseZ26-strata-home.R (stage 1 on P26, home vs the old local files). Then (same day, user):
    package.xml lost its 24 Data Sources defaults (F: paths): a blank path reads the home or the package, else stops saying to run a
    Data Download; so a new library no longer scans the build machine's LOCA2 folder (the shipped lists, then Rescan).

46. **CO2 fertilization** - TO DO, open science (user, 2026-11-04: how can we introduce the effect of CO2 fertilization into the model?).
    Today no growth pathway responds to CO2, so projected growth carries the climate penalty with no offset, and the SSPs differ only
    through climate. Nothing is built; the proposal below is a starting point and its literature values are from memory, to verify.
  - **Proposed form:** the standard beta factor, `multiplier = 1 + beta x ln(CO2 in year t / CO2 reference)`, with one flow multiplier per
    growth flow group and year, under its own Flow Multiplier Type ("CO2"), like Climate and Site Productivity. It does not vary across the
    map, so non-spatial rows in stsim_FlowMultiplier may do; check that they combine with the spatial multipliers as expected. Dead pools
    follow through larger litter inputs, with no change to decay.
  - **Reference year (the main trap):** the growth curves are fitted to FIA plots, so they already hold the CO2 of those measurements.
    The reference must be the CO2 of the plots' measurement years, not preindustrial, or the effect is counted twice. Before that window the
    multiplier falls below 1, so decide whether it applies in the historical period too, and test the stage 13 hand-over.
  - **No overlap found in the climate terms, to confirm:** the tree-ring response comes from standardized ring-width indices, whose long-term
    trend is largely removed, and Miami NPP is a climatology with no CO2 term. Check that the standardization used does remove it.
  - **Beta is the uncertainty, so run it as a range:** FACE experiments gave about +23% NPP in young stands at about 550 ppm (Norby 2005;
    beta about 0.6), but the response faded under nitrogen limitation (Oak Ridge; Norby 2010), mature stands responded little or not at all
    (EucFACE; Ellsworth 2017, Jiang 2020), and tree rings often show better water-use efficiency without more growth (Penuelas 2011, van der
    Sleen 2015). Choices: one beta with low/central/high cases (0 = today), or by functional type. Possible refinements: lower in mature
    stands, on nitrogen-poor sites, and for C4 grasses, with more response where water limits growth.
  - **Size against the climate signal:** at about 530 ppm by 2050 (to check against the SSP table) from a 400 ppm reference, beta 0.3 gives
    about +8% and beta 0.6 about +17%. Puget's forest climate multipliers in 2041-50 are 0.90-0.94 (results 30, 32, 33), so the same size and
    able to change the sign of a growth trend.
  - **Inputs and options:** CO2 by year from observations (NOAA) and the SSP concentrations (Meinshausen 2020), shipped in defaults/climate
    with citations, so no download. Climate Options gets a CO2 effect (None by default, so results do not change) and beta. Stage 11 reads
    the run's SSP. A run with no climate (constant climate) needs a stated choice: probably no CO2 either.
  - **Testing:** FIA remeasurement failed a placebo test for annual climate sensitivity (defaults/climate/README.md), so it is unlikely to
    isolate a CO2 trend. Report results as a sensitivity range, with the unit tests checking the multiplier against hand values.
  - **For the user to decide:** whether it applies in the historical period; which betas; whether beta varies by stand age or type.

47. **Example libraries by region and resolution** - TO DO, idea stage (user, 2026-11-04; replaces item 13). A range of libraries, already
    run and able to be rerun, covering different regions and resolutions. Users pick the one that matches their interest: geography, land
    cover, major transitions or model resolution.
  - **No separate demo code (user):** each library is a data release (stage 17), whose archive is a `.ssimbak` of the whole library, with its
    tables, maps, figures, metadata and rerun instructions.
  - **Must pass first:** restore an archive into a new library and run a parent scenario, ideally on another computer (user: later).
    tests/phaseZ-data-release.R only checks that the `.ssimbak` exists, so `how-to-rerun.txt` is unproven. The archive holds no Data Sources
    Home inputs, so the test should also show what can rerun without a Data Download.
  - **Keeping them current:** each library is tied to a package version and carbon method, so items 39 and 46 date them. Build the full set
    after the open science items settle, with one or two until then, and treat each as a fixed, versioned release that states its package version.
  - **Catalog:** one page or table: region, resolution, main land cover, main transitions, fire or not, run years, scenarios, download size,
    package version. Fill it from each release's model record and contents where they hold the fields (not yet checked).
  - **A possible first set (to decide):** P26 Northern Sierra Nevada (fire, forest; matches the guide; built and run), Puget Lowlands (urbanization,
    harvest, marine climate, no fire; built), one region at a second resolution (needs a build), and a region outside the West, such as agriculture
    or southeastern plantation forestry (needs a build, and tests the package beyond the western regions it has run on).
  - **Size and hosting:** Puget's archive was 3.6 GB before its projections, over GitHub's 2 GB limit per release file, so host on ScienceBase
    or similar. A coarser version of a region could be the small entry point; a results-only download would be a new stage 17 option.
  - **For the user to decide:** which regions and resolutions; whether each is a formal USGS data release with its own review, or some are
    informal examples; where the catalog lives.

48. **Say gNATSGO, not gSSURGO, throughout the package** - TO DO (user, 2026-11-04). The soil data the package reads and downloads is gNATSGO
    (gSSURGO with its gaps filled), and some labels already say so (Soil Organic Carbon list, Data Sources page), but gSSURGO remains elsewhere.
    Git grep counts: src 31 (3-carbon-flows 12, 8-initial-stocks-spatial 6, 5-initial-conditions 4, calibrate 4, dom 2, figures 2,
    download-sources 1), guide 8, docs/carbon-assumptions.md 4, README 3, docs/carbon-build-process.md 2, tests 10, tools 2, defaults 4, package.xml 1.
  - **It reaches outputs, not only comments:** run log lines (stages 3, 5, 8) and the SoilSource text in stage 3's rate table
    ("Forest type median (no gSSURGO target)"), so results run after the change read differently from older ones. Numbers do not change.
  - **Check before changing:** the text match on the Soil Organic Carbon choice in src/3-carbon-flows.R (line 186) still works; tests that
    match the old wording; and keep the mentions that are correct: package.xml's "gSSURGO also reads" (a gSSURGO file still works) and
    data-sources.csv's "gSSURGO with its gaps filled". Done when the only gSSURGO left describes that relationship. Mirror any guide change in docs/guide/source.
  - **Timing:** src/ and package.xml edits wait until no run is going.

49. **Test national mode end to end** - TO DO (user, 2026-11-04; carried over from item 44). Fill a national home (about 175 GB, overnight; MRLC
    served about 1.3 MB/s), then run stage 1 on P26 and P29 against it. Done when both pass and their study areas match the same regions built
    from regional downloads; report what differs. Needs enough free disk and an overnight window, and RCMAP still comes by hand (see <home>/supplied).
