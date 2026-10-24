# UI improvements (to do later)

Ideas for the lucasCore pages in SyncroSim Studio, collected during the P26 user-guide walkthrough. Newest last.

1. **Data Sources page** (Project properties > Advanced > LUCAS Core > Data Sources). Group the fields by data category (land
   cover, forest inventory, disturbance and fire, climate, soils and terrain, ownership and infrastructure, study-area polygons)
   instead of one long list, and give each source a link to where the data can be downloaded. Needs a custom view
   (`ui/DataSourcesView.cs`, like BuildOptionsView) over the single-row `lucasCore_DataSource` sheet; the URLs can live in the view or
   in a defaults table. (2026-10-23)
2. **Data Sources: show the default paths.** A blank field means "use the package default" (the column's defaultValue in
   package.xml), but the page shows nothing, so a new library looks unconfigured. Show the default greyed in each blank field, or
   write the defaults into the sheet when LibrarySetup fills a new project. (2026-10-23)
