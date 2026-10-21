# Historical transitions (stage 6)

- `pathways/*.csv`: ST-Sim transition pathways, one file per set (urbanization, intensification, harvest, fire, ag expansion, ag
  contraction). Copied unchanged from `F:/lucas-master/Data/Transition Pathways/Transitions - <Set>.csv`, the six sets the CONUS 1km
  build merged into its historical model. Stage 6 reads every file in the folder, so adding a set (insects, prescribed fire, succession,
  wetland change are still in the source folder) means copying it here and giving its groups a source.
- `state-locations.csv`: each state class's place in the ST-Sim pathway diagram (`stsim_DeterministicTransition`). From `States.csv`.
- `sources.csv`: where each transition group's spatial multiplier comes from. One row per group; `Classes` is `|`-separated:
  - `NlcdGain` / `NlcdLoss`: NLCD classes the modal annual NLCD (stage 5, on the model grid) gains or loses between year-1 and year.
    The multiplier is 1 where the cell changed. Land-use change is mapped where the cell's modal class changes, the same rule as the
    state class map.
  - `NaturalVeg`: a named group; each of its types may reach only the nearest natural state class of the start year (state class map
    with developed, agriculture, water, ice and barren removed and filled from neighbours). One multiplier per type, in the start year.
  - `Mtbs`: MTBS burn severity values (1 unburned to low, 2 low, 3 moderate, 4 high; 5 increased greenness and 6 non-mapping are
    ignored). Class 1 counts as low severity, as in the CONUS 1km build; it is mostly unburned ground inside fire perimeters, so
    dropping it from the low row would cut the low-severity area substantially.
  - `NlcdClearcut`: `from>to` classes of the modal annual NLCD (model grid) between year-1 and year, where less than half the cell
    burned (MTBS fraction) in either year. Mapped on the same NLCD as the state class map, so every clearcut cell was forest in some
    year and is a forest class; only the pathway minimum age can stop it (and stage 6 raises the age of cut cells to that minimum in
    their first clearcut year). A first version used 30 m fractions: 24% of the area fell on cells whose modal class was never forest
    and 35% on stands younger than the minimum age, so ST-Sim could realize only 42% of it. The user chose coherence between the maps
    over matching the 30 m area (2026-10-20).
  - `Landfire`: LANDFIRE annual disturbance types (the `DIST_TYPE` column of each year's attribute table, so the coding changes in 2024
    do not matter). Years with no LANDFIRE folder (before 1999) get no transitions.

MTBS and LANDFIRE give each cell the fraction of its 30 m pixels that had the disturbance (over the same aggregation blocks as the NLCD),
so the expected area matches the 30 m area. Within a source with several groups (fire severities), the cell's whole fraction goes to its
most common group: ST-Sim lets a cell make one transition per timestep, so separate fractions would compete and under-burn.

Every group with a source gets a multiplier in every year (an all-zero raster when nothing happened), the start year, and the year after
the end year. Every pathway type with no time-varying source gets a zero transition target (a type with no multiplier and no target would
run on every eligible cell). Types in the harvest set with no source (Selection 20%, Selection 85%, Salvage Logging) get zero targets.
