# User Guide wording for lucasCore 2.0.3: mortality and climate (draft)

Draft text for the live User Guide. Nothing here is in the guide yet.

## "Where the pages are" table

Add one row under **Projection**, after Climate:

| Page | What it sets | Read by |
| --- | --- | --- |
| Projection > Mortality and Climate | On a Projection Climate scenario: how strongly severe mortality blocks are placed in the dry periods of the climate run, and how much the rate rises in them | Stage 11 |

Projection > Mortality gains one setting, Timing and Amount.

## Section 3.9, Drought and insect mortality: new subsection "Exploring a climate response"

**What the record supports.** In a projection the event continues at the rates of the record, in blocks of historical
years, and by default the blocks fall with no regard to the climate of the projection. We looked for a climate signal in
the record of 1991 to 2022 across 35 western pyromes. It is there, but weak: dry years have somewhat more mortality than
wet ones when all pyromes are pooled, and a single region's record cannot rank its own years. That is not enough to
calibrate a response. Two settings let you explore one instead.

**How to switch it on.**

1. On the Projection Setup's page Projection > Mortality, set Timing and Amount to "From the Projection Climate result",
   and run the setup. The setup still draws the blocks and still holds no climate, so it serves any number of climate
   futures. A library made before lucasCore 2.0.3 lacks the names this needs, and the setup stops and says so: close
   the library in SyncroSim, run `tools/add-definitions.R` on it once, and run the setup again.
2. Make the Projection Climate scenario depend on the Build result and, below it, on that Projection Setup result.
3. On the Projection Climate scenario's page Projection > Mortality and Climate, give one or both settings, and run it.
4. Make the projection depend on the setup and the Projection Climate result as usual.

Every projection from a setup switched this way needs a Projection Climate result made this way. Without one ST-Sim stops
and says a distribution has no external variable values. With both settings blank the blocks stay as the setup drew them.

**Timing strength (0 to 1).** The blocks an iteration drew are placed in time so that the more severe ones tend to fall
in dry periods. At 0 they stay where they were drawn. At 1 the worst block always falls in the driest period. Each
iteration keeps exactly the years it drew, so the amount of forest it loses does not change, only when it loses it. A
value near 0.3 is about what the record shows.

**Increase in dry periods (percent).** The rate of a year is raised by this percentage, scaled by how deep the dry period
is. Depth 1 is a dry period as deep as the deepest one in the climate run's own historical years; a year half as dry gets
half the percentage; a wet year is unchanged. Depth is held at 2, so the largest increase is twice the percentage. With
this setting, climate runs with more or deeper dry periods have more mortality. It is an assumption to explore: the
record does not tell us what the value should be.

**What "dry" means here.** Dryness is measured from the chosen LOCA2 run: the yearly water deficit of the forest open to
the event, averaged over the 7 years ending in each year, and compared with the 30 years around that year. A dry period
is one that is dry against its surrounding years. A climate that dries steadily does not, by that alone, count as a dry
period: the forest is taken to adjust to the climate it has had.

**Where to see the result.** The stage 11 log has lines beginning "Mortality and Climate". Projection Results > Mortality
and Climate by Year lists, for each projection year, the water deficit, dryness, depth, the multiplier on the rate, and
the mean rate as drawn and as placed.

**Limits.**

- With only the timing strength, a climate run with more droughts gets the same total mortality, placed differently.
- Some regions' outbreaks followed a dry period by several years (the Colorado Rockies in 2007 to 2012). The placement
  has no lag: we tested lags of 0 to 10 years and none did better across the West than no lag.
- Dryness is one series for the study area.
