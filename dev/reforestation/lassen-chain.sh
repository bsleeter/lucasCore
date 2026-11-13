#!/bin/bash
# To-do 57: the full chain on Lassen Volcanic NP (150 m) with everything of 2026-11-12 (fitted forest and shrub post-disturbance
# settings, wetland twins to Palustrine Emergent, moderate fire stand-replacing in shrubland, reforestation): Build (stages 1, 5, 2,
# 3, 4, 6, 7, 8, 12), historical run 1985-2023, Projection Setup (stages 9, 10; only Reforestation fitted, the other surfaces None,
# as the step 8 test: Lassen has too few urbanization events, to-do 60), projection to 2050, Run Figures of both, and the
# reforestation check. Run from the repository root: bash dev/reforestation/lassen-chain.sh
set -e
LIB=F:/lucasCore/dev/libs/lassen/Lassen.ssim; TAG="chain 2026-11-12"
R=$(ls -d "/c/Program Files/R"/R-*/bin/Rscript.exe | tail -1)
q() { grep -v -i "warning\|built for\|In ssimLibrary\|^ *$" || true; }   # grep finds nothing to print: not an error
runid() { "$R" -e "suppressPackageStartupMessages(library(rsyncrosim)); L <- ssimLibrary('$LIB', summary = FALSE); t0 <- Sys.time(); r <- run(scenario(L, $1)); cat(sprintf('RESULT %d (%.1f min)\n', scenarioId(r), as.numeric(difftime(Sys.time(), t0, units = 'mins'))))" 2>&1 | grep "RESULT" | awk '{print $2}'; }
B=${1:-}; H=${2:-}   # resume: bash lassen-chain.sh <Build result> <historical result>
if [ -z "$B" ]; then echo "== Build $(date +%H:%M)"
B=$("$R" dev/reforestation/lassen-build.R 1,5,2,3,4,6,7,8,12 --name="Build Lassen 150 m $TAG" 2>&1 | tee /dev/stderr | grep "^result" | awk '{print $2}')
echo "BUILD RESULT $B"; fi
if [ -z "$H" ]; then
echo "== Historical $(date +%H:%M)"
HS=$("$R" tools/new-historical.R $LIB --build=$B --historical-only --name="Historical 1985-2023 $TAG" --replace 2>&1 | q | tail -1)
H=$(runid $HS); echo "HISTORICAL RESULT $H"; fi
echo "== Run Figures and reforestation check (historical) $(date +%H:%M)"
if [ -z "${2:-}" ]; then "$R" dev/reforestation/lassen-run-figures.R $B 1 $H 2>&1 | q | grep -v Datasheet || true; "$R" dev/reforestation/lassen-historical.R $H $B 2>&1 | q; fi
echo "== Projection Setup $(date +%H:%M)"
SS=$("$R" tools/new-projection-setup.R $LIB --build=$B --historical=$H --resolution=150 --end=2050 --name="Projection Setup $TAG" --replace 2>&1 | q | tail -1)
"$R" dev/reforestation/lassen-setup-options.R $SS 2>&1 | grep "^scenario" || true   # (a multi-line Rscript -e runs only its first line on Windows)
S=$(runid $SS); echo "SETUP RESULT $S"; [ -n "$S" ] || { echo "setup $SS failed: see its run log"; exit 1; }
echo "== Projection $(date +%H:%M)"
PS=$("$R" tools/new-projection.R $LIB --build=$S --years=27 --iterations=1 --name="Projection 2024-2050 $TAG" --replace 2>&1 | q | tail -1)
P=$(runid $PS); echo "PROJECTION RESULT $P"; [ -n "$P" ] || { echo "projection $PS failed: see its run log"; exit 1; }
echo "== Run Figures $(date +%H:%M)"
"$R" dev/reforestation/lassen-run-figures.R $B 1 $P 2>&1 | q | grep -v Datasheet || true
echo "== Done $(date +%H:%M): Build $B, historical $H, setup $S, projection $P"
