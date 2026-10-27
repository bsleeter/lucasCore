# UI improvements

Ideas for the lucasCore pages in SyncroSim Studio, collected during the P26 user-guide walkthrough. Newest last.

## Priorities (2026-10-25)

The open items (6-14) in order. What drives the order: some items change the model itself (its inputs or its results), and anything
built on P26 (the guide's numbers and figures, the demo bundle, metadata) should come after those are settled.

| Order | Item | Why here | Depends on |
| --- | --- | --- | --- |
| ~~1~~ | ~~11 LOCA2 list scan (the scan part)~~ | DONE 2026-10-26, verified in Studio | - |
| ~~2~~ | ~~7 Spatial multiprocessing in the Build~~ | DONE 2026-10-26 | - |
| ~~3~~ | ~~8 Area-preserving resampling~~ | DONE 2026-10-26 (Build Options choice; a P26 Area-matched comparison run is optional) | - |
| 4 | 9 FIA plot data | Largest change to the model's inputs (curves, carbon); must reproduce the .Rds results before it becomes the default | - |
| 5 | 10 TreeMap option | Same domain as 9 (FIA plots, forest type, age); an option, so it changes results only if made the default | 9 helps (FIA plot ids) |
| 6 | 12 Data Download stage | Needs the final dataset list (9 and 10 add or replace sources); its LOCA2 download refreshes the lists through 11 | 9, 10, 11 |
| 7 | 13 P26 demo bundle | Needs 12's layout and manifest, and a frozen P26 rerun after 8, 9 and 10 | 12; 8, 9, 10 |
| 8 | 14 FGDC metadata | The model record needs the final input list and 12's manifest, and ships with 13 and P26 data releases; the output-metadata stage can start earlier | 12, 13 |
| any | 6 Images viewer for figures | UI convenience, independent of the rest | - |

While 8-10 are open, the guide's procedures (chapters 6-10) can still be written: the steps do not change, only the P26 numbers and
figures, which are redone once after the P26 rerun.

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
6. **Build Figures in Studio's Images viewer** - TO DO. Stage 12's PNGs are only a table of files (Build Results > Build Figures) plus a
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
9. **FIA plot data instead of the prebuilt USGS tables** - TO DO (user, 2026-10-25). Stages 2-4 fit growth curves, carbon parameters
   and decay calibration from two condition-level tables the user supplied (Data Sources: FIA Condition Carbon and Merchantable Volume,
   `USGS_carbon_density_and_merchVol_on_forest_conditions_CONUS_20240212.Rds`, and FIA Condition Disturbance and Treatment Codes,
   `USGS_forest_conditions_dstrbcd_and_trtcd_20240213.Rds`). Another user has no such files. Planned: read the FIA DataMart directly
   (the state COND, PLOT and TREE tables, or FIADB SQLite), filtered to the study area's states and the inventory years, and derive the
   same fields the .Rds tables carry (condition carbon by pool, merchantable volume, stand age, forest type group, DSTRBCD/TRTCD). Keep the
   .Rds route as an option, and check that the derived tables reproduce its P26 and CONUS curves before switching the default.
10. **TreeMap for forest type group and stand age** - TO DO (user, 2026-10-25). Today the forest type comes from LANDFIRE EVT or the USFS
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
12. **Data Download stage: fetch the Data Sources for a region** - TO DO (design agreed with the user, 2026-10-25; not started).
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
13. **P26 demo data bundle** - TO DO (user, 2026-10-25). A stand-alone, shippable set of the input data for the P26 Northern Sierra
   Nevada example, so a new user can install lucasCore, unzip the bundle and follow the guide end to end without downloading anything.
   A one-off for a reproducible example, not part of the model or the package.
   - **Contents**: every Data Sources input the P26 Build, historical run, Projection Setup and Projection Climate read, clipped to P26
     plus a buffer (the same rule as item 12, so the fitting region, pyrome and edge effects are covered): Annual NLCD, LANDFIRE EVT /
     disturbance / FRI / elevation / roads, RCMAP, C-CAP, forest type groups, CMS stand age, MTBS, LCMS, NIFC perimeters, FSim, FPA-FOD,
     PRISM, gSSURGO soil carbon, NCCPI, WUI, forest ownership, the strata layers (ecodivisions, counties, federal lands, pyromes), and the
     FIA condition tables cut to the plots P26's curves use (CA/NV, or the ecodivisions it touches). LOCA2: a small set (e.g. one or two
     models, SSP2-4.5 and SSP3-7.0, one member) rather than all ten.
   - **Layout**: the item 12 home-folder layout and manifest, so the bundle drops in as the Data Sources Home and every path resolves
     with nothing to browse to. If item 12 is not built yet, ship with a short script or a library already pointing at the folder.
   - **Built by a script** (e.g. tools/make-demo-bundle.R, outside the package's stages): reads the P26 extent, clips each source from the
     developer's national copies, writes the layout + manifest, a README (what each file is, source, vintage, citation, licence/terms),
     and checks that a fresh library built from the bundle alone reproduces the P26 Build (same state class areas and initial carbon).
   - **Optional extras**: the finished P26 Demo Library (Build, historical run, figures) for users who only want to explore results;
     the guide's screenshots refer to it.
   - **Packaging and hosting**: one zip (or a few), size to measure; GitHub release assets are capped at 2 GB per file, so a larger bundle
     goes to a data repository (Zenodo, ScienceBase) with a DOI, linked from the README and the guide's chapter 1. Check each dataset's
     terms allow redistribution of a clip, with attribution.
14. **FGDC metadata for the model and its outputs** - TO DO (user, 2026-10-25). Completed runs need FGDC-compliant metadata (CSDGM,
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
   - Fits with item 13: the P26 demo bundle and a data release of P26 results would ship with these records.
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
17. **Run Figures: a comparison set for several futures** - TO DO (user, 2026-10-25). Today's Run Figures describe one run (a projection
   is joined to its historical run). Comparing futures (normal climate, SSP2-4.5, SSP5-8.5, or different land-use rules) needs its own
   set, built on dev/figures/compare-futures.R. Planned, in stage 13: the Run Figures page takes several runs, each with a label, plus a
   reference run (default: the first); one run = today's set, several = the comparison set. Contents: (1) total ecosystem carbon and its
   cumulative change since the projection start, one line per future, history once; (2) NPP, Rh and NBP per year plus cumulative NBP;
   (3) carbon by pool at the end year, grouped bars; (4) transitions per year by family per future (a check: identical when futures
   share a Projection Setup); (5) end-year carbon difference maps against the reference; (6) mean NPP difference maps over the last
   decade; (7) a summary table per future (end carbon, cumulative NBP, NPP mean and spread, burned and harvested area, differences from
   the reference). With Monte Carlo iterations: means with bands, and maps of the mean difference with its sign agreement.
18. **Spin-up and decay calibration choices in the UI** - TO DO (user, 2026-10-26). The dead-matter calibration (stage 3) and spin-up
   (stage 4) rest on assumptions a user should be able to see and set, in a Carbon Options group (or its own page): (a) the calibration
   targets - FIA's measured down woody material pools (coarse and fine woody debris, litter, duff, standing dead) or the condition
   table's modelled down dead and litter; (b) the stand ages fitted - mature stands only, from a minimum age (60 years by default; the
   user expects it to vary by forest type eventually), excluding conditions with a recorded fire or harvest in the past N years; (c) the
   spin-up's last disturbance - high-severity fire (default, as the old LUCAS spin-up), clearcut, or a mix; (d) the **fire return
   interval** of the spin-up cycles - today each cell's LANDFIRE FRI_REPLAC (stage 5), to be shown and overridable (per forest type or
   a single value); (e) the pool groupings matched to FIA (src/dom.R FIA_DOM), at least documented on the page. Young stands are a
   check on the disturbance flows (fire and harvest event flows), not a calibration target. Design and dev results: dev/nfcms and
   dev/fia FINDINGS.md.
19. **Dead organic matter calibration from measured FIA data** - PROPOSED 2026-10-26 (user asked for the write-up). Calibrate decay to FIA's
   measured down woody material pools in mature stands, fix snag fall from remeasured dead trees, use fire as the spin-up's last
   disturbance, and fit the high-severity fire and clearcut event flows to plots after those events. Proposal, results on P26 and
   implementation plan: docs/dom-calibration-proposal.md; evidence: dev/fia (scripts 05-15) and dev/nfcms. UI choices: item 18.
20. **Turnover and DOM rate table a user can view and override** - TO DO (user, 2026-10-27). Pick a region (ecodivision) and forest
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
