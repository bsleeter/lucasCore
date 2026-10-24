# UI improvements (to do later)

Ideas for the lucasCore pages in SyncroSim Studio, collected during the P26 user-guide walkthrough. Newest last.

1. **Data Sources page** (Project properties > Advanced > LUCAS Core > Data Sources). Group the fields by data category (land
   cover, forest inventory, disturbance and fire, climate, soils and terrain, ownership and infrastructure, study-area polygons)
   instead of one long list, and give each source a link to where the data can be downloaded. Needs a custom view
   (`ui/DataSourcesView.cs`, like BuildOptionsView) over the single-row `lucasCore_DataSource` sheet; the URLs can live in the view or
   in a defaults table. (2026-10-23)
2. **Data Sources: show the default paths.** A blank field means "use the package default" (the column's defaultValue in
   package.xml), but the page shows nothing, so a new library looks unconfigured. Show the default greyed in each blank field, or
   write the defaults into the sheet when LibrarySetup fills a new project. (2026-10-23) **Done for new libraries** (2026-10-23):
   LibrarySetup writes the package's default paths (defaults/library/project/lucasCore_DataSource.csv); a path check or browse
   button per field is still open.
3. **Build Options: rename "Run a projection".** It runs nothing in the Build; it prepares the Build for projections (stage 7's
   LOCA2 multipliers, and the horizon the Projection Setup reads). Something like "Prepare for projections, to year". (2026-10-23)
4. **Model design, not just UI: a projection's climate is fixed in the Build.** Stage 7 computes the LOCA2 multipliers in the Build,
   so each SSP / climate model needs its own Build. Moving the LOCA2 part of stage 7 into the Projection Setup would let one Build
   serve several climate futures. (2026-10-23)
