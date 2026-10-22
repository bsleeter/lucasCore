# Land cover crosswalks (stage 5)

- `evt2016-crosswalk-CONUS-v2.csv`, `evt2001-crosswalk-CONUS-v2.csv`: LANDFIRE EVT values -> LUCAS state class Id (column ID; forest
  type groups 100-999). EVT 2016 pixels named "Recently ..." take the EVT 2001 value. From `Data Sources/EVT`.
- `rcmap-state-class.csv`: RCMAP 2001 vegetation class -> grassland and shrubland state classes (the CONUS 1km build's mapping).
- `ccap-state-class-crosswalk.csv`: C-CAP 2001 classes -> state classes; only wetland classes (>= 90) are used. From `Data Sources/CCAP`.
- `LF16_FRI_200.csv`: LANDFIRE LC16 fire regime table; FRI_REPLAC (replacement-fire return interval, years) gives the spin-up return
  interval. From `Data Sources/FRI/CSV_Data`.

Edits to the source crosswalks:
- 2026-10-20: "California Lower Montane Foothill Pine Woodland and Savanna" (EVT 2016 7114) and "California Lower Montane Blue Oak-Foothill
  Pine Woodland and Savanna" (EVT 2001 2114) moved from Oak/Pine (400, an eastern group) to Western Oak (920). This is blue oak / foothill pine
  savanna, and FIA types it in the western oak group; 2,866 km2 of California changes class.
- 2026-10-21: EVT 2001 "Developed-Upland Deciduous / Evergreen / Mixed Forest" (13, 14, 15) moved from Exotic Hardwoods (990) to
  Developed: Open Space (21), matching EVT 2016, which maps every urban and ruderal forest EVT to 21. Stage 5 takes EVT 2001 wherever
  EVT 2016 is not forest, so town tree canopy became Exotic Hardwoods (81 km2 in the Northern Sierra pyrome); it now takes the
  surrounding forest type. Reviewed and kept (user decision): EVT 7030 "Mediterranean California Lower Montane Conifer Forest and
  Woodland" stays Western Oak (920), following LANDFIRE's own cover type for it (SAF 246 California Black Oak); foothill riparian
  woodland and shrubland (9129, 9629) stay Elm/Ash/Cottonwood (700), the FIA group of western cottonwood-willow stands.
  Script: dev/crosswalk/01-evt-by-forest-type.R tabulates the EVTs behind every forest type in a pyrome.
- `land-cover-crosswalks.csv` (2026-10-21): the four crosswalks in one table (Source, Code, Description, State Class, Note), made by
  `tools/make_landcover_crosswalks.R` from the source CSVs above. It is the default of the scenario sheet **Land Cover Crosswalks**
  (Crosswalks group), which users can edit per scenario; the starter's Build scenario holds it prefilled, an empty sheet uses this
  file. Stage 5 logs every row that differs from this default and checks that every EVT, RCMAP and C-CAP code in the study area has
  a row. That check found RCMAP 1, 10, 11, 12 and C-CAP 0 missing from the source crosswalks (silently unmapped before); they are now
  listed, still unmapped. Source values that are not ST-Sim state classes (EVT 61, 83, 84, 1000, 1001; C-CAP 10-80) are blank with a
  Note; stage 5 never uses them.
