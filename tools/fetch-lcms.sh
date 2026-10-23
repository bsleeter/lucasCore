#!/usr/bin/env bash
# =============================================================================
# fetch-lcms.sh - USFS LCMS v2025-11 CONUS annual Change rasters (30 m, cause of change incl. 9 = Tree Removal), 1985-2025
# =============================================================================
# One coherent harvest record for the whole historical period (user decision 2026-10-22; LANDFIRE disturbance starts in 1999).
# Downloads each year's zip from the USFS raster gateway (4 at a time, resumable), tests it, extracts it into a folder per year and
# keeps the zip only until extraction succeeds. Plus the methods PDF (class codes).
# Usage: bash tools/fetch-lcms.sh [first_year] [last_year]
# =============================================================================
set -u
OUT="F:/lucas-master/Data Sources/LCMS/v2025-11"; BASE="https://data.fs.usda.gov/geodata/LCMS"
Y0=${1:-1985}; Y1=${2:-2025}
mkdir -p "$OUT/Change_Annual"
curl -sS -L -C - -o "$OUT/LCMS_v2025-11_Methods.pdf" "https://data.fs.usda.gov/geodata/rastergateway/LCMS/LCMS_v2025-11_Methods.pdf"
one() {
  y=$1; z="$OUT/Change_Annual/LCMS_CONUS_v2025-11_Change_Annual_$y.zip"; d="$OUT/Change_Annual/$y"
  if [ -d "$d" ] && ls "$d"/*.tif >/dev/null 2>&1; then echo "$y already extracted"; return 0; fi
  for try in 1 2 3; do
    curl -sS -L -C - -o "$z" "$BASE/LCMS_CONUS_v2025-11_Change_Annual_$y.zip" && unzip -tq "$z" >/dev/null 2>&1 && break
    echo "$y attempt $try failed"; sleep 5
  done
  if ! unzip -tq "$z" >/dev/null 2>&1; then echo "$y FAILED"; return 1; fi
  mkdir -p "$d" && unzip -oq "$z" -d "$d" && rm -f "$z" && echo "$y done: $(ls "$d" | tr '\n' ' ')"
}
export -f one; export OUT BASE
seq "$Y0" "$Y1" | xargs -P 4 -I{} bash -c 'one {}'
echo "LCMS DONE: $(ls -d "$OUT"/Change_Annual/[12]* 2>/dev/null | wc -l) years extracted"
