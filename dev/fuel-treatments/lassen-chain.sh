#!/bin/bash
# Fuel treatments on Lassen: a Build with the treatment pathways and flows (stages 1, 5, 2, 3, 4, 6, 7, 8, 12, as
# dev/reforestation/lassen-chain.sh), its historical run 1985-2023, then dev/fuel-treatments/lassen-fuel-treatments.R (a baseline
# and treatments, both projections at once). Run from the repository root: bash dev/fuel-treatments/lassen-chain.sh [Build] [historical]
set -e
LIB=F:/lucasCore/dev/libs/lassen/Lassen.ssim; TAG="fuel treatments 2026-11-13"
R=$(ls -d "/c/Program Files/R"/R-*/bin/Rscript.exe | tail -1)
q() { grep -v -i "warning\|built for\|In ssimLibrary\|^ *$" || true; }
runid() { "$R" -e "suppressPackageStartupMessages(library(rsyncrosim)); L <- ssimLibrary('$LIB', summary = FALSE); t0 <- Sys.time(); r <- run(scenario(L, $1)); cat(sprintf('RESULT %d (%.1f min)\n', scenarioId(r), as.numeric(difftime(Sys.time(), t0, units = 'mins'))))" 2>&1 | grep "RESULT" | awk '{print $2}'; }
B=${1:-}; H=${2:-}
if [ -z "$B" ]; then echo "== Build $(date +%H:%M)"
B=$("$R" dev/reforestation/lassen-build.R 1,5,2,3,4,6,7,8,12 --name="Build Lassen 150 m $TAG" 2>&1 | tee /dev/stderr | grep "^result" | awk '{print $2}')
echo "BUILD RESULT $B"; [ -n "$B" ] || { echo "the Build failed"; exit 1; }; fi
if [ -z "$H" ]; then echo "== Historical $(date +%H:%M)"
HS=$("$R" tools/new-historical.R $LIB --build=$B --historical-only --name="Historical 1985-2023 $TAG" --replace 2>&1 | q | tail -1)
H=$(runid $HS); echo "HISTORICAL RESULT $H"; [ -n "$H" ] || { echo "historical $HS failed"; exit 1; }; fi
echo "== Fuel treatments test $(date +%H:%M)"
"$R" dev/fuel-treatments/lassen-fuel-treatments.R $B $H 13 3 20 2>&1 | q | grep -v Datasheet
echo "== done $(date +%H:%M)"
