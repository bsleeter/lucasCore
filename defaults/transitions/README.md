# Historical transitions (stage 6)

- `pathways/*.csv`: ST-Sim transition pathways, one file per set (urbanization, intensification, harvest, fire, ag expansion, ag
  contraction). Copied unchanged from `Data/Transition Pathways/Transitions - <Set>.csv`, the six sets the CONUS 1km
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
  - `NlcdPersist`: NLCD classes the modal annual NLCD shows in year-1 and year; on where it does. Forest Return and Shrub Return
    (to-do 57) return a disturbed cell in the second year NLCD shows its type; Reforestation (41-43, not 90) takes a natural
    non-forest cell to forest the same way. Only cells with a pathway can use the map.
    Forest Return has a second witness (2026-11-15, `src/post-disturbance.R`): a cell most of whose LANDFIRE 2016 pixels are a tree
    type (`evt2016-tree-classes.csv`: the classes of LANDFIRE EVT 2016 whose lifeform is Tree, the three "Recently ..." classes left
    out) and whose forest loss came at least 15 years before 2016 is also on, in the year 15 years after the loss. NLCD is slow to
    call slow-growing regeneration forest (Yellowstone's 1988 burn: 2% forest in NLCD 2016, half trees in LANDFIRE 2016).
  - `All`: on everywhere (Post-disturbance: Conversion; the pathways' age limits decide).
  - `WaterChange` (to-do 2, `src/water-change.R`): change among water, wetland and barren. A 30 m rule: USGS DSWE annual open water (Data
    Source `DsweFolder`) says whether a pixel is water beside wetland (a change must hold 5 clear years); elsewhere the annual NLCD decides alone (a pixel turns to water
    or back in the first of two years running the NLCD says so, user 2026-11-26), and the annual NLCD says what the land side is. `Classes` are the rule's change codes (1 to water,
    2 water to wetland, 3 water to barren, 4 wetland to barren, 5 barren to wetland). Each cell gets the share of its 30 m pixels with
    the change that year; whole cells are then taken by rank, largest share first, until the year's 30 m area is met, and written as 1 / 0
    (as drought and insect mortality, user 2026-11-25), so the area follows the 30 m rule and every iteration is the same. A cell is
    taken only where its class has the pathway (`pathways/wetland-change.csv`) and no other transition is on it that year; area flagged
    on cells with no pathway lands on the next-ranked cells that have one (but is dropped on cells of a class outside these transitions,
    such as cropland: change in and out of agriculture belongs to the land-use sources, user 2026-11-25), and what does not fill a cell carries to the next year. The
    An upland forest, shrub or grass cell can become water as well (a new reservoir, user 2026-11-26), but only in a year at least half
    its pixels turned to water; a strip of shoreline in such a cell is dropped. The
    two emergent wetland types share codes 2|5 and stage 6 gives each the cells whose nearest wetland type (stage 5) is its own. With no
    DSWE files the source is left out and the types keep a zero target.
- `pathways/reforestation.csv` (2026-11-12, `tools/make_reforestation.R`): Barren, the sage family, Non-sage, Chaparral, the grass
  classes and Palustrine Emergent to every forest class, one type per forest class, age reset. Stage 6 gates each type to stage 5's
  ReforestType map (the forest type every cell would reach), as NaturalVeg gates Ag Contraction; Reforestation Options off drops the
  source (zero target).

MTBS and LANDFIRE give each cell the fraction of its 30 m pixels that had the disturbance (over the same aggregation blocks as the NLCD),
so the expected area matches the 30 m area. Within a source with several groups (fire severities), the cell's whole fraction goes to its
most common group: ST-Sim lets a cell make one transition per timestep, so separate fractions would compete and under-burn.

Every group with a source gets a multiplier in every year (an all-zero raster when nothing happened), the start year, and the year after
the end year. Every pathway type with no time-varying source gets a zero transition target (a type with no multiplier and no target would
run on every eligible cell). Types in the harvest set with no source (Selection 20%, Salvage Logging) get zero targets.
