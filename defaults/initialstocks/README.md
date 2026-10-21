# Initial stocks (stage 8)

- `stock-types.csv`: the 14 ST-Sim stock types, the "Carbon Initial Conditions" attribute name each has in the tables below, and its
  column in stage 4's Initial Stock Curves.
- `wetland-forested-fire.csv`, `wetland-forested-harvest.csv`: forested wetland pools by class and age, last disturbance fire / harvest.
- `grassland-shrubland.csv`, `emergent-wetland.csv`: grass, shrub and emergent wetland pools by class.

All four are the CONUS 1km build's tables (`F:/lucas-master/Data/State Attributes/State Attributes - Initial Stocks *.csv`), from its
non-forest spin-up with the same non-forest flows stage 3 copies. Forest pools come from stage 4. Developed, agriculture, barren, water
and ice start at zero except soil (belowground slow), which takes gSSURGO wherever a class's value is zero.
