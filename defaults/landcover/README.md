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
