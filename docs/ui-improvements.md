# UI improvements

Ideas for the lucasCore pages in SyncroSim Studio, collected during the P26 user-guide walkthrough. Newest last.

## Priorities (2026-11-02)

The open items in order. Item numbers are ids and do not change; this table is the order. The rule from 2026-10-25 still holds: items
that change the model itself (its inputs or results) come first, and anything built on P26's results (metadata, the
guide's numbers and figures) after them, so it is redone only once. Within that, quick usability fixes go first.

| Order | Item | Changes results? | Why here | Depends on |
| --- | --- | --- | --- | --- |
| 1 | 14 FGDC metadata | No | User order 2026-11-02: first. Plan (a working document, not in this repository) (phases 0-6; decisions settled 2026-11-02: CSDGM first, one release per Build, maps every year, model archive always, ScienceBase folder by hand; Phase 0 done with the user 2026-11-02; Phase 1 built 2026-11-02: defaults/metadata definitions, data dictionary, citations, src/metadata.R, tests/unit-metadata-definitions.R; citation questions in the plan); lineage from the home's manifest and each Build's Data Sources Used | 12 (done) |
| 2 | 39 Grassland, shrubland and wetland carbon: options beyond today's crude method | Yes | User order 2026-11-02: third, with the other open science items (user: explore additional options).  Step 1 (rates on a page) and the diagram view done; the diagram shows emergent wetland rates settling far above their starting pools; suspect values (emergent wetland growth 31, irrigated grass 9.19 Mg C/ha/yr), root turnover splits. Review done 2026-11-06 (dev/nonforest/review). Revised approach accepted the same day: one stage 3 solver (measured stocks as targets, growth from data, rates solved; IPCC, IBIS or data as the target source), IPCC factors for soil change on conversion, carbon for pasture and cropland. Nine steps; step 1, the emergent wetland fix, is next | - |
| release | 46 CO2 fertilization | Yes, in projections with a Projection Climate result (Central by default; None turns it off) | Added 2026-11-04; built, tested (Puget run, age-band check), documented (guide 7.3.1) and pushed 2026-11-06. Left: a release | - |
| later | 47 Example libraries by region and resolution | No (each holds its own results) | Added 2026-11-04, replaces 13. Best built after the open science items, since each carbon change dates them | 14, restore test |
| any | 49 Test national mode end to end | No | Added 2026-11-04. Never run end to end; fills about 175 GB overnight | 12 (done) |
| next | 51 After the 1.1.0 release: P26 rebuild and rerun (moved and synced 2026-11-06), Puget parents to Build 58, guide sections, code.usgs.gov resync, safeguards | Only the P26 rerun | Added 2026-11-05: what the release left | 43 (done) |
| open, paused | 50 Water, wetland and barren change | Yes (historical and projected land change, wetland carbon) | Added 2026-11-05. Not modelled today; P26 swaps about 150 km2 each way between water and land (reservoirs), Puget has river bars, ponds and shoreline wetland change | - |

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
