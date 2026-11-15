#!/bin/bash
# Rangeland restoration on Hart Mountain (300 m): a Build (stages 1, 5, 2, 3, 4, 6, 7, 8, 12), its historical run 1985-2023, then
# dev/rangeland-restoration/hart-restoration.R (a baseline and restoration, both projections at once). Run from the repository
# root: bash dev/rangeland-restoration/hart-chain.sh [Build] [historical]
set -e
LIB=F:/lucasCore/dev/libs/hart-mountain/HartMountain.ssim; TAG="rangeland restoration 2026-11-14"
R=$(ls -d "/c/Program Files/R"/R-*/bin/Rscript.exe | tail -1)
q() { grep -v -i "warning\|built for\|In ssimLibrary\|^ *$" || true; }
runid() { "$R" -e "suppressPackageStartupMessages(library(rsyncrosim)); L <- ssimLibrary('$LIB', summary = FALSE); t0 <- Sys.time(); r <- run(scenario(L, $1)); cat(sprintf('RESULT %d (%.1f min)\n', scenarioId(r), as.numeric(difftime(Sys.time(), t0, units = 'mins'))))" 2>&1 | grep "RESULT" | awk '{print $2}'; }
B=${1:-}; H=${2:-}
if [ -z "$B" ]; then echo "== Build $(date +%H:%M)"
B=$("$R" dev/rangeland-restoration/hart-build.R --name="Build Hart Mountain 300 m $TAG" 2>&1 | tee /dev/stderr | grep "^result" | awk '{print $2}')
echo "BUILD RESULT $B"; [ -n "$B" ] || { echo "the Build failed"; exit 1; }; fi
if [ -z "$H" ]; then echo "== Historical $(date +%H:%M)"
HS=$("$R" tools/new-historical.R $LIB --build=$B --historical-only --name="Historical 1985-2023 $TAG" --replace 2>&1 | q | tail -1)
H=$(runid $HS); echo "HISTORICAL RESULT $H"; [ -n "$H" ] || { echo "historical $HS failed"; exit 1; }; fi
echo "== Restoration test $(date +%H:%M)"
"$R" dev/rangeland-restoration/hart-restoration.R $B $H 27 10 20 2>&1 | q | grep -v Datasheet
echo "== done $(date +%H:%M)"
