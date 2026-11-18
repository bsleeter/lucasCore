# UI improvements

Ideas for the lucasCore pages in SyncroSim Studio, collected during the P26 user-guide walkthrough. Newest last.

## Priorities (2026-11-02)

The open items in order. Item numbers are ids and do not change; this table is the order. The rule from 2026-10-25 still holds: items
that change the model itself (its inputs or results) come first, and anything built on P26's results (metadata, the
guide's numbers and figures) after them, so it is redone only once. Within that, quick usability fixes go first.

| Order | Item | Changes results? | Why here | Depends on |
| --- | --- | --- | --- | --- |
| top | 65 Avoided conversion and projected development: scale and steering levers, and four ways to drive how much converts and where (LUCAS only, LUCAS + RPA or ICLUS steering, RPA or ICLUS alone, population-scaled) | Yes, in scenarios that use them | Added 2026-11-14 (user: "save this as a top to-do and pick it up after the Hart Mountain testing is complete"). Plan and decisions in the Avoided conversion doc | Hart Mountain rangeland restoration test |
| 1 | 14 FGDC metadata | No | User order 2026-11-02: first. Plan (a working document, not in this repository) (phases 0-6; decisions settled 2026-11-02: CSDGM first, one release per Build, maps every year, model archive always, ScienceBase folder by hand; Phase 0 done with the user 2026-11-02; Phase 1 built 2026-11-02: defaults/metadata definitions, data dictionary, citations, src/metadata.R, tests/unit-metadata-definitions.R; citation questions in the plan); lineage from the home's manifest and each Build's Data Sources Used | 12 (done) |
| 2 | 39 Grassland, shrubland and wetland carbon: options beyond today's crude method | Yes | User order 2026-11-02: third, with the other open science items (user: explore additional options).  Step 1 (rates on a page) and the diagram view done; the diagram shows emergent wetland rates settling far above their starting pools; suspect values (emergent wetland growth 31, irrigated grass 9.19 Mg C/ha/yr), root turnover splits. Review done 2026-11-06 (dev/nonforest/review). Revised approach accepted the same day: one stage 3 solver (measured stocks as targets, growth from data, rates solved; IPCC, IBIS or data as the target source), IPCC factors for soil change on conversion, carbon for pasture and cropland. Nine steps; step 1, the emergent wetland fix, is next | - |
| next | 53 Forested wetlands as wetland counterparts of three forest type groups (spruce/fir, oak/gum/cypress, elm/ash/cottonwood), with burial, peat fire and drained peat | Yes (woody wetland classes, and the three upland types lose their hydric FIA plots) | Planned 2026-11-09; choices decided 2026-11-10 (other types by region, burial, peat fire now); not started | - |
| later | 54 Climate response for emergent wetland growth | Yes (marsh growth by year, in history and in projections, when turned on) | Added 2026-11-09 (user). Today only CO2 changes marsh growth under alternative climate futures; the response model needs a short review first (item 54) | - |
| later | 55 Grass and shrub stocks fitted to literature (chaparral wood turnover 0.08; non-sage and native sage steppe split by RAP herb share) | Yes | Refit done 2026-11-09 (item 55); left: the RAP tests at the Sky Oaks towers, the foothill chaparral scale | - |
| next | 56 Run Build stages on their own or a few in sequence, each result a dependency of the next | No (the same results, fewer reruns) | Added 2026-11-10 (user), after the Great Dismal Swamp Build failed in stage 8 after 44 minutes and had to be rerun whole | - |
| later | 57 A post-disturbance state for forest: regrowth after a delay, or conversion to non-forest, with adjacency to a seed source | Yes (burned forest waits, returns or converts; carbon of the waiting years) | Added 2026-11-11 (user). P26: about a quarter of single high-severity burns are not forest after 30 years in NLCD, and reburns mostly convert | 58 (developed together) |
| next | 59 Harvested wood products: the fate of the carbon in Forestry Sector, after a run (stage 18, not spatial) | Yes, in reporting (wood products pools and their emissions; an NBP that counts storage in products). The ST-Sim runs do not change | Added 2026-11-11 (user). Forestry Sector has no flows out today, so harvested wood is stored forever | Steps 1-5 done outside Studio (tables, model, stage 18, Run Figures and Compare Runs, P26 and Puget results, guide section 7.5); left: run inside Studio, guide screenshots, the 1.4.0 release |
| later | 58 Management and mitigation for disturbed forest: replanting and restoration, salvage, site preparation, fuel treatments | Yes, in scenarios that turn them on | Added 2026-11-11 (user). Developed with 57 so its structure takes these actions | 57 (developed together) |
| next | 64 Guards against Build failures when a transition never occurs in the study area | No (Builds that now fail complete) | Added 2026-11-14 (user), after the Hart Mountain Build failed in stage 6 with no harvest in the area | 60 (the projection side, done) |
| next | 63 The Build turns on tabular States and Transitions output by default (without ages) | No (which outputs a run saves) | Added 2026-11-14 (user): today ticked by hand in Studio; the scripts already set it | - |
| release | 46 CO2 fertilization | Yes, in projections with a Projection Climate result (Central by default; None turns it off) | Added 2026-11-04; built, tested (Puget run, age-band check), documented (guide 7.3.1) and pushed 2026-11-06. Left: a release | - |
| later | 47 Example libraries by region and resolution | No (each holds its own results) | Added 2026-11-04, replaces 13. Best built after the open science items, since each carbon change dates them | 14, restore test |
| any | 49 Test national mode end to end | No | Added 2026-11-04. Never run end to end; fills about 175 GB overnight | 12 (done) |
| next | 51 After the 1.1.0 release: P26 rebuild and rerun (moved and synced 2026-11-06), Puget parents to Build 58, guide sections, code.usgs.gov resync, safeguards | Only the P26 rerun | Added 2026-11-05: what the release left | 43 (done) |
| open, paused | 50 Water, wetland and barren change | Yes (historical and projected land change, wetland carbon) | Added 2026-11-05. Not modelled today; P26 swaps about 150 km2 each way between water and land (reservoirs), Puget has river bars, ponds and shoreline wetland change | - |
| later | 66 Marsh elevation for tidal marsh methane (a relative tidal elevation map, as salinity came from LANDFIRE) | Yes (methane of oligohaline marsh outside the Gulf and South Atlantic) | Added 2026-11-16 (user: "mark the tidal elevation map as future work in this branch"), on the wetland methane branch. In cooler regions high marsh emits a tenth of low and mid marsh; the model uses one site-weighted value | The wetland methane branch (marsh salinity, stage 8) |
| later | 67 Monthly temperature for the wetland Q10s and the marsh growth response | Yes (methane, wetland soil CO2 and marsh growth in years and places with warm summers) | Added 2026-11-16 (user), on the wetland methane branch. The multipliers use the annual mean temperature, which understates a curved response | PRISM monthly mean temperature in the Data Download |

Finished items were removed from this list on 2026-11-05 at the user's request: 1-12, 15-25, 28-30, 32, 34, 35, 37, 40, 41, 42, 43, 45, 48 (42 the Fill prompt's grassland table names and 48 gNATSGO wording, both done 2026-11-05; 43 the historical land-use and harvest shortfall, verified on Puget and released in 1.1.0, its follow-ups in 51; item 10 went into 35; the text is in git history). Removed by the user without being done: 13, the Calaveras demo bundle (which library serves as the demo is undecided, not Puget, which has no fire), and 26, 27, 31, 33, 36, 38, 44.
Pushed: everything through the v1.1.0 release (2026-11-05: land-use transitions by class pair, Ag Change, targets from a historical run, USGS release files, data release stages 16-17; v1.0.1 2026-11-02, v1.0.0 the same day); the repo is public, so push only when the user asks.

14. **FGDC metadata for the model and its outputs** - PLANNED 2026-10-31 as a metadata and data release generator following USGS
   FSP (SM 502.7 and 502.8 as reissued 2026-06-01): implementation plan at (a working document, not in this repository) (one
   content model, CSDGM writer, model record, stage 15 Data Release, Release Information page, mp and content checks, review packet,
   phases 0-6 ending in a P26 trial release; decisions settled 2026-11-02 (CSDGM first, one release per Build, maps every year, archive always, ScienceBase by hand); Data Release is stage 17; Phase 0 needs the Center data manager).
   Phase 1 (definitions, data dictionary, citations) done 2026-11-02. Phase 2 (model record) done 2026-11-02: `src/metadata-record.R`
   (facts from a Build result, the content model, the CSDGM writer, mp), `tools/model-record.R "<library>" --build=<id>`, record defaults,
   keywords and Use Constraints notes in `defaults/metadata`, `tests/unit-metadata-record.R`; P26 Build 53 passes mp with no errors or
   warnings, but it predates Data Sources Used, so its lineage is inferred from the home: test the lineage again on the next P26 Build.
   Stage 16 - Model Record (2026-11-03, the user's call: its own stage, not part of Build Figures) writes it in a scenario on the Build result:
   the Build's run log exists only once the Build has ended, so it cannot be in the Build's pipeline. Stage 1 logs the R version and git
   commit for the record. Tested on a copy of Puget Lowlands result 6: 0 mp errors, same XML as the tool.
   Phase 3 (2026-11-03): Stage 17 - Data Release, `src/release.R`, `src/17-data-release.R`, `tools/data-release.R`, `ui/DataReleaseView.cs`,
   `tests/unit-release.R` (43 checks), `tests/phaseZ-data-release.R`. The writer passes on P26 from the tool (runs 54, 65, 66, 67: 7 records, mp 0 errors, 0 warnings).
   Stage tested end to end on Puget Lowlands 2026-11-03. Phase 4 (2026-11-03): Release Information page and project People list (`ui/ReleaseInformationView.cs`, sheets Person, ReleaseInformation, ReleaseOriginator), `rl_read_info`, release status Draft/Provisional/Approved (a blank fails the last two), `tests/phaseZ-release-information.R` on a copy of Puget (15 checks); the guide has section 7.5.
   Phase 5 (2026-11-03): content checks and the `review/` packet, `src/release-review.R`, `defaults/metadata/review-checklists.csv` (USGS checklists 2.8 and 2.6, word for word), `tests/unit-release-review.R` (46 checks: each fault must be caught). Metadata identifier made optional (the checklist says the ScienceBase team assigns it). Phase 6 (P26 trial release and a mock review) is next.
   Existing libraries need tools/sync-library.R --schema-only for the new sheets. The 2026-10-25 scope below
   still holds. TO DO (user, 2026-10-25). Completed runs need FGDC-compliant metadata (CSDGM,
   FGDC-STD-001-1998, as USGS data releases use; XML), in two layers:
   - **Model metadata** (thorough, one record per model): what the model is and how it was built. Identification (title, abstract,
     purpose, originators, citation, keywords, use constraints), extent and time period (study area bounding coordinates, 1985-2023
     and the projection years), spatial reference and resolution, **lineage**: every input dataset as a source citation (from the Data
     Sources page and item 12's manifest: source, vintage, URL, clipped or national) and every stage as a process step (what it does,
     its key options, the date it ran, the result scenario id), software versions (SyncroSim, stsim, lucasCore), and the entity and
     attribute definitions of the model's classifications (state classes, transition groups and types, stock and flow groups, strata).
     Could be written by the Build (a stage or a step of stage 12) or by the outputs stage below from the Build result.
   - **Output metadata stage** (its own scenario, like Run Figures): accepts one or more result scenario ids (historical runs,
     projections, Run Figures), exports the delivered products and writes one metadata record per product: tabular outputs (state class,
     transition, stock and flow tables as CSV, with every column defined: units, domains, the iteration/timestep meaning) and spatial
     outputs (state class, age, transition and stock maps as GeoTIFF: raster info, bounding coordinates, value attributes and the class
     lookup). Each record cites the model metadata as its lineage source and adds the run's own settings (years, iterations, climate
     run, Projection Setup, multiprocessing tiles).
   - **User fields** on a Metadata Options page (project or scenario level): originator, point of contact, publisher, distribution and
     access constraints, citation/DOI, keywords (with thesauri), so the stage fills everything else automatically.
   - **Validation**: run the USGS metadata parser (mp) on every record and report errors in the stage's checks; consider an ISO 19115
     export later from the same content.
39. **Grassland and shrubland carbon: expose the rates, then improve the science** - TO DO, top priority (user, 2026-10-30: before
    the P26 rerun; the rates came from IBIS simulations, "not very tractable"; at least make them visible and overridable, open to
    better science). **Today** (all package tables from the CONUS 1 km build, copied by stage 3 and stage 8): Net Growth one value per
    class (defaults/stockflow/nonforest-net-growth.csv, Mg C/ha/yr: natural perennial grass 2.31, annual 0.95, irrigated perennial
    9.19, chaparral 3.84, sage/other shrub 0.97-0.99); growth split, live turnover and dead pool decay/emission per class
    (nonforest-multipliers-grassland-shrubland.csv, the CBM pool structure in nonforest-pathways.csv); initial pools per class
    (defaults/initialstocks/grassland-shrubland.csv, from the build's spin-up; soil 92 Mg C/ha natural grass, 24 sage, 75
    chaparral; gSSURGO is used only where a class's soil is 0, never for grass or shrub). All 288 class x flow values are the same
    in every one of the 19 ecodivisions; the only spatial and yearly variation is the climate multiplier (Miami NPP, precipitation)
    on non-forest growth. Nothing is calibrated to observations and nothing is on a page. Alternatives under discussion with the
    user (2026-10-30).
    **Step 1 (expose) DONE 2026-10-30** (user: "Expose only for now"; then "the same design for wetlands"). Carbon Assumptions >
    Grassland, Shrubland and Wetland Carbon (feed NonForestCarbon, ui/NonForestCarbonView.cs): Non-Forest Growth (Ecodivision, Class,
    Age, Net Growth) and Non-Forest Rates (Ecodivision, Class, Age, Flow, Value); Fill / Reset loads every value that does not change
    with age (presets defaults/carbon-assumptions/<method>/nonforest-growth.csv 11 rows, nonforest-rates.csv 434 rows: 9 grass/shrub
    and 2 emergent wetland classes, the forested wetlands' rates; their 300-age growth curve and growth split are not listed but can
    be set with rows); the Carbon Method page's Fill and tools/carbon-assumptions.R fill them too. Stage 3 starts from the package
    tables and applies rows the more specific last (class; + age; + ecodivision; + both); checks growth splits add to 1 at every age,
    emergent wetlands' shares out of each pool's total loss ("AG Very Fast ->" etc.) add to 1, rates in 0-1; logs the differences.
    Starting pools stay the package tables (stage 8): a changed rate acts from the first year, not on the initial stocks. Test
    tests/phaseZ25-nonforest-carbon.R: all pass (empty = the package's 65,246 rates and 11,609 net growth values exactly; class,
    ecodivision and age rows land only where meant). FIXED 2026-10-30 (dev/nonforest/01-nonsage-fix.R): Shrubland: Non-sage's eight
    turnover rates were Post Fire Shrub's shifted down one row (in the CONUS build's own file too); now Post Fire Shrub's, and its
    starting pools rebuilt by an ordered annual simulation (foliage 1.71 -> 0.86, fine roots 1.26 -> 0.65, soil 26.7 -> 21.3). Was:
    (fine roots -> AG very fast 0.01, merchantable -> snags 0.51, other wood -> AG fast 0.0045, where the other shrubs have ~0.26,
    0.0045, 0.33); emergent wetland net growth 31 Mg C/ha/yr; irrigated perennial grass 9.19 - to review with the science step.
    Page checked in Studio (user, 2026-10-30). Libraries made before need tools/sync-library.R --reference=dev/libs/sync-reference-20261030.ssim (the Age columns); the
    suitability test library is synced. Next (user to decide): the science options (gSSURGO soil calibration, RAP growth,
    literature rates).
    **Diagram view DONE 2026-10-31** (user: ecologist's view, rates by default with a flux toggle, total NPP, the full steady-state
    budget, no atmosphere pool). The page's Tables/Diagram switch (ui/NonForestBudget.cs, NonForestDiagram.cs) draws one class with
    the values stage 3 uses and solves its steady state. With the package rates it lands on P26's starting pools for grass and shrub
    (chaparral live 7.0 / dead 33.8 / soil 75.3 vs 7.0 / 29.8 / 74.6; natural perennial 4.5 / 24.8 / 92.1 vs 4.5 / 22.4 / 91.8), so
    those starting tables are the rates' equilibrium. NOT for emergent wetlands: Palustrine Emergent's rates settle to live 36 and dead
    49 Mg C/ha against starting pools of 4.9 and 17.4 (soil 621 vs 609), so the starting pools or the rates (31 Mg C/ha/yr net
    growth?) came from different inputs - for the science step. Also seen in the diagram: every grass and shrub class sends coarse
    root turnover half to AG fast (above ground), and annual grass half its fine root turnover to AG very fast.
    Diagram follow-up DONE 2026-10-31 (8a7fc0c, user): CO2 and water leave each pool as arrows (curving up to the atmosphere,
    sideways to water), sized by flux; guide Figure 3.17. Left as is (user): BG slow's "water" label sits on the curve to deep soil.
  - **Plan 2026-11-06 (user: a selectable IPCC defaults option, and open to a third built from literature or external data).**
    SUPERSEDED the same day by the revised approach below (after the review). Kept for its findings on the code; its three separate
    rate sets became target sources for one solver.
    - **What there is today:** one rate set (the CONUS 1 km build's, from IBIS), with the same values in every ecodivision. The
      cbm-defaults and fia-measured presets hold identical nonforest-growth.csv and nonforest-rates.csv files, so the non-forest choice
      does not depend on the dead organic matter method. Starting pools are package tables only (stage 8, defaults/initialstocks), so a
      changed rate leaves the pools out of step. Soil is gNATSGO soc0_999 (the whole profile) only where a class's soil is 0, which
      never happens for grass or shrub.
    - **The selector:** a new column on the Carbon Method page, "Grassland, Shrubland and Wetland Carbon": 1 LUCAS CONUS (IBIS),
      the default, with results unchanged; 2 IPCC Tier 1 defaults; 3 literature and regional data. Fill loads the option's preset
      into Non-Forest Growth, Non-Forest Rates and the new starting-pool sheet. Presets go in
      defaults/carbon-assumptions/nonforest/<option>/, apart from the dead organic matter methods. Rows a user adds still override the
      preset, as they do now.
    - **Phase 1, the framework (needed by both new options):**
      - A Non-Forest Initial Stocks sheet (class, ecodivision optional, pool, Mg C/ha) for stage 8.
      - A "Starting pools" choice: the option's table, or the steady state of the rates in use. The steady-state solve already exists
        in the diagram view (ui/NonForestBudget.cs); port it to R. With the second choice, any edited rate also moves the starting
        pools, which fixes the emergent wetland mismatch (rates settle at live 36 and dead 49 Mg C/ha against starting pools of 4.9
        and 17.4).
      - Tests: option 1 reproduces today's 65,246 rates, 11,609 growth values and starting pools exactly. The steady state of option
        1's grass and shrub rates matches the package tables (already seen in the diagram view).
    - **Phase 2, IPCC Tier 1.** IPCC gives stocks, not flux rates: Tier 1 assumes grassland biomass and dead organic matter do not
      change, and soil moves toward a new equilibrium over 20 years after land-use change. So the option sets the stocks from IPCC
      and derives rates that hold them at steady state.
      - Keys: IPCC climate zone (2019 Refinement Vol 4 Ch 3 decision tree, from PRISM temperature and precipitation, plus
        elevation) and IPCC soil class (HAC, LAC, sandy, spodic, volcanic, wetland, from the gNATSGO/SSURGO taxonomy). Both vary
        within an ecodivision: use the majority zone per ecodivision for rates, and set starting soil per cell.
      - Biomass: grassland above- and belowground biomass by climate zone (2006 Vol 4 Table 6.4, updated in 2019, with a root:shoot
        ratio), carbon fraction 0.47. Shrubland values must be found; the 2019 Refinement's woody vegetation tables are the first place
        to look.
      - Growth: above-ground NPP = above-ground biomass (it turns over every year); below-ground NPP = root biomass x root turnover.
        This is a modelling choice; IPCC gives no grassland NPP.
      - Soil: SOCref (0-30 cm, 2019 Table 2.3) x F_LU x F_MG x F_I (Table 6.2 for grassland). Soil decay is solved so the steady
        state equals the target.
      - **Depth mismatch:** IPCC SOCref is 0-30 cm, while gNATSGO soc0_999 and the current tables are the whole profile. Choose:
        the soil pool is 0-30 cm only, or deeper carbon is held as an inert remainder.
      - Wetlands: 2013 Wetlands Supplement. Coastal (Ch 4): tidal marsh biomass, soil stock and a soil carbon accumulation rate
        (burial, as the existing Stabilization flows). Inland mineral (Ch 5): no CO2 stock change at Tier 1. Wetland CH4 is not in the
        model today; leave it out or add it as a flux.
      - Land-use change: IPCC moves soil linearly over 20 years; LUCAS moves it exponentially at the new class's decay rate. Measure
        how far apart they are.
      - Ship the tables with citations (defaults/carbon-assumptions/nonforest/ipcc/) and a script that derives the rates
        (tools/make_nonforest_ipcc.R). Check every value against the documents, as was done for the CO2 review.
    - **Phase 3, literature and regional data.** A review like the CO2 one picks the sources. Starting candidates:
      - Grass and shrub growth: RAP NPP partitioned into herbaceous and woody (30 m, yearly since 1986) and RAP herbaceous biomass.
        RAP growth could also replace Miami NPP as the yearly climate signal for these classes.
      - Root:shoot and root turnover: Mokany et al. 2006; Gill and Jackson 2000.
      - Shrub biomass: sagebrush and chaparral allometry studies; litter and dead wood from LANDFIRE FCCS fuelbeds.
      - Soil: gNATSGO per cell, with soil decay calibrated to it, as forests already are.
      - Wetlands: CCRCN soil cores and accretion rates, Holmquist et al. 2018 (tidal wetland soil carbon), EPA NWCA 2011 soil carbon
        (Nahlik and Fennessy 2016), and marsh NPP studies.
      - Build it as a stage 3 step: stocks are the targets and rates are solved to steady state, so it reruns per region from the Data
        Download. It is not a fixed table.
    - **Phase 4, compare and document:** run all three options on P26 and Puget (in copies). Compare starting stocks, NPP,
      heterotrophic respiration and net flux by class against RAP and NWCA where they overlap. Show each option in the diagram view.
      Add a guide section.
    - **Scope decided by the user 2026-11-06:**
      - **Agriculture is in:** pasture and cropland get rates and starting pools in options 2 and 3 (IPCC cropland Ch 5 and grassland
        Ch 6 factors; crop biomass removed at harvest each year). Option 1 keeps today's agriculture (zero biomass, gNATSGO soil). Ag
        Change transitions then move soil carbon toward the new class's equilibrium.
      - **Soil depth, inert deep remainder:** IPCC sets the active 0-30 cm soil; the carbon below 30 cm (gNATSGO whole profile minus
        0-30 cm) is held unchanged, so totals stay comparable across options. It goes in the existing Deep Soil stock (user,
        2026-11-06), which has no outflows and is already in the DOM: Soil and Total Ecosystem groups, the output filters and the
        metadata definitions. Today only emergent wetlands use it: BG Slow -> Deep Soil stabilization (0.19 of BG Slow's loss in Estuarine
        Emergent, 0.25 in Palustrine Emergent), starting at 0. So stage 8 needs Deep Soil added to defaults/initialstocks/stock-types.csv
        to set its starting value. In wetlands the remainder and the buried carbon share the pool.
      - **IPCC keys:** rates by ecodivision (its majority climate zone, in the existing sheets' ecodivision column); starting soil per
        cell from the cell's climate zone and soil class.
      - **Option 3 is a stage 3 build from data:** stocks from RAP, gNATSGO and the wetland datasets are the targets, and the rates are
        solved per region at each Build. It is not a fixed table. The sources need the Data Download (stage 15).
    - **Review done 2026-11-06** ("Nonforest carbon stocks and rates", dev/nonforest/review/reports/, with notes in research_notes/;
      not committed). The IPCC values were read from the primary PDFs, and three were spot-checked again (2019 SOCref W2 HAC 24,
      inland wetland W2 74, high-intensity grazing F_MG 0.90).
      - **IPCC grassland:** Table 6.4 biomass and Table 6.1 root:shoot confirmed, with no 2019 change. Carbon fraction 0.47
        herbaceous, 0.50 woody. Growth = 1.8 x peak aboveground biomass (Ch 11 Table 11.1a perennial grass R_S 0.80), so natural
        perennial grass grows 1.35-2.29 Mg C/ha/yr by zone. Fine root turnover is 0.20-0.29/yr.
      - **IPCC soil:** the 2019 SOCref values replace 2006's; dry zones are lower (W2 HAC 38 -> 24). Dead organic matter in non-forest
        land is zero at Tier 1, so litter needs decay of at least 1/yr. Soil classes come from the EPA US inventory crosswalk (Annex
        3.12, Table A-185).
      - **Gaps IPCC does not fill:** no temperate shrub biomass, no tidal marsh aboveground biomass, no burial for undisturbed marsh
        (0.91 is a rewetted-marsh factor). The IPCC option borrows labelled literature values for these (sage growth 0.65/1.16/3.9,
        chaparral 1.5/3.0/5.0 Mg C/ha/yr).
      - **Verdicts on today's values:** sage, chaparral, annual and natural perennial grass hold up (perennial grass is high in dry
        zones). Emergent wetlands are 2-6 times too high: growth 31 (evidence 3-15), soil 609 (about 270 to 1 m), live and dead pools
        settling at 36 and 49 (evidence 4-12 and 1-5). Irrigated perennial 9.19 fits only California alfalfa; pasture is 4-7. Pasture
        counts as grassland in IPCC, so it should carry grassland biomass.
      - **Option 3 data:** RAP partitioned NPP (30 m, 1986-present, CC0; no agriculture), gNATSGO, NASS county yields with the USDA
        Tech. Bull. 1939 Table 3-5 coefficients (not MODIS NPP, which underestimates cropland), and Byrd 2018, NWCA, CCRCN and Wang 2019
        for wetlands.
      - **Structural:** Deep Soil has no outflow, so wetland burial should be a target flux (about 1-1.6 Mg C/ha/yr) rather than fixed
        shares of BG Slow's loss.
      - **Still open:** which root turnover to use, chaparral root:shoot, Non-sage shrub (no data), shrub litter decay rates, the
        pasture management factor, cropland growth in the IPCC option, the wetland 0-30 cm and deeper split, the IPCC climate-zone
        raster, and the 2019 wetlands chapter (Vol 4 Ch 7, not read).
  - **Revised approach (user accepted 2026-11-06: "love this approach").** One stage 3 calibration for grass, shrub, wetland, pasture
    and cropland, built like the forest one: measured stocks are the targets, growth comes from data, and the rates are solved so each
    class holds its targets. IPCC, IBIS and regional data are sources of targets for that solver, not separate rate tables, because
    IPCC Tier 1 gives stocks and stock change factors but no growth or rates. The 2026-11-06 scope decisions still hold (agriculture in,
    Deep Soil for the soil below 30 cm, IPCC keys by ecodivision with soil per cell). Steps, in build order:
    1. **Emergent wetlands first** (the largest error, and the most carbon per hectare). Growth about 3-8 Mg C/ha/yr (estuarine above
       palustrine); soil about 270 Mg C/ha to 1 m for estuarine (Holmquist 2018) and 150-250 for palustrine (NWCA West); fast litter
       decay; burial into Deep Soil as a set yearly rate (about 1.0-1.6 Mg C/ha/yr, Wang 2019, the Pacific values 1.04-1.10) in place
       of the 0.19 and 0.25 shares of BG Slow's loss. Starting pools at the steady state of these rates. Can ship before the rest.
       - **By region (user, 2026-11-06).** Today's emergent wetland values come from field measurements in coastal Louisiana (user;
         the user doubts them). They are identical in every ecodivision (palustrine net growth 31.24 in Hot Continental, Marine and
         the rest). Louisiana marshes measured 6-38 Mg C/ha/yr total production (Hill and Roberts, PMC5696422), about 3/4 of it below
         ground, so 31 is a real top-site Gulf value but not a class average, and not a value for the West. The values vary by
         ecodivision through the sheets' existing ecodivision rows:
         - **Live biomass:** Byrd et al. 2018 30 m tidal marsh aboveground biomass (six regions including Puget Sound, San Francisco
           Bay and Louisiana; USGS data release v2.0, public domain) where it covers a cell, else the ecodivision mean.
         - **Growth:** peak aboveground biomass plus root turnover, with root:shoot by region (2.6 Louisiana Spartina, 4-5
           northeastern marshes; Darby and Turner 2008, not confirmed).
         - **Soil:** estuarine from Holmquist 2018 and the CCRCN cores by region; palustrine from NWCA 2011 by region (to 120 cm:
           West 216, Interior Plains 195, Coastal Plains 198, Eastern Mountains and Upper Midwest 478 Mg C/ha).
         - **Burial into Deep Soil:** Wang et al. 2019 by region (Mg C/ha/yr: Pacific Northwest 1.10, California 1.04, CONUS mean
           1.62, Gulf and Mid-Atlantic higher).
         - **Palustrine separate from estuarine:** lower growth and burial, no tidal sediment supply. Western palustrine emergent is
           mostly wet meadow and farmed or diked wetland, so it takes the low end. Methane matters more here than in saline marsh;
           it is not modelled today.
         - The Louisiana values stay as the Gulf coast end of the range, used where the data say so.
         - **Weakest part:** inland palustrine growth outside the Delta and the Gulf, which has little data; those rows rest on NWCA
           soil and an inferred growth rate, and are flagged that way.
       - **Decided by the user 2026-11-06:** the new values are the package default (today's kept as legacy for the step 3 choice);
         soil to 1 m, split at 30 cm (BG Slow 0-30 cm, Deep Soil starts with 30-100 cm); palustrine burial a low flagged rate (0.5
         Mg C/ha/yr West and Interior Plains, 1.0 eastern and Gulf coastal plains). Flow order rules must be followed (user).
       - **CORRECTION 2026-11-06:** in ST-Sim's flow order, today's emergent rates DO hold the package's starting pools (foliage 0.755,
         fine roots 4.14, AG and BG litter 3.32 and 14.06, BG Slow 620 vs the table's 609): growth runs at order 1 and dieback at 6, so
         year-end live carbon is small. The "settle at live 36 and dead 49" above (and in the review) came from the diagram view's
         continuous steady-state solve, which ignores flow order; the diagram view needs the ordered solve too (ui/NonForestBudget.cs).
         Today's real faults stand: growth 31, soil about 609, and burial 3.0 Mg C/ha/yr into Deep Soil (2-3x measured).
       - **Built 2026-11-06 (not run in SyncroSim yet; not committed):**
         - src/nonforest-solve.R: one year as ST-Sim steps it (flow order from stsim_FlowOrder.csv; flows of one order from the stocks
           at the start of their step, as the package's ApplyEquallyRankedSimultaneously = TRUE; a rate is the flow's [Type] value times
           any "<pool> ->" total-loss value), the steady state, and nf_fit_emergent: each pool's total loss and the burial share by a
           bounded root search so the ordered steady state hits peak live carbon (year-end + the year's growth), year-end litter and
           BG Slow, and the burial flux. The litter and BG Slow loss shares (emission, lateral transport, decay to BG Slow) are kept.
         - defaults/stockflow/emergent-wetland-regions.csv (targets by class and region, each with its source) and
           emergent-wetland-ecodivisions.csv (each ecodivision's estuarine and palustrine region).
         - tools/make_emergent_wetland.R writes the emergent rows of nonforest-multipliers-wetland.csv and nonforest-net-growth.csv,
           initialstocks/emergent-wetland.csv (now by ecodivision, with Deep Soil) and stockflow/emergent-wetland-fit.csv; keeps the old
           rows in defaults/stockflow/legacy-ibis/; removes the emergent rows from both carbon method presets (a class-wide row would
           override the ecodivision values). All 38 fits converge; no pool dies back fully. Examples: Pacific Northwest estuarine root
           turnover 0.61/yr, soil loss 0.020/yr, burial share 0.50; West palustrine 0.75, 0.017, 0.39.
         - Stage 8: emergent starting pools by ecodivision; Deep Soil in initialstocks/stock-types.csv (no forest curve column: forest
           starts with none); the summary counts Deep Soil as soil.
         - tools/sync-library.R step 7: removes emergent rows a filled sheet still holds at the legacy values; changed rows are kept.
         - tests/unit-nonforest-solve.R: 22 checks pass (the order rules, hand cases with growth before and after turnover, the legacy
           rates reproduce the legacy pools, every new table's sums, steady state and burial). tests/unit-carbon-assumptions.R passes.
         - **Tested in SyncroSim 2026-11-06 (merged to main a6b5d7f and after; not pushed):**
           - dev/nonforest/02-emergent-stsim-check.R, real ST-Sim on the package's emergent tables (synthetic library, five
             ecodivisions, 30 years, no transitions): PASS. Every pool holds its fitted value (largest relative gap 2.2e-6) and Deep Soil
             gains each region's burial rate every year (largest gap 6.7e-6), so the solver's flow order rules are ST-Sim's.
           - tests/phaseZ25-nonforest-carbon.R on lucasCore-suitability.ssim: ALL PASS (stage 3 writes the new package values, 65,246
             rates and 11,609 net growth values; scenario rows still land only where meant).
           - tests/phaseZ28-stage8-deep-soil.R (new): ALL PASS. Stage 8 writes a Deep Soil map (0 here: Placer has no emergent cells);
             every other pool matches Build 47's own stage 8 maps except the 131 Shrubland: Non-sage cells, which match the
             2026-10-30 fixed table (Build 47 predates that fix).
           - The test library was on lucasCore 1.0.1, which SyncroSim no longer has: moved to 1.1.0 as P26 was (core_Package version,
             then SyncroSim.Console --update), synced (full, then --schema-only --reference=dev/libs/sync-reference-20261106.ssim for
             the CO2 columns the starter lacks). Backups .bak-20261106-1533, -1543, -1618.
           - sync-library step 7 runs as one SQL query (two SyncroSim reads per scenario were too slow), and step 5 now skips a
             scenario whose stock group memberships cannot be read instead of stopping. Dry run on P26: 92 rate and 2 growth legacy
             emergent rows in one scenario would be removed, so P26 must be synced before its rerun (item 51).
         - **Diagram view fixed 2026-11-06** (ui/NonForestBudget.cs Solve): the year in ST-Sim's flow order, as src/nonforest-solve.R
           (stsim_FlowOrder.csv; same-order flows from the stocks at the start of their step), steady state by Gaussian elimination,
           then one year from it for each arrow's flux; the tooltip shows the stock a flow is computed from and its flow order when
           that differs from the year-end stock. Checked with a console harness on the package tables: Marine estuarine emergent
           foliage 1.2, fine roots 2.197, litter 1 and 2, soil 111, burial 1.10 (the new starting pools exactly); natural perennial
           grass and chaparral land on their starting tables to 4 decimals (soil within 0.15%; chaparral dead 29.8, which the old solve
           put at 33.8). The page note says so. lucasCoreUI.dll rebuilt; not yet opened in Studio.
         - Left: the guide, and a Build on a region with emergent cells.
    - **Grassland and shrubland by ecodivision (built 2026-11-06).** User decisions: growth and soil together; one package table by
      ecodivision (not solved at each Build); ecodivision x class means; today's IBIS values kept as legacy; alfalfa and irrigated
      pasture are Agriculture: Pasture (step 6), not Grassland: Irrigated Perennial.
      - **Sample** (dev/nonforest/03-grass-shrub-sample.R, user OK to fetch): 60 windows of 3 x 3 km per ecodivision (1,140), every
        NLCD 2001 grass (71) and shrub (52) cell classed as stage 5 does (RCMAP 1985 vegetation state, from the user's
        E:/lucasData/supplied zip; elsewhere 71 -> Natural Perennial, 52 -> Non-sage). Read remotely at the windows only: RAP rangeland
        NPP v3 (CC0; README: bands annual herb, perennial herb, shrub, tree, kg C/m2, raw / 1000 = Mg C/ha/yr; not for agricultural
        land) mean of 2014-2023, and gNATSGO soc0_30 and soc0_999 (Planetary Computer). Cells RAP sees as mostly trees (tree NPP > herb +
        shrub) are left out: 73-99% of the cells in Marine, Savanna, Subtropical, the Continental ecodivisions and their Mountains.
      - **CONUS class means** (NPP Mg C/ha/yr; soil 0-30 / whole profile Mg C/ha; today's growth): Natural Perennial 2.67, 31 / 74 (2.31);
        Annual 2.80, 27 / 58 (0.95); Irrigated Perennial 2.86, 32 / 83 (9.19; 507 cells); Chaparral 3.19, 25 / 40 (3.84); Native Sage
        Steppe 1.26, 24 / 47; Invaded Sage Steppe 0.93, 17 / 37; Sage 0.49, 16 / 31 (0.99); Non-sage 1.22, 20 / 45. Starting soil falls:
        natural grass 92 -> 74 whole profile, chaparral 75 -> 40.
      - **tools/make_grass_shrub.R**: an ecodivision keeps its own value with >= 5 windows and >= 500 cells (85 of 171), else the class's
        CONUS mean (86; all of Irrigated Perennial); Post Fire Shrub takes Non-sage's targets; thin eastern samples and Irrigated
        Perennial are flagged in defaults/stockflow/grass-shrub-targets.csv. Net Growth = NPP; today's turnover, litter rates and growth
        split kept; only BG Slow's outflow (Emission: BG Slow -> Atmosphere, 342 rows) is refitted (src/nonforest-solve.R nf_fit_pool:
        all of a pool's outflow rates scaled by one factor, ordered steady state) to hold the 0-30 cm soil: 0.0009-0.023/yr. Starting
        pools = the steady state; Deep Soil starts with the soil below 30 cm. Legacy rows in defaults/stockflow/legacy-ibis/; presets
        lose their grass and shrub rows; sync-library step 7 removes legacy grass and shrub rows too.
      - **Tests:** tests/unit-nonforest-solve.R 29 of 29 (grass and shrub: only BG Slow's outflow changed, Net Growth = NPP, pools =
        steady state within 5e-5, soil targets met). dev/nonforest/02-emergent-stsim-check.R with five grass and shrub classes added:
        PASS in real ST-Sim over 30 years (largest gap 1.1e-4 Mg C/ha, the 4-decimal rounding of the starting pools). In SyncroSim on
        lucasCore-suitability.ssim: tests/phaseZ25-nonforest-carbon.R ALL PASS; tests/phaseZ28-stage8-deep-soil.R ALL PASS (819 grass and
        shrub cells start at their ecodivision x class pools, Deep Soil included, largest gap 1.7e-6; every other cell = Build 47).
      - **Next (user, 2026-11-06):** fit the live and dead pools as well, chaparral by age, and keep IBIS out of this option (literature
        values only; IBIS stays the legacy choice). A research pass on litter and root decay, the fate of decomposed carbon, live
        turnover and allocation, and chaparral after fire is running first ("Grass and shrub turnover and decay").
      - **Built 2026-11-06 (main 7d59da5; not pushed).** Report: dev/nonforest/review/reports/Grass and shrub turnover and decay.md (4
        research threads; register of 60+ values with status). User decisions: adopt its six revisions (sage foliage share 0.14; Irrigated
        Perennial root:shoot 1.7; chaparral root:shoot 0.6, foliage share falling with age to 0.12, mature litter 7, standing dead 0.35 x
        aboveground live); one chaparral class on the chamise curve (mixed / Ceanothus as the high case); Native Sage Steppe scales with
        NPP (Sage's rates). Found: the dead-pool emission shares called IBIS are CBM-CFS3's defaults (0.815 / 0.83), so they are kept and
        cited as CBM.
        - defaults/stockflow/grass-shrub-literature.csv (per class: growth split, live turnover, root and litter decay, snag share, litter
          and AG Slow targets, sources) and chaparral-age.csv. tools/make_grass_shrub.R sets every rate from them (k -> 1 - exp(-k) a year;
          grass foliage dies back yearly; fine roots -> BG very fast, coarse -> BG fast, wood -> snag branches and AG fast), solves AG very
          fast decay (litter target over AG very fast + fast), AG Slow emission (CBM: decay fully emitted + 0.006/yr to BG Slow) and BG
          Slow emission (gNATSGO 0-30 cm), and keeps no IBIS value. Classes with RatesOf take the source class's rates whole.
        - Chaparral: live by age 11 x s x (1 - exp(-0.09 (a + 1))) (s = ecodivision NPP / CONUS mean), foliage share 0.12 + 0.25 exp(-0.15
          (a + 1)), roots 0.6 x mature aboveground with 75% alive after fire; Net Growth and growth split by age (ages 0-99, 100+ mature);
          95.5% of wood turnover stays standing (fitted to standing dead 0.35 x live); its own high-severity fire rows (foliage 95% burned,
          wood 55% burned and the rest standing, litter and snags 80%, AG Slow 50%, 25% of roots killed) in both Disturbance Flows presets,
          and stage 3 adds them to a filled sheet that has none. Starting pools by age (initialstocks/chaparral.csv) from that fire on a
          mature stand and regrowth. Stage 5: chaparral cells get their years since the last fire perimeter (start year - 1900 if none).
          Fire pathways: only high-severity fire resets chaparral's age (medium and low leave the stand alive).
        - Medians (Mg C/ha): Natural Perennial live 3.1 dry / 6.4 moist (aboveground 0.6-1.1), Sage live 3.5 (aboveground 1.0, litter
          0.32), chaparral mature live 17.6 (aboveground 11, litter 7, standing dead 3.85).
        - Tests: tests/unit-nonforest-solve.R 32 of 32 (growth splits are the literature's; pools = steady state; chaparral's age-A pools
          step to age A + 1); unit-carbon-assumptions ALL PASS; dev/nonforest/02-emergent-stsim-check.R in real ST-Sim PASS (chaparral cells
          at ages 0, 5, 30, 80, 2 follow the R run for 30 years to 9.8e-6). New tests/phaseZ29-chaparral-age.R (stage 5).
        - **Decided by the user 2026-11-06:** chaparral keeps the literature's mature growth (1.6 Mg C/ha/yr at the CONUS mean, against
          RAP's 3.19, which likely includes mixed and Ceanothus stands; chamise literature about 2), scaled by each ecodivision's RAP NPP.
          The grass and sage-family litter target counts leaf and fine litter only (AG very fast; fine woody debris follows its literature
          rate): sage leaf litter then decays at k 0.29/yr (literature 0.1-0.7; it was 2.1 when the target also counted AG fast), with
          total surface litter 0.63 Mg C/ha (0.32 leaf + 0.31 fine woody). Chaparral's 7.0 still counts AG very fast + fast (k 0.09).
          Grass litter decays at k 0.66-0.89, a little above litterbag values: a calibration term for grazing and photodegradation.
        - **SyncroSim tests (lucasCore-suitability.ssim, main 7a7e77d):** phaseZ25 ALL PASS (stage 3 writes all 74,746 grass, shrub and
          wetland rates and 13,509 growth values, chaparral by age included); phaseZ28 ALL PASS (819 grass, shrub and chaparral cells at
          their pools, chaparral by age, largest gap 1.7e-6; every other cell = Build 47); phaseZ29 ALL PASS (34 chaparral cells, 8 burned
          since 1900 with a median of 26 years since fire, the rest 85).
        - **Solano test library (2026-11-06):** user, "we are not ready to update the P26 final runs yet ... a smaller testing library
          with a lot of grass, shrub, and wetland". `dev/libs/lucasCore-test-Solano.ssim` (throw-away; Solano County, 250 m, 1985-2023,
          34,568 cells; starter scenarios, Stand Age Source TreeMap since the CMS age needs an Earthdata login, FIA Data = DataMart). Build
          result 13 passes every stage (32.6 min). Starting pools, Mg C/ha (live / dead / soil 0-30 / deep / total): annual grass
          7,256 cells 4.6 / 3.6 / 30.1 / 35.1 / 73.5; natural perennial 4,945 cells 4.7 / 3.8 / 27.4 / 35.8 / 71.6; estuarine emergent
          (Suisun Marsh) 2,590 cells 2.4 / 3.0 / 96 / 131 / 232; palustrine emergent 1,280 cells 1.2 / 3.0 / 76 / 118 / 198; chaparral
          483 cells, 78% burned since 1900 (median 21 years), live 4.6 at 0-5 years rising to 17 at 21+, dead 8.8 just after fire;
          Non-sage 178 cells 15.5 / 8.2 / 33.8 / 27.3 / 85. Stage 3 writes chaparral's own fire flows (foliage 95% burned, other wood
          55% burned and 45% to snag branch, roots 75% survive, dead pools 80% burned, AG slow 50%). Study area 28.3 Tg C.
          Three bugs found and fixed on the way: stage 5 read the CMS stand age path with TreeMap chosen (e6992a7); the Carbon
          Assumptions fill dropped StateClassId from Disturbance Flows, so a new library's chaparral fire rows became duplicate
          all-class rows (a5cb318); and the data home's lost download records (item 52).
          Seen, not item 39's grass and shrub work: cropland, developed, water and barren cells take gNATSGO soc0_999 (the whole
          profile) into BG Slow with no Deep Soil split - cropland median 103, 821 Delta peat cells above 300 Mg C/ha, water cells
          median 142; the pasture and cropland step of the plan should split them like the grass and shrub classes.
        - **Solano historical run 2026-11-07** (scenario 14, result 15, 1985-2023, 1 iteration, 22.6 min). Per hectare of each class:
          estuarine emergent live 2.4 throughout (no climate multiplier), BG Slow steady (98 -> 100), Deep Soil +1.04/yr (131 -> 170.6,
          California burial exactly); palustrine Deep Soil +0.49/yr (118 -> 136.7). Grass live 2.3-5.8 with the precipitation multiplier
          (lows 1990, 2020), litter 1-2, soil steady. Chaparral NPP 0.33-2.81 a year, mean about 1.6 (the literature's mature growth);
          high-severity fire in 2015 and 2020 (1,488 and 3,531 ha study-wide) took chaparral live 12.3 -> 6.9 Mg C/ha, back to 8.9 by
          2023. Land change mixes class means: cropland returned to grass brings its whole-profile BG Slow (about 150) and no Deep Soil,
          grass turned to cropland takes its Deep Soil along (cropland Deep 0 -> 3) - the cropland soil issue above.
          **Found:** only chaparral has its own fire rows, and only for high severity. Low and medium fire on chaparral, and every fire
          on grass and the other shrubs, use the all-class (forest) rows: medium severity kills 53.5% of roots (chaparral high severity
          25%), and high severity on grass kills 95% of roots (perennial grass resprouts). In this run medium and low fire moved 56,657
          Mg C in chaparral against 32,517 for high. Grass and shrub fire rows by severity are needed.
        - **One soil definition and fire by severity (built 2026-11-07, main b51cf4c; user: "wetlands should be the only class with
          the Deep Soil pool ... issues if different classes define their soil pool differently"; wetland soil all in BG Slow).**
          BG Slow holds a cell's whole soil in every class: grass and shrub fit it to gNATSGO soc0_999 (as forest, agriculture and
          developed already were; soil loss 0.002-0.004 /yr, slower than the 0-30 cm fit), emergent wetlands to the regional soil to
          1 m; Deep Soil starts at 0 and gains only wetland burial. Fire: defaults/stockflow/nonforest-fire.csv (every grass, shrub and
          emergent class x High / Medium / Low; chaparral High stays in chaparral-age.csv; all inference) -> tools/make_nonforest_fire.R
          writes high severity into both Disturbance Flows presets and medium and low into event-pathways.csv as class rows covering
          every all-class pair (a class row hides the all-class row of its pair: chaparral's wood split 0.55 / 0.45 exactly in the
          run). Stage 3 adds a class's preset rows to a filled sheet that has none for it. Tests: unit-nonforest-solve 33 of 33;
          unit-carbon-assumptions ALL PASS (new: every class covers every pair at every severity); 02-emergent-stsim-check PASS in
          real ST-Sim (largest gap 9.3e-4 Mg C/ha, burial 4.4e-6, chaparral 2.2e-5). Solano rebuilt (Build result 16, 73 of 73 checks
          pass) and rerun (result 18): Deep Soil 0 outside wetlands (cropland no longer picks it up), estuarine Deep Soil +1.04 /yr,
          no grass roots killed by fire (8,851 Mg C before in low-severity annual grass fire alone), chaparral medium and low fire
          kill 1,342 and 0 Mg C of roots (6,759 and 3,353 before); chaparral live 10.6 Mg C/ha in 2023 (8.9 before).
        - **Left:** a literature pass on the fire shares; the guide (grass,
          shrub, chaparral and emergent wetland sections); the P26 rebuild in item 51 (synced 2026-11-06, not yet rebuilt: the final
          runs stay as they are for now); eastern grass and shrub data; the Non-sage class has no data of its own.
      - **Open:** eastern grass and shrub rest on few untreed cells and RAP is built for rangelands; growth by age after fire (step 8);
        live and litter targets (RAP biomass, shrub literature, FCCS) not yet used.
    2. **Use only the pools each class has.** Keep the shared stock types; turn off the flows that do not apply. Grass: foliage, fine
       roots, AG and BG fast litter, soil. Shrub: add woody stems and coarse roots. Wetland: add burial to Deep Soil. Fewer unknowns
       for the solver, and a readable diagram view.
    3. **The solver.** Per class and ecodivision: growth from RAP (rangeland) or NASS yields (cropland, hay); live stocks from RAP
       biomass or the shrub literature; soil from gNATSGO per cell, with soil decay calibrated per cell as for forests. Each pool's loss
       rate = inflow / target stock. Starting pools come from the same solve, so rates and stocks cannot drift apart. Spin up with the
       historical disturbance (fire return interval, conversion history), as forests do, where a class is not at equilibrium (invaded
       sage, degraded rangeland, recently converted land). Target sources: data (the default for the new method), IPCC (reference
       stocks in place of gNATSGO, for an inventory-consistent run), or IBIS (today's values, kept as the legacy option).
    4. **Soil change on conversion from IPCC factors.** gNATSGO measures soil under today's land use; IPCC gives the relative effect of
       use (cultivated cropland 0.69-0.77 of native grassland over 20 years, high-intensity grazing 0.90, 2019 Tables 5.5 and 6.2). A
       cropland cell's native target is its gNATSGO soil divided by the cropland factor, and Ag Change transitions move soil toward
       the new class's target. This is the response land-use scenarios most need, and it barely exists today.
    5. **Growth that varies across the map.** RAP's 30 m long-term mean growth written as a spatial multiplier on non-forest growth,
       the way Site Productivity works for forests.
       - **Built 2026-11-07 (b486314, 8e160ba and fixes; main, not pushed).** User decisions: soil keeps the class mean (as forest);
         RAP fetched 1986 on; off by default. Build Options: Grass and Shrub Productivity = None / RAP NPP (2014-2023). Stage 8: a
         grass or shrub cell's multiplier = its RAP herb + shrub NPP (2014-2023 mean, treed 30 m pixels out) / its ecodivision x class
         target NPP, capped 0.3-2.5; starting live and dead carbon scaled by it; Flow Multiplier Type Grass and Shrub Productivity on
         Net Growth Non Forest: Total; stage 11 carries it into projections. New Data Sources column RapNppFolder, Data Download
         handler (COGs read for the region, one 4-band file a year; never whole for CONUS, 75 GB a year). Solano: 40 years, 5.75 GB
         (the region box is 160 x 145 km, not the county; the 20 MB a year estimate was wrong).
       - **Neighbourhood fill, both multipliers (user, 2026-11-07).** A cell that became forest, grass or shrub during a run grew at
         1, since each map only covered its own type at the start year. Now every land cell takes the inverse-distance weighted mean
         of nearby source cells of its ecodivision (2 km at the grid, then 10 km at about 1 km; else 1); grass cells at the 0.3 floor
         (RAP sees them nearly bare: fallow or graded land mapped as grass, 5% of Solano's) are not passed on. src/productivity-fill.R,
         tests/unit-productivity-fill.R (9 pass). Solano: 99.2% of other land cells filled (mean 1.01).
       - **Solano.** Multiplier mean 1.06: Annual 1.00, Natural Perennial 1.15, Chaparral 0.90, Non-sage 1.39, Irrigated Perennial
         0.63. Quick test (stage 8 + 1985-1995) against the run without it: live carbon follows the class means through the run
         (Natural Perennial +15-23%, Non-sage +30%, Chaparral -12%, Annual unchanged); soil within 2%.
       - **Quick tests (user, 2026-11-07: rerun only the changed stages, 5-10 historical years).** tools/quick-test.R <lib>
         --stages=8 [--build=<id>] [--years=10]: reruns only those stages on a Build result, then a short run (new-historical.R --also,
         --years). Solano: 2.3 + 6.6 min, against 35 + 23 for a full Build and run. Stage 8 alone needed two fixes: it replaces its
         productivity row (the result already holds the Build's, and two rows of one group and type stop ST-Sim), and it saves the
         Initial Conditions Spatial row again so SyncroSim writes the Properties sheet (one feed with the maps; a result holding the
         maps without it failed with "Object reference not set").
    6. **Carbon for pasture and cropland.** Pasture: grassland biomass with a grazing removal. Cropland: growth from NASS county yields
       and the USDA Tech. Bull. 1939 Table 3-5 coefficients, a harvest removal each year, residue to litter.
       - **Plan (user, 2026-11-07, revised the same day).** Agriculture grows and decays carbon like the other classes, which also
         fixes what today's setup gets wrong (below). Cropland stays one class (NLCD 82; orchards and vineyards stay in it for now,
         user: ignore the orchard issue): growth from NASS county yields (USDA Tech. Bull. 1939 Table 3-5: harvest index, root:shoot,
         residue), crop differences carried by a Cropland Productivity flow spatial multiplier (Cropland Data Layer crop type x NASS
         yields, relative to the ecodivision's cropland mean, neighbourhood-filled like the grass and shrub one); the harvest leaves
         the system each year as a new harvest flow; residue to the fast litter pools, roots to the belowground pools; litter decays;
         soil target its own gNATSGO value with decay calibrated to hold it; no climate response at first (irrigation, and NASS
         yield trends would need removing). Pasture (NLCD 81) carries grassland-like biomass, growth from NASS hay yields, with hay
         and grazing removal. Soil change on conversion (step 4) then follows from the classes' own inputs and decay, with IPCC
         factors as the check. Considered and set aside: crop-type classes as FORE-SCE uses (10-12 types; too many transitions and
         pathways for a land use near carbon neutral), an orchard class, and orchard wood as a fixed stock.
       - **What agriculture does today (checked 2026-11-07, defaults and the Solano historical run, result 18).** Ag Expansion
         (every class to cropland or pasture) burns foliage, other wood and snags (90% CO2, 9% CO, 1% CH4), sends 80% of
         merchantable stems to the forestry sector, and moves roots half to aboveground and half to belowground fast litter; litter
         and soil are untouched. Ag Contraction and Ag Change trigger no flows. Cropland and pasture run with every flow multiplier
         at 0, so nothing grows or decays there: the killed roots and the carried-over litter never decompose (Solano cropland
         litter 0 in 1985 -> about 0.8 Mg C/ha in 2023) and converted soil keeps the natural class's level (cropland BG Slow about
         150-155 Mg C/ha throughout, moving only as cells join or leave). Solano 1985-2023: 20,300 ha to cropland, about 24,600
         Mg C emitted and 62,000 Mg C of roots to litter; 21,700 ha back to grass or wetland, whose soil then follows that class's
         decay. Grass and shrub cleared for crops are burned rather than ploughed in (the CO and CH4 are likely wrong for them).
       - **NLCD definitions (MRLC legend, checked 2026-11-07).** The model's Pasture is NLCD 81 Pasture/Hay: grasses, legumes or
         grass-legume mixtures planted for livestock grazing or for seed or hay crops, typically perennial. Grazed rangeland that
         is not tilled is NLCD 71 Grassland/Herbaceous (or 52 Shrub/Scrub), so it belongs to the grass and shrub classes, not
         pasture. Cropland is NLCD 82 Cultivated Crops: annual crops (corn, soybeans, vegetables, tobacco, cotton), perennial woody
         crops (orchards and vineyards) and all actively tilled land. Start-year 81 and 82 cells keep their class (stage 5); Ag
         Expansion, Contraction and Change come from the Annual NLCD's gains and losses of 81 and 82 (defaults/transitions/sources.csv).
       - **Built 2026-11-07 (main, not pushed; user: start building; Agriculture Sector stock; yields vary by year).**
         - Growth: dev/agriculture/02-nass-county-npp.R reads the NASS Quick Stats crops bulk file (qs.crops_20261106, 1.13 GB, in
           the home under agriculture/nass; county survey PRODUCTION and AREA HARVESTED 1984-2025, 481,000 county x year x crop
           rows) and converts yields with USDA Tech. Bull. 1939 (2nd ed. 2024) Ch 3 Table 3-3 (dry matter, harvest index,
           root:shoot; read from the PDF, which pdftotext's -raw mode lays out correctly) and Table 3-4's carbon fraction 0.45:
           defaults/stockflow/ag-crop-coefficients.csv. Field crops are cropland, alfalfa and other hay pasture. The crop mix is
           held at each ecodivision's 1985-2023 mean area and the yearly value is a yield index: the survey's mix shifts as series
           end (California lost most of its cotton, wheat and barley), which doubled a plain yearly mean there. Cotton: lint
           converted to seed cotton at 0.38 (from memory, to check). Cropland level median 5.75 Mg C/ha/yr (Prairie 5.5,
           Mediterranean 9.7, Temperate Steppe 4.0); pasture 4.1; corn-belt growth +50% from 1985-94 to 2014-23. Not covered:
           vegetables, fruit and nuts, grazed-only pasture.
         - Soil: dev/agriculture/01-ag-soil-sample.R, gNATSGO under NLCD 2021 81 and 82 cells in 1,140 windows of 3 x 3 km (4.1
           min, none failed); cropland whole profile 52-201 Mg C/ha by ecodivision, Savanna 828 (Florida sugarcane on peat).
         - Model: tools/make_agriculture.R. The pools each class has (foliage, fine roots, AG and BG very fast litter, AG Slow, BG
           Slow); growth at flow order 1 (Net Growth Agriculture: Atmosphere -> Foliage / Fine Roots, group Net Growth Agriculture:
           Total); harvest at order 2 (Harvest: Foliage -> Agriculture Sector, group Harvest: Agriculture, -1 in Net Biome
           Productivity): cropland the NASS harvested share, pasture 0.75 of aboveground (assumed, between hay 0.95 and grazing);
           the rest dies back (live carbon 0 at year end). Litter decay from defaults/stockflow/ag-literature.csv (residue k 1.0
           and cropland AG Slow 0.2 assumed); AG Slow and BG Slow emission solved to hold AgSlow and the gNATSGO soil. Yearly Crop
           Yield flow multiplier (new type) on Net Growth Agriculture: Total from the NASS index, the mean of the last 10 NASS
           years after 2025. Starting pools: defaults/initialstocks/agriculture.csv (soil the class mean, as grass and shrub).
           CO2 fertilization now acts on the agriculture growth group. The old zero agriculture rows are gone from
           nonforest-multipliers-other.csv. tests/unit-agriculture.R 22 pass.
         - Plumbing: new stock, flow types, groups and flow multiplier type in defaults/stsim and the stock-flow sheets;
           tools/sync-library.R adds them to a library and appends the rows a non-result scenario's flow order, groups, diagram and
           filters lack. Stage 3 now declares Growth Options as an input (a rerun of stage 3 alone fell back to the default FIA
           source). tools/quick-test.R copies every Build-stage options sheet and puts the library's Stock-Flow Definitions ahead
           of the Build result (ST-Sim refused the harvest pathway: Build 20's diagram predates the Agriculture Sector stock, and a
           stage cannot add rows to its own input sheets).
         - Solano quick test (stages 3 and 8 on Build 20, result 58; 1985-1995, result 60; 4 + 7 min): cropland growth 8.6-9.7 Mg
           C/ha/yr by year (Mediterranean), harvest 4.5-5.1, live carbon 0 at year end, litter about 1.6 above and 1.5 below
           ground, AG Slow 0.2, Net Biome Productivity -0.4 to +0.4 a year (about 0 on average, as expected for cropland remaining
           cropland); pasture growth 3.5-4.3, harvest 1.4-1.7, NBP -0.3 to +0.2. Class-mean soil drifts only as cells join and
           leave a class (pasture 215 -> 180 as cropland soils move in).
         - Next: the Cropland Productivity map (CDL x NASS, phase 2), Ag Expansion's plough-in for grass and shrub (phase 3), and
           checks: the cotton lint factor, pasture removal, residue decay.
       - **Cropland Productivity (built 2026-11-07/08, main, not pushed; user: CDL 2014-2023 nationally, fallow 0 and unsurveyed crops
         left out, normalize by ecodivision, extend to non-agriculture cells for land use change).**
         - Data: the Cropland Data Layer's national 30 m zips (1.6-2.0 GB a year) kept whole at the top of the home (land-cover/cdl,
           Data Sources CdlFolder, national handler; CropScape did not answer and a remote read of a zip this size did not return).
           2014-2021 and 2023 in; **2022 still missing**: NASS's server answers HEAD (2.07 GB) but every GET came back empty (9 tries,
           2026-11-07); stage 8 averages the years it has with a warning. Come back to it.
         - Method (src/cropland.R, shared by stage 8 and the sample): each pixel's CDL crop (defaults/stockflow/cdl-crops.csv, the
           legend read from the 2014 zip's metadata) takes its county's 1985-2023 NASS growth of the crop group (ag-county-crop-npp.csv,
           else the ecodivision's, else CONUS); double crops both; fallow 0; vegetables, orchards, vineyards, grazed land left out.
           A cell's mean over pixels and years / the same estimate's ecodivision mean (ag-cdl-ecodivision-npp.csv, from
           dev/agriculture/03-cdl-ecodivision-sample.R: the 1,140 soil windows, 1.4 min), capped 0.3-2.5, filled to every other land
           cell from agriculture within 10 km of the same ecodivision. A first version divided by the NASS level (Mediterranean 9.71
           against a CDL-based 6.66: fallow and unsurveyed land) and gave Solano 0.41; the user chose the ecodivision normalization
           over a county one (a county one would erase the difference between counties).
         - Build Options: Cropland Productivity (None | CDL x NASS 2014-2023, off by default); lucasCoreUI.dll rebuilt; Starter rebuilt.
         - Two stage 8 faults found on the way: the Flow Spatial Multiplier sheet was declared input and output, and a rerun's saves of
           it were never kept when a dependency held it (no stage 8 rerun had ever changed it; Build 20's own grass and shrub row hid
           it). Stage 8 now writes it as an output and carries the dependency's rows itself, all productivity rows in one save.
         - Solano: cropland multiplier mean 0.58 (10% 0.35, 90% 0.75), pasture 0.90; 88% of other land cells filled (mean 0.61).
           Mediterranean ecodivision at 1 km: east-side San Joaquin dairy (corn silage) 2.0-2.5, Sacramento Valley rice 1.3-1.6,
           Solano and the west Delta 0.5-1.0, west-side San Joaquin 0.3-0.6 (cotton, wheat, fallow; its almonds and pistachios are
           left out, so it is likely too low).
         - Validation, Solano quick test (stages 3 and 8, 1985-1995, result 87) against NASS's Solano county survey, 1986-1995 means:
           growth 5.4 Mg C/ha/yr on NLCD cropland (9.3 without the map) against 7.7 per NASS harvested ha; harvest 2.8 against 3.4;
           total harvest 230 against 136 thousand Mg C/yr, the model's NLCD cropland (82 thousand ha) about twice NASS's harvested
           area of surveyed crops (40 thousand ha): the gap is orchards, tomatoes and other unsurveyed crops and fallow, which NASS's
           survey does not count but the model grows at its neighbours' level. Yearly correlation 0.31 (the yearly signal is the
           ecodivision's yield index, not Solano's mix).
         - Validation against the County Agricultural Commissioners' reports (user 2026-11-08; NASS Pacific Region AgComm CSVs
           1986-1995 in `E:/lucasData/agriculture/cac`; dev/agriculture/04-cac-county-check.R with 04-cac-crop-factors.csv), which
           list every crop: Solano's harvested area is 79 thousand ha against the model's 82 thousand ha of NLCD cropland, so the
           area gap with the NASS survey was the survey's coverage, not fallow. Growth 5.4 (model) against 6.6 Mg C/ha/yr (reports;
           524 against 441 thousand Mg C/yr, model 16% low); harvest 2.8 against 2.5 (230 against 200 thousand Mg C/yr, model 15%
           high): the model's harvested share of growth (0.52) is above the reports' (0.38). Grain, sugar beets and hay are 86% of
           the reports' growth and use the Table 3-3 coefficients; vegetables, fruit, nuts and vines (6 thousand ha in 1986-1995)
           use provisional factors (to check). No yearly agreement (r 0.11 growth, 0.06 harvest). Rows fixed: Solano barley 1990
           (yield 40.5 t/ac, a units error; state yield used) and unspecified vegetables with no production (state yield). Left
           out: irrigated pasture 8.3 thousand ha (NLCD maps 0.7 thousand ha of Solano pasture/hay) and range pasture 58 thousand ha.
         - **County scale (user 2026-11-08: "build this all at the county scale").** The ecodivision rates made Solano's cropland
           grow and harvest too much: the map was divided by the ecodivision's CDL mean (6.66) while the rows hold the NASS level
           (9.71), raising every Solano cell 1.46 times, and the harvested share was the Mediterranean's (0.52 of growth, silage and
           hay) where Solano's crops harvest about 0.40. Now (stage 8, src/cropland.R):
           - Cropland Productivity is divided by the ecodivision x class NPP the rows hold (ag-targets.csv), so each cell grows at its
             own crops' county rates (ag-cdl-ecodivision-npp.csv and the 03 sample are no longer used).
           - Crop Harvest (new flow multiplier type, on Harvest: Agriculture): the cell's harvest / aboveground growth over its CDL
             crops (county NASS AG and Harvest per crop group, 02 now writes them) / the ecodivision x class harvest rate, capped
             0.3-2.5 and so the rate stays <= 1; filled as Cropland Productivity; carried over by stages 7 and 11.
           - California: tomatoes, vegetables, tree fruit, tree nuts and grapes take the county's growth from the commissioners'
             reports 1986-2020 (dev/agriculture/05-cac-county-crop-npp.R, ag-cac-county-crop-npp.csv; 04-cac-crop-factors.csv's
             fruit, nut, vegetable and grape factors are provisional); elsewhere these CDL classes stay left out (no fallback).
           - CDL years 2014-2025 (user placed 2022, 2024 and 2025 in the home 2026-11-08; 2025 is NASS's 30 m resampling of its
             10 m layer).
           Solano (stages 3, 8: result 91; 1985-2020 run, result 95), cropland cells: Cropland Productivity mean 0.46 (was 0.58),
           Crop Harvest mean 0.85 (10% 0.45 in the northern grain, 90% 1.31 toward the Delta). Against the commissioners' reports:
           2014-2020 (the CDL years) growth 378 against 356 thousand Mg C/yr (+6%; the ecodivision maps gave about +33%), harvest
           155 against 136 (+14%; was about +82%); 1986-1995 growth 358 against 524 (-32%) and harvest 146 against 200 (-27%): the
           maps hold today's crops (more orchards and fallow), Solano grew more sugar beets, corn and tomatoes then. No yearly
           agreement in either period (the yearly signal is the ecodivision's NASS index).
         - **Crop factors checked (user 2026-11-08).** dev/agriculture/04-cac-crop-factors.csv against the literature (notes in
           dev/nonforest/review/crop-factors-check.md, not committed; Kroodsma and Field 2006, the Wolf 2015 supplement, Monfreda 2008
           were paywalled): almonds are kernel meats, HI 0.20 -> 0.14 (CDFA Whole Orchard Recycling inputs: kernel 0.14 of ANPP, roots
           0.30); walnuts, pecans, pistachios in-shell, HI 0.25 (an estimate); deciduous fruit DM 0.14, HI 0.40 (Rufat and DeJong 2001);
           citrus apart, DM 0.13, HI 0.15 (Zhao et al. 2021; lemons, grapefruit, tangerines now counted); dried plums DM 0.80; hay other
           HI 0.85, RS 0.54, wild hay RS 0.80, seed alfalfa RS 0.40 (IPCC 2019 Tables 11.1a, 11.2); sweet corn, snap beans, carrots
           (Zhao); tomatoes DM 0.06; grapes and silage confirmed (raisin yields of 8-12 t/ac are fresh tons). Not found: asparagus
           (HI 0.30 likely too high), melons, onions, peppers, olives, figs, and yearly root growth of any tree crop.
         - **Crop Mix (user 2026-11-08: vary the crop mix through time).** dev/agriculture/06-cac-county-crop-mix.R ->
           defaults/stockflow/ag-cac-county-crop-mix.csv: each California county's yearly NPP, AG and harvest 1986-2020 with every crop
           at its fixed county rate (so only the mix and harvested area change; yields stay with the Crop Yield index). Stage 8 divides
           by the county's cropland on the model's annual NLCD that year and by the same over the reported CDL years (2014-2020): one
           growth map (Net Growth Agriculture: Total) and one harvest-share map (Harvest: Agriculture) a year, 1 on NLCD pasture and
           outside California, capped 0.3-2.5 and the harvest rate <= 1; 1985 takes 1986's, 2021 on 1 (the maps' mix). Stage 8 now
           declares the annual NLCD sheet and, rerun on its own, finds it down the dependency chain. Solano (stages 3, 8: result 103;
           1985-2020: result 105), against the reports with the checked factors:
           | Solano cropland, thousand Mg C/yr | growth model / reports | harvest model / reports | yearly r growth, harvest |
           | 1986-1995 | 522 / 521 (0%; result 95: -31%) | 189 / 202 (-6%; was -27%) | 0.60, 0.37 (was 0.11, 0.06) |
           | 1996-2013 | 407 / 385 (+6%) | 175 / 166 (+6%) | 0.95, 0.84 |
           | 2014-2020 | 370 / 343 (+8%; result 95: +10%) | 156 / 137 (+14%; was +13%) | 0.72, 0.89 (was -0.14, -0.17) |
         - Open: Crop Mix outside California (the NASS county survey thins out after 2008; the Census of Agriculture in the home's
           QuickStats file is 1997-2022 every 5 years and has no county cropland total); the reports' 2021 on (another format); the
           factors not found; orchards and vegetables outside California (literature growth by crop group, or a Landsat production
           map). A county yearly yield index is no longer needed in California: Crop Mix and the Crop Yield index together follow the
           reports' years.
    7. **A climate response fitted to RAP.** RAP's yearly growth 1986-2023 against PRISM fits the yearly climate response for grass
       and shrub, in place of the Miami NPP climatology; test it with the placebo check the tree-ring response went through. The step
       most likely to change projections.
       - **Fitted 2026-11-07 (dev, not yet in the model).** dev/nonforest/04-rap-climate-sample.R: RAP NPP every year 1986-2023 at
         the 1,140 grass and shrub windows (27.5 min; 1 window failed), PRISM at each centre; raw window crops kept in the home
         (derived/rap-npp-windows, 4.2 GB; user: no full 30 m CONUS archive, about 3 TB). dev/nonforest/05-rap-climate-fit.R: the
         tree-ring form per window and life form (Annual grass, Perennial grass, Shrub), NPP over its 1991-2020 mean, pooled by
         ecodivision (DerSimonian-Laird; under 5 windows the CONUS pool). CONUS pools: precipitation 0.29 / 0.34 / 0.34, last year's
         0.04 / 0.11 / 0.12, temperature -0.001 / 0.024 / 0.025 per degree (annual / perennial / shrub); Mediterranean low (0.07-0.21).
         Leave-one-window-out: the RAP response beats the window's own mean in 75-80% of windows (Miami NPP in 23-31%: it swings 1.0-1.4
         times the observed variation, the RAP response 0.4 times); RMSE 0.18-0.20 against Miami's 0.26-0.32. Placebo (20 shuffled-year
         draws): precipitation coefficients -0.007 to -0.005, 95% within +-0.065. Perennial and shrub responses nearly equal: RAP's
         partition may share one signal across life forms.
       - **Wired in 2026-11-07 (main, not pushed).** Climate Options: Non-Forest Growth = None / Miami NPP (default) / RAP fit.
         defaults/climate/rap-climate-coefficients.csv (tools/make_rap_climate_coefficients.R): the model uses LifeForm All, one
         response per ecodivision (one climate map per flow group and year, and every grass and shrub class grows through Net Growth
         Non Forest: Total); life-form rows kept for reference. Marine's precipitation coefficient is negative (-0.14).
         tests/unit-rap-climate.R 9 pass.
       - **Solano quick test (stages 7, 8 + 1985-1995; 3.9 + 6.7 min).** The study-area non-forest multiplier's year-to-year SD
         1986-2023 is 0.038 with the RAP fit against 0.332 with Miami (1990: 0.96 against 0.56). In the Mediterranean windows RAP's
         own NPP varies with SD 0.15 of its mean; Miami swings 2.4 times that and beats the window's mean in 3% of windows, the RAP
         fit 0.33 times and beats it in 72%. So Miami is clearly wrong there, but the RAP fit catches only a third of the variation:
         Mediterranean coefficients are small (precipitation 0.12-0.15, last year's about 0). Likely cause: calendar-year
         precipitation, where Mediterranean grass grows on the October-September water year (autumn rain of one calendar year feeds
         the next spring). Next: refit on water-year precipitation (needs PRISM monthly, not in the home).
       - **Water year (built 2026-11-07, user OK).** The PRISM Data Download now also fetches monthly precipitation (from two years
         before the region's first, and 1990-2020; 516 files, 1.4 GB at the top of the home), with a have() check so a rerun fetches
         only what is new. Refit on October-September water years: better everywhere (Mediterranean r 0.33 -> 0.39, share of variation
         0.33 -> 0.39, beats the mean in 78% of windows; elsewhere r 0.45 -> 0.49); CONUS precipitation 0.39, last year's 0.04,
         temperature 0.03; Mediterranean 0.11 and Mediterranean Mountains 0.21. Stage 7 sums PRISM monthly, stage 11 LOCA2 monthly
         (loca2_annual "ppt_wy"); tree ring stays on calendar years. Solano quick test: SD of the yearly multiplier 0.047 (calendar
         0.038, Miami 0.332), against RAP's own 0.15 in Mediterranean windows. The linear response stays cautious there: total rain,
         even by water year, explains little of Mediterranean grass growth (timing within the season matters).
         Possible next step (not decided): use RAP's observed yearly NPP anomaly directly as the historical multiplier (the region's
         RapNppFolder already holds 1986 on), and the RAP fit only for projections.
       - **Calibrated to RAP's variation (built 2026-11-07, user: stay with the RAP fit, use seasons + aridity half-scaled).**
         dev/nonforest/06-rap-climate-explore.R compared five forms by leave-one-window-out prediction; the best everywhere (model SD)
         splits the water year's rain into Oct-Dec / Jan-Mar / Apr-Jun / Jul-Sep anomalies, keeps last water year and temperature,
         and lets the rain slopes vary with aridity (log of the water-year normal / 500 mm), one fit over all life forms per
         ecodivision: Mediterranean r 0.39 -> 0.43, beats the mean 73 -> 84%; elsewhere r 0.50 -> 0.53, 75 -> 83%. It still
         reproduces only about half of RAP's SD; scaling the response by k^0.5 (k = RAP's SD over the fit's, 1.2-2.4 by ecodivision)
         reproduces about three quarters at 4-7% more RMSE (beats the mean in 57-69%); full matching beats it in only 27-45%.
         Built: dev/nonforest/07-rap-climate-seasonal-fit.R, tools/make_rap_climate_coefficients.R (10 coefficients, AridMin/AridMax,
         Scale; ecodivisions with fewer than 30 windows take CONUS, since the small fits turned rain slopes strongly negative at one
         end of their aridity range); src/climate.R clamps aridity to the fit's range and floors at 0; stage 7 sums seasons from PRISM
         monthly, stage 11 from LOCA2 monthly (loca2_annual "ppt_seasons", one read; seasons sum to the water year exactly across the
         2014/2015 file split). tests/unit-rap-climate.R 11 pass. Stage 11 not yet run end to end.
         Solano quick test (stage 7 alone + 1985-1995; 2.5 + 6.7 min): the study-area multiplier's yearly SD 1986-2023 is 0.090
         (0.047 before, Miami 0.332), against RAP's own Solano SD of 0.134; r with RAP's yearly ratio 0.41; RMSE 0.130 against 0.138
         for a constant 1.0. Rerunning stage 7 on its own first failed in ST-Sim ("Object reference"): its result held the Initial
         Conditions maps without Properties and hid stage 8's productivity multipliers. Fixed: keep_ic_properties() (shared.R) in
         stages 7 and 8, and stage 7 carries dependency productivity rows over as stage 11 does.
       - **Default and projection test (2026-11-07, user: make RAP the default; keep the modeled multipliers over the historical).**
         Non-Forest Growth now defaults to RAP fit (package.xml, the Climate Options page; lucasCoreUI.dll rebuilt). Libraries whose
         Climate Options row already says Miami NPP keep it. The historical years stay on the fitted response from PRISM, not RAP's
         observed yearly NPP (decided: one model for historical and projection years). Solano stage 11 test (CanESM5 r1i1p1f1
         SSP2-4.5, 2024-2035, 2.7 min; result 52): every check passes; the non-forest multiplier's study-area mean by year is
         0.90-1.20, SD 0.097 (PRISM years 0.090), mean 0.979; cells 0.73-1.38; the last historical decade 0.974 -> the first
         projected 0.975, so no step at the join. A projection-climate scenario on a quick-test result (stage 7 alone) needs the
         full Build result as a second dependency: CO2 fertilization reads stage 3's flow multipliers. Not run: an ST-Sim projection
         (needs a full historical run and a Projection Setup); the multipliers enter it through the same sheet as historical years.
    8. **Shrub growth by age.** Chaparral regrows for 20+ years after fire and sage for decades, so growth by age after fire (the
       Non-Forest Growth sheet already has an age column) in place of a constant rate at equilibrium. Matters most in P26.
       - Chaparral was already by age (built 2026-11-06, item 39 step 1 notes). **The sage family built 2026-11-08 (user: "Shrub
         growth by age"; branch 51d6a45, main fast-forwarded, not pushed).** Sage, Native and Invaded Sage Steppe, Non-sage, Post Fire Shrub.
         - RAP chronosequence (dev/nonforest/08-shrub-fire-recovery.R; 6.7 min, the 1,140 windows' kept RAP crops, MTBS perimeters
           1984-2023, RCMAP 1985 classes, nothing downloaded): NPP of cells in one 1988-2022 perimeter against unburned cells of the
           class in the window that year, over the same ratio before the fire. 130 windows; 16 (Sage) to 121 (Non-sage) fires. Total
           NPP 0.81-0.91 of unburned in the fire year and the next, 1 or more from year 2 (herbs 1.2-1.8x unburned in sage classes);
           shrub NPP 0.47-0.64 at year 1 (perimeters hold unburned ground: 36-53% burned), then flat at about 0.7 for 30 years in the
           sage steppe classes and back by 10-15 years in Non-sage. Chaparral total back by year 2 (the chamise curve's growth is
           already about flat with age).
         - Literature (dev/nonforest/review/sage-recovery-literature.md, not committed): big sagebrush is a seeder, mountain
           sagebrush back in about 37 years (Nelson et al. 2014), Wyoming 18% at 16 years and 50-120+ (Bates et al. 2020; Baker
           2006); RAP / NLCD shrub cover recovers too fast (Applestein and Germino 2021), so the woody curve is the literature's.
         - Model (tools/make_grass_shrub.R; defaults/stockflow/shrub-age.csv): by years since high-severity fire a, wood and coarse
           root shares of growth = mature x (1 - exp(-k (a + 1)))^p (Sage and Native Sage Steppe k 0.035 p 2: 25/50/90% at
           19/34/84 years; Invaded 0.02, 1.5: 24/49/134; Non-sage 0.05, 1.5: about 8/19/50; Post Fire Shrub 0.25, 1.2: 90% in 9);
           foliage and fine roots take the rest in their mature ratio (the herbs filling in); Net Growth x 0.6-0.8 in the fire year
           and the next (RAP's dip over the burned share), mature from year 2. Turnover and decay stay the class's. Rows each year to
           39, then 5-year bins to AgeMax (150; Non-sage 100, Post Fire Shrub 30): 26,410 growth-split and 5,358 Net Growth rows.
           Starting pools by age (initialstocks/shrub-age.csv): the mature steady state after the class's high-severity fire
           (nonforest-fire.csv) grown on; the AgeMax row is the steady state itself (regrowth reaches 96-98% of it by 150).
           Temperate Desert Sage: wood 0 at 0, 0.02 at 10, 0.19 at 30, 0.87 at 150 Mg C/ha; foliage back to 0.27 by year 5;
           surviving coarse roots (10%) die back for about 10 years before the new shrubs rebuild them.
         - Stage 5 gives these cells their years since the last fire perimeter (never burned since 1900: the class's AgeMax, mature);
           stage 8 fills them by age bin (fill_class takes the bin at or below a cell's age); high-severity fire resets their age
           (medium and low do not; fire.csv). tests/unit-nonforest-solve.R 35 of 35 (new: bin pools step to the next bin's, gap
           9.6e-5; wood rises; AgeMax = the literature split and RAP NPP); unit-carbon-assumptions ALL PASS; unit-agriculture 33.
         - Solano quick test (stages 3, 5, 8 on Build result 20: result 107, 12.2 min; 1985-2020: result 109, 25.2 min; every
           check passes). Stage 5: 178 Non-sage cells, 66% burned since 1900 (median 15 years since fire), the rest at 100;
           chaparral 483 cells, 78% burned, median 9 (the summary line had recycled an index against a logical vector and printed
           21; the ages themselves were right). Stage 8: every sage-family cell finds its age bin. Non-sage per hectare against
           result 95 (the same years before this change; fire areas the same within 1%): 1985 wood 2.26 / coarse roots 7.15 (was
           4.85 / 11.65), 2010 1.94 / 5.33 (4.44 / 11.48), 2020 after the LNU fires 0.63 / 3.74 (1.14 / 7.06); foliage and fine
           roots a little higher (the herbs). Chaparral unchanged. Solano has no Sage or Sage Steppe cells: P26 and the Great
           Basin are where this matters.
         - Open, from the literature check: mature sage aboveground (1.0 Mg C/ha, Nagy et al. 2021) is at the bottom of the direct
           harvests (Bradley et al. 2006 about 4.4-5.0; Cleary et al. 2010 3.1 at 39 years); the fire rows' root kill (Sage 90%)
           against the literature's view that grass roots survive (about 50% of root carbon); a sage foliage share falling with age
           (Rittenhouse and Sneva 1977); Invaded Sage Steppe may never return to sage (a conversion, not regrowth).
    9. **Validation throughout,** against data the calibration did not use: RaCA soil carbon, AmeriFlux grassland and sagebrush sites,
       and the US greenhouse gas inventory's grassland and cropland soil change totals.
       - **Paused 2026-11-08 (user: "pick it up later").** Plan: no model runs needed except for the inventory totals (a CONUS run;
         compare its per-hectare soil change after conversion from the tables instead). RaCA against the starting soil by
         ecodivision x class (RaCA locations are blurred); AmeriFlux grassland and sagebrush towers against growth, the RAP climate
         response and post-fire recovery, stepped in R (src/nonforest-solve.R). Nothing downloaded yet; to ask first: the RaCA SOC
         pedons CSV (NRCS, about 0.8 MB; the full zip about 336 MB only if needed) and the EPA 1990-2022 inventory's Chapter 6 PDF and
         LULUCF tables zip. AmeriFlux BASE files need the user's account (CC-BY-4.0): candidate sites US-Var, US-Rws, US-Rls, US-Rms,
         US-Wkg, to confirm against the public site list.
    10. **Emergent wetlands vary across the map (planned 2026-11-07, user: at least look at these as options).** Emergent wetlands
        have no spatial or climate multiplier today; growth, burial and soil are one value per ecodivision x class. Candidates, from
        memory and not yet checked (data release, coverage, access):
        - Tidal marsh growth: Byrd et al. 2018 (USGS), 30 m CONUS tidal marsh aboveground carbon from Landsat and field plots, as a
          multiplier the way RAP is for grass and shrub (cell / ecodivision x class mean, filled to nearby cells). It is standing
          biomass, not growth: assumes growth scales with biomass (reasonable for marsh grasses that turn over yearly).
        - Tidal marsh soil: Holmquist et al. 2018, 30 m tidal wetland soil carbon to 1 m, in place of the regional value; soil decay
          then per cell or calibrated to the ecodivision mean, as forest's is.
        - Inland (palustrine) marsh: no national productivity map fit for wetlands (RAP misreads flooded vegetation; MODIS NPP is
          500 m and poor over wetlands). The NWI water regime (temporarily, seasonally, semi-permanently flooded) could modify decay
          and burial instead of growth; the decay difference by regime would come from thin literature.
        - A climate response for wetland decomposition (temperature), which likely matters more for projections than either map.
        Order if adopted: tidal growth and soil first (same pattern as step 5), then NWI water regime, then the climate response.
        - **Checked 2026-11-08.** Byrd 2018 maps standing biomass in six regions only; a 2023 USGS release (Woltz, Stagg, Byrd,
          Windham-Myers, Rovai and Zhu, doi 10.5066/P9I1PCLS, CC0) maps total NPP of estuarine and palustrine tidal marsh at 30 m for
          CONUS, 2015 (aboveground one third everywhere: peak biomass, one crop a year). Holmquist 2018 soil (ORNL DAAC, needs an
          Earthdata login) adds little over one mean density by its own paper: not taken. Decay: emergent litter already takes CBM's Q10
          (2.0-2.65; the one marsh study, Kirwan et al. 2014, has 1.3-1.5) and wetland soil (BG Slow) none. NWI water regime: weakest.
        - **Tidal marsh NPP built 2026-11-08 (user: "recalibrate and use the map for pattern"; main ba0d00e, not pushed).** Downloaded
          (user OK) to <home>/wetlands/tidal-marsh-npp (163 MB zip; EEM and PEM rasters). dev/nonforest/09-tidal-marsh-npp.R ->
          defaults/stockflow/tidal-marsh-npp.csv (by ecodivision x class). Against the model's regional values (inference: estuarine 5-8
          picked in a 5-15 class range, the Pacific set low from memory): Subtropical 8.5 vs 8 (13,411 km2), Mediterranean 12.2 vs 6,
          Marine 7.8-8.1 vs 5, Hot Continental 9.7 vs 8, Savanna 2.8 vs 8; tidal palustrine 8-14 vs 4-7 (the model class is mostly inland).
          tools/make_emergent_wetland.R: estuarine NPP and peak foliage (= aboveground NPP, the map's one crop a year) from the map where
          it holds 10 km2 or more (8 ecodivisions); palustrine keeps its regions. Savanna: map NPP 2.83 cannot supply the region's burial
          with the soil target held, so burial gives way (user: NPP matters more): 1.62 -> 0.573 (scaled by map / region NPP). Burial is
          its own target (Wang et al. 2019), not calibrated from soil carbon. Build Options: Tidal Marsh Productivity (None / USGS tidal
          marsh NPP (2015)), stage 8: cell's mapped NPP / its ecodivision x class map mean, capped 0.3-2.5, on Net Growth Wetland: Total;
          live and dead carbon scaled, soil not; no map pixels: 1. Data Sources: TidalMarshNppFolder (data-sources.csv row, Data Download
          handler, citation). tests/unit-nonforest-solve.R 37 of 37; metadata, carbon assumptions, agriculture, CO2, strata-home pass.
        - **Solano (option on in Build scenario 3; synced; stages 3, 5, 8 on Build 20: result 110, 12.4 min; 1985-2020: result 112, 23.5
          min).** Every check passes. Estuarine 2,590 cells 99.9% mapped, multiplier mean 0.99 (10% 0.83, 90% 1.14); palustrine 1,280
          cells 64% mapped (the rest inland), mean 0.89 (0.66-1.14). Estuarine growth 6.0 -> 12.1 Mg C/ha/yr against result 95; litter,
          soil and burial about the same (the fit holds them: the extra growth decays and moves out laterally); year-end live roots 1.5 ->
          0.04 (peak roots = foliage x root:shoot is about the year's root growth, so roots turn over yearly, as the map's own
          one-crop assumption implies). Soil drifts down where the multiplier is below 1 (soil is not scaled): palustrine BG Slow 194.0 ->
          190.8 by 2020 (193.6 before). Open: whether to scale soil too, or set peak roots from the release's belowground biomass layer
          (not downloaded), which would keep live roots through the year.
    - Still open from the review: root turnover, chaparral root:shoot, Non-sage shrub (no data), shrub litter decay rates, the pasture
      management factor, the wetland 0-30 cm and deeper split, the IPCC climate-zone raster.
46. **CO2 fertilization** - TO DO, open science (user, 2026-11-04: how can we introduce the effect of CO2 fertilization into the model?).
    Today no growth pathway responds to CO2, so projected growth carries the climate penalty with no offset, and the SSPs differ only
    through climate. Nothing is built; the proposal below is a starting point and its literature values are from memory, to verify.
  - **Proposed form:** the standard beta factor, `multiplier = 1 + beta x ln(CO2 in year t / CO2 reference)`, with one flow multiplier per
    growth flow group and year, under its own Flow Multiplier Type ("CO2"), like Climate and Site Productivity. It does not vary across the
    map, so non-spatial rows in stsim_FlowMultiplier may do; check that they combine with the spatial multipliers as expected. Dead pools
    follow through larger litter inputs, with no change to decay.
  - **Reference year (the main trap):** the growth curves are fitted to FIA plots, so they already hold the CO2 of those measurements.
    The reference must be the CO2 of the plots' measurement years, not preindustrial, or the effect is counted twice. Before that window the
    multiplier falls below 1, so decide whether it applies in the historical period too, and test the stage 13 hand-over.
  - **No overlap found in the climate terms, to confirm:** the tree-ring response comes from standardized ring-width indices, whose long-term
    trend is largely removed, and Miami NPP is a climatology with no CO2 term. Check that the standardization used does remove it.
  - **Beta is the uncertainty, so run it as a range:** FACE experiments gave about +23% NPP in young stands at about 550 ppm (Norby 2005;
    beta about 0.6), but the response faded under nitrogen limitation (Oak Ridge; Norby 2010), mature stands responded little or not at all
    (EucFACE; Ellsworth 2017, Jiang 2020), and tree rings often show better water-use efficiency without more growth (Penuelas 2011, van der
    Sleen 2015). Choices: one beta with low/central/high cases (0 = today), or by functional type. Possible refinements: lower in mature
    stands, on nitrogen-poor sites, and for C4 grasses, with more response where water limits growth.
  - **Size against the climate signal:** at about 530 ppm by 2050 (to check against the SSP table) from a 400 ppm reference, beta 0.3 gives
    about +8% and beta 0.6 about +17%. Puget's forest climate multipliers in 2041-50 are 0.90-0.94 (results 30, 32, 33), so the same size and
    able to change the sign of a growth trend.
  - **Inputs and options:** CO2 by year from observations (NOAA) and the SSP concentrations (Meinshausen 2020), shipped in defaults/climate
    with citations, so no download. Climate Options gets a CO2 effect (None by default, so results do not change) and beta. Stage 11 reads
    the run's SSP. A run with no climate (constant climate) needs a stated choice: probably no CO2 either.
  - **Testing:** FIA remeasurement failed a placebo test for annual climate sensitivity (defaults/climate/README.md), so it is unlikely to
    isolate a CO2 trend. Report results as a sensitivity range, with the unit tests checking the multiplier against hand values.
  - **Decided by the user 2026-11-05:**
    - **Projections only:** the FIA data behind the growth curves already hold the CO2 effect of their measurement years, so historical runs
      get no CO2 multiplier. The multiplier is 1 at the reference (the projection start, or the CO2 of the FIA measurement window) and
      grows from there.
    - **Betas from the science:** a thorough review of the latest CO2 enrichment findings sets the default beta range and how it varies by
      the model's vegetation types (forest type groups, shrub, grass, wetland, agriculture).
    - **Defaults grounded, users can adjust:** given the large uncertainty, the reviewed values are the defaults, with optional user
      adjustments (for example low, central and high cases, or per-type betas on a page).
    - The approach follows the user's own earlier Global Change Biology study, which applied a CO2 fertilization effect in LUCAS:
      an annual multiplier, in several versions (one per CO2 enrichment assumption), that scaled base growth the way the Climate and
      Site Productivity multipliers do now. So here: one CO2 multiplier series per year and per assumption (low, central, high, or
      user betas), as its own Flow Multiplier Type on the growth flows; the run picks the series.
  - **Literature review done 2026-11-05** ("CO2 fertilization betas for LUCAS", reports/ in the lucas-master session worktree; notes
    beside it in research_notes/). Recommendations, beta per ln CO2, low/central/high:
    - Match biomass production (NPP into the live pools), not GPP (0.5-0.7) or stock change (about 0.25): stage 3's growth flow is the
      gross inflow to the live pools.
    - Forest young ECM 0.20/0.45/0.65, young AM 0.10/0.30/0.65, mature ECM 0.05/0.30/0.45, mature AM, mixed or low-P 0.00/0.15/0.35,
      single default 0.05/0.25/0.55. Shrub 0/0.15/0.40; grassland 0.10/0.30/0.60 (no C3/C4 split: BioCON reversed over 20 years); pasture
      0.15/0.35/0.55; crops 0.10/0.20/0.30 (revised: C4 about 38% of cropland without hay, NASS 2024); woody wetland 0/0.20/0.30 (no
      experiment); emergent wetland 0.00/0.20/0.35 (revised: GCReW sedge about +20%, the C4 grass declined).
    - Build in type and age: no published age threshold, so a taper (full young beta below about 20-30 years, falling to a non-zero
      mature floor by about 100 years) in age-banded stsim_FlowMultiplier rows (AgeMin/AgeMax); a modelling choice. Mycorrhizal type
      by forest type: apply the Jo et al. 2019 species list to FIA tree records and weight the ECM and AM betas by ECM basal-area share
      (groups 500, 800 and 180 are mixed; several ECM groups hold AM cedar or juniper types). Leave nitrogen, phosphorus, water and a
      600 ppm cap to user settings.
    - Central forest beta 0.25 gives 2100 multipliers 1.087 / 1.178 / 1.245 (SSP2-4.5 / 3-7.0 / 5-8.5: 602.8 / 867.2 / 1135.2 ppm,
      Meinshausen 2020 Table 5) from 425.6 ppm (NOAA global mean 2025); the model uses its projection start year's CO2.
    - **Checked against the papers 2026-11-05:** about 31 flagged values, now each CONFIRMED, CORRECTED or STILL UNVERIFIED in the
      report's table (the checks are verify_*.md in research_notes). Corrected: Wang 2020, Davis 2022, Keenan 2023 (beta 0.62 linear),
      Terrer 2019 (375 to 625 ppm, log beta 0.23), PHACE, the marsh, scrub oak, Hawaii (reference 2010). Still unverified: Duke +11% with N,
      some ambient CO2 levels, per-crop FACE numbers, the FIADB type codes and species tables, the woody wetland ratio.
    - Sleeter et al. 2019 (GCB, doi:10.1111/gcb.14677): linear in ppm, 2.7-13.6% per 100 ppm (beta about 0.12-0.62, Medium 0.35),
      from 2002 (historical too), one beta for every class, not in the main scenarios. The new defaults sit a little lower for forests and
      well lower for shrub and grass.
    - Options: None/Low/Central/High/User series (Central the default), a per-type user beta table with stratum overrides, a CO2 cap,
      the reference CO2 shown; No Climate gets no CO2 by default.
  - **Decided 2026-11-06:** the user accepted the review's revised default table (crops 0.10/0.20/0.30, emergent wetland
    0/0.20/0.35, the rest as reviewed) as the starting point. Both the age taper (AgeMin/AgeMax rows) and the mycorrhizal
    weighting (ECM basal-area share per forest type from FIA tree records and the Jo et al. 2019 species list) go in the first
    build. The No Climate projection gets no CO2 fertilization (it stays the true baseline).
  - **Built 2026-11-06:** src/co2.R and stage 11 (CO2 rows in stsim_FlowMultiplier with the Build's rows
    copied over), the Climate page's CO2 group (series, ceiling, reference; CO2 Betas table loaded with the series' defaults for the study area's strata, user decision 2026-11-06, reloaded on a series switch), defaults/climate/co2-*.csv (SSP CO2
    from RCMIP v5.1.0, betas, classes, age bands, ECM shares from tools/make_co2_ecm_share.R), tests/unit-co2.R (33 checks pass).
    Departures from the plan: the user rows adjust any series rather than a separate "User" series; the reference CO2 defaults to the SSP's value in the historical end year.
  - **Run test 2026-11-06 (Puget Lowlands, with the user's OK; future tests go in a test library):** climate scenario 70 -> result
    71 (stage 11, 5.5 min; ACCESS-CM2 SSP2-4.5 to 2050, Central; CO2 426.1 -> 506.9 ppm, reference 423.1 = SSP2-4.5 2023; 5,562 CO2
    rows + the Build's 154,406 rows; 2050 multipliers forest 1.030-1.081, shrub 1.027, grassland 1.054, wetlands 1.036). Projection
    72 -> result 73 against result 65 (same climate, no CO2): growth ratio 1.001 in 2024, 1.012 in 2030, 1.031 in 2040, 1.048 in
    2050 (forest 1.049, non-forest 1.050, wetland 1.036 = exactly the emergent multiplier, so the rows take effect in ST-Sim).
    Ecosystem carbon 2050: 365.32 vs 363.11 Tg C (+2.2 Tg; biomass +1.7, dead organic matter +0.5). Puget also got sync-library
    (Co2 columns, CO2 type; backups .bak-20261106-0958 and -0959) - scenarios 70-73 and the backups await the user's keep/delete.
  - **Studio check 2026-11-06:** the user opened the CO2 page with the loaded CO2 Betas table and said it "looks great".
  - **Jo et al. 2019 comparison (2026-11-06, user request):** their species list (PURR doi:10.4231/R76D5R7S, CC0; 379 FIA codes)
    agreed with the genus table on 345 of 374 typed species. The 29 differences: poplars, aspens, willows, alders and eucalypts EM
    (the genus table counted them half), Cercocarpus, Casuarina and Guapira EM, Gleditsia AM+EM; ERM and NM trees left out of the
    share. The ECM shares now use their list first (defaults/climate/co2-mycorrhiza-species.csv), the genus table (aligned with their
    genus choices) only for species they lack. Changed: Aspen/Birch 0.59 -> 0.85, Alder/Maple 0.54 -> 0.76, Elm/Ash/Cottonwood
    0.21 -> 0.27, others 0.03 or less. Puget's result 71/73 used the old shares; scenario 70's CO2 Betas table holds the old defaults
    (Load the defaults refreshes it; it will ask, since the rows now differ).
  - **User Guide 2026-11-06:** new section 7.3.1 CO2 fertilization (equation, default beta table, ECM and age weighting, the page
    settings and CO2 Betas table, results, the Puget test, how to separate CO2 from climate, sync-library) and a pointer in 7.3
    step 12 (Claude Doc rev 461); Figure 7.22, the user's screenshot of the CO2 page (captures/7.3k-co2-page.png), with figures
    7.22-7.31 renumbered to 7.23-7.32 (rev 475). The repo snapshot (docs/guide) is not rebuilt.
  - **Age-band check 2026-11-06 (dev/co2/age-band-test.R, synthetic ST-Sim library dev/libs/co2-age-test.ssim):** cells of ages 10,
    25, 26, 100, 101 in five strata; stage 11's three row shapes (blank-stratum bands, stratum x band, one blank row) with year 1 and
    year 2 values, and a 0.5 blank-type row. All four variants (0.5 untyped, 0.5 per class, 0.5 alone, 0.5 and CO2 on two groups
    holding the same flow) exact on 30 of 30 rows. The year-t multiplier is the band of the cell's age at the start of year t (a cell
    aged 25 takes band 1 in year 1, band 2 in year 2). stsim_OutputFlow lists a flow once per group it belongs to: sum one group.
  - **P26 synced 2026-11-06** (user request): moved to 1.1.0, SyncroSim update, sync-library (CO2 columns and type, Pasture and
    Cropland attributes; Ag Change types were there). Backups .bak-20261106-v101 (before the move) and .bak-20261106-1303. Its
    climate scenarios now read blank CO2 fertilization as Central when rerun; its results are unchanged until then. The user said every
    other dev library except Puget is a throw-away test library: no sync owed there.
  - **Still to do:** a release (version bump, .ssimpkg).

47. **Example libraries by region and resolution** - TO DO, idea stage (user, 2026-11-04; replaces item 13). A range of libraries, already
    run and able to be rerun, covering different regions and resolutions. Users pick the one that matches their interest: geography, land
    cover, major transitions or model resolution.
  - **No separate demo code (user):** each library is a data release (stage 17), whose archive is a `.ssimbak` of the whole library, with its
    tables, maps, figures, metadata and rerun instructions.
  - **Must pass first:** restore an archive into a new library and run a parent scenario, ideally on another computer (user: later).
    tests/phaseZ-data-release.R only checks that the `.ssimbak` exists, so `how-to-rerun.txt` is unproven. The archive holds no Data Sources
    Home inputs, so the test should also show what can rerun without a Data Download.
  - **Keeping them current:** each library is tied to a package version and carbon method, so items 39 and 46 date them. Build the full set
    after the open science items settle, with one or two until then, and treat each as a fixed, versioned release that states its package version.
  - **Catalog:** one page or table: region, resolution, main land cover, main transitions, fire or not, run years, scenarios, download size,
    package version. Fill it from each release's model record and contents where they hold the fields (not yet checked).
  - **A possible first set (to decide):** P26 Northern Sierra Nevada (fire, forest; matches the guide; built and run), Puget Lowlands (urbanization,
    harvest, marine climate, no fire; built), one region at a second resolution (needs a build), and a region outside the West, such as agriculture
    or southeastern plantation forestry (needs a build, and tests the package beyond the western regions it has run on).
  - **Size and hosting:** Puget's archive was 3.6 GB before its projections, over GitHub's 2 GB limit per release file, so host on ScienceBase
    or similar. A coarser version of a region could be the small entry point; a results-only download would be a new stage 17 option.
  - **For the user to decide:** which regions and resolutions; whether each is a formal USGS data release with its own review, or some are
    informal examples; where the catalog lives.

49. **Test national mode end to end** - TO DO (user, 2026-11-04; carried over from item 44). Fill a national home (about 175 GB, overnight; MRLC
    served about 1.3 MB/s), then run stage 1 on P26 and P29 against it. Done when both pass and their study areas match the same regions built
    from regional downloads; report what differs. Needs enough free disk and an overnight window, and RCMAP still comes by hand (see <home>/supplied).

50. **Water, wetland and barren change** - TO DO, planned 2026-11-05 (user: lake and reservoir fluctuation, and coastal change, consistent with the
    other land-use changes). Today a change among water (11), barren (31), woody wetland (90), emergent wetland (95) and upland natural land has
    no pathway, so it is on no map and the model holds the cell's old class. Maps measured 2026-11-05 (area-matched, 1985-2023; sustained = not
    back within 3 years): P26 upland to water 158 km2 and back 150 (reservoir shorelines; water 714 -> 736 km2), barren to water 46, water to
    barren 17, emergent wetland to water 17; Puget water to barren 24 and back 19 (river bars, tidal flats), upland to water 23 and back 20,
    agriculture to water 17, emergent wetland to water 14 and back 13, only 9 km2 on C-CAP estuarine cells. Puget's upland to woody wetland of
    28.5 km2 in the 1990s alone looks like an NLCD classification shift: check it first. Change to or from developed or agriculture stays with
    urbanization and agriculture.
  - **Groups:** one type per class pair (the stage 6 pair rule), in two groups: Water Change (to water; from water to barren or land) and
    Wetland Change (gain, loss). The package's unused Wetland Change types and groups are reworked to fit (one name reads "Palustine").
  - **Maps:** stage 6 builds them the same way: class pairs from the held class, with persistence: 5 years for water changes (user, 2026-11-05;
    3 years is too short for reservoirs, whose drawdowns last through droughts). Paused: an open to-do, not being built.
  - **Destination class:** the annual NLCD gives woody or emergent wetland only; palustrine vs estuarine comes from C-CAP (static). Proposed:
    the nearest wetland class of the start year, and the nearest upland class for land, with gates like ag contraction's.
  - **Carbon (to decide):** proposed: vegetation lost to water or barren moves to the dead pools; soil under new water stays and does not decay
    (water has no decay rates); new wetland or land starts from what the cell holds. Wetland soils are large (Palustrine Emergent about 609
    Mg C/ha), so the choice matters. Overridable on Disturbance Flows.
  - **Projections:** each type its own target, as clearcut and selection, from what the historical run realized (Targets From Historical Run);
    placed by adjacency to the class the cell becomes (Projection Allocation Method Adjacency, as Ag Change). Sea-level rise is not in the
    record: a coastal scenario would be a separate option.
  - **Optional:** C-CAP coastal change (1975-2016) for estuarine wetland change in coastal regions, after the NLCD version works.
  - **Checks:** map counts (mapped against sustained, by pair), the replay check, then a Build and historical run.

51. **After the 1.1.0 release** - TO DO, added 2026-11-05. What the release left, in no fixed order:
  - **P26 guide library:** moved to 1.1.0 and synced 2026-11-06 (item 46); still to rebuild and rerun.
  - **Other dev libraries:** throw-away test libraries (user, 2026-11-06); no move or sync needed.
  - **Puget parents on old Build 6:** Build Figures (7), Build Record (9), Historical Figures (16), Data Release (18) and Compare
    Projections (42) depend on Build 6; repoint them to 58 before their next run. The climate scenarios (23-25) depend on Build 6 too;
    that is harmless (their Build 6 rows match 58 exactly), but rebuild them on 58 at some point.
  - **Puget Recent set:** deleted by the user 2026-11-05, to be rebuilt on Build 58 / run 59.
  - **User Guide:** add Ag Change, Run Settings "Target areas from" and the Adjacency allocation method; then rebuild the docs/guide
    snapshot.
  - **code.usgs.gov:** resync the release copy (`bash tools/release-snapshot.sh --sync=F:/lucasCore-release`, then the user pushes).
  - **Stage 6 log:** "% on classes with no pathway" still uses the start-year class (reads far too high for intensification).
  - **Stage 9/10 safeguard:** fail or warn when Projection Start and "Target areas from" name different historical runs (setup 60 started
    from run 13 with targets from run 59); and sync-library could add default rows for new groups to sheets that already have rows (setup
    21 had no Ag Change rows).
  - **Uncommitted:** `dev/fire/01-projection-fire-maps.R` (the lucasFire library path after the move).
  - Checked 2026-11-05: a new 1.1.0 library gets Pasture and Cropland and the Ag Change types and groups from the package.

52. **Data home loses its download records** - DONE 2026-11-07 (user, 2026-11-06: leave it for now, but first on the list). The
  Solano Data Download (2026-11-06, `E:/lucasData`) fetched about 9 GB of national datasets that were already in the home: FIA DataMart
  (3.2 GB, 1.5 hours), TIGER counties, EPA ecoregions, WBD watersheds, PAD-US and LOCA2. Pyromes was fetched again on 2026-11-04 at 16:29.
  The files were intact (139 FIA files identical and kept; 54 "unrecorded files left by an unfinished download" replaced); what was lost
  is their rows in the top-level `manifest.csv` / `files.csv`, which `dataset_up_to_date` (src/download.R) needs to skip a dataset. On
  2026-11-04 at 09:56 the same home logged all of these "up to date in the top of the home", so the rows went missing between 10:34 and
  16:29 that day. Find what rewrote or truncated the top-level records (a Data Download into a region folder, a test, the Data Sources
  page, a concurrent run), fix it, and consider a fallback: treat a dataset as present when every planned file is already in place with a
  known size, instead of fetching it again.
  - **Cause (found 2026-11-07): not the code.** `E:/lucasData` itself was created at 15:15:09 on 2026-11-04, and every folder in it,
    the logs included (the Nov 1 logs have creation time 15:17:45), between 15:15 and 15:17: the home was copied to E: folder by folder,
    and the three files at its top (`manifest.csv`, `files.csv`, `settings.csv`) were not copied. `settings.csv` was written new at
    16:28 (the LANDFIRE email typed again), and the 16:29 download fetched every national dataset again ("8 files already in place,
    identical: kept" for each). The region folders' tables were inside folders, so they came along and nothing was fetched for them.
    No writer of the tables (`.write_home_table`, `home_to_region`, stage 15, the tests, which use a temporary home) can drop rows of
    another dataset.
  - **Fix: a copy of each dataset's rows inside a folder.** A done dataset's manifest row and files.csv rows are also written to
    `<folder>/records/<Column>-manifest.csv` and `<Column>-files.csv` (src/datahome.R `write_record`, called by `run_dataset` after it
    records; `home_to_region` moves them with the rows). Stage 15 starts with `home_restore_records` on the top, every region and every
    edition folder: rows the tables lack come back from records/ when every recorded file is on disk at its recorded size (else it
    says which dataset could not be restored, and that dataset is fetched as before), and a done dataset with no record yet gets one,
    so an existing home is covered at its next Data Download. `Rscript tools/data-home.R <home> --restore` does the same by hand.
    Not done: treating files in place as present with no record at all; their version and region cannot be known from the files.
  - Tested: tests/unit-home-regions.R (37 pass, 7 new): with both top tables removed and a region's files.csv removed, the rows come
    back, and a rerun skips without planning a fetch; a file of another size is not restored; a done row without a record gets one.
    The real home: `tools/data-home.R E:/lucasData --restore` wrote the records of all 14 top datasets and of every region's.
  - Guide: section on Data Sources Home (the paragraph on `manifest.csv` and `files.csv`) needs a sentence on `records/` and on
    copying a home whole (the Claude Doc; left for the user).
53. **Forested wetlands as wetland counterparts of three forest type groups** - PLANNED 2026-11-09, not started (user: pick up in a
  new session once the commits since v1.1.0 are confirmed in the UI). Today `Wetland: Palustrine Forested` (and Estuarine Forested)
  use one generic forest curve copied to every ecodivision (net growth 3.8 Mg C/ha/yr at maturity), upland forest decay, about 54 Mg
  C/ha of soil and no burial. Stage 5 knows each woody wetland cell's forest type group (`Fz`) but overwrites it with the wetland
  class (src/5-initial-conditions.R, the state class block).
  - **Review:** literature on saturated decomposition, wetland soil carbon and burial, and how models (DayCent, DNDC, LPJ-WHy, CaMP)
    slow decay under saturation: `dev/nonforest/review/reports/Woody wetland carbon modeling.md` and its notes (local only, not in
    git). Main points: leaf litter barely slows (flowing or tidal water can speed it); soil decay falls to about 0.2-0.35 of
    aerobic; peat routes more of the litter and root loss into soil; mineral woody wetland soils hold about 125 Mg C/ha to 1 m and
    organic about 600 (Uhran et al. 2021); burial about 0.2-0.3 Mg C/ha/yr on peat, mangroves 0.8-1.6. The US GHG Inventory counts
    these wetlands as Forest Land through FIA, with no wetland decay or burial.
  - **Why three classes (user, 2026-11-09: "it is really just 3 classes"):** FIA conditions on hydric sites (physiographic class
    31-39; latest inventory per plot from 2000; condition proportion summed) are 5% of forest. Three groups hold 77% of them:
    spruce/fir 37.5% (57% of the group's plots are hydric; MN, MI, WI, ME), oak/gum/cypress 21.6% (31%; FL, GA, NC, LA, SC, AL),
    elm/ash/cottonwood 18.1% (23%; MI, WI, MN, NY). Next are aspen/birch 4.4% and oak/pine 4.0%; every western group is under 0.3%.
    Hydric plots (conditions) by group and main ecodivision: spruce/fir 3,433 (Warm Continental 3,278), oak/gum/cypress 2,141
    (Subtropical 2,036), elm/ash/cottonwood 1,853 (Warm Continental 1,131, Hot Continental 396, Subtropical 249); nearly all have a
    stand age. Tally scripts were throw-away (FIA DataMart COND + PLOT, REF_FOREST_TYPE).
  - **Design chosen (user, 2026-11-09: "the most reasonable option"):** wetland twin classes, not a per-cell saturation map and
    not a hydrology stratum (the tertiary stratum holds Federal Lands).
    1. FIA split: in src/fia.R, hydric conditions of groups 120, 600 and 700 take their own group codes 121, 601 and 701, so every
       step keyed on the forest type group separates them (growth fits, DOM calibration to FIA measured dead wood, harvest ages,
       stem turnover, snag fall). The upland classes lose their hydric plots (spruce/fir changes most).
    2. Classes `Wetland: Spruce/Fir Group` (121), `Wetland: Oak/Gum/Cypress Group` (601), `Wetland: Elm/Ash/Cottonwood Group` (701),
       state label X Wetland, Y the existing type labels. Ids inside 100-999 so growth, spin-up and stage 8 treat them as forest;
       the checks that match the name "Forest:" (stage 4 rates filter, stage 6 harvest, figures.R, run-figures.R) move to the id.
    3. Every transition and table row of the three upland classes copied for its twin (user: "all the transitions that exist for
       those three forest classes will need to be updated for their wetland counterparts"): pathways fire, harvest, ag expansion,
       ag contraction, urbanization (and any other pathway file holding them), state-locations, harvest-age, transition types Ag
       Contraction Cropland / Pasture and Succession Post Fire with their group rows, spin-up return interval and soil targets, CO2
       classes / default betas / ECM share, carbon method presets (growth-inputs, cbm-crosswalk, live-turnover), species crosswalk,
       merchantable density, forest-type crosswalk. Written by a new tools/make_wetland_forest.R so it reruns when upland rows
       change; a unit test checks every upland row has its twin. Ag contraction picks the nearest natural class of the start year,
       so the twins join it unchanged.
    4. Stage 5: woody wetland cells (NLCD 90, including those that were ever forest and today run as upland; NLCD 95 with C-CAP
       forested or scrub-shrub) take the twin when `Fz` is 120, 600 or 700. Estuarine Forested stays as it is.
    5. Decomposition: from the stage 3 calibration on hydric plots (FIA measured down wood, snags, litter and duff), with soil fitted
       to gNATSGO per cell; the review's per-pool multipliers become a check on the fitted rates. Burial: a BG Slow -> Deep Soil flow
       for the twins.
    6. Tests: unit tests for the rows; a throw-away eastern test library (for example around the Great Dismal Swamp or northern
       Minnesota: Solano and Puget have almost no hydric forest); fitted rates against the review's multipliers, soil and burial
       against its targets.
  - **Decided (user, 2026-11-10):**
    1. Woody wetland cells of the other type groups (about 23%; user: "assign those cells ... to one of our three forested wetland
       classes ... which is closer or more common in that region"): each takes the twin most common among the FIA hydric forest plots
       of its ecodivision (by condition proportion); an ecodivision with too few hydric plots to choose (the West: mostly riparian
       cottonwood and willow) takes Elm/Ash/Cottonwood. `Wetland: Palustrine Forested` and its generic curve are retired. The cost:
       those cells grow on the twin's curve, not their own type's (a wet aspen stand grows as spruce/fir wetland). The build prints a
       tally of the reassigned cells by ecodivision and source group.
    2. Burial (BG Slow -> Deep Soil): spruce/fir 0.25 Mg C/ha/yr, oak/gum/cypress 0.1, elm/ash/cottonwood none (mostly mineral
       floodplain, where the carbon is river sediment).
    3. Peat fire and drained peat are part of this to-do, not a follow-up (user: "include now"). Organic-soil cells from gNATSGO
       (Histosols; already downloaded) are marked; on them fire also burns BG Slow (depth of burn by severity), and woody or emergent
       wetland converted to cropland or pasture loses soil carbon as drained organic soil. Rates from the woody wetland review plus a
       short check of peat-fire depth of burn and the IPCC 2013 Wetlands Supplement emission factors for drained organic soils.
  - **Built 2026-11-10 (branch claude/lucascore-syncrosim-todo-f02a9f, version 1.3.0; not on main, not run yet):**
    - FIA split: `src/fia.R` `fia_hydric_group` (PHYSCLCD 31-39), cache key bumped. 9,780 hydric conditions, 77% of their area in
      the three groups.
    - Twins: `tools/make_wetland_forest.R` copies every upland row (23 files) for its twin; Ids 121/601/701, diagram cells H14-H16,
      Ag Contraction types 1009-1014. Forest-by-name tests now use `is_forest_class` (stages 4, 6, 12).
    - Other types by region: `tools/make_wetland_forest_regions.R` -> `defaults/growth/wetland-forest-regions.csv`. Warm Continental
      (and Mountains) Spruce/Fir; Subtropical and Savanna Oak/Gum/Cypress; every other ecodivision Elm/Ash/Cottonwood (Hot
      Continental by its own plots, the rest by default). Stage 5 assigns palustrine woody wetland cells (NLCD 90 not estuarine in
      C-CAP, NLCD 95 that C-CAP maps as forested or scrub-shrub) and logs the reassignments; estuarine forested cells run
      as `Wetland: Estuarine Forested` (91, its own rates and curves; 2026-11-10: until then folded into Palustrine Forested, 90,
      which now starts with no cells and stays defined for older libraries).
    - Burial: `defaults/spinup/wetland-burial.csv`; flow `Stabilization: BG Slow -> Deep Soil` in the forest pathways for the twins
      only, rate = burial / soil target, fixed outside the gNATSGO soil multiplier (stage 3 calibration and flows, stage 4 spin-up).
    - Organic soils: Data Source `HistosolFile` (Data Download: gNATSGO mukey raster for the region + the component table, percent
      Histosols). Stage 8 writes the Organic Soil Share map as the spatial multiplier of flow group `Organic Soil`.
      `tools/make_organic_soil.R` writes `defaults/stockflow/organic-soil-pathways.csv`: peat fire on the twins burns 0.03 / 0.07 /
      0.15 of BG Slow (low / medium / high), and cropland and pasture lose 11.2-14.3 and 2.8-3.6 Mg C/ha/yr (US Inventory) as a share
      of a 600 Mg C/ha reference stock. Sources: `dev/nonforest/review/notes/peat-fire-drained-organic-soils.md` (local).
    - Library update 1.3 (`ui/LucasCoreUpdates.cs`): the twins, their transition types and groups, the Histosol column, the new flow
      types, groups, memberships, order, filters and the Organic Soil Share multiplier type.
    - Tests: `tests/unit-wetland-forest.R` (31 checks); all unit tests pass except `unit-treemap.R`, which needs a local DataMart.
    - Still to do: an eastern test library (Chesapeake and Suffolk, Virginia: the Great Dismal Swamp with Lake Drummond and the drained farmland east of it; chosen 2026-11-10) through Data Download, Build and a historical
      run (done: Builds 10 and 17, historical runs 13 and 19); merge to main and release 1.3.0.
    - Refitted on the split FIA conditions (2026-11-10): stem turnover, the CO2 ECM share (and the default betas made from it) and
      minimum harvest ages, for the twins and the three upland types they split from; every other class's rows kept as they were
      (the reruns also moved a few unrelated rows: four stem turnover rows by at most 0.0003 from the cached conditions, and the ten
      harvest ages of types with too few cuts, which take a Build's curves and so depend on which Build is given). Wetland against
      upland: ECM share Subtropical Oak/Gum/Cypress 0.129 against 0.392, Warm Continental Spruce/Fir 0.568 against 0.713;
      clearcut age Spruce/Fir 64 against 37 (65 and 157 cuts), Oak/Gum/Cypress 29 against 27, Elm/Ash/Cottonwood 35 against 23;
      stem turnover Subtropical Oak/Gum/Cypress 0.0147 against 0.0174. The harvest age tool now applies the hydric split itself
      (fia_hydric_group), reads FIADB_REFERENCE.zip when no REFERENCE folder is unpacked and a Build's curves by SQL; both tools
      fall back to the shipped ecodivision map. tests/unit-wetland-forest.R checks these tables for rows of the twins' own.
    - Great Dismal Swamp test (library `Great Dismal Swamp`, Build result 7, 2026-11-10): the Histosol share needed its own home
      folder (`soils-terrain/histosol/*.tif`; written into a folder of its own name, stage 8 could not open it). Stage 5 gave 34,386
      woody wetland cells a twin (65% already of a twin's group; the loblolly, oak/hickory and oak/pine cells -> Oak/Gum/Cypress).
      Stage 8: 14,965 of 87,557 land cells at least half organic, nearly all Oak/Gum/Cypress (mean share 0.44). Fault found: the
      Oak/Gum/Cypress twin started at 263 Mg C/ha of soil against its gNATSGO target of 1,066, because stage 4's spin-up burned
      peat in every fire at full strength while stage 3 calibrated without it; stage 4 now leaves the peat-fire flows out
      (`PEAT_FIRE_FLOWS`, `src/flows.R`). Starting soil stays the class mean (user, 2026-11-10: "just start each cell the same";
      per-cell gNATSGO soil was weighed and set aside, since cells away from the class balance drift toward it during a run).
      To do: Build again and check the twins' starting soil against the target.
    - Dead wood decay (user, 2026-11-10): the twins' snag, down log and fine woody debris multipliers had been the ecodivision's
      shared upland values (the regional rule of 2026-10-27), so wetland dead wood decayed as upland's. Stage 3 now fits each twin
      on its own mature FIA dead wood plots in its ecodivision (Level "Wetland class"); a twin with too few takes its own class
      pooled over ecodivisions, never the upland types' values. Upland forest keeps the regional rule. To check on the next Build:
      the GDS Oak/Gum/Cypress twin (172 mature plots) gets its own values, and the upland types' shared values move a little.
    - Peat stock (user, 2026-11-10: "How do we initiate soc for areas where it is much higher than the class mean? Like for ag
      lands here (or similarly in the Delta region of California). Seems we are missing a large potential land use change
      effect"). Every class keeps its class-mean soil in BG Slow, in balance; the carbon above it on organic soil goes into the
      stock DOM: Peat (it was defined but unused), cell by cell: stage 8 sets it to the cell's gNATSGO soil above its class's soil,
      at most its Histosol share of that gNATSGO soil. Peat has no decay; peat fire (any class, 0.03 / 0.07 / 0.15 by severity),
      drainage under cropland and pasture (the inventory factors as a share of 600 Mg C/ha) and urbanization (0.2, as BG Slow)
      take from it, so a wetland drained to farmland starts losing its peat. The Organic Soil Share multiplier and the flow group
      Organic Soil are retired (no flows from BG Slow scale by it now). Peat counts in DOM: Soil and Total Ecosystem, diagram cell
      F6; `tools/make_organic_soil.R` writes it all; library update 1.3 adds its groups and diagram cell. GDS preview (Build 10's
      soil, the same formula): 16,395 cells, 35 Tg C of peat; Oak/Gum/Cypress twin mean 1,037 Mg C/ha, cropland 454 cells at a
      mean 156 (drained loss then about 3.7 Gg C/yr, against 0.2 when drainage took BG Slow at the class mean). To check on the
      next GDS Build and historical run. lucasCoreUI.dll rebuilt.
    - Wetland dead wood fits at their limits (2026-11-10, user: "Look into the decay fits hitting their limits"; then "Yes, make the
      change"). Two causes: FIA's duff on hydric plots is the top of the muck or peat (mature means: Spruce/Fir 152 Mg C/ha against
      29 upland, Oak/Gum/Cypress 60 against 13, Elm/Ash/Cottonwood 108 against 5), carbon the model holds as soil, so the duff fit
      went to its limit; and a wetland class fitted alone over every ecodivision on its thin plots let the ecodivisions with near-zero
      pools steer snag and duff to the limits (GDS Build 17: Elm/Ash/Cottonwood snag 20 and duff 20, Spruce/Fir duff 0.05). Stage 3
      now fits a wetland class on its own plots only where it has enough in the ecodivision, with duff held at its upland counterpart's
      multiplier there (`hold_duff`, `cal_fit_measured`); with too few it takes the ecodivision's upland values (its counterpart's
      litter and duff). This replaces "never the upland types' values" from earlier the same day. Stage 3 alone on a copy of GDS
      (all 589 CONUS cells): 4 wetland cells on their own plots (Warm Continental Spruce/Fir and Elm/Ash/Cottonwood, Subtropical
      Oak/Gum/Cypress, Hot Continental Elm/Ash/Cottonwood), none at a limit; the 8 wetland values still at a limit (7 snag, 1 duff of
      57 cells) are inherited from upland fits, and upland forest has 38 snag and 20 duff multipliers at a limit of 532 (an older,
      separate issue).
    - **To do: lateral export from forested wetlands** (user, 2026-11-10). Only the emergent marsh classes export carbon to Aquatic
      (Lateral Transport from BG Slow, BG Very Fast and AG Very Fast; `tools/make_emergent_wetland.R`): in GDS run 19 estuarine
      marsh 1.66 Mg C/ha/yr, palustrine marsh 0.03. The three wetland forest twins and Wetland: Estuarine Forested export none,
      though swamps do (the Great Dismal Swamp's blackwater drains to the rivers around it; tidal swamps and mangroves are flushed
      as marsh is), so the swamp sink may be somewhat too large. Steps: a literature check of dissolved and particulate organic
      carbon export from forested wetlands (palustrine and tidal; by region if the data allow); then export rates for the twins and
      Estuarine Forested from the same pools as marsh, with stage 3 calibrating soil decay so the spin-up still reaches the gNATSGO
      soil (export as a fixed flow, as burial is), and the pathways and memberships written by the tools. Not started.
    - **To do: peat carbon by soil series, pooled across soil surveys** (user, 2026-11-10: the Peat map shows county boundary
      effects; "Add option 3 to 53 as a to-do and leave it as-is for now"). The edge is in gNATSGO's carbon for the same soils, not
      in where Histosols are mapped: in GDS, Oak/Gum/Cypress twin cells at least 90% Histosol average 1,962 Mg C/ha (10th-90th
      percentile 1,881-1,979) in the Chesapeake survey and 2,515 (1,788-3,221) in Suffolk's. Each survey entered its own horizon
      data (organic matter, bulk density, depth) for the same series. Plan: in the Data Download's Histosol step, also read
      gNATSGO's horizon table (chorizon; Planetary Computer gnatsgo-tables, probably a few hundred MB) and compute each Histosol
      component's carbon to its full depth; pool by series name (compname, and its taxonomic great group as a fallback) over the
      surveys where it is mapped; give each map unit its series' pooled carbon, weighted by component percent; stage 8 then sets
      Peat from that in place of soc0_999 on organic cells (mineral components keep gNATSGO). Keeps real differences between
      series and organic shares, removes the survey edges. Weighed and set aside: Uhran et al. 2021's wetland soil carbon map
      (wetlands only, to 1 m, so no farmland peat and no deep peat); a single pooled study-area peat density (removes real
      variation); spatial smoothing (blurs real edges). Not started.
    - **To do: deep peat burns where a swamp is drained** (user, 2026-11-11). Peat fire takes a fixed share of a cell's peat by
      severity (0.03 / 0.07 / 0.15, any class), however wet or dry the peat is. In a drained swamp, ditches lower the water table,
      and fires there can smoulder deep into the peat for weeks. The Great Dismal Swamp's 2008 South One and 2011 Lateral West fires
      did this. GDS run 24 gives 238 Gg C of peat fire in 2008 and 131 in 2011, all from those shares. Steps: a literature check of
      measured peat burn depth and carbon loss in drained against undrained peatlands, with the GDS fires first and also pocosins and
      other drained swamps by region; how burn depth follows the water table or the drought at the time of the fire; and whether
      fire is more likely in a drained swamp. Then choose how the model knows a cell is drained: a drainage map (ditch density, or
      the NWI's drained or ditched modifier) or a yearly drought index. Then scale the peat fire share by it, up to a burn depth
      cap, and check it against the GDS fires. Not started.
  - **Known limits:** mineral and organic soil are not separated within a class (oak/gum/cypress mixes both); scrub-shrub and
    pocosin cells get a tree curve; cells with no forest type pixel take a neighbour's type, which may be upland; FIA soil carbon is
    modelled, so soil targets stay gNATSGO (which overstates organic wetland soils by about 35%, Uhran et al. 2021). New runs will
    differ from the P26 final runs (left as they are).
54. **Climate response for emergent wetland growth** - ADDED 2026-11-09, not started (user: "add growth response to wetlands as a
  to-do"). Today `Wetland: Estuarine Emergent` and `Wetland: Palustrine Emergent` grow at their ecodivision rows (estuarine
  recalibrated to the USGS tidal marsh NPP map, to-do 39 step 10) with Tidal Marsh Productivity for the pattern, and the only yearly
  change is CO2 in projections. Their growth flows (`Net Growth Wetland Emergent: Atmosphere -> Foliage / Fine Roots`) form the flow
  group `Net Growth Wetland: Total`, which no climate effect reaches: defaults/climate/flow-multipliers.csv holds Forest Growth,
  Non-Forest Growth (grass and shrub only) and the two Q10 groups. So under alternative LOCA2 futures marsh growth differs only by
  CO2, while grass, shrub and forest growth and every class's litter decay respond to the climate. Forested wetlands grow on the
  forest net growth flows and already take the forest climate effect. (Agriculture growth has the same gap; not part of this item.)
  - **Build:** a Climate Options choice, Wetland Growth (None / ... ), a `WetlandGrowth` role row for `Net Growth Wetland: Total` in
    flow-multipliers.csv, and the emitter in src/climate.R so stage 7 (PRISM years) and stage 11 (LOCA2 years, against the climate
    model's own 1991-2020 normal) write it like the others; the Climate Multipliers figure picks it up as another series.
  - **Response, to decide (review first):** rain is a poor driver of tidal marsh, which is fed by tides and rivers, and better for
    inland (palustrine) marsh. Candidates: (a) Miami NPP as for grass and shrub before RAP fit, the quickest; (b) temperature only
    (a Q10 or the Miami temperature term) for estuarine marsh and Miami for palustrine; (c) a fit of marsh productivity to climate,
    space for time across the USGS tidal marsh NPP map (2015 only) or from a yearly series if one exists (Landsat marsh biomass,
    eddy flux at marsh sites such as AmeriFlux US-Myb, US-Tw1), with sea-level rise and salinity as covariates to consider.
  - **Tests:** a quick test on a library with emergent wetland (Solano: Suisun Marsh; Calaveras has 21 inland cells), stage 7 and a
    Projection Climate result under two SSPs, checking the series against the forest and grass ones and that 1.0 holds at the normal.
  - **BUILT 2026-11-16 on the wetland methane branch (user: option b, with the choice broken out like forest and grass and shrub):**
    Climate Options: Wetland Growth = None / Miami NPP / Temperature / Temperature and Miami NPP (default; a scenario without a value
    takes it). Temperature is Miami's temperature term alone, f(T) / f(Tn), about 4% per degree C; Temperature and Miami NPP gives it
    to the cells that start as estuarine emergent marsh and Miami NPP (the smaller of its temperature and precipitation terms) to every
    other cell. `WetlandGrowth` role row in defaults/climate/flow-multipliers.csv, src/climate.R (stages 7 and 11 pass the state class
    map), the options page (ui/ClimateOptionsView.cs), tests/unit-wetland-climate.R. Run on the Sabine and Lacassine test library.
    Left: option c (a fit to marsh productivity data), the library update method for the new column, and the guide.
55. **Shrubland growth: chaparral and non-sage on different bases** - REFIT 2026-11-09 (steps 1 and 2 done; first noted the same day, user: "option 1 but note
  this for later follow up work"). Found in the Calaveras test: in the Mediterranean ecodivision non-sage shrub grows at 3.9 Mg
  C/ha/yr and chaparral at about 2.0, although RAP NPP is nearly the same for both (3.92 and 3.85).
  - **Why:** chaparral's growth is solved from literature biomass (defaults/stockflow/chaparral-age.csv: 11 Mg C/ha aboveground at
    maturity, Bohlman et al. 2018, scaled by the ecodivision's RAP NPP; slow wood and coarse root turnover 0.03), so RAP sets only
    its pattern between ecodivisions (tools/make_grass_shrub.R prints the mature NPP against RAP). Non-sage has no data of its own
    (grass-shrub-literature.csv: RatesOf Native Sage Steppe, i.e. Sage's shares and turnover) and takes RAP's NPP level as is,
    grass and forb layer included. Post Fire Shrub takes Non-sage's.
  - **Effect:** stocks agree (Calaveras start: live 18.4 vs 15.5 Mg C/ha, dead organic matter 10.3 vs 10.9; soil is solved to each
    class's gNATSGO target either way), since two thirds of non-sage growth goes to foliage and fine roots that turn over within a
    year or two. The fluxes do not: NPP, litter fall, heterotrophic respiration and the size of the climate response are about 2x
    chaparral's per hectare. In Calaveras non-sage cells also average 1.44 on Grass and Shrub Productivity (about 5.6 Mg C/ha/yr).
  - **Options considered:** (2) scale non-sage's NPP by chaparral's literature / RAP ratio per ecodivision (0.52 in the
    Mediterranean), stocks kept on target: comparable fluxes, but assumes RAP overstates open shrubland as it does chaparral;
    (3) give chaparral a fast-turnover component (understory or more fine roots) so its NPP meets RAP with biomass kept: raises
    chaparral's fluxes 2x, also without direct data. Follow-up: a short review of measured NPP in chaparral and in the open
    shrublands non-sage stands for (coastal sage scrub, montane and foothill shrub), and of RAP NPP against them, then choose.
  - **Direction (user, 2026-11-09):** RAP NPP for every grass and shrub class, then fit each class's stocks to the best literature
    estimates. The user's own question: chaparral is mostly a California type with the best field data of any shrub, so keeping it
    as the one biomass-anchored exception may be acceptable; against that, it borders non-sage and annual grass on the same slopes.
    The plan, in order:
    1. **Decide chaparral first** from measured total NPP (aboveground and roots) of mature chaparral: near RAP's 3.5-4 Mg C/ha/yr,
       refit chaparral to RAP NPP with its turnover fitted to the literature stocks (11 Mg C/ha aboveground, root:shoot 0.6, standing
       dead 0.30-0.39 of live; foliage turnover stays 0.5 from chamise leaf life, so wood and roots take the rest, wood about 0.03 ->
       0.10-0.15/yr - check that is plausible for chamise twig and branch shedding); near 2, keep chaparral's biomass anchor and treat
       RAP shrub NPP as high, which puts non-sage's 3.9 in question instead.
    2. **Fit stocks for every RAP-anchored class:** today their live biomass follows from borrowed literature turnover (non-sage and
       Post Fire Shrub use Sage's) and is never checked against measured biomass; only litter and soil are fitted. Fit each class's
       turnover so its live carbon meets literature stocks: big sagebrush biomass for the sage family, foothill and montane shrub
       biomass for non-sage (none yet), and grass peak aboveground biomass (RAP's herbaceous biomass, Jones et al. 2021, as a check:
       it is derived from the same NPP, so not independent). RAP has no shrub or tree biomass (cover and NPP only), so shrub stocks
       need field data or fuel loads (LANDFIRE FCCS).
    3. Grassland: Irrigated Perennial has no ecodivision RAP sample anywhere (one CONUS mean, 2.86); about half the class x
       ecodivision pairs of the sage family, annual grass and chaparral use the class's CONUS mean.
  - **Review (2026-11-09):** `dev/nonforest/review/reports/Chaparral NPP and shrub stocks.md` and its notes (local only). Measured
    chamise and scrub oak aboveground NPP about 1.4-1.5 Mg C/ha/yr at 23-35 yr, Ceanothus 3.4-5 (Riggan et al. 1988, Gray 1982,
    Schlesinger et al. 1982, Mooney et al. 1977); no belowground NPP measured for any chaparral; chamise total about 2-3. RAP NPP is
    MOD17 on Landsat (total NPP, roots included; no soil-moisture term), never validated for shrubs; MODIS GPP ran 26-90% above the
    young Sky Oaks chamise tower. Verdict: RAP likely high in chaparral only (its sage and open-shrub values sit near the parent
    product's shrub mean). RAP has no shrub biomass (cover and NPP only); its herbaceous biomass is a year's production.
  - **Done (user 2026-11-09: "go ahead with the refit", "yes do that"):**
    1. Chaparral keeps its biomass anchor; wood turnover 0.03 -> 0.08 (chamise 0.06-0.13 from standing dead). Mature NPP in the
       Mediterranean ecodivision 1.9 -> 2.48 Mg C/ha/yr; stocks unchanged (11 aboveground, 6.6 roots at the CONUS mean).
    2. Live-stock targets in grass-shrub-literature.csv (AgLiveTarget, RootLiveTarget, StockSource; at the class's CONUS mean NPP),
       fitted by tools/make_grass_shrub.R fit_stocks: Natural Perennial 1.0 / 3.0 and Irrigated Perennial 1.7 / 2.0 (foliage share
       and fine-root turnover 0.82, 0.86/yr); Annual 0.95 / 0.8 (roots now die back yearly; only the ratio is fitted, since RAP's
       2.8 exceeds the field annual total of about 1.75, so its stocks follow NPP); Sage 1.0 / 2.4 and Invaded 0.9 / 1.7 (wood,
       fine- and coarse-root turnover; little change). Non-sage 1.5 / 2.0 and Native Sage Steppe 1.4 / 2.4 (herbaceous parts
       inferred): growth split by RAP's herbaceous share (0.67, 0.76) - that share grows as Natural Perennial grass, the rest as
       Sage (mixed_rates) - then wood (0.039, 0.033) and root turnover fitted; they held 3-5x the targets on Sage's split.
       Post Fire Shrub follows Non-sage (a legacy class, not used now; user 2026-11-09).
    Calaveras quick test (stages 3, 4, 8 and 10 years on a copy): annual grass live 4.8 -> 3.7, non-sage live 18.4 -> 7.4 and dead
    organic matter 10.3 -> 5.5 Mg C/ha, chaparral stocks unchanged; shrubland 2.46 -> 2.33 Tg, grassland 5.92 -> 5.82, both steady.
  - **Still open:** the decisive RAP tests (RAP NPP at the Sky Oaks towers against tower GPP x 0.5; RAP against the unpartitioned
    Landsat NPP at chaparral pixels; RAP herbaceous production against the San Joaquin and Hopland clipping series); the
    foothill chaparral scale s (Calaveras 1.21 lifts mature chaparral to about 13.3 Mg C/ha against a measured Sierra foothill
    chamise value of about 7.5); a root target for irrigated pasture (assumed); and step 3 above.

56. **Run Build stages on their own, or a few in sequence, as a dependency chain** - TO DO, added 2026-11-10 (user: "I want the
    ability to run each of these on its own, or a few sequentially, and have them serve as dependencies down the chain. This way if
    one step fails down the chain, I do not have to re-run the entire thing"). Prompted by the Great Dismal Swamp Build: stages 0-7
    passed and stage 8 failed after 44 minutes on a misplaced input (the Histosol share written into a folder of its own name), and
    the only way to a complete Build result from Studio was the whole Build again.
  - **Today:** a Build is one scenario whose pipeline runs stages 0-12 into one result; a failure leaves that result partial and
    nothing starts from it. tools/quick-test.R already makes a scenario that depends on a Build result with a pipeline of only the
    named stages, and the stages read what they need through dependencies, so the mechanism works, but only from a script and only
    on top of an existing Build result.
  - **Wanted:** in Studio, a Build split into steps (each stage, or a group such as 0-4, 5-7, 8, 9-11, 12), each step a scenario
    whose result is the dependency of the next, so a failed step is rerun alone and the steps before it are kept; a Build run as one
    pipeline should still be possible and give the same result.
  - **What the quick tests already taught (each must hold for a chain of steps):** options sheets did not reach a rerun stage through
    the dependency (stage 3 fell back to the default FIA source), so quick-test.R copies every Build options sheet; sheets a stage
    appends to (Flow Spatial Multipliers in stages 7, 8 and 11) must carry the earlier rows over, since a result's own rows hide its
    dependency's; the Stock-Flow Definitions scenario goes first in the dependency list; Initial Conditions Spatial is saved again
    so SyncroSim writes its Properties; stage 12 finds its files in the dependencies' folders.
  - **To settle:** how the steps appear in Studio (step scenarios made by a command, or the Build's own pipeline rerun from a chosen
    stage on a chosen result); which later scenarios (Projection Setup, historical and projection runs, Model Record, Data Release)
    accept the last step's result where they now look for a Build result; and how the model record lists a chain of results as one Build.
  - **Related:** a check before stage 0 that every Data Sources file opens would have stopped this Build in seconds.
57. **A post-disturbance state for forest: regrowth, delay and conversion** - TO DO, added 2026-11-11 (user: forest is a use class,
    so a stand-replacing disturbance resets age and the stand regrows the next year; this "misses things like disturbance that lead
    to forest never returning. It also misses things like regrowth around Mount St Helens after the 1980 eruption"). Map consistency
    with NLCD is not a goal (user, 2026-11-11). The user chose option B, a post-disturbance state, as the general approach, not
    necessarily `Shrubland: Post Fire Shrub`.
  - **Why use-based forest stays:** FIA counts forest land by use, so land that is unstocked for now is still forest, and the US
    greenhouse gas inventory and IPCC report by use too. FIA's young plots carry slow establishment in the growth curves, and the
    post-fire snag, down log and forest floor path is calibrated on FIA post-fire plots (dev/fia/FINDINGS.md). The post-disturbance
    state goes between disturbance and forest without changing those.
  - **P26 evidence (2026-11-11; `dev/fire/p26-fire-gap.R`, summary `dev/fire/p26-fire-gap-summary.R`).** Method: forest
    pixels (Annual NLCD 41-43 the year before) at a first MTBS burn, 1986-2024, in the P26 pyrome, followed in Annual NLCD to 2025,
    against unburned forest given the same mix of fire years.
    - Size: 692 kha of forest burned, about a third of P26's 1,890 kha of 1985 forest. NLCD forest fell to 1,416 kha by 2025, and grass
      rose from 40 to 292 kha.
    - Share NLCD forest after a single burn, at 1 / 5 / 10 / 20 / 30 years: high severity 0 / 1 / 1 / 26 / 69%; moderate 8 / 11 / 14 /
      43 / 65%; low 53 / 61 / 63 / 75 / 78%; unburned forest 99 / 98 / 97 / 96 / 95%.
    - High severity goes grass (years 1-5), then shrub (to about year 20), then forest. The median return is 21 years, and about a
      quarter is still non-forest at 30 years.
    - Reburns: 8% forest at 20-25 years; of high-severity pixels burned again after a 1986-2005 fire, 3% are forest in 2025.
    - High severity, forest at 20 years by type group: Fir/Spruce 9%, Ponderosa 23%, California Mixed Conifer 24%, Western Oak 31%.
    - Limits: MTBS maps only large fires; only 21 kha of high-severity burn has 30 years to see; NLCD calls 44% of low-severity burns
      grass the year after, so NLCD's own response to burned ground is in these numbers.
  - **The design:**
    - **Entry:** a cell enters a post-disturbance state after any stand-replacing disturbance with no assured regrowth: high-severity
      fire (perhaps a share of medium severity; MTBS moderate behaves almost as high), insect or drought die-off at stand-replacing
      levels, wind, volcanic loss. Harvest and planted stands go straight back to forest at age 0, as now.
    - **Carbon in the state:** the state keeps its forest type's dead wood, decay, snag fall and soil parameters, so the FIA
      post-disturbance calibration holds. Live carbon grows as grass and shrub. Age runs from the disturbance.
    - **Return:** back to forest at age = years since the disturbance (no reset: FIA's young curves already hold the establishment
      lag, and the shrub carbon of the waiting years stands in for the young stand's). This is a probability over a time-since-
      transition window, by forest type, disturbance, severity and region.
    - **Conversion:** not back by the window's end means a permanent non-forest class chosen by region (for example Chaparral in the
      Mediterranean ecodivisions, Non-sage elsewhere; a regions table as for the wetland twins). The forest's dead wood and soil carry
      over.
    - **Repeat disturbance:** inside the window, it restarts the clock or converts; P26's reburns mostly convert.
    - **Climate:** in projections, the return and conversion chances can follow climatic water deficit through a multiplier (the
      regeneration-failure feedback: Davis et al. 2019, Stevens-Rumann et al. 2018, Coop et al. 2020).
  - **Adjacency: the seed source (user, 2026-11-11).** The old LUCAS approach sent disturbed cells into `Shrubland: Post Fire Shrub`
    and moved them out by a probability, using adjacency so that cells near standing forest returned first. They were more likely
    to return to their pre-fire class than cells far from a seed source. The `Succession Post Fire: <type>` transition types (one
    per forest type group) let a cell return as a different forest type than before, by adjacency to that type.
    - This is why the old design had one shared class: a cell could become any type its neighbours were.
    - A shared class forgets the pre-disturbance type, and with it the type's dead wood parameters and its most likely return.
    - Settled in the scoping below (user, 2026-11-11: "That sounds good for 57"): per-type classes, one adjacency calculation for
      return, and type change, if wanted, by static gates rather than adjacency.
    - The machinery exists for Ag Change: `src/adjacency-curve.R` fits an event rate by the share of a class within a radius from
      the annual maps, scaled to ST-Sim's adjacency multiplier; stage 10 sets it up (`AdjacencyRadius`, `AdjacencyUpdate`). The same
      fit on the P26 burns would give return by the share of unburned forest (of the same type, or any type) around each burned pixel
      at the time of the fire. Literature check: seedling density by distance to a live seed source after high-severity fire.
  - **Scoping (2026-11-11).** The user's main concern is run time, since adjacency calculations slow runs.
    - **How ST-Sim's adjacency costs:** an adjacency setting belongs to a transition group (state attribute, neighbourhood radius,
      update frequency). ST-Sim keys its maps by transition group (`CreateAdjacencySettingDictionaryByTGID`,
      `m_TransitionAdjacencyStateAttributeValueMap` in SyncroSim.STSim.dll 4.5.4), so it computes each group's neighbourhood share
      at each update. The cost is groups with a setting x cells x neighbourhood cells, in update years only. It does not grow with
      the number of classes or transition types. Projections now have 4 such groups (urbanization's developed share, agriculture
      expansion, the two Ag Change directions), at 3 cells' radius, updated every 5 years (stage 10).
    - **State classes: +31** (54 to about 84). One post-disturbance class per forest class with a stand-replacing fire pathway: 28
      upland type groups and the 3 wetland twins. Each class holds its own type, so it keeps that type's dead wood, decay and soil
      parameters and returns to it. One new state label X (for example "Forest Disturbed"). `Shrubland: Post Fire Shrub` (59) is
      retired (net +30). No new permanent non-forest classes: conversion goes to the existing Chaparral, Non-sage or grass classes
      by region.
    - **Transition types: +2, and 29 retired.**
      - "Post-disturbance: Return" and "Post-disturbance: Conversion", each with one pathway per class (the source class says which
        type a cell returns to).
      - The 29 unused `Succession Post Fire: <type>` types go, and so do `Ag Contraction Cropland / Pasture: Shrubland Post Fire
        Shrub` with class 59. Farm land never contracts into a post-disturbance class.
      - Entry needs no new type: the forest classes' Fire: High Severity pathways are pointed at their post-disturbance class.
      - Reburns use the existing fire types, with proportions: part to conversion, part restarting the clock.
    - **Transition groups: +2 named** (plus ST-Sim's 2 [Type] groups for the new types). Return gets the adjacency setting.
      Conversion has none: it is set by time since disturbance (what has not returned by the window's end converts). They are
      separate groups because an adjacency multiplier applies to a whole group.
    - **Adjacency: +1 attribute, +1 setting.** A "Live Forest" attribute (1 on every forest class, 0 on the post-disturbance
      classes) drives the Return group's multiplier, updated every 5 years: five adjacency calculations in projections, against four
      today. The class picks the type and adjacency only sets the speed, so a cell can't return as a type that doesn't belong there.
      The compromise: a cell gets seed-source credit from any forest type around it, not only its own.
    - **Type change (optional), by static gates, not adjacency.** This is how Ag Contraction picks its destination today: stage 6
      fills each farm cell with the most common natural class around it in the start-year map, and writes one 0/1 map per destination,
      the spatial multiplier on that destination's transition type ([6-historical-transitions.R](../src/6-historical-transitions.R),
      "ag contraction destinations"; stage 9 keeps those rows in projections). For post-disturbance classes: one transition type per
      destination forest type, each gated to cells where that type is present nearby in the start year (or listed for the
      ecodivision), at a small probability by region. No cost at run time. The limit, as for Ag Contraction: the gates are fixed at
      the start year.
    - **What would multiply the cost (avoid):** return by own-type forest, up to 31 calculations; type change by adjacency, about one
      per destination type; replanting that favours cells far from a seed source (to-do 58), probably +1, since ST-Sim seems to
      compute per group. For 58, prefer area targets prioritized by time since disturbance and ownership.
    - **Rows, not run time:** a tool (as for the wetland twins) writes the carbon rows for the 31 classes: dead wood, decay and soil
      copied from each forest type; grass and shrub growth from the regional non-forest class; fire carbon flows; flow-multiplier
      group memberships. That's several thousand default rows. No spin-up, since no cell starts in these classes (unless starting
      from MTBS history is added). Stage 10 fits the return curve by time since fire, the conversion share, and Return's adjacency
      curve.
    - **Before building, two checks:**
      - DONE 2026-11-11: own-type against any-forest seed source on P26 (`dev/fire/p26-seed-source.R`, summary
        `dev/fire/p26-seed-source-summary.R`). Forest pixels at a first moderate or high-severity MTBS burn, 1986-2005, not burned
        again within 20 years: 74.4 kha, 36% back to NLCD forest within 20 years (moderate 46%, high 27%). Live forest is NLCD
        forest the year after the fire; type is the USFS type group map; shares are within 150 m on the 30 m grid, and within
        450 m on P26's 150 m grid (3 cells, as ST-Sim computes it).
        - The seed source matters: within 450 m, return rises from 21% with almost no live forest around (share under 0.05) to
          51% at 0.3-0.4 and 86% above 0.8. Within 150 m, 23% to 95%.
        - Any forest does as well as own type, or slightly better. Return within 20 years, logistic fits with severity and type
          (deviance explained, AUC): severity and type alone 4.3%, 0.63; any 450 m 12.0%, 0.72; own 450 m 10.7%, 0.71; both
          12.0%. Any 150 m 16.4%, 0.75; own 150 m 15.8%, 0.75; both 16.4%. Own type adds nothing once any-forest share is in.
        - The two rarely disagree: 3.1 kha (4%) have an any-forest share at least 0.25 above the own-type share. At the same
          any-forest share (0.3-0.6), return varies little with the own-type part of it (53% to 57%).
        - So one "Live Forest" attribute is enough. The 150 m share predicts better than the 450 m share, so the seed-source
          effect works at a shorter range than P26's adjacency radius. At 150 m model cells, ST-Sim's smallest neighbourhood is
          one cell around (radius 150 m); that radius is worth testing.
        - Limits: return includes replanting (not separated; to-do 58); the type map (USFS, 2000s) postdates some of the fires;
          NLCD forest the year after a fire includes partly burned stands.
      - Not needed (user, 2026-11-11: "I am not worried about the adjacency timing for just a single layer"): the timing test of
        one extra adjacency setting.
  - **Shrubland too (user, 2026-11-11).** In the Northern Basin and Range, NLCD shows large areas of shrubland turned to grassland
    after fire, the way cheatgrass establishes. Decisions:
    - **Shrubs get post-disturbance classes, as forest does** (user: a consistent approach; NLCD calls burned shrubland grass whether
      it is regrowing or converting, so without separate classes real conversion can't be told apart, calibrated, or managed in
      projection scenarios). One class each for Sage, Native Sage Steppe, Invaded Sage Steppe, Non-sage and Chaparral: +5, so +36
      classes in all with the forest ones, class 59 retired.
      - Carbon while waiting: the class's own type's (the shrub-age recovery curves, whose early years are already grass and herb,
        and its dead wood, litter and soil), so it is a copy of its parent class with its own identity. Forest post-disturbance
        classes differ: they grow shrub and grass, not trees.
      - Out: back to its shrub type with age carried over, or conversion. Same Return and Conversion transition types as forest.
      - Calibration: NLCD is a weak signal for shrub return (big sagebrush is back to a quarter of its cover after about 19 years, so
        NLCD can show grass for decades on recovering land). Use RCMAP's yearly fractional cover (shrub, sagebrush, annual herbaceous,
        1985 on): conversion where annual herbaceous cover dominates and sagebrush doesn't recover; NLCD as the check. Needs a
        Northern Basin and Range region home (a download; ask first).
      - Window: longer for big sagebrush (reseeds, doesn't resprout; something like 30-40 years), shorter for resprouting chaparral
        and many Non-sage shrubs.
      - Adjacency: a shrub Return group with a "Live Shrub" attribute (sagebrush seed travels tens of metres), so two adjacency
        calculations in all (Live Forest, Live Shrub). Fallback: static gates or none for shrubs. Rerun the own-type check for shrubs.
      - Groups: forest Return, shrub Return, and one Conversion group: +3 named groups.
      - To-do 58 gains shrub actions on these classes: post-fire seeding of sagebrush or perennial grasses, sagebrush seedlings
        ("plugs"), pre-emergent herbicide against cheatgrass.
    - **Conversion goes to `Grassland: Annual`** for the sage family and chaparral, one class for cheatgrass and California annual
      grassland (user: "they share a class name but underlying carbon values differ by ecodivision"). The class already has its own
      sampled rows in the dry ecodivisions: Temperate Desert NPP 1.31 Mg C/ha/yr, soil 43 Mg C/ha; Temperate Desert Mountains 1.21,
      36; Temperate Steppe 2.69, 80; Mediterranean 3.62, 66. Non-sage converts to annual grass or stays, by region. Soil carries over
      and moves toward the annual grass level through decay.
    - **Fire raises burned area on converted land (user: "Yes, raise burned area").** Projections draw a historical year's burned
      fraction per pyrome and spread it with one rate map per severity, whatever the class, so converted annual grass burns no more
      often than the sagebrush it replaced, and post-disturbance land reburns no more often, although reburns drive most conversion.
      Add a fire multiplier by state class (ST-Sim transition multipliers per class; no run-time cost) on `Grassland: Annual` in the
      dry ecodivisions and on the post-disturbance classes, fitted from how often each burned historically. It adds fire on top of
      the year drawn, so the grass-fire cycle feeds itself as conversion spreads. Calibrate so the historical period still matches
      the observed burned area.
  - **Forest keeps its separate post-disturbance classes** (#3, user 2026-11-11: settled). The reasons for shrubs hold for forest:
    real conversion has to be told apart, calibrated and managed.
  - **Walkthrough: one burned forest cell (agreed with the user, 2026-11-11; "lets begin").**
    1. **The fire.** High-severity fire moves the cell from `Forest: California Mixed Conifer Group` to its disturbed class (for
       example `Forest Disturbed: California Mixed Conifer Group`). Age resets to 0, so from then on age is years since the fire.
       The pathways use ST-Sim's age limits, not a time-since-transition clock, and cells that start in the state take their age
       from stage 5's map.
    2. **Carbon while it waits.**
       - Dead wood: the forest's fire flows kill the trees into snags, down wood and the forest floor, which decay at the forest
         type's rates (copied from its forest class): the post-fire path calibrated on FIA's post-fire plots carries on unchanged.
       - Soil: the forest type's soil and decay.
       - Live growth: shrub and grass, from the region's non-forest class (in P26 Non-sage's curve, 25/50/90% of its woody carbon at
         about 8/19/50 years, plus its herbaceous growth; Chaparral's in the Mediterranean ecodivisions). No tree growth.
    3. **The window** is set per forest type and region (say 30 years for Mixed Conifer), not per cell. Each year, a waiting cell
       has a chance to return to its forest type: from the fitted return curve by years since the fire (P26 high severity: 26% back
       by 20 years, 58% by 25, 69% by 30), scaled up by the live forest around it.
    4. **Return is gradual.** Cells in one burn come back over the years, the edges near standing forest first. A returning cell
       goes back to its forest class with its age carried over: a cell back at year 22 joins the forest curve at age 22.
    5. **Conversion.** A cell still waiting at the window's end converts; a high-severity reburn inside the window converts a share
       at once and sends the rest back to age 0 in the same class (P26: reburned pixels were 8% forest after 20-25 years). Where to:
       - historical runs: what NLCD shows then (shrub 52 to the region's shrub class, grass 71 to its grass class);
       - projections: shares fitted from that history per forest type and region, as pathways with proportions (P26 non-returners
         after 30 years: 28% shrub, 1% grass, so mostly Non-sage or Chaparral);
       - which shrub or grass class in a region: a regions table (as for the wetland twins), or static gates from the non-forest
         classes around the cell at the start.
    6. **Management** (to-do 58): replanting early in the window (years 1-5), back to the forest type at a seedling age, with a
       chance of failure; a scenario sets the area planted per year and where.
    7. **Historical runs follow NLCD.** Entry from the fire maps already used (MTBS and LANDFIRE high severity); return where stage
       6's annual map shows NLCD forest two years running; conversion at the window's end to the class NLCD shows. A burn late in
       the record (2015 with a 30-year window) is still waiting in 2023 and carries into the projection in its disturbed class.
    - **Two points to settle:** the shrub carbon in the live pools carries into the forest's on return, and the forest curve grows
      on from its age (P26: the same order around year 20; check per type, so there's no jump); and burns in the last years of the
      record may not have a confirmed return yet, so they reach the projection still waiting.
    - **Conversion timing (#4):** at the window's end and at a reburn, not decided at the fire. It matches what the record can show
      (conversion only shows as a return that never happened), management early in the window acts on cells whose outcome is still
      open, and carbon in the waiting years is nearly the same either way (shrub and grass for forest). The cost: a cell that would
      have returned after its window converts, so windows matter: forest about 30 years, big sagebrush about 30-40, chaparral and
      resprouting Non-sage about 10-15, all fitted per region.
    - **A side benefit (user):** land use and land cover line up better. The disturbed classes give NLCD-like maps of the land in its
      waiting stage, burned forest that shows as shrub or grass, without changing use-based accounting.
  - **Build (started 2026-11-11, user: "Yes go ahead"; on the to-do 53 branch, version 1.4.0 there, not merged).** Names and Ids agreed:
    `Disturbed: <type>` (state label X Disturbed, Y the type's label; the wetland twins' disturbed classes take "Wetland <type>"),
    Id 2000 + the parent's (not NLCD codes, not 100-999, not the legacy EVT targets 61, 83, 84, 1000, 1001). Order: 1 structure,
    2 carbon, 3 historical maps (stage 6), 4 projections (stages 9-10), 5 starting cells (stages 5, 8), 6 figures, 7 calibration
    (RCMAP, Northern Basin and Range; download to ask) and a test Build, release 1.4.0.
    - **Step 1 DONE 2026-11-11.** `tools/make_post_disturbance.R` writes, from `defaults/transitions/post-disturbance-settings.csv`
      (window, return age and chance, reburn conversion, forest's shrub share, by parent; provisional values from P26) and
      `post-disturbance-regions.csv` (each ecodivision's shrub and grass class): 36 classes; the types Post-disturbance: Forest
      Return, Shrub Return, Conversion and their groups (+ Post-disturbance); `pathways/post-disturbance.csv` (return and
      conversion); fire.csv (high severity into the disturbed class, reburn proportions, medium and low keep it); urbanization and
      ag expansion as the parent; diagram cells (columns I and J); CO2 classes (disturbed forest as Non-sage; then rerun
      tools/make_co2_default_betas.R); definitions (edited as text lines). Stages 5 and 8 count forest as Ids 100-999; stage 6's
      natural classes for Ag Contraction gates stop at 999; transition pairs and Run Figures know the Disturbed family (cover and
      balance group Disturbed). Library update 1.4 (`Update_1_400`) adds the label, classes, types and groups, worked out from each
      library's own classes; tested on a copy of Calaveras (schema 1.4, 36 classes, Ids 2051-2990). tests/unit-post-disturbance.R
      (17 checks, including no apostrophe in any update description). Class 59 and the Succession Post Fire types are kept for now
      (nothing reaches them); retiring them touches about 20 tables. Found and fixed on the way: four definitions rows whose `{*}`
      quotes had been doubled to 16 by an earlier read-and-rewrite.
    - **Step 2 DONE 2026-11-11.** Stage 3 derives the disturbed classes' carbon each Build (`src/disturbed-carbon.R`;
      tests/unit-disturbed-carbon.R, 12 checks), from the rows it already has, so they follow their parents and the defaults hold no
      copies (copying them would have added about 210,000 multiplier rows, and gone stale when make_grass_shrub reruns). A disturbed
      shrub class takes all its parent's non-forest rows and its fire class rows; a disturbed forest class takes the growth pathways,
      growth split, live turnover and net growth of its ecodivision's shrub class, and its forest type's dead wood pathways
      (FOREST_PATHWAYS) and rates (stage 3's per-cell rates, burial where the type has it); its fire rows are the all-class (forest) rows.
      Only the study area's ecodivisions are written, and a disturbed forest class only where its type has rates.
    - **Tested 2026-11-11 on a copy of the GDS 1.3 rerun library** (updated to 1.4 with a test package; SyncroSim's 1.4.0 entry points
      at this worktree): stages 3, 4 and 6 rerun on Build 23 (8.5 min) and 1985-2012 historical (34 min), both clean. High-severity
      fire put 34 ha (2006) and 533 ha (2008) into Disturbed: Wetland Oak/Gum/Cypress Group; the 2011 fire had no high-severity pixels.
      In the class: live carbon 2.8 to 4.3 Mg C/ha (2008-2012, shrub growth), standing dead 17.3 to 1.6 and down wood 10.6 to 9.3,
      peat 1,290 to 1,231 after the 2011 fire; NPP 2.4-3.4, NEP -4.9 (2009) to -0.1 (2012). Its dead wood rates are its forest twin's
      exactly (snag stem transfer 0.145, decay 0.059, BG Slow emission 0.0000874). Total ecosystem carbon within 0-9 Gg C of run 24
      (136 Tg), the same as the run-to-run noise before any land was disturbed. A quick test that skips stage 6 keeps the Build's old
      pathways (fire stays in the forest class).
    - **Step 3 DONE 2026-11-11.** Return pathways are probability 1 at any age in the window (the chance is a multiplier: NLCD maps
      in history, an age-dependent multiplier in projections, step 4; ST-Sim's transition multiplier values take AgeMin and AgeMax).
      Stage 6 sources (`sources.csv`): NlcdPersist, on in year y where the modal NLCD shows the group's classes in y - 1 and y (Forest
      Return 41|42|43|90, woody wetland for the twins; Shrub Return 52, RCMAP cover to follow for the sage family); All, on everywhere
      (Conversion; the pathways' age limit converts at the window's end). Conversion's destination uses the pathways' proportions,
      not yet the NLCD class at the time. The three groups and Post-disturbance get maps (main-transition-groups.csv). GDS copy
      (stage 6 on the step 2 result, 1985-2012, 34 min): the 2008 fire put 540 ha into Disturbed: Wetland Oak/Gum/Cypress Group;
      313 ha returned in 2009 (NLCD kept them as woody wetland), 20 ha more in 2012, 207 ha still waiting in 2012.
    - **Step 4 DONE 2026-11-11.** Stage 9 turns the three groups' maps on from y1 + 1 and writes the return chance as transition
      multiplier values by class and age: 0 below ReturnAgeMin, then ReturnProbability divided by the mean adjacency multiplier
      (`defaults/projection/post-disturbance-adjacency.csv`, so the mean chance holds). Stage 10 adds a Live Forest attribute (1 on
      Ids 100-999) and the return groups' adjacency multiplier (the P26 curve: any live forest nearby, not own type). Fire multipliers
      by class (`fire-class-multipliers.csv`; disturbed forest 1.5 from P26's reburns; disturbed shrub and annual grass 1 until
      calibrated). On a rerun, stage 9 replaces only these rows of TransitionMultiplierValue.
    - **Tested end to end 2026-11-11 on the GDS copy** (`dev/libs/t57/GDS57.ssim`, multiprocessing on): Build 48 (46 min), historical
      1985-2023 50 (33 min), Projection Setup 52 (15 min), projection 2024-2043 54 (18 min, 1 iteration), all clean. Historical: the
      2008 fire put 536 ha into Disturbed: Wetland Oak/Gum/Cypress Group, 475 ha returned as NLCD showed woody wetland again, 94 ha
      still disturbed in 2023 (all at age 16). Projection: the only fire year drawn was 2024 (2,185 ha, 572 high severity), on the
      same swamp. It reburned the 94 ha cohort: 40 ha converted (the 0.9 reburn share), 9 ha returned that year, 4 ha stayed disturbed
      with age reset. The new burns waited out ReturnAgeMin, then returned at about 10% a year from 2039 (40, 54, 32, 32 ha), 169 ha
      still disturbed in 2043. 4 ha of Disturbed: Non-sage returned and 2 ha converted at the 12-year window's end. No forest
      conversion at a window's end yet, since 20 years is shorter than the 30-year window.
    - **Step 5 DONE 2026-11-11.** Stage 5 starts a regrowing cell (`src/regrowth-age.R`) in its type's disturbed class, by the
      setting DisturbedStart in `defaults/landcover/regrowth-age.csv`: Fire (default, user 2026-11-11), only cells a fire perimeter
      dates, meaning the cell's return (the year NLCD first shows it as forest) comes within the forest window after the latest
      perimeter of the 30 years before the start; All, every regrowing cell; None. A dated cell's age is the years since that fire,
      others keep the regrowth age. Stage 8 gives a disturbed start cell its type's pools at that age (stock curves, or the forested
      wetland tables for a twin) for dead wood and soil, and live carbon from its ecodivision's shrub class at that age (shrub-age.csv,
      chaparral.csv). Measured on the existing maps (`dev/fire/regrowth-fire.R`): P26 3.6 of 45.3 kha of regrowing
      cells are dated by a perimeter (fires mostly 1965-1985; median 7 years since the fire, against 12 by the regrowth rule); Puget
      none of 58.4 kha (old clearcuts). So under Fire, Puget's regrowing clearcuts start as young forest (harvest goes straight back
      to forest), and under All they would wait in a disturbed class until NLCD shows forest. GDS quick test (stages 5, 6, 8 on Build
      48 with All, result 57; 5 years, result 59): 8 cells (18 ha; pine and oak types) started disturbed, live carbon 5.4 Mg C/ha from
      Non-sage against 13.1 on their types' curves, and still waiting in 1990 (their NLCD return is about 2000). No disturbed start
      cells for the shrub classes: chaparral and the sage family already start at their age since fire.
    - **Windows by region: DONE 2026-11-11 (user: "I could see southeastern forests having a much shorter period").**
      `post-disturbance-settings.csv` has an Ecodivision column (blank = every ecodivision), and ParentClass takes Forest or one
      class's name. For each class and ecodivision the most specific row wins: the class there, the class anywhere, Forest there,
      Forest anywhere (`src/post-disturbance.R`, `pd_resolve`). `tools/make_post_disturbance.R` writes a class's return, conversion
      and reburn pathways by ecodivision only where its settings or destinations differ between ecodivisions, else one blank-stratum
      row, so ST-Sim never sees both for one class and type. Stage 9 writes the return chance by ecodivision the same way, and stage
      5 takes each start cell's window from its type and ecodivision. Provisional southeastern rows: Subtropical and Subtropical
      Mountains forest, window 15, return from age 2 at 0.2 a year (59% back by 5 years, 87% by 10, 95% by 15). Not fitted: step 7
      fits each ecodivision by the P26 method (`dev/fire/p26-fire-gap.R`: share back to NLCD forest by years since a
      stand-replacing loss). The forest pathways grew from 1,237 to 1,795 rows, since every forest class now has its rows by
      ecodivision; the shrub classes' are unchanged. tests/unit-post-disturbance.R checks the resolution and that no class mixes
      blank and ecodivision rows (23 checks). GDS check (stages 5, 6, 8 on Build 48, result 63; Projection Setup on it, result 69):
      stage 5 found each regrowing cell's window (none fire-dated: under Fire all 8 start as forest); stage 9 wrote one return row
      per class with the Subtropical values (0.474 a year from age 2, i.e. 0.2 / the 0.42 mean adjacency multiplier), since GDS is
      all Subtropical. A first version wrote rows for all 19 of the library's ecodivisions; stage 9 now takes the study area's from
      its stratum map. The setup then stopped in stage 10: a Projection Setup on a quick-test result builds its fitting region
      differently from one on a full Build and reaches past the downloaded NLCD (setup 52, on Build 48, passed). Not this change.
    - **Step 7, forest part DONE 2026-11-12** (user: "Write them"; `tools/fit_post_disturbance.R`, 2 min): the Forest rows of
      post-disturbance-settings.csv fitted by ecodivision, the P26 method on CONUS. 268 MTBS wildfires of 1986-2010 (up to 40 per
      ecodivision), 1.95 million pixels NLCD showed going from forest to barren, shrub or grass within two years of high severity,
      followed to NLCD forest two years running (Kaplan-Meier, censored at 2024 or a reburn; each fire at most 500 pixels). East:
      Subtropical 84% back by 13 years (0.169 a year from year 4), Subtropical Mountains 83% by 16, Warm and Hot Continental about
      82% by 14-18. West: Mediterranean Mountains (P26, Lassen) 37% by 25 (0.030 a year from 11; P26's provisional 58% at 25 had
      counted pixels NLCD never showed lost), Marine and Marine Mountains 44% by 29, Temperate Steppe Mountains 29% by 30, Temperate
      Desert Mountains 18% by 24, Temperate Steppe 3% by 25 (11 fires). Reburn conversion 0.79-0.99 except Marine 0.30. Shrub share
      of non-returners 0.71-0.97 in the West, 0.20-0.30 in the Subtropical ecodivisions. CONUS fallback: window 26, from year 4,
      0.022 a year (40% back). The western windows are partly the record's length (about 10% of pixels followed past 30 years, curves
      still rising slowly), so conversion at the window's end may come early there; in historical runs Reforestation brings back
      what NLCD later shows as forest. Curves in `dev/fire/post-disturbance-fit.csv`. Pathways regenerated (fire.csv,
      post-disturbance.csv); tests/unit-post-disturbance.R 24 checks. Not yet run in a Build. Open: the shrub classes (RCMAP cover,
      now downloaded: see below), forest type within an ecodivision. RCMAP V8 sagebrush and shrub cover 1985-2025 downloaded
      2026-11-12 to the national copy <home>/land-cover/rcmap-cover/<comp>/ (82 yearly tifs, 198 GB, 116 min; Data Download
      scenario in the Lassen library; manifest <home>/records/RcmapCoverFolder-manifest.csv), so later Builds need not fetch it.
    - **Step 7 shrub DONE 2026-11-12 (user: "go for it" on the recommendation: write as fitted, invaded steppe kept slower,
      chaparral conversion provisional).** `tools/fit_shrub_post_disturbance.R --severity=3,4 --write`: RCMAP sagebrush (sage family)
      or shrub cover after MTBS moderate and high severity wildfire 1986-2010, up to 60 fires per ecodivision; "back" = cover at half
      its pre-fire level two years running; only pixels NLCD shows as shrub (52) the year before (RCMAP alone also counted shrub
      understory in forest: only 34% of its Non-sage and 54% of its Chaparral pixels were NLCD shrub). 2.1 M pixels in 551 fires.
      | Class | Window | ReturnAgeMin | ReturnProbability | ReburnConversion | back by window | was (provisional) |
      | Sage, Native Sage Steppe | 27 | 8 | 0.028 | 0.98 | 43% | 35 / 10 / 0.05 / 0.9 |
      | Invaded Sage Steppe | 27 | 8 | 0.017 (0.6 x the sage fit) | 1 | - | 35 / 10 / 0.03 / 0.95 |
      | Non-sage | 20 | 2 | 0.080 | 0.69 | 79% | 12 / 2 / 0.25 / 0.8 |
      | Chaparral | 8 | 2 | 0.252 | 0.10 | 87% | 12 / 2 / 0.3 / 0.8 |
      Severity barely matters: high only (396 fires) and moderate only (550) give windows within 2 years and the same curves, so
      moderate-severity shrub fires lose and regain cover as high-severity ones do (to-do 61). NLCD on the same pixels (share grass
      1 / 5 / 10 / 20 years after): Chaparral 0.54 / 0.35 / 0.08 / 0.06, Non-sage 0.38 / 0.34 / 0.23 / 0.12, Sage family
      0.59 / 0.60 / 0.57 / 0.35; so NLCD's post-fire shrub-to-grass is mostly temporary in chaparral and non-sage, and lasting only in
      sage, where RCMAP has 25% of the sagebrush back at 20 years while NLCD already calls 64% shrub (other shrubs first). Curves in
      `dev/fire/shrub-post-disturbance-fit.csv`, the NLCD comparison in `dev/fire/shrub-post-fire-nlcd.csv`. Pathways regenerated;
      unit-post-disturbance 24 checks. Open: RCMAP cannot separate native from invaded steppe (invaded kept slower by judgement; could
      be fitted on the annual-grass layer stage 5 uses); chaparral's 0.10 conversion of pixels that reburn before recovering is low
      against the type-conversion literature (repeat fires within about 5 years are rare in a 1986-2010 sample): check on RCMAP
      annual herbaceous cover (to-do 61). Not yet run in a Build.
    - **Step 6 DONE 2026-11-12 (figures; user chose three of four proposed: not the settings chart).** Build Figures (stage 12):
      "How forest starts: regrowth and reforestation": (a) how each natural cell NLCD shows as forest only later starts (regrowth
      with its NLCD age, disturbed at the start, reforests later by slow recovery or encroachment, or forest with its source age),
      (b) the year NLCD first shows it as forest, (c) the BpS forest share. Stage 5 now writes the two maps it needs (Land Cover
      Layers: StartRule, FirstForestYear; in the 1.4 update). Run Figures (stage 13): "After disturbance, and reforestation": (a)
      how each cell in a disturbed class came out (back to forest or shrubland, converted, still waiting at the end), (b) its last
      high-severity fire, (c) reforestation by year; and "Disturbed land and reforestation over time": (a) area in the disturbed
      classes, forest and shrub, (b) yearly returns, conversions and reforestation. A projection joins its historical run in front.
      Lassen (Build figures result 35; Run Figures 36 historical, 37 historical + 10-year projection): the 2012 Reading and 2021
      Dixie fires put 13 and 44 km2 of forest into its disturbed classes; few have returned by 2023 (window 30 years, NLCD not yet
      forest); in the projection a high-severity reburn converts 12.7 km2 in 2027 (reburn conversion 0.9), worth a look in step 7.
      Found by the test: the Build figure counted areas on the finer display grid (25 times too large), and a run that wrote no
      transition maps (the projection) showed its fires as "before 1986"; it now says "no fire map for its year". Scripts
      `dev/reforestation/lassen-run-figures.R`.
    - **TO DO (user, 2026-11-11): non-fire disturbance, Mount St Helens and the rest.** Two gaps:
      - Before the start year: only fire perimeters date a disturbance, so DisturbedStart Fire leaves the 1980 blast zone, older
        windthrow and insect kill as young forest with their NLCD regrowth age. Option: an optional Data Source of recorded
        stand-replacing events (polygons with year and cause: the Mount St Helens 1980 blast and debris zones, large hurricanes, bark
        beetle outbreaks), read with the fire perimeters, so DisturbedStart Fire becomes "Recorded". The user's version (2026-11-11:
        "a gis boundary layer and then a date the user can either set (or read from the layer itself)"): an uploaded events file,
        a polygon layer plus a year typed in the Build or taken from a field of the layer. Agreed as the clean approach for St
        Helens; not built. It is the only route for land never forest in the record (see the St Helens split below).
      - During the record (user, 2026-11-11: "for now, I do not want to model these changes", so not to build; the record is used
        only to start cells in 1985): only fire and harvest are modelled. Stage 6 takes clearcut and selection from LCMS Tree Removal (class 9,
        split by what NLCD shows next), and the LCMS Change layer already downloaded (v2025-11, 1985 on) names other causes: 1 Wind,
        2 Hurricane, 3 Snow or Ice, 4 Desiccation, 5 Inundation, 10 Defoliation, 11 Southern Pine Beetle, 12 Insect, Disease or
        Drought Stress, 13 Other Loss (`dev/harvest/02-lcms-vs-nlcd.R`). Option: a "Disturbance: Stand-Replacing" group from those
        codes split "standrep" as Tree Removal is (shrub or grass in NLCD within two years), with pathways from each forest class to
        its disturbed class (age reset) as high-severity fire has. Return then follows NLCD as for fire. No new download. In
        projections it needs a rate (the historical years' area, drawn as fire is, or a mean by ecodivision).
    - **BUILT 2026-11-12 (steps 1-10 below; release with 1.4.0), design agreed (user, 2026-11-11-12): a reforestation transition for natural non-forest that becomes
      forest with no fire or harvest behind it.** The user's idea: such a cell starts as what NLCD calls it in 1985, grows on that
      class's curve, and moves to forest when NLCD shows forest; in projections a spatial multiplier (a suitability layer, as other
      transitions have) says where it is likely. Measured first, since stage 5's any-year rule already folds most of this into
      forest:
      - How big (`dev/fire/reforestation-conus.R`, 200k random 30 m points, Annual NLCD 1985-2025, LCMS v2025-11 and MTBS 1985-2023;
        event: natural 31, 52, 71, 95 to forest 41-43, 90 two years running, forest in 2/3 of the years after). CONUS, 1986-2023:
        38.6 Mha of events; 18.4 after harvest, 1.8 after fire, 5.0 forest earlier in the record and lost with no recorded cause,
        13.5 Mha (355 kha a year, falling from about 610 to 170 kha a year by decade) non-forest since 1985 with nothing recorded.
        Subtropical has the most.
      - Split of those 13.5 Mha by timing, LANDFIRE BpS 2020 group and later harvest (`dev/fire/reforestation-conus-split.R`):
        | Reading | Mha | kha a year | cut again later |
        |---|---|---|---|
        | forest by 2004, BpS forest: clearcut regrowth, already right (any-year rule, NLCD regrowth age) | 7.3 | 192 | 32% |
        | forest from 2005, BpS forest: slow recovery, the St Helens type | 2.6 | 69 | 1% |
        | BpS non-forest (mostly NLCD shrub on BpS shrubland or grassland, dry West and Prairie): encroachment | 1.7 | 44 | 4% |
        | BpS riparian, savanna or other (1.1 of it Subtropical, probably bottomland regrowth) | 1.9 | 50 | 27% |
        So real reforestation is about 4.3 Mha, about 113 kha a year. Caveats: per 30 m pixel (the model grid smooths flicker), each
        point is about 6,700 ha so some ecodivision numbers rest on a few dozen points, BpS is modelled potential, and 2004 is the
        regrowth rule's 20-year limit, not fitted.
      - Mount St Helens (`dev/fire/st-helens.R`, a 1,783 km2 box over the mountain and the blast zone to its north, so it also holds
        nearby harvest land): 872 km2 natural non-forest in 1985. 438 km2 (50%) forest by 2004, almost all BpS forest, mostly
        1995-2004: stays forest in 1985. 155 km2 (18%) forest from 2005, at a falling rate (61, 46, 27, 22 km2 per five years): the
        transition's case. 279 km2 (32%) never forest by 2025, half barren (the pumice plain and debris avalanche) but 176 km2 BpS
        forest: only the events file reaches it. Group map `dev/fire/st-helens-groups.tif` (not committed).
      - The narrower design this points to: keep the any-year rule for cells first forest by 2004 on BpS forest, riparian or
        savanna (clearcut regrowth); apply the reforestation transition to cells first forest from 2005 on BpS forest (slow
        recovery: start as the 1985 class) and to cells on BpS non-forest (encroachment: no legacy dead wood; the natural one for the
        projection suitability surface, since it continues). Fire-dated cells, and event-file cells if added, still start in the
        disturbed class. The cutoff counts from the start year, not the disturbance, so cells first forest just before and just
        after it start very differently; that is the cost of a rule for cells whose disturbance year is unknown.
      - **Decided (user, 2026-11-12):** on by default; the cutoff is fitted, and the user can override it; LANDFIRE BpS (or a
        similar potential natural vegetation layer) is needed, so the Build downloads it.
      - **Build plan** (written 2026-11-12, not started). Each step is tested before the next.
        1. **BpS as a Data Source.** Column `BpsFile` (package.xml lucasCore_DataSource, defaults/library/data-sources.csv and
           project/lucasCore_DataSource.csv, defaults/download/endpoints.csv), downloaded as EVT and FRI are, by `lf_single()` in
           src/download-sources.R: LFPS layer LF2020_BPS (LF 2.2.0, the edition in `F:/lucas-master/Data Sources/BpS`; check the
           LFPS layer name and whether a newer edition exists), all of CONUS from LANDFIRE's full-extent zip. Its attribute table
           (VALUE, GROUPVEG) is read from the download's CSV_Data. New `defaults/landcover/bps-groups.csv`: GROUPVEG to forest
           (Conifer, Conifer-Hardwood, Hardwood, Hardwood-Conifer, Peatland Forest), riparian or savanna, non-forest (Grassland,
           Shrubland, Sparse, Barren, Peatland non-forest), other. Citation and data dictionary rows.
           DONE 2026-11-12. LFPS lists LF2020_BPS as the current CONUS edition (LF2023_BPS is Alaska only); the national zip is
           `CONUS_LF2020/LF2020_BPS_CONUS.zip` (2.0 GB). LFPS jobs return the raster alone, so the attribute table ships as
           `defaults/landcover/LF20_BPS_220.csv` (VALUE, BPS_CODE, BPS_NAME, GROUPVEG; 2,189 values) and `src/reforestation.R`
           reads it (`bps_lookup`, `bps_potential`; riparian and savanna as forest unless set otherwise; Hawaii types with no group,
           water and fill as other). tests/unit-reforestation.R (17 checks). Fetched by Data Download for GDS (plumbing only: 4 MB,
           identical cell for cell to the national copy, same grid as EVT), P26 (29 MB) and Puget (20 MB), which the step 4 tests
           use (user, 2026-11-12: test in the West). A library made before needs `tools/sync-library.R --columns-only` with a
           fresh `tools/new-library.R` library as `--reference` (the starter is not rebuilt yet).
        2. **Fit the cutoff** (`tools/fit_reforestation_cutoff.R`, national layers, as `dev/fire/reforestation-conus.R` samples
           them). Cells with a dated stand-replacing event during the record on BpS forest (LCMS Tree Removal that NLCD shows as
           shrub or grass, MTBS high severity) give the years from the event to NLCD forest (two years running, forest in 2/3 of
           the years after). Return times are censored at the record's end, so the quantile comes from a survival curve
           (Kaplan-Meier), not from the returns seen. Cutoff per ecodivision = the 0.9 quantile (a setting), with the division's
           or CONUS's value where an ecodivision has too few events (minimum also a setting). Shipped as
           `defaults/landcover/reforestation-cutoff.csv` (Ecodivision, Years, Events, Source), like post-disturbance-settings.csv
           (blank Ecodivision = all; most specific row wins, `pd_resolve`'s rule). Check it against the regrowth rule's 20 years
           and the CONUS split (how much moves between regrowth and reforestation).
           DONE 2026-11-12 (`tools/fit_reforestation_cutoff.R`, 4.5 min; `src/reforestation.R` `reforest_cutoff`, 7 more checks in
           tests/unit-reforestation.R). Changes from the plan, found while fitting:
           - a cohort, not Kaplan-Meier: events of 1986-1995 all have 29 years of record after them, so return within 29 years
             is never censored; the cutoff is the 0.9 quantile of years to return among those that returned (KM's 0.9 is undefined
             where many burns never return, and those are conversions, not slow returns). Values of 28-29 in the dry West sit at
             that limit, so they are lower bounds;
           - a high-severity fire counts only where NLCD shows barren, shrub or grass within two years (some MTBS pixels stay
             forest in NLCD, which gave 1-year "returns"), and return is looked for from the first non-forest year;
           - sample: 10 km tiles (570 drawn, 30 per ecodivision on NLCD 1985 forest; 388 with events, 874k event pixels: 91%
             clearcut). Each tile counts as at most 500 events, since one burn or harvest unit can hold most of an ecodivision's
             events (Temperate Desert Mountains: 84% in one tile); equal tile weights let tiles with a few slow events swing it
             (Hot Continental 12 to 21 years).
           Result (years; median return in brackets): CONUS 21 (12); Subtropical 11 (7), Subtropical Mountains 12, Hot Continental
           and its Mountains 12, Warm Continental and its Mountains 18, Marine 20 (17), Mediterranean 20, Savanna 21 (CONUS's;
           3 events), Marine Mountains 23 (17), Mediterranean Mountains 24 (18; Lassen), Prairie 26, Tropical/Subtropical Steppe
           29, Tropical/Subtropical Desert 27 (with its domain), Temperate Steppe and Temperate Desert 28, the dry mountains 27-28.
           Clearcuts returned 93% of the time within 29 years (90% within 20), high-severity fires 21% (90% of returns within 28).
           Against the flat 20 years on the CONUS sample's unrecorded reforestation on forest potential: 0.9 Mha moves to regrowth
           (slow western and Marine mountains) and 0.6 Mha to reforestation (Subtropical: 0.54 to 0.99), so 3.2 to 2.8 Mha.
           Open: RegrowthLag (the age of a regrowing cell, 20 everywhere) could take the fitted median return by ecodivision
           (6-23 years) the same way; not changed.
        3. **Settings and override.** A single-row Build sheet `ReforestationOptions` (as HarvestAgeOptions): Enabled (Yes by
           default), CutoffYears (blank = the fitted table; a number overrides it everywhere), and the reading of riparian or
           savanna BpS (default: as forest potential). Added to stage 5's inputs in package.xml. The regrowth rule's RegrowthLag
           keeps setting the age; the cutoff replaces its other job (which cells count as regrowing), so `regrowth_age()` takes the
           cutoff per cell instead of `lag`.
           DONE 2026-11-12. package.xml `ReforestationOptions` (single row; Enabled, CutoffYears 1-60, RiparianAs 1 Forest potential
           or 2 Non-forest potential), in the scenario's LUCAS Core group after Minimum Harvest Age and an input of stage 5 (stages
           6 and 9 add it when they read it); `reforest_options()` in src/reforestation.R reads it (rsyncrosim returns the list
           label, so both label and code read). `regrowth_age(..., cutoff =)` takes one cutoff or one per cell (default the lag, so
           stage 5 is unchanged until step 4 passes the fitted one); the age stays lag-based, at least 1. tools/quick-test.R copies
           the sheet. A library made before gets the table when it opens (checked on the Lassen library: written and read back).
           Tests: unit-reforestation 30, unit-regrowth-age 19 checks.
        4. **Stage 5: which cells reforest.** Among natural cells forest only by the any-year rule (NLCD at the start 31, 52, 71,
           95): first forest at or after the cell's cutoff on BpS forest, or at any time on BpS non-forest, start as their
           start-year class (the grass, shrub, barren or wetland type stage 5 already gives non-forest cells, with the shrub age
           rule). The rest stay as now: forest with the regrowth age, or the disturbed class where a fire perimeter dates them
           (DisturbedStart Fire wins over reforestation). BpS on the model grid: the share of the cell's 30 m pixels in each group,
           the cell's group the most common. New output `ReforestType.tif`, a forest type for every land cell, for stage 6's
           gates and projections: the cell's own type where it starts as forest or disturbed, the any-year rule's type (wetland
           twin included) where it reforests, else the nearest forest type (`fill_modal`). Check what reads `EverForest.tif` downstream and whether
           it should drop these cells. Say lines: area by reading and ecodivision, against the CONUS split.
           DONE 2026-11-12 (src/5-initial-conditions.R; `reforest_pick()` in src/reforestation.R, 8 more checks). Candidates: natural
           cells forest only by the any-year rule, NLCD 31, 52, 71 or 95 at the start, not woody wetland. First forest = two years
           running from the second year on, then forest in 2/3 of the years after (else they flicker and stay forest). The cutoff
           also replaces RegrowthLag as the limit of regrowth (`regrowth_age(cutoff =)`), so a cell either regrows or reforests;
           with Reforestation off it is RegrowthLag, as before. Reforesting cells start as G (shrub, grass), W (emergent) or barren,
           age 0 (chaparral and sage then take their fire age). BpS on the model grid: the most common potential of the cell's 30 m
           pixels; BpsForestShare.tif the forest share. ReforestType.tif: every land cell's forest type (own, parent of a disturbed
           class, the any-year rule's for reforesting cells, else neighbours'); both added to Land Cover Layers (a library made
           before needs `tools/sync-library.R --columns-only`). EverForest is read by nothing downstream (output only), so it keeps
           its meaning (NLCD forest in any year). No BpsFile with Reforestation on stops stage 5 with a message.
           Lassen test (library dev/libs/lassen/Lassen.ssim, 150 m, user 2026-11-12: a test library, run efficiency first;
           `dev/reforestation/lassen-build.R`, stages 1 and 5 in 8 min, result 13): 19,318 land cells; 6,591 forest only by the
           any-year rule; 117 reforest (111 slow recovery on BpS forest, first forest 24-37 years after 1985; 6 encroachment), all
           inside the park, at the edges of the high country's open land (map `dev/reforestation/lassen-step4.png`, not committed);
           4,947 regrow before the 24-year cutoff and stay forest; 1,526 flicker. Found by the test: the age check counted the
           disturbed classes (age = years since the fire) as "other cells" that must be 0, and failed on the 7 fire-dated cells; it
           now allows them an age of at least 1 and names the failing cells by class.
        5. **Definitions.** Transition group `Reforestation`; one type per destination, `Reforestation: <forest type>` (as Ag
           Contraction's), incl. the wetland twins; stsim_TransitionType, TransitionGroup, TransitionTypeGroup,
           TransitionSimulationGroup and stockflow main-transition-groups.csv. `tools/make_reforestation.R` writes
           `defaults/transitions/pathways/reforestation.csv`: every natural non-forest class (Barren: All, the grassland classes,
           Sage, Native and Invaded Sage Steppe, Non-sage, Chaparral, emergent wetland) to every forest type, probability 1, age
           reset. Disturbed classes have no rows (they have Return). tools/sync-library.R brings existing libraries up to date.
           DONE 2026-11-12 (`tools/make_reforestation.R`; 7 more checks in tests/unit-reforestation.R, 45 in all). 31 types
           `Reforestation: <type>` (Ids 1100-1130; a twin "Reforestation: Wetland <type>"), all in group Reforestation (not in the
           simulation groups, as Post-disturbance), a main spatial group for stock-flow. 310 pathways from 10 source classes (Barren,
           sage family, Non-sage, Chaparral, the three grass classes, Palustrine Emergent; not Post Fire Shrub 59, Estuarine
           Emergent, the disturbed classes) to the 31 forest classes, probability 1, age reset. Libraries made before 1.4: the 1.4
           update (ui/LucasCoreUpdates.cs Update_1_400) adds the group, the types and the columns of steps 1 and 4 (BpsFile,
           ReforestTypeFileName, BpsForestShareFileName); it compiles, but is NOT yet run on a library: SyncroSim runs an update
           provider only from an installed package, not the dev pointer (memory: release-library-updates), so test it on a copy of
           a 1.3 library at the 1.4.0 release, together with main's own 1.4 update (the two must be merged). The Lassen library was
           made again from the package (old one kept as dev/libs/lassen/Lassen-before-step5.ssim); stages 1, 5, 6 (result 4, 10
           min): the pathways load, the 31 types have zero targets until step 7 gives them maps.
        6. **Carbon.** No flows on the transition (as Ag Contraction): the grass or shrub live carbon carries into the forest class,
           which grows from age 0 on its FIA curve. Stage 8 needs nothing, since these cells start as non-forest classes. Check per
           forest type that there's no jump in live biomass at the transition. These cells also start with no forest legacy dead
           wood: right for encroachment, low for St Helens-type recovery (the events file is the fix there).
           CHECKED 2026-11-12 on Lassen (full Build result 6, 35 min; `dev/reforestation/carbon-at-transition.R`): no jump.
           Stage 3's net growth is a mass balance (g(t) = C(t+1) - (1 - r) C(t)), so a reforested cell follows its curve from age 0
           plus the carried grass or shrub carbon, which fades at the forest pools' turnover (foliage 0.11-0.91, fine roots 0.64,
           other wood 0.04, coarse roots 0.02 a year). The 117 cells carry 5.5 Mg C/ha live (median; Non-sage 5.5, chaparral 16.2,
           grass 3.2, barren 0); 3.3 is left after 5 years, 2.7 after 10, 1.9 after 20, against destination curves of 4-10 Mg C/ha
           at age 5 and 10-19 at age 10. So the cell's live carbon is continuous at the transition and a little above the curve for
           some years. The open point is the age itself: NLCD shows forest only once trees have canopy, so a stand it first shows
           as forest is older than 0. On the curves, 20 years is 23-38 Mg C/ha, which the model credits only over the next 20 years.
           Age 0 (user, 2026-11-12) is the conservative choice, and continuous; a young age would credit that carbon in the year of
           the transition (a jump). Kept (user, 2026-11-12: "Keep age 0").
        7. **Stage 6 (historical runs).** sources.csv row `Reforestation, NlcdPersist, 41|42|43|90`: on where the modal NLCD shows
           forest two years running, as Forest Return. Type gates from `ReforestType.tif` at the start year, as the NaturalVeg
           gates. Only cells in a natural non-forest class can take it: the reforesting cells, and cells a fire converted that NLCD
           later shows as forest (decided: they take it). Check: no clash with the land-use class pairs (transition-pairs.R).
           DONE 2026-11-12. sources.csv `Reforestation, NlcdPersist, 41|42|43` (the NlcdPersist maps Forest Return uses: on where the
           modal NLCD shows forest the year before and that year); stage 6 gates each type to ReforestType (as the NaturalVeg
           gates) and takes ReforestationOptions (off: the source is dropped, so a zero target) and Land Cover Layers as inputs.
           No clash with the land-use pairs: those start from developed or agricultural classes. Lassen (stage 6 on Build result 6,
           38-year run; `dev/reforestation/lassen-historical.R`): all 117 cells reforest in the year NLCD predicts (1988-2023,
           most 2010-2023), as their ReforestType; 3 more are fire-converted cells NLCD shows as forest again (decided). Found by
           the test: (1) NLCD 90 in the source turned 7 shrub, grass or emergent cells that NLCD later calls woody wetland into
           upland forest (their ReforestType comes from neighbours); Reforestation now follows 41-43 only, as stage 5's any-year
           rule (Forest Return keeps 90 for the twins); (2) ST-Sim writes transition maps only for transition simulation groups
           and [Type] groups, so Reforestation is now a simulation group, as Ag Contraction (package defaults, make_reforestation.R
           and the 1.4 update). NLCD 2023 shows 86 of the 117 as forest; the model keeps the rest forest (no transition back).
        8. **Projections (stages 9 and 10).** transitions.csv row `Reforestation`: Target by ecodivision, the area from the
           historical record, the mean of its recent years (decided: 10 by default, a setting). allocation.csv: a fitted surface
           `Reforestation`, SourceClasses 31|52|71|95, EventClasses 41|42|43|90. covariates.csv: new forest potential (BpS forest
           share), distance to forest and forest share within 1 km, with elevation, slope and land cover. The destination type in
           projections: `ReforestType.tif` (step 4).
           DONE 2026-11-12. Stage 9: Reforestation is a Target group in its own sampling set, drawing from the last Recent Years
           (Reforestation Options, new column, default 10) of the reference period; its historical area in a year is the cells whose
           Build start-year class can reforest and that NLCD first shows as forest two years running that year (stage 6's map is NLCD
           forest everywhere, so the plain map would have counted every forest cell). Stage 10: Event Classes "Reforestation" = the
           stage 5 rule per fitting cell (`reforest_pick` on the fitting grid's NLCD, BpS potential and the cutoff by ecodivision), so
           regrowth after clearcut or fire is not an event; new built-in covariates Forest potential (BpS) (forest share of the cell),
           Distance to forest and Forest share within 1 km (NLCD 41-43 by epoch), the Reforestation surface's rows in covariates.csv,
           and their effect curves in Suitability Curves. Stages 9 and 10 take Reforestation Options. tools/new-projection.R gained
           --base and --also (a setup on a quick-test result). Lassen (setup result 22, 150 m fitting grid; the other surfaces set to
           None, to-do 60): 155 events, out of sample AUC 0.79 (fit 1986-2012, scored on 2013-2023; the top 10% of eligible land held
           22% of the later reforestation); suitability rises with forest potential and forest share and falls steeply with distance
           to forest (map and curves `dev/reforestation/lassen-surface.R`, png not committed). 10-year projection (result 21): 229.5 ha
           reforested against 216 ha of targets (iteration 1), within a cell a year. Found by the test: in a projection that starts
           from a historical run, stage 9 replaced the start map by the run's 2023 state before counting Reforestation's history,
           so its target was 0 (the reforested cells are forest by then); it now uses the Build's start-year classes. Note: on
           forest potential reforestation can only show after the cutoff (24 years at Lassen, so 2009 on), so the recent-years rate
           (about 0.2 km2 a year at Lassen, against 0.07 over the whole record) is the rate of the record's late years; it will run
           high late in a long projection as the stock of cells recovering from disturbance before 1985 runs down. Settled
           2026-11-12 (user: "We can remove this. I think this is the best data to fit on as of now"): the recent 10 years stay
           the projection's rate; no adjustment planned.
        9. **Tests.** tests/unit-reforestation.R: the cutoff table's resolution and the override, the cell readings, the pathway
           table (every source class to every forest type, no disturbed classes). tests/unit-regrowth-age.R updated for the
           per-cell cutoff. End to end on P26 or Puget (both have rule cells; GDS has few): stages 5 and 6, a short historical
           run (reforesting cells reach forest when NLCD does; area by year against the NLCD record), then a Projection Setup.
           Starting carbon before and after.
           DONE 2026-11-12, on the Lassen Volcanic NP library at 150 m (user: test in the West; Lassen as the test area) rather than
           P26 or Puget. tests/unit-reforestation.R: 50 checks (BpS table and potential, the cutoff and its override, the options,
           the cell rule, the definitions and pathways, stage 6 and projection wiring, the 1.4 update text); unit-regrowth-age 19.
           End to end: stage 5 (step 4), the historical run (step 7: all 117 cells in the year NLCD predicts), the Projection Setup
           and a 10-year projection (step 8). Off switch (Reforestation Options: Enabled off; quick test of stages 5, 6, 8 on Build
           result 6, result 24): regrowth back to RegrowthLag 20, the 117 cells start as forest (15,560 forest cells, 15,443 with it
           on), Reforestation gets zero targets. Starting carbon at Lassen, on against off: live biomass 3.224 against 3.250 Tg C
           (-0.026, -0.8%), all stocks 8.461 against 8.505 (-0.044, -0.5%), about 100 Mg C/ha of live carbon on each of the 117
           cells (263 ha), which off start with CMS' old-forest age. The full unit sweep: all pass but unit-treemap, which needs the
           FIA DataMart under the worktree's dev/libs (environment, not this change); unit-metadata-definitions found the
           Reforestation group and types missing from defaults/metadata/definitions.csv (added).
        10. **Docs.** CHANGELOG (changes Build results), defaults README files, the Build page help, metadata; ships in 1.4.0.
           DONE 2026-11-12: CHANGELOG (Unreleased: Changed, Added, the 1.4 upgrade note), defaults/landcover and
           defaults/transitions README, user guide section 3.9 Reforestation Options and the Reforestation surface in 6.4, the
           Stratum Sources and unit counts (National Parks), metadata definitions (step 9). The data dictionary describes released
           outputs, which this does not change. Open for the 1.4.0 release: run library update 1.4 on a copy of a 1.3 library, merged
           with main's own 1.4 update (step 5); the starter library rebuilt (tools/build_starter.R) for BpsFile, the new options and
           National Parks; the guide's transition type and group counts (143 and 15, already behind the post-disturbance classes).
        11. **Full chain on Lassen (user, 2026-11-12: "Go ahead with the full Lassen test").** DONE 2026-11-13 with
           `dev/reforestation/lassen-chain.sh` (Build stages 1, 5, 2, 3, 4, 6, 7, 8, 12; historical 1985-2023; Projection Setup with
           only Reforestation fitted; projection to 2050, 1 iteration; Run Figures of both). Three bugs found and fixed:
           - Historical runs returned 3 km2 to forest in 2012 and 1.5 in 2021, the years they burned (NLCD still shows forest in the
             fire year): return pathways now start at age 2 (8442020).
           - Stage 10 stopped fitting the Reforestation surface (92 events; a covariate had fewer distinct values than its smooth's
             k): k now shrinks to the data, a covariate under 4 values is dropped (8442020).
           - Stage 6 dropped the ecodivision of the by-ecodivision pathway rows (fire.csv reburns, post-disturbance.csv return,
             conversion), so all 19 ecodivisions' rows applied everywhere: each disturbed forest class had 19 return pathways, and
             90% of a burn returned in its first eligible year (1-year experiments: return multiplier 0 gave 0 ha; adjacency fixed at
             0.5 still gave 65% of the age-13 cells, i.e. the 0.071 chance drawn about 19 times). Conversion started at the
             earliest window (12 years; Lassen's is 25), reburn proportions stacked. Now only the study area's rows are kept, an
             ecodivision's own rows replace the blank rows for that class and type, and a Build check stops on a duplicate pathway.
             Every library built with the by-ecodivision settings (since 2026-11-12) needs a new Build.
           Final chain: Build 72 (no duplicate pathways; 1,464 pathway rows for Mediterranean Mountains), historical 74, setup 78,
           projection 80, figures 76 and 82. Reforestation: 117 of 117 cells in the expected years (117 transitions), 116 forest in
           2023. No return in the fire years. Projection: back to forest 33 km2 over 2024-2050, steady (0.4-2.7 km2 a year)
           instead of pulses; conversion at the 25-year window (5.6 km2 in 2037 from the 2012 burn, 14 in 2046 from 2021); disturbed
           forest peaks at 62 km2 after the drawn 2031 fire and falls to 23 by 2050.
      - **Decided (user, 2026-11-12), for the steps above:**
        - Flickering open woodland (natural cells forest in some years but under 2/3 of the years after; about half of P26's
          rule cells) starts as forest, as now, with its CMS or TreeMap age (step 4).
        - Riparian or savanna BpS reads as forest potential (step 3's default, step 4).
        - A cell that has already left its disturbed class as non-forest (the window ended, or a reburn converted it) and that
          NLCD later shows as forest takes Reforestation back to forest: historical runs follow NLCD (steps 5 and 7; the
          pathways' sources include the shrub and grass classes conversion leads to; the gate map then needs a type for every
          cell, not only the reforesting ones; projections use the same map). Within the window, return stays the disturbed
          class's Forest Return.
        - Age at the transition: 0; the grass or shrub live carbon carries over (step 6).
        - Projection rate: the mean of the record's recent years (10 by default, a setting), since the rate falls by decade
          (step 8).
    - **DECIDED 2026-11-12 (user: "it should probably become an herbaceous wetland"): a burned forested wetland that does not
      come back converts to Wetland: Palustrine Emergent**, at the window's end and at a high-severity reburn, whatever the
      ecodivision (`tools/make_post_disturbance.R`; tests/unit-post-disturbance.R, 24 checks), so it keeps wetland carbon and
      burial. Not yet run in a Build on a wetland library (GDS). The question as it was: what a burned forested wetland converts
      to.** The GDS test showed a burned swamp converting to Shrubland: Non-sage, the region's shrub class, at a reburn or the
      window's end. Upland shrub carbon and no burial are wrong for a swamp that stays wet. Options:
      - the wetland twins convert to a wetland class (`Wetland: Palustrine Scrub-Shrub` or `Palustrine Emergent`, with their own
        carbon and burial), by a column in `post-disturbance-regions.csv` or a twin-specific row in the settings;
      - historical runs take the destination from NLCD at the time (90 woody wetland, 95 emergent herbaceous wetland, 52 shrub), as
        the "conversion destination by NLCD" step plans for every class, and projections use the shares fitted from that;
      - the twins' waiting class keeps wetland carbon (peat, burial) rather than the upland shrub's, whatever it converts to.
      Check against the GDS record: how much of the 2008 and 2011 burns NLCD shows as 90, 95 or 52 later. Settle this before
      calibration (step 7) and before a real wetland library is built on 1.4.
    - Found and fixed by this test (released as 1.3.2): the Projection Setup stopped with "historical run 45 has no 2023 map for DOM:
      Peat". The stock output filter had peat maps off. The library's path also has to stay short: the historical run failed on a
      Windows long path in the scratchpad, and ran fine from `F:\lucasCore\dev\libs\t57`.
    - Test notes: a quick test whose Build result is itself a quick-test result fails at the historical step (new-historical.R wants
      the stock-flow definitions, which are in the original Build result); pass the original result too. The transition output filter
      is stage 0's, so a test that doesn't rerun stage 0 has no summaries of new groups. Multiprocessing was off in the GDS library
      (core_Multiprocessing), and its automatic tiles are whole counties (2), so turning it on gives at most about 2x (user: "it will
      cut the run time almost in half"); turned on in the test copy. Ideas for faster test libraries: finer tiles from a tertiary
      stratum with many units (historical runs follow maps, not targets), 300 m resolution, one county or watershed, shorter windows
      around the events tested. Stage 3 on GDS calibrates all 19 ecodivisions (8.5 min), not just the study area's two; why is not
      checked.
  - **Starting cells: disturbed before the start year (user, 2026-11-11, the Mount St Helens case).** Stage 5's "forest in any
    year" rule already starts a natural cell as forest when NLCD shows it as forest in any later year, so a blast zone or burn that
    regrew starts as its forest type. Its age is the problem: a stand that began after the start year (age 0 or less from CMS or
    TreeMap), or one with no age, takes the most common age of its neighbours (`fill_modal`), which in a large disturbed patch is the
    old forest around it. Measured 2026-11-11 (`dev/fire/start-ever-forest.R`; P26 Build 53, Puget's starting maps from historical
    result 59, NLCD at 150 m):
    - P26: 83.5 kha (4.2% of starting forest) are forest only by the rule (NLCD 1985: 68 kha shrub, 15 kha grass). NLCD shows them
      as forest at any time from 1985 to 2023. 84% start older than 20 years. Mean starting live biomass 68 Mg C/ha, against 5.5
      for NLCD forest aged 1-10 and 102 for all forest: about 5 Tg C of live biomass too much at the start (2.6% of P26's).
    - Puget: 72.3 kha (9.2% of starting forest; 55 kha shrub, 18 kha grass), mostly old clearcuts: 77% show as forest by 2005. Their
      ages match the rest of the forest (90% older than 20), and their live biomass is 126 Mg C/ha, against 33 for forest aged 1-10
      and 132 for all forest: about 7 Tg C too much (6.5% of Puget's), and the regrowth of 1985-2005 is missed.
    - Under 57, these cells start in their type's post-disturbance class, with time since disturbance from the event's date where
      it is recorded, otherwise from NLCD's return year (about the 21-year median before return) or TreeMap's establishment year.
      In historical runs they return when NLCD shows them as forest. Cells never forest in the record start as grass or shrub,
      unless a recorded disturbance and a forest potential (LANDFIRE BpS or EVT) say otherwise, and that is a Build option.
    - Correction (2026-11-11): the neighbour fill is not the main cause. Almost all of these cells take their age straight from the
      source: P26 98.5% from CMS (median about 45; 549 cells, about 1.2 kha, filled), Puget 96% from TreeMap (median 44; 1,309 cells,
      about 2.9 kha, filled). The sources and NLCD disagree. Puget's cells mostly regrow as clearcuts do; about half of P26's flicker
      between forest and shrub or grass (open mixed conifer, ponderosa and western oak), where CMS's age may be right.
    - DONE 2026-11-11, apart from 57 (user: "Yes, from NLCD"): stage 5 takes these cells' starting age from the NLCD record where it
      shows them regrowing (`src/regrowth-age.R`, settings `defaults/landcover/regrowth-age.csv`, tests/unit-regrowth-age.R): not
      forest in the first two years, then forest two years running less than 20 years after the start, and forest in at least 2/3
      of the years after that; age = 20 minus the years until that first forest. Others keep the CMS or TreeMap age. On the existing
      maps: P26 45.3 kha reset (median age 48 to 10; live biomass now 73 Mg C/ha against 18 for NLCD forest aged 1-20, about 2.5 Tg
      C less at the start), Puget 58.4 kha (44 to 9; 128 against 53, about 4.4 Tg C). A first version without the 20-year limit
      reset 74.5 kha of P26, mostly cells first forest after 2005, more likely open stands filling in. Changes Build results.
  - **Also to settle:**
    - which model fire severities enter, given how LANDFIRE severity maps to MTBS's classes;
    - starting cells in the state, with time since disturbance from MTBS, for runs that start well after 1984;
    - whether historical runs take return or conversion as observed in NLCD, and the fitted chances only in projections;
    - fitting by forest type and ecodivision beyond P26 (rerun the script on other region homes);
    - the carbon check: shrub and grass carbon in the waiting years against the FIA curve at the same age, per type.
  - **Developed with to-do 58** (management and mitigation, user 2026-11-11): the state's classes, pathways, windows and strata
    must leave room for replanting, salvage, site preparation and fuel treatments, so 58's options are checked against each
    design choice here before it is built.
  - **Related:** natural succession onto barren, grass and shrub land (Mount St Helens' blast zone, abandoned land) uses the same
    pathways and could be scoped with this; Ag Contraction already moves agriculture into forest types. `Shrubland: Post Fire Shrub`
    (class 59) and its transition types can be reused or retired. RETIRED 2026-11-13 (user: "Retire the post fire shrubland class
    as it is not longer being used"): class 59, its Y label and the two Ag Contraction types to it (`Ag Contraction Cropland /
    Pasture: Shrubland Post Fire Shrub`) are gone from the defaults (state lists, pathways, locations, carbon, CO2 and metadata
    tables; about 13,700 rows). Nothing reached it: no cell starts in it (the EVT "Recently ..." codes are not used, id 1000 in the
    crosswalk), Ag Contraction goes to the start year's nearest natural class, and fire sends land to the disturbed classes.
    Existing libraries keep the class and types in their lists (unreached; deleting them could orphan scenario rows and outputs);
    new libraries do not get them. The archived defaults/stockflow/legacy-ibis tables and the EVT provenance CSV are unchanged.
    Also retired 2026-11-13 (user: "Also retire the Succession Post Fire types"): the 28 `Succession Post Fire: <type>` transition
    types (no pathway used them; the disturbed classes return by Post-disturbance: Forest Return), their group `Succession: Post
    Fire Recovery` and the empty parent `Succession`, and their three definitions. Same rule for existing libraries.
58. **Management and mitigation actions for disturbed forest** - TO DO, added 2026-11-11 (user: "imposing management, such as
    replanting/restoration to mitigate the permanent loss of forest. In an alternative scenario, we could impose replanting on the
    forest - recently disturbed classes to push them back to their original types"). Kept apart from to-do 57, whose goal is the
    state-and-transition structure for post-disturbance return and conversion. Developed together with 57 (user): each structure
    choice in 57 is checked against the options here, so the actions can be added without rebuilding it. The actions are scenario
    choices for projections; the baseline keeps what happened historically.
  - **Salvage logging: moved to the disturbed classes (DONE 2026-11-13, user: "Yes, make that change, include the wetland
    twins").** `Forest Harvest: Salvage Logging` had pathways on the 28 upland live forest classes (same class, TSTMax 5, which
    counted from the type's own last transition, not from a fire), from before the disturbed classes. It is now on the 31 disturbed
    forest classes (wetland twins too), ages 0-5 (years since the disturbance), same class, no age reset, written by
    tools/make_post_disturbance.R; tests/unit-post-disturbance.R checks it. Carbon flows unchanged (CBM salvage: 72% of snag stems
    and 85% of any merchantable live wood to the forestry sector). Not driven by default (no source map, no target, no projection
    rule); a projection scenario sets its target or area. Live forest after insects or wind can't be salvaged: those don't move
    land into a disturbed class.
  - **Replanting, site preparation and salvage: BUILT 2026-11-13** (user: "Start with replanting, salvage and site prep on a dedicated
    page"; fuel treatments later, as their own step: they change the fire pathways). The baseline stays as observed: a scenario's
    area is management above the historical rate (the fitted natural return includes past planting); FACTS-based separation later.
    - Types (tools/make_management.R; Ids 1200-1205, group Management: Replanting): Replanting, after Burn Site Prep, after
      Mechanical Site Prep, each with a "(failed)" twin. From every disturbed forest class (31, wetland twins too); planted: to the
      parent forest type, age reset to 0; failed: same class and age (carries the site preparation carbon, can still return or
      convert). Survival splits a row's area between the two. Site preparation carbon on groups Site Preparation: Burn (cover burns
      as clearcut slash, roots die, half the litter and fine woody debris and 30% of branch snags burn) and Site Preparation:
      Mechanical (cover to litter and fine woody debris, roots die): provisional judgement values. Salvage: the existing type, on
      the disturbed classes (above). Stage 6 gives every one a zero target (no historical map).
    - The page (Projection > Management Actions, ui/ManagementActionsView.cs; user: parameters with their explanations beside
      them, an Add button that writes the choices as a grid row, the grid the record and still editable): years, area a year, where
      (a unit at any of the three strata levels the Build uses, from Build Results > Strata Summary, or any; with spatial tiles the
      tile level's unit is required, user: "these area targets ... MUST be specified at the same strata"), years since the
      disturbance (replanting 1-5, salvage 0-2), survival (0.8), priority (random, or far from live forest: the inverse of the
      seed-source curve, an adjacency multiplier on Management: Replanting, stage 10), site preparation. Each row in words.
    - Stage 9 (src/management.R): targets on the types' [Type] groups for every unit combination of one set of strata keys (tile
      level and the levels rows name), zeros included, so no blank-strata row overlaps a unit's; the age window as multipliers;
      Projection Results > Management Actions (as set up). Checks: one window per action, one priority, tile-level units with tiles.
    - Maps and summaries: the replanting family, its [Type] groups and salvage's [Type] group are main groups
      (defaults/stockflow/main-transition-groups.csv). Found on Lassen: a library's transition output filter is written when the
      library is made, so new groups were run but not reported; the 1.4 update adds them (summary, maps) to every scenario with a
      filter. Also the update adds the types, groups and the sheet's StratumId column.
    - Test (dev/management/lassen-management.R; Lassen Build 91, historical 93, baseline projection 99): replanting 300 ha a year
      2024-2050 (survival 0.8, pile and burn, far from live forest) and salvage 200 ha a year, setup 114, projection 116. Planted
      about 220-260 ha and failed 47-76 a year while recent burns are within 1-5 years (none 2027-2030 and 2035-2044 when no burn
      is; 3,472 ha in all); salvage only in the 0-2 years after the drawn 2031 and 2045 fires (1,188 ha). By 2050: forest 32,362
      against 30,116 ha, disturbed forest 817 against 2,513; natural return 2,383 against 3,069 ha and conversion 1,710 against
      2,194 (planted land no longer waits). Carbon by 2050: biomass +0.092 Tg C, dead matter -0.062 (salvage, burned slash),
      ecosystem +0.021, forestry sector +0.021. With transition maps on (a 3-year copy), every management [Type] group is mapped
      each year (2024 planting after burn site prep: 118 cells, 265 ha). tests/unit-management.R 24 checks.
    - Costs (user 2026-11-13: "start with costs per hectare and research defaults"): ST-Sim transition attributes, group Management
      Cost, types Planting, Site Preparation and Salvage Logging (USD). Each page row has a cost per unit area (salvage: net cost,
      negative = net revenue) and a site preparation cost, filled from defaults/management/costs.csv (2024 USD per hectare,
      provisional: planting 1,200 (600-3,000), pile and burn 1,800 (1,000-3,000), mechanical 2,200 (1,000-3,500), salvage -1,000
      (-5,000 to 1,500); sources and regional values in dev/management/cost-defaults-research.md). Stage 9 writes them on the
      types' [Type] groups from the row's start year in its strata (planting and site preparation on failed plantings too); rows
      overlapping in type, place and years must agree. Lassen (setup 120, projection 122): ST-Sim's total is area x value, exactly:
      planting 4.63 M USD, site preparation 6.94 M, salvage -1.05 M over 2024-2050.
    - Cost follow-ups (user 2026-11-13, done the same day; "Transition Attribute Values ... can also hold a distribution of cost
      values to give us a built in range"):
      - Regional defaults: costs.csv by Region (California, Pacific Northwest, Interior West, South, Northeast; All = national, the
        fallback), each ecodivision's region in cost-regions.csv; several regions in a study area: values per ecodivision.
      - Ranges: each value a Beta (mean = central, min/max = low/high, SD = range / 6, capped so the Beta exists), Value Sampling
        Frequency "Iteration Only": one cost scenario per iteration. A row's own value scales the default range; Cost Range Fixed
        writes the value alone. (ST-Sim's Value Min/Max must be >= 0: why salvage is a cost and a revenue, not a signed net.)
      - Salvage: Management Cost: Salvage Logging (logging and haul) and Management Revenue: Salvage Timber, the revenue by the
        disturbed class's age (AgeMin = AgeMax = a, value x 0.75^a; loss 0.25 a year, Prestemon et al. 2006).
      - Budget mode: a row's Budget (USD a year) instead of its Amount; stage 9 sets the area = budget / central cost per area.
        Chosen over ST-Sim transition attribute targets, which would break the planted/failed survival split (the two types are
        simulated as separate groups, in random order). What a run spends varies around the budget with the sampled costs.
      - Compare Runs: Compare Cost Summary (src/compare-figures.R compare_cost): costs, revenue, net cost (iteration mean, lowest,
        highest), extra net cost over the baseline, carbon gained (total ecosystem carbon at the end), USD per Mg C (range from the
        iterations' net cost) and per Mg CO2e; no ratio without a gain.
      - Lassen (setup 128, projection 130: 2024-2036, 3 iterations; replanting 300 ha a year, a 500,000 USD a year replanting
        budget from 2030 = 113.6 ha a year at 4,400 USD/ha, salvage 200 ha a year; California defaults): USD per hectare by
        iteration, planting 1,585 / 1,123 / 1,315 (range 800-2,500), site preparation 2,963 / 2,627 / 3,334 (1,850-4,000), logging
        4,507 / 6,834 / 4,747 (4,000-8,750), salvage revenue 4,389 / 3,547 / 5,521 (by age, 2,250-8,000). No warnings. Net cost
        12.1 M USD (7.8-14.8 M). Carbon against baseline 99: -0.20 Tg C, no ratio - but 99 is one iteration with other fire draws,
        so the difference is mostly fire noise: a fair test needs a baseline with the same iterations.
      - Two carbon bases (user 2026-11-13: "against ecosystem carbon and ecosystem + HWP"), done after merging main (to-do 59):
        CarbonGainWithProducts = the ecosystem gain + the run's carbon stored in harvested wood products at its end minus the
        baseline's (stage 18 on both runs; NA without), with its USD per Mg C (range) and per Mg CO2e. Salvage moves dead wood to
        products, which ecosystem carbon alone counts as lost. Lassen plumbing test (dev/management/lassen-cost-hwp.R; stage 18 on
        99 and 130, 20 draws, results 134 and 136 - the stage's first runs inside SyncroSim: Lassen and Puget lacked stage 18,
        added with tools/sync-library.R --schema-only and a fresh tools/new-library.R library as the reference): products stored in
        2036 0.0125 Tg C against the baseline's ~0.006, gain -198,057 Mg C ecosystem, -191,661 with products; no ratio (the
        mismatched baseline).
      - Matched baseline (user 2026-11-13: "Yes, run it"; dev/management/lassen-matched-baseline.R): the same Projection Setup
        without Management Actions (setup 138; stage 9's seeded draws give the same historical-year schedule as setup 128, all
        324 rows), projection 140 (2024-2036, 3 iterations, multiprocessing on), stage 18 result 142. Burned 2024-2036 by iteration
        within 1-8% of run 130's. Management run 130 against it, at 2036: live biomass +0.186 Tg C, dead wood, litter and soil
        -0.152 (salvage and burned slash), total ecosystem +0.037 (37,118 Mg C), wood products stored +0.0064, so +43,514 Mg C with
        products. Net cost 12.1 M USD (7.8-14.8 M by iteration): 325 USD per Mg C (210-398), 89 per Mg CO2e, on ecosystem carbon;
        277 USD per Mg C (179-339), 76 per Mg CO2e, with wood products. The combined actions; the ratio for replanting alone, and
        for salvage alone, needs runs with one action each (later).
    - Forest management (improved forest management; user 2026-11-13: "change the target areas for clearcut and selection (increase
      selection and reduce clearcut), increase the minimum harvest age"; "Protecting old forest should just use the MaxAge field";
      Selection 20% and 85% "can either be removed or completely re-engineered"): Projection > Forest Management
      (ui/ForestManagementView.cs, src/forest-management.R, stage 9).
      - Found: harvest is an ordinary Target group (Forest Clearcut and Forest Selection [Type], per county, the drawn year's mapped
        area); minimum harvest ages are the Build's (stage 6, pathway AgeMin); clearcut resets the stand to age 0 in its own type
        (no regrowth delay), removes 0.97 of the merchantable wood and burns 96% of the slash; selection removes 0.5 and leaves it.
      - A row (years, a unit at any of the three strata levels): clearcut moved to selection (by area, or by volume: 0.97 / 0.5 =
        1.94 selection hectares a clearcut hectare), selection moved to light selection (Selection 20%: 0.2 removed; 2.5 by
        volume), a harvest scale, and min and max age per harvest type (multipliers, 0 outside: they narrow the Build's ages; a
        maximum protects older forest). A row by a level the targets are not keyed on moves the three types' targets to the
        combined keys, each split by its group's historical harvest in the reference years (forest land where none was mapped).
        Two rows on one place and year stop the setup.
      - Light selection: Selection 20%'s flows were already a sound 20% removal; it gets Forest Selection's minimum ages (stage 6;
        projections on older Builds read them from the Build's Minimum Harvest Ages output) and Forest Selection's allowed-cells map
        (GAP exclusion). Selection 85% (merchantable wood to dead wood: an error) removed from the defaults.
      - Timber revenue on every projection: Management Revenue: Harvest Timber per ecodivision, forest type and 10-year age band =
        merchantable volume x removal share x regional stumpage (defaults/forest-management/stumpage.csv, 2024 USD/m3, provisional:
        dev/forest-management/stumpage-research.md; softwood/hardwood by forest-type-wood.csv; California softwood 40, the interior
        mixed conifer value, not the redwood-inflated statewide 50). Compare Cost Summary pairs iterations with a baseline that
        has the same ones (a matched setup shares each iteration's draws).
      - Found on the way: stage 9 sees only the sheets its transformer declares (the volume curves were invisible); declaring the
        Build's stsim_Transition as an input copied it into the setup result, and the projection then found no initial conditions
        (use lucasCore sheets such as OutputHarvestAge instead).
      - Lassen plumbing test (dev/forest-management/lassen-forest-management.R; Lassen is GAP 1-2, so the test lifts the harvest's
        GAP exclusion, and scales the drawn harvest x50: clearcut 1.7 -> 85 ha a year, selection 6.2 -> 310): baseline setup 160,
        projection 162; IFM (x50, half the clearcut to selection by volume, 30% of selection to light, clearcut 80-200, selection
        up to 200) setup 165, projection 167; 2024-2036, 3 iterations. Clearcut realized 443 / 360 / 878 ha against the baseline's
        882 / 808 / 1,744; light selection 5,324 / 1,800 / 5,877. Timber revenue 45.6 M USD (baseline mean) against 38.0 M: 7.66 M
        given up for 44,090 Mg C: 174 USD per Mg C (-1 to 452, iterations paired), 221 with wood products (34,602 Mg C: less harvest,
        less stored in products). Plumbing only: an artificial harvest in a national park. Clearcut revenue reaches 73,921 USD/ha
        in the oldest bands (~1,900 m3/ha): check the volume curves' top end.
      - Open: slash retention on clearcuts; more wood to long-lived products (stage 18's end-use mix); revenue a row can override.
    - Fuel treatments (user 2026-11-13: "Next is Fuel Treatments"; "Lets go with the severity shift"): Projection > Fuel Treatments
      (ui/FuelTreatmentsView.cs, src/fuel-treatments.R, stage 9; research in dev/fuel-treatments/research.md).
      - Three transition types on upland forest, back to the same class without an age reset (tools/make_fuel_treatments.R, Ids
        1300-1302, group Fuel Treatment): Mechanical Thinning (25% of live biomass cut, 80% of the merchantable cut to the forestry
        sector, slash piled and 90% burned), Prescribed Burn (litter 80%, fine woody debris 60%, coarse 30%, snag branches 30%, snag
        stems 5% consumed, crown scorch 2% of foliage, 5% of live trees killed) and Thin and Burn (both). Flows from
        tools/make_fuel_treatment_flows.R; CO2/CO/CH4 0.9/0.09/0.01 of what burns.
      - Effect, the severity shift: a wildfire in a treated cell has its high and medium severity multiplied down by years since
        treatment (defaults/fuel-treatments/effects.csv: thin and burn x0.28 high, x0.60 medium in years 0-5, fading by 20; burn
        alone x0.38 / x0.65; thin alone x0.65 / x0.85), and low severity up by 1 + ((1 - mH) sH + (1 - mM) sM) / sL, the shares
        from the historical severity maps, so the burned area stays the same. ST-Sim time-since-transition multipliers (one TST
        group per treatment; the first matching row wins, so the retreatment block comes first).
      - A row: treatment, area a year, years, a unit, stand ages (minimum 20 by default), retreatment interval (thin 20, burn 10,
        thin and burn 20 years: multiplier 0 on the treatment until then), priority (random, or where wildfire burned more often:
        a map of the historical burned share, FuelTreatment-Priority.tif), cost per hectare by region (Beta range per iteration,
        Management Cost: Fuel Treatment; thin and burn 0.9 x the two). Thinning's wood earns timber revenue (removal 0.2).
      - Lassen plumbing test (dev/fuel-treatments/lassen-fuel-treatments.R; Build 170, historical 172; setups 180 and 183,
        projections 185 and 186 run at once, 2024-2050, 3 iterations): thin and burn 400 ha a year where fire burned more often and
        prescribed burn 600 at random. High-severity fire 5,654 -> 4,755 ha (-16%), medium -7%, low +5%, burned area the same.
        Conversion over the run unchanged (2,124 against 2,140 ha); in 2050, 22% less forest in the disturbed classes (2,817 ->
        2,191 ha) and 690 ha more live forest: the avoided conversion (user 2026-11-13: "it is possible we could see the added
        benefit of treatment beyond just severity reduction") is still waiting in the disturbed state at 27 years. Ecosystem
        carbon 0.20 Tg C lower in 2050 (0.16 with wood products): at this rate (~27,000 ha on ~30,000 ha of forest) the thinning
        and burning outweigh the fire avoided. Cost 37.2 M USD, timber revenue 25.6 M; no USD per Mg C (carbon lost).
      - Found on the way: libraries made before the treatment groups lacked them in the transition output filter, so the area
        treated was not reported (Lassen and Puget patched; LucasCoreUpdates.cs adds them on a library update).
      - Open: regional effects (the South's short-lived burn effect; no effect in wet forest); a longer run and lower rates for the
        carbon sign; FACTS hazardous fuels records for the baseline.
    - Open: planting a different type (assisted migration); FACTS records for the baseline; a full Build on Puget
      (tiled by county, 20-30 jobs; user 2026-11-13) to try the tile rule in a run.
  - **Replanting and restoration:** a management transition from a post-disturbance class back to a forest type.
    - Window: within a few years of the disturbance (time since transition, for example 1-5 years), before shrubs take the site.
    - Age: reset to a seedling age on planting (natural return keeps age = years since the disturbance, to-do 57).
    - Survival: a share of plantings fails and stays in the post-disturbance state, where it can still return or convert. Failure
      can follow climatic water deficit, as natural return does.
    - Type: the original type by default. A scenario can plant a different, more drought-tolerant type (assisted migration) along
      the pathways 57 provides for type change.
    - Amount: an area per year (ST-Sim transition targets), since planting is limited by budget and nursery stock.
    - Where first: by ownership (secondary strata: federal lands, PAD-US); far from a live seed source, the reverse of natural
      return's adjacency, since those cells won't come back on their own; reburned cells, which mostly convert.
  - **Salvage logging:** removing snags after the disturbance, to harvested wood products. It changes the dead wood the cell carries
    into the post-disturbance state and often comes before replanting, especially on private land. A share of disturbed area in a
    short window, by ownership.
  - **Site preparation:** burning or removing slash and shrubs before planting, with its carbon flows (emissions, and dead wood and
    shrub carbon removed).
  - **Fuel treatments and prescribed fire:** lower the high-severity share of later fires, so less forest enters the post-disturbance
    state at all. In ST-Sim, a treatment transition, and a multiplier on fire severity (or on high-severity fire) for treated cells
    for some years after. The model's Forest Selection harvest may cover mechanical thinning in part; to check.
  - **Outputs:** the carbon difference from a baseline without the action; area treated, planted and salvaged; forest conversion
    avoided, per hectare treated or planted.
  - **Calibration: don't count historical planting twice.** The return rates fitted in 57 (from NLCD) already include whatever
    replanting followed past fires. Separate planted from natural return where records allow: the Forest Service's FACTS
    reforestation records, and private-land records where they exist. Then fit the baseline as natural return plus the historical
    planting rate, and let a scenario change the rate. Where no records exist, the baseline stays as observed and a scenario counts
    only planting above the historical rate. The same holds for salvage and fuel treatments (FACTS hazardous fuels records; LANDFIRE
    disturbance records treatments too).
  - **What 57 must allow, so these can be added later:** post-disturbance classes that know their original type; a time-since-
    disturbance clock that management can read; an age that can be reset on planting; ownership in the strata; an adjacency
    attribute that a scenario can use in reverse; and the dead wood pools of the waiting years, so salvage and site preparation can
    take from them.
62. **Study areas from managed units: National Parks, then wildlife refuges and DoD installations** (59 on its branch, renumbered at the 2026-11-13 merge: 59 is wood products) - National Parks BUILT
    2026-11-12, not yet tested in a Build (user: "I'd like the ability to select National Parks to be the study area. Eventually I'll
    expand this to include things like DoD installations, Wildlife Refuges, etc... the plumbing to select a single national Park
    would be useful right away for testing").
  - Source (user's choice 2026-11-12: PAD-US over the National Atlas map, which has names and GNIS ids but is 1:1,000,000, 2014,
    splits wilderness from its park, and no Data Download fetches it any more): PAD-US 4.0, the same 49 state geodatabases as
    PadusFile. The federal_fee layer Federal Lands reads keeps only the owner, so a new Data Download dataset `PadusUnitsFile`
    writes `study-area/padus-units/padus4-units.gpkg` (padus4.gpkg is left as libraries read it; the home is write-once), layer
    `nps_units`: Unit_Nm of NPS fee land (Mang_Name NPS, Category Fee). The state files hold no Proclamation boundaries, so a park
    is the land NPS owns (inholdings are holes), as Federal Lands' fee rule; wilderness Designation polygons overlap and are left out.
  - Preset `National Parks` (Number 10, prefix NPS: "NPS: Yosemite National Park"), ValueField Unit_Nm through
    `defaults/strata/nps-units-crosswalk.csv`; other land 9999 "Not National Park Service land" (Fill Default). Every NPS unit
    is listed (parks, monuments, recreation areas, seashores, historic sites). `tools/make_nps_units.R` writes the list and crosswalk
    with stable ids (a rerun keeps them, new units take the next; names differing only in accents share one).
  - Existing libraries: `tools/new-library.R <library> --rebuild-strata` adds the source and its units (it stops if a custom source
    already uses Number 10; custom sources now take 11-20).
  - Next: refuges (Mang_Name FWS, Des_Tp NWR) and DoD installations (Mang_Type / Mang_Name DOD) as more layers of the same file:
    that changes the file, so the dataset takes a new version and the Data Download adds it as a new edition.
  - **Seven more sources, BUILT 2026-11-13** (user: "Build your four plus tribal lands and BLM, separate numbers", "add MSAs as 17,
    skip CSAs"). Numbers 11-17; custom sources now take 18-20 (Number x 1e8 must fit a 32-bit id, so 20 is the most).
    | # | Preset (prefix) | Source | Units |
    | --- | --- | --- | --- |
    | 11 | FWS Refuges (FWS) | PAD-US layer fws_units: FWS fee land, Des_Tp NWR, NCA, RMA (refuges, conservation areas such as Grasslands WMA, waterfowl production areas, wetland districts); not hatcheries or Farm Service Agency interests | 717 |
    | 12 | DoD Installations (DoD) | PAD-US layer dod_units: Mang_Name DOD, Des_Tp MIL. PAD-US keeps installations as Proclamation boundaries (DoD fee land is not mapped by installation; the first query, Category <> Proclamation, found only 9 easements), so land inside a boundary counts whoever owns it | 677 |
    | 13 | National Forests (NF) | PAD-US layer usfs_units: Forest Service fee land, Des_Tp NF or NG, names ending National Forest or National Grassland (not purchase units, experimental areas or "<forest> Other" parcels); inholdings are not part of a forest | 172 |
    | 14 | Wilderness (Wilderness) | PAD-US layer wilderness: Des_Tp WA, any manager; overlaps the other sources, hence its own | 802 |
    | 15 | Tribal Lands (Tribal) | TIGER/Line 2022 AIANNH (new dataset TribalLandsFile, study-area/tribal-lands/tribal-lands.gpkg): federally recognized reservations and off-reservation trust land (CLASSFP D2, D3, D5, D8) and state reservations (D4), dissolved by AIANNHCE (the id); not the statistical areas (OTSAs, SDTSAs, ANVSAs, Hawaiian Home Lands) | 334 |
    | 16 | BLM National Conservation Lands (BLM) | PAD-US layer blm_ncl: BLM designations NM, NCA, WSA (not ACECs, not river corridors) | 538 |
    | 17 | Metropolitan Areas (Metro) | The Counties polygons through msa-crosswalk.csv (OMB July 2023 delineation, metro CBSAs, county GEOID to CBSA code), dissolved; no new download. Connecticut: old counties to their main planning region's metro (Litchfield, Windham: none; Waterbury-Shelton has no county and is not listed) | 382 |
    - Lists and crosswalks: `tools/make_unit_lists.R` (stable ids, as tools/make_nps_units.R); the shipped universal lists gain 3,629
      units (10,235 in all), every existing row unchanged; presets, Studio template rows, endpoints, data sources, citations, strata
      README, user guide 3.2.
    - PAD-US units edition 2 (padus4-units.gpkg with the six layers, editions/PAD-US-4-0-state-geodatabases-...-1f466c30). Found:
      stage lookups of strata polygons ignored editions, so every library would have read edition 1 (nps_units only). Now a preset
      whose layer is not in the edition picked reads the newest edition that has it (src/shared.R strata_edition_with_layer; the
      shipped lists follow the package). `tools/new-data-download.R --new-editions` added.
    - Tests: each source read from the home with one known unit's area (Sacramento NWR 44 km2 once its two duplicate polygons are
      merged, Fort Irwin 3,057, Lassen NF 4,323, Caribou Wilderness 84, Navajo Nation Reservation 63,333, Grand Staircase-Escalante
      7,616, Vallejo metro 2,347 with water). Stage 1 in a fresh library (dev/libs/strata-units-test.ssim): Metro: Vallejo, CA with
      Metropolitan Areas and Tribal Lands as strata, 96,010 cells (2,160 km2, Solano County's land); Wilderness: Lassen Volcanic
      Wilderness Area with National Forests and Wilderness as strata, 14,149 cells (318 km2; the wilderness is about 320). All checks
      pass. unit-strata-home, home-editions, page-feeds, metadata-record, release pass.
    - Not done: a full Build on one of these; National Forests use fee land (PAD-US also has the forests' proclamation boundaries,
      should the whole boundary be wanted later).
60. **Transitions a study area does not have: projections should not stop** - DONE 2026-11-13, added 2026-11-12 (user: "This raises a good
    issue about what happens when there are no transitions of a certain type within a study area"). Found on the Lassen Volcanic NP
    test library (to-do 57 step 8): the Projection Setup stopped in stage 10, "Urbanization: only 4 events in the fitting region -
    choose a larger Suitability Fitting Region". Today:
    - stage 6: a group with no events has Off maps; fine.
    - stage 9: a Target group gets zero targets in every unit and year; fine.
    - stage 10: a Fitted surface with fewer than 30 events stops the whole setup. A larger fitting region needs every fitting
      layer (NLCD, roads, elevation, WUI, NCCPI, ...) downloaded for that region too, so for a small study area (a park, a refuge,
      a county with no agriculture) the only way through is to set the surface to None by hand.
    Proposed: a surface whose groups have zero historical area in the study area in every reference year is skipped (nothing to
    place: say so); one with some area but too few events falls back to None (random within its strata) with the event count in the
    log and in the suitability summary, unless the user set a fitting region. Check the same for Adjacency surfaces, the patch size
    step (no events) and stage 9's fire (a pyrome with no burnable area). Test on Lassen (no urbanization or agriculture).
  - **DONE 2026-11-13** (user: "60 needs to be addressed immediately as this can block a user from running the model. If too few
    transitions occur during historical, the covariate approach should be dropped and use only adjacency"). Stage 10: a Fitted
    surface with fewer than 30 events in its fitting region (MIN_FIT_EVENTS) no longer stops. Its covariates are dropped and every
    allowed cell weighs 1; for developed or agriculture events the adjacency multiplier is read from the model grid's annual maps as
    Method Adjacency does (src/adjacency-curve.R) and set on every group of the surface; other events (harvest, reforestation, ag
    contraction) are random within their strata; with no events on the model grid either, no adjacency curve. Logged, and a
    "Covariates dropped: too few events to fit" row in the suitability summary with the event count. Adjacency-method surfaces with
    no events already passed (flat multiplier); the patch size step skips a group with no patches. Stage 9, fire method 2: a study
    area with no burnable land no longer stops on "burn probability 0 or missing" (a full run with no burnable land not tested).
    Test, Lassen (Build 72, historical 74), the default allocation (every surface Fitted; it stopped before on Urbanization):
    setup result 86 completes. Urbanization and Open Space adjacency only (curves from 14 and 17 model-grid events), Ag Expansion
    flat (no events), Ag Contraction, Clearcut and Selection random within strata, Reforestation fitted (92 events, AUC 0.545); a
    5-year projection from it runs (result 88). Not done: a user-set fitting region still falls back the same way.
61. **Burn severity in non-forest classes: does MTBS capture high-severity shrubland fire?** - TO DO, added 2026-11-12 (user: "look at
    burn severity distribution across the non-forest classes. I am a little unclear if there is much high severity shrubland fire
    captured in MTBS Burn Severity"). It matters because only high severity moves a shrub cell into its disturbed class (to-do 57:
    Disturbed: Sage, Native and Invaded Sage Steppe, Non-sage, Chaparral; window, return, conversion to grass); low and medium
    severity leave the shrub class and its age as they were. MTBS classes come from dNBR thresholds set per fire, and shrub and grass
    fires (little pre-fire biomass, so a small dNBR) may rarely reach "high" even when the shrubs are consumed and must regrow from
    seed or resprouts. To do:
    - measure the MTBS severity mix (1 unburned to low, 2 low, 3 moderate, 4 high) by NLCD class at the fire year (41-43, 52, 71)
      and by RCMAP or LANDFIRE type (sage, chaparral, desert scrub), CONUS sample and P26, and against LANDFIRE disturbance
      severity;
    - compare with what NLCD and RCMAP show after the fire (shrub cover lost, grass gain): does moderate severity in shrubland
      also mean the shrubs are gone?
    - options: treat moderate and high as stand-replacing for shrub classes; a per-class severity map (stage 6 and the projection's
      severity shares); RdNBR or RAVG instead of the MTBS classes.
65. **Avoided conversion and projected development** - TO DO, top priority after the Hart Mountain rangeland restoration test
    (user 2026-11-14: "save this as a top to-do and pick it up after the Hart Mountain testing is complete"). Mitigation measure 2,
    rescoped by the user 2026-11-14: "simply providing a lever that reduces/scales down urbanization and ag expansion relative to a
    no-management scenario. The assumption would be that there is no leakage"; then "the option of focusing development (whether
    scaled or not) on lower carbon cells", "lower fire risk", and WUI data "to either focus development or prohibit development".
    Plan, parameters and open decisions: the Avoided conversion doc (claude.ai artifact Ta6iPXbgp1kHYZCSxC8fRN); notes in
    `dev/avoided-conversion/research.md` (protection literature, background) and `dev/avoided-conversion/ssp-projections.md` (ICLUS,
    RPA 2020, county population projections).
    - **Levers:** scale (a multiplier on the Urbanization and Ag Expansion targets by years and place, no leakage) and steering (a
      weight on the allocation surface: lower carbon, lower fire risk (FSim burn probability), WUI prohibit or focus (SILVIS WUI), a
      user map). Steering moves development within a county; scale changes the total.
    - **How much and where (user's four options):** 1 LUCAS only (historical NLCD rates, all or a subset of the reference years;
      LUCAS allocation); 2 LUCAS + RPA or ICLUS maps as steering; 3 RPA or ICLUS alone, their maps driving quantity and placement
      (for an SSP ICLUS lacks, the user picks the ICLUS series); 4 county population projections scaling the urbanization rates,
      with LUCAS allocation or RPA/ICLUS steering (not for agriculture). Option 4 is what earlier LUCAS work in California did.
    - **Reporting:** conversion avoided and carbon kept against a matched baseline; new development by carbon band, burn
      probability and WUI class.
    - **Open:** build order (4, then 2, then 3 proposed); population source (Hauer 2019, Wear and Prestemon 2019, state
      projections); option 4's form; ag expansion on historical rates or RPA; check the urbanization and ag expansion soil carbon
      flows against the literature (IPCC 20% on developed land; grassland to crop -36%); test library Placer.
64. **Guards against Build failures when a transition never occurs in the study area** - TO DO, added 2026-11-14 (user: "guards
    against build failures due to conversions not occurring in the study area"). The Build counterpart of to-do 60 (which made
    projections tolerate missing transitions). Found 2026-11-14: the Hart Mountain Build (no forest harvest anywhere) failed in stage 6
    after 27 minutes, "object 'Timestep' not found": the harvest minimum-age check built its table from zero harvest layers, an empty
    table with no columns (fixed for that table: `age_blocked` gets its columns when there is no harvest). To do:
    - sweep the Build stages (1-8, 12) for the same pattern: `rbindlist` or `lapply` over zero rows, then a `by =`, `merge` or column
      access, and give each its columns or skip the step with a note in the run log; for each family a small area may lack:
      harvest (clearcut, selection), urbanization and intensification, ag expansion, contraction and change, fire (and each
      severity), reforestation, post-disturbance return and conversion, wetland change;
    - a test: a synthetic study area with none of them (or the stages' table builders called on empty inputs), so the case stays
      covered; and Build Figures (stage 12) drawing "none in this study area" instead of failing;
    - fail early, before the long stages, only on what a Build truly needs (land cover, strata), not on an absent transition.
63. **The Build turns on tabular States and Transitions output by default (without ages)** - TO DO, added 2026-11-14 (user: "The
    model Build should by default turn on tabular output for States and Transitions (without ages). Right now, this step has to be
    done manually"). Today only the scripts set it (`tools/new-historical.R`, `tools/new-projection.R`: Output Options > Tabular >
    States and Transitions every year, ages unchecked, since 2026-11-14; transition attributes too in projections). A historical
    run or projection made in Studio inherits the Build's stsim_OutputOptions, which has none, so the user ticks them by hand. To do:
    - the Build (stage 1 or 4, or `tools/new-library.R` on the Build template) writes stsim_OutputOptions with SummaryOutputSC and
      SummaryOutputTR on, timestep 1, SummaryOutputSCAges and SummaryOutputTRAges off (and SummaryOutputTA on, ages off, for the
      management costs), when the sheet is empty, so a user's own choice is kept;
    - check that historical and projection scenarios made in Studio from the Build inherit it, and the Projection Setup (stage 9)
      does not clear it.
    - First findings 2026-11-12 (to-do 57 step 7 shrub fit, 907 sampled western fires 1986-2010): only 396 had any high-severity
      pixel that lost shrub cover, 550 had moderate; and moderate-severity pixels lose and regain RCMAP shrub cover as high-severity
      ones do (same return curves and windows within 2 years). DONE 2026-11-12 (user: "Yes, do it here"): moderate (Medium) and
      high severity are both stand-replacing for the five shrub classes, in historical runs and projections alike (the fire pathways,
      `tools/make_post_disturbance.R`: the parent goes to its disturbed class with age reset, and in the disturbed class a moderate
      or high reburn converts ReburnConversion); forest stays high only. Run Figures' "Last stand-replacing fire" counts moderate fire
      for shrub cells. The shrub fire carbon follows (user: "Yes, align them"): the Medium rows of the five classes in
      `defaults/stockflow/nonforest-fire.csv` now equal their High rows (chaparral's High from chaparral-age.csv), and
      `tools/make_nonforest_fire.R` regenerated the medium-severity event rows (event-pathways.csv). Low severity is unchanged.
      Not yet run in a Build.
    - Chaparral type conversion: the fitted ReburnConversion (0.10) says most chaparral that reburns before recovering still comes
      back; check on RCMAP annual herbaceous (and herbaceous) cover, a second national download (Data Source RcmapCoverFolder
      components), and against the short-interval reburn literature. Detail (user, 2026-11-13: "Lets keep this detail in the to-do
      list"):
      - Where 0.10 comes from (tools/fit_shrub_post_disturbance.R, 2026-11-12): chaparral pixels (Mediterranean ecodivisions, NLCD
        shrub the year before) burned at MTBS moderate or high severity 1986-2010, 792,096 pixels in 99 fires. "Back" = RCMAP shrub
        cover at half its pre-fire level or more two years running. A reburn = a moderate or high reburn before the pixel was back:
        10,653 pixels, so mostly short-interval reburns (chaparral is usually back in a few years). For them, the Kaplan-Meier share
        back within 15 years of the reburn was about 90%; ReburnConversion = 1 - that = 0.10.
      - What it does: fire moves chaparral to Disturbed: Chaparral (age 0); from age 2, 25.2% a year returns (about 87% back by age
        8); at the window's end (age 8) the rest, about 13% of a burn not reburned, converts to Grassland: Annual. A moderate or high
        reburn while disturbed converts 10% of those cells to Grassland: Annual outright; the other 90% restart at age 0 (a new
        chance to return, or to reach the window's end).
      - Why provisional: low against the literature (repeated fires within about 5-10 years convert chaparral, especially obligate
        seeders, to nonnative annual grass in southern California); repeat fires within a few years are uncommon in a 1986-2010
        sample and the fit cannot tell short from very short intervals; "back" at half the pre-fire shrub cover is lenient; RCMAP
        shrub cover does not tell resprouting chaparral from subshrubs or a shift to coastal sage; nothing requires grass not to
        rise, so a pixel can count as back while converting.
      - The check: RCMAP annual herbaceous cover on the same reburned pixels (does annual grass take over where shrub cover
        returns?), with the published short-interval reburn studies; possibly a conversion that depends on the interval between
        fires.

59. **Harvested wood products: what happens to the carbon in Forestry Sector** - PLANNED 2026-11-11, not started (user: "a
    lucasCore stage to calculate the fate of harvested wood products from either historical and/or projection scenarios ... a
    complete wood products model based on how the USFS models wood products. This does not need to be spatial at all").
    Today harvest moves merchantable carbon to the Forestry Sector stock (`LULC: Harvest Live`: clearcut 0.97, selection 0.5 and
    0.2, salvage 0.85 live and 0.72 of snag stems (`LULC: Harvest DOM`), urbanization and ag expansion 0.8), and nothing flows out of it.
    NBP counts the whole removal as a loss, and the run does not report what stays stored in products or landfills.
  - **Method:** the US Greenhouse Gas Inventory's harvested wood products model (IPCC production approach), as the USFS models it:
    Smith, Heath, Skog and Birdsey 2006 (GTR NE-343) for roundwood to primary products by region and softwood/hardwood; Skog 2008
    (Forest Products Journal 58(6)) for end uses, half-lives in use and discard disposition; and the USFS HWP C calculator
    (Stockmann et al. 2012; Loeffler et al. 2014 for the other National Forest System regions) for the regional set-up, the 1906
    start and the Monte Carlo. Every number goes in `defaults/wood-products/*.csv` with its source table. None is entered from memory.
  - **Chain, by year and vintage:**
    1. Removals from the run: `stsim_OutputFlow` to Forestry Sector by year, iteration, transition type, from-state class (forest
       type, and from it softwood or hardwood) and ecodivision (mapped to the USFS / RPA region the ratios use).
    2. Removals to roundwood: harvest and salvage are growing-stock removals. Land-clearing wood (urbanization, ag expansion)
       follows TPO "other removals" (user 2026-11-11): a regional utilized share becomes roundwood, and the rest is emitted in the year
       it is cleared (burned or left to decay). Bark goes with the mill residue. Check whether the Merchantable stock includes bark.
    3. Roundwood to primary products (lumber, plywood/veneer, OSB and other panels, paper and paperboard, other industrial
       products, fuelwood), plus mill residue used for fuel, used for products, or not used.
    4. Primary products to end uses (new residential, residential repair and upkeep, nonresidential construction, manufacturing,
       shipping and pallets, furniture, paper, other). Each has a first-order decay with its half-life in use. The shares
       change by year where the tables do.
    5. Discards: burned with energy capture, burned without it, recycled (paper goes back into use), composted, to landfills or to
       dumps. The shares change by year (dumps give way to landfills after about 1970).
    6. Solid waste disposal sites: in landfills, only a share of wood and of paper decays, each with its own half-life. The rest is
       stored permanently. Everything in dumps decays. Landfill decay is split into CO2 and CH4 (and the CH4 captured or flared), so
       a CO2e line can count the methane.
    Pools tracked: products in use, landfills, dumps. Flows out: emitted with energy capture, without it, and CH4 from landfills.
    Exponential decay has no memory, so a pool per end use (not per vintage) is exact while the half-life stays fixed. Use vintages
    only where a parameter changes by year of production.
  - **Before the run (user 2026-11-11: spin-up from history):** the stage starts in 1906 on a regional harvest history (USFS
    records, as the HWP C calculator uses). The history is scaled to the study area by the ratio of the run's first-decade removals to
    the region's removals in those years. Pre-1985 wood then keeps decaying through the run. A user table (harvest by year, Mg C or
    a volume unit) can replace the default history. The scaling factor and the starting pools are reported.
  - **History and projections:** a stand-alone projection is joined to its historical run (`find_history`, `join_runs`, as in
    stages 13 and 14), and the model runs over the whole series from 1906. Two projections from the same history then share the same
    historical part exactly (a check). A projection scenario can change the shares after its start year (for example more
    long-lived products or mass timber, more energy recovery) on an options page. Without changes it keeps the last historical year's
    shares.
  - **Uncertainty (user 2026-11-11: parameter draws):** N draws (default 100) per run iteration of the product ratios, half-lives
    and landfill parameters, within the published ranges (the HWP C calculator's distributions where it has them). Results give the
    mean and a 90% interval. The run's own iterations are kept apart, so land change and parameter uncertainty can each be
    reported.
  - **Stage and pages:** 18 - Wood Products, in its own scenario on the run's Build result, like Run Figures. Inputs: the run (blank
    = the newest result), draws, the land-clearing option, a harvest history override, and projection share changes. Outputs: pools
    by year (in use by end use, landfill, dump; mean and interval), flows by year (to each fate, CH4, CO2e), the starting pools
    and the scaling factor, and figures (pools stacked over time; where each year's harvest goes; a stored-carbon versus
    emitted fan). Not spatial.
  - **Run and Compare figures (user 2026-11-11: both):** when a Wood Products result exists for the run, Run Figures and Compare
    Runs add the products and landfill stocks to the carbon stock chart, and an NBP that counts the change in the products and
    landfill pools (production approach) beside today's NBP. Compare Runs adds a column for each to its carbon table. How they find
    the result (a lookup by RunScenarioId, or a named Wood Products result) is to settle.
  - **Step 1, parameter tables - mostly done 2026-11-11:** `tools/make_wood_products.R` writes `defaults/wood-products` (README.md
    there: files, sources, lucasCore's choices, checks) from the Smith 2006 CD tables and the HWP-C vR repository (its regional
    templates and the California, Oregon and Washington inputs). Smith's Table 8 decay curves are rebuilt from Tables D2 and D3 to
    within 0.001. Choices made: Smith's Table D6 for primary products, with its West hardwood row for RMN, RMS, PWE and PSW (the HWP-C
    templates fill those gaps with 100% fuel); sawtimber end uses for lumber and plywood whatever the log; Table D3 half-lives (HWP-C),
    not Skog 2008's calibrated ones. Smith's region map read from its page image: Ohio is in the Northeast.
    Harvest history (2026-11-11): `regional-harvest-history.csv`, each Smith region 1906-1997 (Pacific 1906-2019), from three tables
    transcribed from page images into `defaults/wood-products/transcribed/` and checked against their printed totals: Haynes 2003
    Tables 16 and 13 (removals by RPA region, subregion shares, 1952-97) and the 1956 Historical Forestry Statistics Table 15 (lumber
    by Census region 1905-54, spliced at 1952); CA, OR and WA from their state inventories. Only the shape is used (the stage scales it
    to the run's first decade). Extended 2026-11-12 to 2016 outside the Pacific by FRUS 2017 (Oswalt et al. 2019) Table 35's change
    by subregion from 1996. Land clearing: no source gives the utilized share (Table 40 has only the unutilized "other removals"), so
    lucasCore assumes 0.5, drawn over 0 to 1, in settings.csv - a placeholder for the user to confirm or replace.
  - **Step 2, the model - done 2026-11-12:** `src/wood-products.R` (wp_params, wp_split, wp_spinup, wp_draws, wp_model, wp_summary,
    wp_pulse). Tests: `tests/unit-wood-products.R` (28 checks: by hand, conservation, spin-up, draws, Smith Tables 6 and 8) and
    `tests/unit-wood-products-national.R` (the regional histories scaled to the US roundwood harvest, FRUS Table 41: stock 0.93-0.98
    of the Inventory's in 1990, 2005, 2016; stock change 0.97-1.03; SWDS 1.00-1.02; products in use 0.87-0.90, the Inventory's housing
    starting in 1800). Choices recorded in the README: the run's flow is what left the site (Smith's roundwood share not applied
    again); bark burned with energy capture; mill fuel all energy, as in HWP-C; landfill decay as CO2, as in HWP-C. The model wants
    removals by Smith region, forest type and cause (Harvest or Clearing); the stage (step 3) maps ecodivisions and transition types
    to them. The Northern Region comparison (Stockmann et al. 2012) in the step list was replaced by the national check, which tests
    more of the chain. User 2026-11-12: keep the 0.5 land-clearing default.
  - **Step 3, the stage - built 2026-11-12, not yet run inside SyncroSim:** `src/18-wood-products.R` (transformer WoodProducts,
    "18 - Wood Products"), `src/wood-products-run.R` (the run's `LULC: Harvest` flows by SQL; Smith region from the secondary
    stratum's state or county, Oregon and Washington by ecodivision, or the Region option; Urbanization and Ag Expansion are land
    clearing; a projection joined to its history with find_history, the history's iterations recycled), page `ui/WoodProductsView.cs`
    (run, Region, Draws, Seed, land-clearing share, spin-up), sheets WoodProductsOptions, OutputWoodProducts (Iteration blank = all,
    Year, Source, Variable, Mean, Lower, Upper), OutputWoodProductsEndUse, OutputWoodProductsScale, OutputWoodProductsFigure (two
    figures: stocks and stock change; where the removed carbon goes and in use by end use). New datasheets only, so no library update
    method. `tests/phaseZ30-wood-products.R` runs the stage script with SyncroSim's calls stubbed, read-only: 16 checks pass on
    lucasCore-projection (runs 10 and 12, California) and Puget Lowlands (59 and 64, PNW West); a projection shares its history's
    years exactly. Puget: 17.5 Tg C stored in 2023, 0.05 Tg C/yr stock change, as harvest fell from about 1 Tg C/yr (late 1980s) to
    0.44 while the pre-1985 products decay. Left: run it in Studio once the branch is in the registered package (F:\lucasCore);
    Smith has no PWW row for many forest groups (they take the regional average, logged).
  - **Step 4, Run Figures and Compare Runs - built 2026-11-12, not yet run inside SyncroSim:** the lookup is by RunScenarioId:
    `wp_of_run` (src/run-figures.R) reads the newest Wood Products result whose rows name the run (its over-all rows), so stage 18
    is run on the run first and nothing else is named. A separate figure rather than extra lines on the carbon stock chart (the
    products are a few percent of ecosystem carbon and vanish on its scale): Run Figures "Harvested wood products" - (a) carbon stored
    in use and in landfills and dumps with the interval, (b) ecosystem NBP, the change in products as bars, and NBP with products
    with the interval. Compare Runs: the same two panels with one line per run, and the carbon summary gains HWP (mean stock change)
    and NBP + HWP (sheet columns HwpStored, HwpStockChange, NbpWithProducts; `Update(1.4)` adds them to older libraries at the 1.4.0
    release, tools/sync-library.R before it). A history with no result of its own takes its projection's (stage 18 on a projection
    runs the history's years with the same draws). Runs with no result keep their figures as before, with a log line. The summary
    tables now measure their text (strwidth) instead of counting characters, so long run names no longer overlap the columns.
    `tests/phaseZ31-wood-products-figures.R`: 12 checks pass on lucasCore-projection and Puget Lowlands (NBP with products is NBP
    plus the stock change every year; the history borrowing its projection's result agrees with stage 18 on the history alone).
    Puget 1985-2050: ecosystem NBP -0.148 Tg C/yr, products +0.150, together +0.002.
  - **Step 5, results and guide - 2026-11-12, outside Studio:** stage 18 run read-only (tests/wood-products-stage-stub.R) on P26
    (historical 54; projections 65, 66, 67; PSW, a few Nevada cells RMS) and Puget (59, 64; PWW), with the default 100 draws.
    P26 no-climate: 17.2 Tg C harvested and 1.0 cleared 1986-2050; 4.1 Tg C stored in products in 1985, 9.1 (8.4-9.8) in 2050,
    +0.076 Tg C/yr (27% of removals); NBP +0.163 -> +0.239. The three projections store 9.05-9.12 Tg C (harvest is set by area), and
    products add about 0.09 Tg C/yr to each: no climate +0.02 -> +0.11, SSP5-8.5 -0.16 -> -0.07, SSP2-4.5 -0.21 -> -0.12. Puget
    no-climate: 23.5 Tg C (21.1-25.5) in 2050; history NBP +0.04 -> +0.16, projection -0.41 -> -0.20. User guide (the Claude Doc):
    section 7.5 "Harvested wood products (stage 18)" with Figures 7.33-7.35 from P26, and Appendix A's stage 18 sheets; the repo's
    snapshot (docs/guide) is refreshed at release. Stage 18's end-use chart now shows readable end-use names (WP_ENDUSE_LABELS).
    Left: run stages 18, 13 and 14 inside Studio once the branch is in F:\lucasCore (then the guide's screenshots of the Wood
    Products page), the 1.4.0 version bump and release notes.
    A design point for step 2: Smith's industrial roundwood ratios exceed 1 for pulpwood (it also comes from tops and cull, which the
    model keeps in Other Wood), so the stage uses Smith's ratios as shares of the removed carbon, which is conserved.
  - **Steps:** (1) source the parameter tables and write them to `defaults/wood-products` with citations; check that national
    totals reproduce the Inventory's HWP stock change for the years it publishes, to a few percent. (2) `src/wood-products.R`, the
    model as plain functions, with unit tests on simple cases (one pulse, one half-life, by hand) and against the HWP C calculator's
    published Northern Region results (Stockmann et al. 2012). (3) Stage 18, its sheets and page. (4) Run Figures and Compare Runs.
    (5) P26 and Puget runs, guide section, CHANGELOG.
  - **Open questions:** which region set to use for the ratios (RPA regions or the National Forest System regions) and how
    ecodivisions map to it; whether `Forest Harvest: Forest Selection 20%` (thinning) gets a pulpwood-heavy product mix; whether
    fuelwood counts as energy capture (the Inventory does); exports and imports (the production approach counts wood harvested here
    wherever it goes, so no trade data is needed).

66. **Marsh elevation for tidal marsh methane** - TO DO (future work), added 2026-11-16 on the wetland methane branch (user: "Lets
    mark the tidal elevation map as future work in this branch").
    - Why: Arias-Ortiz et al. 2024 (Table 3, given by the user 2026-11-16) split fresh-oligohaline tidal marsh at or under a
      daily-maximum temperature normal of 25.6 C by marsh elevation: low and mid marsh 54.9 g CH4 per m2 per yr (20 sites; 0.412 Mg C
      per ha per yr as CH4) against high marsh 5.3 (10 sites; 0.040), a tenfold difference. The model has no marsh elevation, so
      `defaults/stockflow/marsh-salinity-ch4.csv` uses their site-weighted mean, 0.288, for oligohaline marsh in every region but
      the Gulf and South Atlantic. The warm group (above 25.6 C; 7 sites; 1.286) has no elevation split in the table, so the Gulf
      values would not change.
    - How: a relative tidal elevation map for the conterminous US at 30 m exists (Holmquist and Windham-Myers, relative tidal marsh
      elevation Z* for 2010; ORNL DAAC Coastal_US_Elevation_Data; also in the USGS coastal wetland collection). Not read or
      downloaded yet: its classes against the paper's low, mid and high marsh are to be checked. It would come in as salinity did
      (stage 8, `src/8-initial-stocks-spatial.R`, Marsh salinity): a Data Sources entry and a Data Download dataset, the share of
      each estuarine emergent cell's pixels in each elevation class, and a zone table by salinity and elevation, feeding the same
      pair of Marsh Salinity flow spatial multipliers (methane up or down, CO2 the other way, the cell's decomposition unchanged).
    - Open: whether the paper's elevation classes can be reproduced from Z*; whether the palustrine emergent class (tidal fresh
      marsh) should take an elevation value too; the mesohaline and polyhaline groups have no elevation split in the table.

67. **Monthly temperature for the wetland Q10s (and the marsh growth response)** - TO DO, added 2026-11-16 on the wetland methane
    branch (user: "Add monthly temp as another to do in this work").
    - Why: the wetland multipliers are written from the year's mean temperature against the 1991-2020 normal: methane
      3.83 ^ ((T - Tn) / 10), wetland soil CO2 2.0 ^ ((T - Tn) / 10), marsh growth f(T) / f(Tn) (src/climate.R). A response this
      curved is not the response at the mean: the year's flux is the sum of the months', and warm months count for more than cool
      ones take away. Where summers are warm and winters cold the annual-mean form understates how much a warm summer adds (and a
      warm winter adds little methane). The 3.83 is Yvon-Durocher et al.'s 0.96 eV between 10 and 20 C; it is 4.22 between 0 and 10
      C and 3.50 between 20 and 30 C, so a monthly form could also use the activation energy itself in place of one Q10.
    - How: PRISM monthly mean temperature is not downloaded today (stage 7 reads monthly precipitation for the RAP fit; the Data
      Download would add monthly-us25m/tmean), and LOCA2 is monthly already (stage 11). The year's multiplier = the mean over months
      of Q10 ^ ((Tm - Tnm) / 10) weighted by the normal month's share of the year's flux (itself Q10 ^ ((Tnm - Tn) / 10)), so it is
      still 1 at the normal climate. One function in src/climate.R for both stages, behind the existing groups (Q10 Wetland CH4, Q10
      Wetland Soil, Net Growth Wetland: Total); the dead-pool Q10 groups of every other class could take it too, a wider change.
    - Open: whether to keep Q10 or move to the activation energy; whether Chang et al. 2021's seasonal hysteresis (a different
      response in the warming and the cooling half of the year) is worth representing; the cost of 12 times the climate rasters read.

68. **Carbon carrying capacity (a PNV carbon metric)** - DONE in code 2026-11-18 (branch `claude/pnv-carbon-metric-lucascore-1d71ac`;
    user: "a metric where historical and/or projections for a region can be compared back to what the true carbon carrying
    capacity of the region was"). Tested by `tests/unit-capacity.R`; outside SyncroSim on the
    Yellowstone library with `dev/capacity/check-library.R` (Build 14, run 15); and inside SyncroSim on a copy of it (stage 8 rerun
    on Build 14, then stages 13 and 14 on runs 15 and 11: all checks pass, the same numbers as outside).
    - Decisions (user, 2026-11-18): the natural-regime mean, not the old-growth maximum (kept as an upper bound); the model's own
      curves and return intervals with LANDFIRE BpS as the potential vegetation map, fixed, computed once in the Build; hybrid
      forest typing (forest today keeps its type, BpS only for developed and farmed land); live biomass, dead wood and litter,
      soil left out. Alternatives set aside: external potential carbon maps (Walker et al. 2022; Sanderman et al. 2017 for soil),
      reference lands (GAP 1, wilderness, FIA upper quantiles), and a dynamic counterfactual run (below).
    - Code: `src/capacity.R`; stage 8 writes Carbon Capacity Summary, by Type and Maps; stages 13 and 14 draw runs against it
      and write Run Carbon Against Capacity and Compare Carbon Against Capacity. User Guide section 7.6.
    - Natural non-forest land (user, 2026-11-18, after the first Yellowstone numbers): natural grassland, shrubland and barren
      land keeps its own class, "with the logic being that NLCD directly maps these main groups from satellite observations with
      relatively high accuracy while BpS is a modeled product. However, this would be good to have as a user selection option."
      The option is the single-row sheet Carbon Capacity Options (Carbon Assumptions), NaturalNonForest: 1 its own class
      (default), 2 LANDFIRE BpS potential (forest on the cell's BpS forest share). Its page (ui/CarbonCapacityView.cs; user: "a
      simple selection rather than a dropdown ... some explanation text"): two radio buttons, each with what it means.
    - Seen on Yellowstone (300 m, 1985-2023; BpS reads 87.5% of the land as forest potential, the annual NLCD has 31% of it in
      grass and shrub). Default: capacity 62.2 Tg C (upper bound 70.9), stock 53.6 in 1985 (86%) and 52.0 in 2023 (84%); the
      1985 deficit of 8.6 is 8.1 forest condition and 0.5 land use. With the BpS option: capacity 89.7 (102.5), 60% and 58%; of
      the 1985 deficit of 36.1, 26.4 is natural grass, shrub and barren land on BpS forest potential.
    - The deficit by cause (user, 2026-11-18: "What does Condition really include? A shift in stand age? Disturbed forest?", then
      "Yes, split it"): land use; non-forest cover; disturbed land; and, on land in its potential cover, live biomass (stand age
      and stocking) apart from dead wood and litter. Yellowstone 1985: live biomass 2.4 Tg C (forest of 101 years on average
      against a regime mean age of 200), dead wood and litter 5.7, disturbed land 0.02 (3.9 by 2023, after the 1988 fires).
      Fire as the last disturbance (user, 2026-11-18: "Can we re-run stage 8 where we assume fire as the last disturbance for all
      cells?"): outside the 1900-1985 fire perimeters (98% of the land) stage 8 starts forest on the post-clearcut curve, the
      capacity uses the post-fire one. With Carbon Assumptions: Spin-up set to high-severity fire for every forest type (stage 8
      rerun on a second copy, dev/libs/capacity-test-fire): starting stock 53.6 -> 55.0 Tg C, 86% -> 88% of the capacity, dead
      wood and litter deficit 5.65 -> 4.25, live biomass unchanged at 2.44. So the clearcut start is about a quarter of the dead
      wood deficit and stand age the rest (an earlier note here, and to the user, said most: wrong). For a park that was never
      logged, fire is the better start. Open: whether a park or wilderness study area should default to it; a historical run
      from the fire-start Build has not been made.
    - Two checks of what the Yellowstone share rests on (user, 2026-11-18: "Run both checks on the scratch library").
      Return interval: lodgepole pine at 200 years in place of LANDFIRE's 338 (Carbon Assumptions: Spin-up; stages 3, 4 and 8
      rerun, capacity-test scenario 23): regime mean age 199 -> 155, capacity 62.2 -> 59.6 Tg C, the 1985 share 86% -> 90%, the
      live biomass deficit 2.44 -> 0.54, dead wood and litter 5.65 -> 5.02. Stand age: this Build's ages are TreeMap 2016 FIA
      plot ages moved back to 1985 (Stand Age Source = TreeMap; an earlier note to the user said CMS: wrong), forest mean 101
      years, 8% over 150, the same inside and outside the 1988 perimeters. NASA CMS 1990 less 5 years gives 110 (27% over 150)
      on forest never inside a 1986-2016 perimeter and 143 (52% over 150) on forest that burned only after 1990. Both maps
      post-date 1988, so neither holds the pre-fire age of the 40% of forest cells inside the 1986-1990 perimeters (CMS reads
      them as just burned; TreeMap gives them the age of their unburned remnants). Also: a cell's age is the mean of its 30 m
      pixels, which pulls every 300 m cell toward 100 and leaves almost none over 200. Open: a pre-fire age source for land that
      burned between the start year and the age map's year; whether the age classes should be kept (a distribution per cell).
      What if the forest that burned in 1988 was old (user, 2026-11-18; estimated outside SyncroSim from Build 14's curves, which
      reproduce the Build's 86% and the fire-start 88%): with the 40% of forest cells inside a 1988 perimeter at 200, 250 or 300
      years in place of 99, the park starts at 95%, 96% or 97% of its capacity (96%, 98%, 98% with fire as the last
      disturbance); live biomass is then 0.6 to 1.2 Tg C above its capacity and the deficit left is dead wood and litter.
    - Forest cover: tree canopy cover against NLCD and BpS (user, 2026-11-18: "we do not have enough forest cover either (reality
      somewhere between NLCD and BpS)"; "Run the offline tree-cover test"; "NLCD also publishes a canopy cover product"). USFS
      Science Tree Canopy Cover v2025-6, 1985 and 2023, 30 m, read as a window from the national files (stored zips at
      data.fs.usda.gov/geodata/rastergateway/treecanopycover, 6 GB a year; /vsizip//vsicurl/ reads 11 MB for the park; the
      geoplatform image service needs a token). The Science version, since the NLCD one zeroes pixels NLCD calls non-treed.
      Park, 1985: NLCD forest 55.9% (canopy median 50%); NLCD grass or shrub on BpS forest 26.1% (median 35%; 95% at or over
      10%, 79% over 20%, 62% over 30%); NLCD grass or shrub on BpS non-forest 5.3% (median 20%; 85%, 52%, 30%). So the raw product
      reads some canopy on open land too, and a 10% threshold passes nearly everything: the BpS gate does the work, and the
      threshold wants calibrating (20 to 30%). Forest share with the rule "NLCD forest, or NLCD grass or shrub on BpS forest with
      canopy at or over the threshold": 80.6% at 10%, 76.5% at 20%, 71.9% at 30% (the park is usually given as about 80% forest).
      Two thirds or more of the added land is inside the 1988 perimeters, where its 1985 canopy (median 39%) is higher than
      outside (24%): the land that burned was treed, and the annual NLCD's grass and shrub labels there in 1985-1987 look like an
      artefact of its time series. 2023, inside the 1988 perimeters: NLCD has 22% forest and 69% shrub, the shrub with a canopy
      median of 29% (65% over 20%), which is young forest; forest share of the park 41% by NLCD, 75% by the 10% rule.
      Capacity: 1,840 to 2,200 km2 more forest adds 21 to 25 Tg C of capacity (62 -> 83 to 87); the share stays 86% if the added
      forest starts at the forest's mean stock and falls toward 75% at half of it, so cover changes the totals and age the share.
      Not built: a stage 5 rule (its own branch), and the same test for when burned forest returns (stage 6).
    - Follow-ups, not started: a Build figure of the capacity; the capacity by tertiary stratum; a surface-fire regime for
      frequent-fire types (LANDFIRE FRI_SURFAC, FRI_MIXED); a natural fire regime for shrubland (chaparral and the sage family
      are counted at their mature stock); potential soil carbon; a dynamic counterfactual run (an ST-Sim scenario started from
      potential vegetation with natural disturbance only, under the same climate and CO2, so the capacity moves with climate).

69. **A full BpS crosswalk for the carbon capacity, as a user choice** - TO DO, added 2026-11-18 (user: "adding a full BpS cross walk
    in the future would be a to-do item and then an optional user choice").
    - Why: the hybrid choice of item 68 takes today's forest type as the natural one, so planted or shifted composition
      (loblolly on former longleaf land, fir where fire exclusion replaced pine) counts as on-type. BpS names the pre-settlement
      type of every pixel.
    - How: a table from BpS name (`defaults/landcover/LF20_BPS_220.csv`, about 925 forest settings in the groups Conifer,
      Hardwood, Conifer-Hardwood, Hardwood-Conifer and Peatland Forest, plus Riparian and Savanna) to the 28 FIA forest type
      groups, and for non-forest settings to the grass and shrub classes; `capacity_build()` then takes each cell's type from the
      share of its BpS pixels by type instead of its own. A setting on the Build Options (or a Carbon Capacity) page: Potential
      forest type = Current type (default) / LANDFIRE BpS. A new column of an existing sheet needs an update method (a minor
      version); a sheet of its own does not.
    - Open: who builds and reviews the crosswalk (it sets the quality of the metric); whether BpS's own fire regime attributes
      (the return intervals in the BpS table of the national release) should replace the FRI layer's for the regime mean.
