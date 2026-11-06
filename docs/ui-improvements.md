# UI improvements

Ideas for the lucasCore pages in SyncroSim Studio, collected during the P26 user-guide walkthrough. Newest last.

## Priorities (2026-11-02)

The open items in order. Item numbers are ids and do not change; this table is the order. The rule from 2026-10-25 still holds: items
that change the model itself (its inputs or results) come first, and anything built on P26's results (metadata, the
guide's numbers and figures) after them, so it is redone only once. Within that, quick usability fixes go first.

| Order | Item | Changes results? | Why here | Depends on |
| --- | --- | --- | --- | --- |
| 1 | 14 FGDC metadata | No | User order 2026-11-02: first. Plan (a working document, not in this repository) (phases 0-6; decisions settled 2026-11-02: CSDGM first, one release per Build, maps every year, model archive always, ScienceBase folder by hand; Phase 0 done with the user 2026-11-02; Phase 1 built 2026-11-02: defaults/metadata definitions, data dictionary, citations, src/metadata.R, tests/unit-metadata-definitions.R; citation questions in the plan); lineage from the home's manifest and each Build's Data Sources Used | 12 (done) |
| 3 | 39 Grassland, shrubland and wetland carbon: options beyond today's crude method | Yes | User order 2026-11-02: third, with the other open science items (user: explore additional options).  Step 1 (rates on a page) and the diagram view done; the diagram shows emergent wetland rates settling far above their starting pools; suspect values (emergent wetland growth 31, irrigated grass 9.19 Mg C/ha/yr), root turnover splits; the science options (user to decide) | - |
| open science, user to place | 46 CO2 fertilization | Yes, as an option (off by default) | Added 2026-11-04. Growth has no CO2 response, and its size is similar to the climate penalty in the projections | - |
| later | 47 Example libraries by region and resolution | No (each holds its own results) | Added 2026-11-04, replaces 13. Best built after the open science items, since each carbon change dates them | 14, restore test |
| any | 49 Test national mode end to end | No | Added 2026-11-04. Never run end to end; fills about 175 GB overnight | 12 (done) |
| next | 51 After the 1.1.0 release: P26 to 1.1.0 and rerun, Puget parents to Build 58, guide sections, code.usgs.gov resync, safeguards | Only the P26 rerun | Added 2026-11-05: what the release left | 43 (done) |
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
  - **Still to do:** the per-age-band check (growth by age band
    in a test library); sync-library and the CO2 type for the other libraries when they move.

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
  - **P26 guide library:** move it to 1.1.0 (`SyncroSim.Console --add --package --pkg=lucasCore --ver=1.1.0 --lib=...`; the user runs it,
    it is the user's library), run sync-library for the Pasture and Cropland attributes and the Ag Change types, then rebuild and rerun.
  - **Other dev libraries** (test, schema-ref, Data Download, older P26 copies) still name 1.0.1 and show lucasCore missing until moved.
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
