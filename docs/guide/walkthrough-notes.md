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
