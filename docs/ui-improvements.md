# UI improvements

Ideas for the lucasCore pages in SyncroSim Studio, collected during the P26 user-guide walkthrough. Newest last.

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
7. **Spatial multiprocessing chosen in the Build** - TO DO (design from the user, 2026-10-24; not started). A spatial run is split
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
8. **Area-preserving resampling of land cover** - TO EXPLORE (user, 2026-10-24: accept the modal undercount for now). The 150 m modal
   NLCD keeps 31% of P26's 30 m developed area (22% of open space 21, 49% of low 22, 72% of medium/high): 79% of developed pixels lie in
   cells under half developed, mostly single-pixel roads (5 of a cell's 25 pixels). It also makes developed cells flicker year to year.
   Options to test: class-priority or threshold rules (a cell is developed above some fraction), area-matching allocation (rank cells by
   fraction until the 30 m area is met), or a finer grid. Each must keep the state class map and the transitions derived from the same
   maps ([[coherence over area]]), and be judged on carbon as well as area.
