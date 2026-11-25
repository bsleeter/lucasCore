# LUCAS contribution to the AGU poster

For "USGS Western Geographic Science Center: A Leader in Interdisciplinary Federal Science". Project: the Land Use and Carbon
Scenario Simulator (LUCAS) and the lucasCore software. Contact: Benjamin M. Sleeter, USGS Western Geographic Science Center.

## 1. Image and caption

Image: `agu-poster-lucas-figure.pdf` (vector, for print) or `agu-poster-lucas-figure.png` (6000 x 2940 px). It is 20 x 9.8 in,
landscape, sized to sit in a 21 x 13 in panel with the text below.

**Caption.** LUCAS in the Southern Sierra Nevada, California, 1985–2023. (a) LUCAS draws on forest inventory, satellite,
climate, soils and land-use data. (b) Land cover in 2023. (c) Highest severity at which each cell burned; 30% of the area
burned at least once. (d) Change in ecosystem carbon (live plants, dead wood, litter and soil). (e) The region gained 20 Tg C
by 2011, then lost two-thirds of that gain to drought and fire; carbon in dead wood grew by half. (f) Plant carbon burned,
killed or harvested each year: the 2020 fires burned or killed 14 Tg C, about ten times the 2016–2019 drought die-off.
(g) Carbon in live plants, dead wood and litter as a share of the carrying capacity, the 212 Tg C the land would hold under
its natural vegetation and fire regime: 85% in 1985, 95% in 2011 and 88% in 2023, with over half of the remaining gap on land
recovering from disturbance. Provisional model results (lucasCore 2.0, 300 m cells, one simulation).

## 2. Summary of the project

How much carbon do U.S. lands hold, what is changing it, and what could it be under different futures? LUCAS answers these
questions with a map-based model that follows land cover, stand age, disturbance and carbon in every cell of a region, every
year. It reconstructs history from 1985 to the present from observed land-cover change, wildfire, harvest and drought
mortality, then projects forward under climate and land-use scenarios. The lucasCore software builds a LUCAS model for any
region of the conterminous United States, from a national park to a state, directly from national datasets. Land managers
and carbon accountants get maps and annual accounts of carbon stocks and fluxes, with each loss traced to its cause.

## 3. Summary of novelty and innovation

- **A model built from national data, anywhere.** A user names a study area and a cell size; lucasCore downloads the national
  datasets, fits growth and decay to local forest inventory plots, and assembles a model ready to run. Work that used to take
  months of hand assembly per region is one repeatable build.
- **A carbon carrying capacity.** Each cell's carbon is compared with what the land would hold under its natural vegetation
  and fire regime, so a region's history and its projections are read against one fixed yardstick, and the gap is split by
  cause: land use, disturbance, stand age.
- **Drought and insect die-off as its own event.** Tree mortality without fire or cutting is mapped from satellite records of
  canopy loss and calibrated to forest inventory remeasurements, so it can be weighed against wildfire and harvest.
- **Every result traceable.** Each model records the datasets, versions and checksums it was built from, and can publish
  itself as a documented data release.
- **Open and reusable.** lucasCore is an open USGS software release that runs in SyncroSim with the ST-Sim state-and-transition
  model, so partners can run, inspect and extend the same model.

## 4. Summary of the interdisciplinary aspect

LUCAS is where several fields' data meet in one account. Forest ecology supplies growth, mortality and carbon pools from U.S.
Forest Service inventory plots. Remote sensing supplies four decades of land cover, burn severity, harvest and canopy loss
(Annual NLCD, LANDFIRE, MTBS, LCMS). Fire science supplies natural fire regimes and burn probability. Climate science supplies
observed weather and downscaled projections (PRISM, LOCA2) that drive growth and decay. Soil science supplies soil carbon
(gNATSGO). Economics and demography supply land-use demand and population scenarios. Carbon accounting methods from the
Canadian forest sector (CBM-CFS3) tie the pools together, and software and data science make the whole reproducible. The
result serves ecologists, fire managers, land-use planners and greenhouse gas inventory teams from one consistent model.

## Notes for the poster author

- Results shown are provisional and come from one region and one simulation; a methods paper is in preparation.
- The figure's example region can be changed; the script that draws it runs on any LUCAS historical run.
- Software: Sleeter, B.M., 2026, lucasCore: a SyncroSim package that builds LUCAS land-use and carbon models, U.S. Geological
  Survey Software Release, https://code.usgs.gov/LUCC/lucasCore.
