# P26 walkthrough notes (2026-10-28)

Rebuilding P26 in a new library (`dev/libs/LUCAS P26 Northern Sierra Nevada.ssim`) step by step to re-grab the guide. Screen tweaks
found along the way are batched here and fixed while Studio is closed (the page DLL is locked while it runs).

## Screen tweaks to make

1. **Packages list: a warning icon on lucasCore** (Figure 1.10): "The package 'lucasCore' was built for an undetermined version of
   SyncroSim and may not function correctly." Not the minSyncroSimVersion attribute (package.xml has 3.1.9, as stsim and burnP3Plus).
   SyncroSim.Core also has the form "built for SyncroSim version '{1}'", so the version is recorded somewhere - probably at install from
   the .ssimpkg, which a folder link skips. Check how a .ssimpkg install records it; if so, the released package will not show it.
2. DONE 2026-10-28 (package.xml displayNames: Data Sources, Stratum Sources, Climate Replicates (LOCA2)). Was: **Project tree labels cut off** (Figure 1.12): "Stratum Sources (study areas, secondary and ..." and "Climate Replicates (LOCA2
   ensemble membe...". Shorten the displayNames (put the detail in the page instead).
3. DONE and installed 2026-10-28 (re-grab Figure 1.15; names and notes in defaults/library/data-sources.csv Name, Note columns) - user 2026-10-28: one row per dataset = short name (bracketed detail and " - ..." dropped; full name, source and link in a tooltip), a fixed-width path box aligned across groups, Browse, a Download button instead of the link line, the found mark. Was: **Data Sources page: path boxes too narrow and not aligned** (Figure 1.15): every path is cut off after ~25 characters ("F:/lucas-master/Data Sources/FI..."),
   and the boxes start at three different x positions. Give the path column a fixed, wider width (or show the end of the path), with a
   tooltip of the full path.
4. MOOT (the link line is gone; the tooltip shows the source). Was: **FIA DataMart Folder link text** mentions only Growth Curve Options; it is now needed by the FIA measured dead wood method
   (COND_DWM_CALC tables). Reword in defaults/library/data-sources.csv.
5. DONE with 2. Was: **Navigation pane too narrow on the project pages**: "Data Sources (national da", "Stratum Sources (study ar"... (see 2).

6. **Build Options: empty gap in the Strata group** (3.3 grab): the group is twice as tall as its two drop-downs and note.
7. **Build tree label cut off**: "Fitted Curves (written by the ..." in the scenario's LUCAS Core pane. Shorten the group's displayName.
8. **Build Options tiles note lags the box**: typing 5 still showed "8 tiles ..." until the box loses focus. Update the note as the number changes.
## Guide sections done
9. **Growth Curve Options says "FIA DataMart"**: the FIA data choice reads "FIA DataMart (state CSVs)" and its note "FIA DataMart Folder"; Data Sources now calls it FIA CONUS. Rename here too.
10. **Growth Curve Options number formats**: Maximum fitted lag shows 40.0000 (years: no decimals); lambda 0.0100 is fine.
11. **Carbon Method: warn when the method changes after Fill**: picking CBM defaults on a page filled with the FIA rows keeps those rows (fitted fire flows, snag shares) - show a line "the sheets hold the FIA measured dead wood rows; press Fill to switch" (the guide says so in 3.6 for now). Needs the page to remember which method filled it (e.g. a hidden FilledWith column).

12. **Data Sources: FRI name** - "LANDFIRE Mean Fire Return Interval" but stage 5 uses the FRI_REPLAC (replacement-severity) field of that
    product for the spin-up return interval. Rename "LANDFIRE Fire Return Interval" with a note "replacement-severity interval, spin-up".
13. **Decay Calibration output unreadable** (4.3e grab): about 20 columns, every name and most values cut to "Spin-...", "M...".
    Shorter displayNames, Return Interval and its Source first after the keys, or a custom view. No guide figure needed (user, 2026-10-28).
- 1.2: new Figure 1.6 (the new library in the Explorer); step 4 names the folder and library.
- 1.3: Figures 1.7-1.11 re-grabbed; new Figure 1.12 (CBM Ecozones) with steps 4-5.
- 1.4: Figures 1.13-1.14 re-grabbed (multiprocessing off; R 4.6.1).
- 1.5: Figure 1.15 re-grabbed (FIA DataMart Folder outlined); sources table gains the FIA DataMart row.
- 1.5 again: Figure 1.15 re-grabbed with the new Data Sources page (marks 1-6 now tab, page, path, Browse, Download, found); steps
  1-6 and the sources table use the new names (FIA CONUS, FIA Carbon/Disturbance Summary).

## Later (user, 2026-10-28)

- Refine the Data Sources page further when building the Data Download stage (to-do 12). Path boxes are still on the narrow side in a
  wide window: SizePaths reserves the navigation pane's width too (ClientSize is the whole page).
- 3.1: Figures 3.1-3.2 re-grabbed (name P26 - Build, new description); 3.2 Figure 3.3 and 3.4 Figure 3.5 re-grabbed.
- 3.3: new subsection 3.3.1 Modal or Area-matched (table of P26 numbers from the 2026-10-25 exploration, docs/ui-improvements.md item 8); step 6 now says Area-matched for P26. CHECK the table against the new P26 Build's stage 5 log (area in the wrong class, developed area) once it has run.
- DECISION (user, 2026-10-28): Carbon Assumptions are set on the Build itself in the guide (no separate scenario, no dependency); the shared scenario becomes an advanced option in 3.6. Guide 3.1 description and pipeline note updated; Figure 3.1's description still says 'Dependencies: Carbon Assumptions' - re-grab. Update docs/carbon-build-process.md step 3 to match.
- 3.5 Growth Curve Options (Figure 3.6, step 4 FIA data); 3.6 Carbon Assumptions written on the Build (Figures 3.7-3.11, table of the eight pages; separate scenario as an advanced note); Figure 3.1 re-grabbed with the Build-only description; Land Cover Crosswalks now Figure 3.12.
- 4.2-4.3 (2026-10-28): P26 Build result 2 ran in 54:59, 68 of 68 Validation checks pass. New 4.2 The run log (Figure 4.5, marks 6
  initial carbon and 7 total time; stage-time table) and 4.3 Checking the result (Validation, numbers from the log); old Figures
  4.5-4.14 renumbered 4.6-4.15. Area-matched numbers agree with 3.3.1 (wrong class 28/65/mean 47 km2; developed 876 -> 1,121 vs
  30 m 1,108; reversals 184); 3.3.1's stage 5 time corrected to ~12 min (log: 11.6 min of stage 5's 22.5). PENDING: grabs of the
  result scenario in the Explorer and its Validation page (then renumber again); re-run 4.4 Build Figures on result 2 - Figure 4.14's
  caption still says 486 Tg C (old Build); this Build gives 0.44 Pg C.
- 4.3 grabs (2026-10-28): Figures 4.6 result scenario (marks 8 result, 9 Run Log), 4.7 Validation (10, 11), 4.8 Initial Stock
  Summary (12, 13); Build Figures onward renumbered 4.9-4.18. Decay Calibration grab dropped (user: no figure needed).
- 4.4 (2026-10-28): Build Figures result 4 ran in 1:35 (10 figures). Steps now start with a Figures folder (New > Folder from the
  result's menu, then New > Scenario on the folder): Figures 4.9-4.14 new (marks 1-8), Run Monitor 4.15 and Export 4.16 kept (marks
  9-11), example Figures 4.17-4.20 redrawn from result 4 (initial carbon 439.3 Tg C, soil classes 66-75). Old 4.4a-d captures in
  captures/old. Chapter 5's reference to the inherited pipeline / No Data figures now 4.12 and 4.13.
- 5.1 (2026-10-28): Figure 5.1 now the Build's right-click New > Scenario menu (mark 1; replaces the name dialog grab, in captures/old); step 2 says drag the result. Figures 5.2 (Explorer + dependency) and 5.3 (ST-Sim pipeline) still from the old library - re-grab.
- 5.1 again: Figures 5.2 (P26 - Historical + dependency, marks 2-3) and 5.3 (ST-Sim pipeline, 4-5) re-grabbed; name in step 1 now P26 - Historical. The inherited-pipeline grab is not used (same as Figure 4.12; in captures/old).
- 5.2 (2026-10-28): Figures 5.4-5.8 re-grabbed (marks 6-19); spatial output now described as inherited from the Build (stage 0); new Figure 5.9 Stocks output filter (outlined, no number) with a paragraph on the stock/flow filters; 5.9-5.17 renumbered 5.10-5.18; dropped 'first two P26 runs have no age maps'. Flow filter grab unused (captures/old).
- 5.3 (2026-10-28): Figure 5.11 re-grabbed (library multiprocessing, marks 23-27). Step 9 rewritten: the Build result supplies the tiling raster (stage 1 Build-Tiles.tif, 5 tiles of whole counties, inherited); SecondaryStrata.tif is the per-county alternative; new paragraph after Table 5.1 on balanced tiles. Figure 5.10 re-grabbed (Build-Tiles.tif inherited, marks 20-22).
- 5.4 (2026-10-28): Figure 5.12 re-grabbed (5 tile jobs, result 6, mark 28); text says 5 jobs, balanced tiles keep pace. PENDING after result 6: the run-time table and paragraph (still the 24 Oct 17-job run), file count/size, and chapter 5.5-5.6 numbers and figures (486.3 -> 500.4 Tg C captions are the old Build).
- 5.4-5.5 (2026-10-28): historical result 6 (5 Build tiles, 20.0-20.2% of cells each) ran 2:51:03 (create 0:04, jobs 2:43:03, merge
  7:55); 2,207 files, 4.3 GB, library 1.5 GB. Table and paragraph updated. FINDING: the three 17-county runs in the Demo Library
  (results 8, 9, 14) took 2:19-2:28 (jobs 2:04-2:12, merge 15 min) with the same largest job (Plumas 19.8%), so 5 balanced tiles
  took ~30 min longer, BUT the user had another bandwidth-heavy process running (2026-10-28), so not a clean test; user
  does not expect 5 tiles to be faster (both wait on ~20% of cells); the gain is memory (5 jobs, not 17) and merge (8 vs 15 min). Guide says so. 5.5 Carbon
  paragraph now 439.3 -> 466.7 (2019) -> 444.3 Tg C (+5.0), fire-year losses 9.3 / 14.3. PENDING: 5.5 transition and developed-land
  numbers, 5.6 Run Figures re-run on result 6 (Figures 5.13-5.18 and their captions).
- 5.5-5.6 (2026-10-28): 5.5 Transitions (families within 0.5-8% of the record: urbanization 244/245 km2, fire 12,126/12,412, harvest
  2,194/2,392 short 8%) and Developed land (run 876 -> 1,120 km2 vs Area-matched map 1,121, NLCD 30 m 1,108; flicker now only a Modal
  note) rewritten. Run Figures result 8 (1:15, 9 figures, run 6): Figures 5.16-5.18 redrawn (urbanized 243, harvested 1,917 km2;
  439.3 -> 444.4 Tg C, +5.1 on the maps; NBP +0.13 Tg C/yr); step 4 and examples say result 6. User's grab (5.6a, marks 29-32,
  annotated, NOT yet in the guide) has the RUN result [6] as the dependency, not the Build result: stage 13 then has no Historical
  Transition Summary and Figure 6 shows bars only. PENDING: re-grab 5.6a with the Build result [2] as dependency and 5.6b Run
  Figures options with Id 6 (Figure 5.14 still shows result 9), then rerun.
- 5.6 again (2026-10-28): user re-made the dependency as the Build result [2] and Run = 6; Run Figures result 9 (1:12; result 8
  deleted) draws Figure 6 with the record points (same totals as 5.5). Figures 5.13 (pipeline, cropped to the page, mark 29 on the
  tab) and 5.14 (Build dependency 30, Run Figures 33, Id 6 34) re-grabbed; step 1 now New > Scenario on the Figures folder,
  "Historical Run Figures". Figures 5.16-5.18 re-uploaded from result 9 (header now the study area name; with the run as dependency
  it read CONUS). Chapter 5 done except Figure 5.15 (Export, still old library) if it should be re-grabbed.
