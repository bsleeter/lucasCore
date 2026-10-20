# Spin-up defaults

`return-interval.csv`: historical disturbance return interval (years) per ecodivision x forest state class, from the LANDFIRE mean
fire return interval (LC16_FRI_200, most common value over the class's area) computed by the earlier FIA-update workflow
(`F:/lucas-builder/Data/LUCAS Carbon Budget Model/Spinup FIA Update.csv`, 67 cells). Cells not listed take the median of their state
class, then the median of all cells. Provisional: stage 5 recomputes every cell from the LANDFIRE map and the stage 5 forest type map.
Spin-up disturbances: historical = Fire: High Severity; most recent = a fitted mix of high-severity fire and clearcut (stage 3b).

`soil-targets.csv`: mean gSSURGO soil organic carbon (Mg C/ha; `gssurgo_soc_0_999.tif` x 0.01, zeros = unmapped) per ecodivision x
forest state class, over the 1 km cells of the CONUS 1km model's forest type map (`ForestTypeGroupFilled.tif`); 173 cells, median 82,
up to 1,099 on organic soils. Stage 3b fits each cell's soil decay so the belowground pools, averaged over the disturbance cycle, match
it; cells not listed take their forest type's median soil multiplier. FIA soil carbon is not used (user 2026-10-20: not reliable).
Provisional: stage 5 recomputes the targets from its own forest type map at the model's resolution.
