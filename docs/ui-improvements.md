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
