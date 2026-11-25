# LUCAS panel for the AGU poster

Poster: "USGS Western Geographic Science Center: A Leader in Interdisciplinary Federal Science"
Figure: `agu-poster-lucas-figure.pdf` (vector text, for print) or `agu-poster-lucas-figure.png` (6000 x 2940 px).
Size: 20 x 9.8 in, landscape, which leaves about 3 in of a 21 x 13 in panel for the title, summary and caption.

## Panel title

LUCAS: land use, disturbance and climate in one carbon account

## Summary (about 75 words)

How much carbon do U.S. lands hold, and what is changing it? The Land Use and Carbon Scenario Simulator (LUCAS) joins forest
inventory, four decades of satellite records, climate and soils data in one model that follows land cover, disturbance and
carbon in every cell, every year. The lucasCore software builds a LUCAS model for any U.S. region from national datasets, so
managers can compare fire, drought, harvest and land-use change on the same footing.

## Caption (about 110 words)

**LUCAS in the Southern Sierra Nevada, California, 1985–2023.** (a) LUCAS draws on forest inventory, satellite, climate, soils
and land-use data. (b) Land cover in 2023. (c) Most recent year each cell burned. (d) Change in ecosystem carbon (live plants,
dead wood, litter and soil). (e) The region gained 20 Tg C by 2011, then lost two-thirds of that gain to drought and fire;
carbon in dead wood grew by half. (f) Plant carbon burned, killed or harvested each year: the 2020 fires burned or killed
14 Tg C, about ten times the 2016–2019 drought die-off. (g) The land was a net carbon sink in 24 of 38 years. Provisional
model results (lucasCore 2.0, 300 m cells, one simulation).

## Short caption (about 45 words), if space is tight

**LUCAS in the Southern Sierra Nevada, 1985–2023.** (a) Data and model. (b–d) Land cover, fire history and carbon change.
(e–g) The region gained 20 Tg C by 2011, then lost two-thirds of it to drought and the 2020–2021 fires. Provisional model
results.

## Where the numbers come from

Run: library `Pyrome 27.ssim`, Historical 1985-2023 (result 9) on Build result 4, both of 2026-11-24; 25,764 km2; 300 m; one
iteration. `agu-poster-numbers.txt` holds the values the script printed. Redraw with
`Rscript dev/figures/agu-poster/agu-poster-figure.R` from the repository folder.

| Statement | Value |
|---|---|
| Ecosystem carbon 1985, 2011 (peak), 2023 | 318.6, 338.9, 325.4 Tg C (+20.3 at the peak, +6.8 at the end) |
| Live plants 1985, 2011, 2023 | 138.5, 154.0, 135.2 Tg C |
| Dead wood 1985, 2023 | 23.1, 34.1 Tg C (+48%) |
| Fire, 2020 | 234,000 ha; 14.3 Tg C burned or killed, of which 6.8 emitted |
| Drought and insects, 2016–2019 | 1.6 Tg C killed (peak 0.64 in 2017) |
| Net biome productivity | mean +0.18 Tg C per year; positive in 24 of 38 years |
| Area burned at least once, 1986–2023 | 30% of cells |

Panel (f) counts, for each cause, the live carbon the event moved to dead pools plus what it emitted or removed as wood. Fire
emissions include a small share from dead pools.
