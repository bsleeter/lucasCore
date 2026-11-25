# User Guide wording for lucasCore 2.0.2: drought and insect mortality in projections (draft)

Draft text for the live User Guide. Nothing here is in the guide yet. Three places change.

## "Where the pages are" table

Add one row under **Projection**, after Fire:

| Page | What it sets | Read by |
| --- | --- | --- |
| Projection > Mortality | Drought and insect mortality after the historical end: historical rates or off, the years drawn together, its reference years, and how it is placed | Stage 9 |

The Build's page keeps its name and place (Build > Mortality) and its settings.

## Section 3.9, Drought and insect mortality: replace the sentence on projections

Old: "A projection keeps the event off; projected rates are to follow."

New: "A projection continues the event at the rates of the record. See Projections, below."

## Section 3.9: new subsection "Projections"

**What a projection does.** After the historical end the event continues at the rates the Build mapped. It is on by
default in a Projection Setup made on 2.0.2 or later. To switch it off, choose Off on Projection > Mortality.

**How much.** Stage 9 reads the Build's yearly mortality maps and works out, for each historical year, the share of the
open forest that had the event. Open forest is a softwood class that has not had the event and is at or over the minimum
stand age. The shares are kept by unit: each softwood forest type group of each ecodivision, with pinyon/juniper as its
own unit. A unit with under 250 km2 in the study area is too small to have a record of its own and takes the rate of its
ecodivision as a whole.

Each iteration then fills the projection years with blocks of consecutive historical years, five at a time by default.
A block starts at any reference year with the same chance. A block that reaches the last reference year runs on from the
first. Every unit takes the same drawn year, so forest types keep their historical relation to each other.

The drawn share is applied to the forest standing in the projection, not to a fixed area. As forest takes the event the
area falls; as stands regrow past the minimum age it returns.

**The reference years matter most.** The record runs from 1986 to 2023 and its rate has risen. Blank reference years on
the page mean the reference period of Run Settings. The stage 9 log states the mean rate of the years chosen beside that
of the whole record. Read that line before a long run.

**Where it falls.** With Clustered (the default) three things place the die-off. All three are read from the Build's own
maps, and none changes the amount.

1. A surface. Stage 9 fits where the events fell against tree canopy cover, the temperature, precipitation and vapour
   pressure deficit normals, elevation and slope. Each cell gets a weight, averaging 1 inside every unit.
2. Patch sizes. The record's yearly patches (cells that touch, corners included) give the sizes of projected patches, as
   fire's sizes come from fire perimeters.
3. Spread. A cell with die-off within three cells in the three years before is more likely to take the event. Stage 9
   measures by how much, as a ratio to what the rate and the surface alone would give.

A piece the record cannot support is left out and the log says so: the surface needs at least 100 event cells in the
reference years, and the spread at least 30 events near earlier ones. If the Build placed the event as fractions
(Build > Mortality, Fraction as probability) there are no whole cells to read, and the projection places the event at
random.

With Random cells every eligible cell of a unit has the same chance and the event falls as single scattered cells.

**Settings (Projection > Mortality).**

| Setting | Values | Blank means |
| --- | --- | --- |
| In projections | Historical rates, Off | Historical rates |
| Years drawn together | 1 to 50 | 5 |
| Reference years, from and to | Years of the record | The reference period of Run Settings |
| Where it falls | Clustered, Random cells | Clustered |

**What to check after a Projection Setup.** The stage 9 log has lines beginning "Drought and insect mortality". They
give the number of units, the reference years and their mean rate, the mean rate drawn, the surface's skill, the patch
sizes and the spread curve. Projection Results > Projection Rates lists each unit's mean yearly area, and Projection
Schedule lists the years drawn under the sampling set Mortality.

**Maps.** A projection maps the event each year it saves transition maps. Average probability maps over the
iterations are written only if the ST-Sim Spatial Average output option is turned on, as for every other group. A library made on 2.0.0 or 2.0.1 had the event's maps off; a Projection Setup on 2.0.2 turns them on. A
historical run of such a library has no maps of the event unless the group Mortality: Drought and Insects [Type] is
ticked under Spatial on the ST-Sim transition output filter.

**Limits.**

- The rates cannot exceed what the record holds and do not respond to the climate scenario.
- An outbreak still running when the record ends, as in the southern Sierra Nevada, is only partly in the record.
- The patch sizes come from whole model cells, so they depend on the resolution of the Build.
- East of the western ecodivisions the Build maps no events, so a projection there has none.

## Section 1.3 table of versions

Add: "2.0.2: drought and insect mortality in projections (historical rates in blocks of years; a fitted surface, patch
sizes and spread from recent die-off). No library update."
