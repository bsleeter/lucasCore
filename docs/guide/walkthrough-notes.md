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

## Guide sections done

- 1.2: new Figure 1.6 (the new library in the Explorer); step 4 names the folder and library.
- 1.3: Figures 1.7-1.11 re-grabbed; new Figure 1.12 (CBM Ecozones) with steps 4-5.
- 1.4: Figures 1.13-1.14 re-grabbed (multiprocessing off; R 4.6.1).
- 1.5: Figure 1.15 re-grabbed (FIA DataMart Folder outlined); sources table gains the FIA DataMart row.
