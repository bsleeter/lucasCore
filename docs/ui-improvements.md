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
