# =============================================================================
# merge_douglas_fir.R - one Douglas-fir state class (user decision 2026-10-21): "Forest: Douglas-fir Group" (200), no Inland (201)
# =============================================================================
# Douglas-fir's growth curves already differ by ecodivision (stage 2 fits FIA's Douglas-fir group per ecodivision), so a separate
# Inland class only duplicated them; the USFS forest type group map has no such split. One-off edit of defaults/:
#   * every "Douglas-fir Coastal Group" becomes "Douglas-fir Group"
#   * rows naming "Douglas-fir Inland Group" are removed (state class, its label, its transition types and their group memberships,
#     its pathway rows and state location, growth / density / CBM species rows, spin-up defaults)
#   * crosswalk values 201 become 200
# Lines are edited as text, so nothing else in a file changes. Rerun tools/make_landcover_crosswalks.R afterwards.
# Usage: Rscript tools/merge_douglas_fir.R
# =============================================================================
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
d <- file.path(normalizePath(file.path(here, "..")), "defaults")
fs <- list.files(d, "[.]csv$", recursive = TRUE, full.names = TRUE)
fs <- fs[!grepl("land-cover-crosswalks[.]csv$", fs)]   # rebuilt from the source crosswalks
for (f in fs) { x <- readLines(f, warn = FALSE, encoding = "UTF-8"); y <- x
  y <- y[!grepl("Douglas-fir Inland Group", y, fixed = TRUE)]
  y <- gsub("Douglas-fir Coastal Group", "Douglas-fir Group", y, fixed = TRUE)
  if (grepl("evt20(16|01)-crosswalk", basename(f))) {             # ID column: 201 -> 200
    h <- strsplit(y[1], ",", fixed = TRUE)[[1]]; k <- which(h == "ID")
    for (i in seq_along(y)[-1]) { p <- strsplit(y[i], ",", fixed = TRUE)[[1]]
      if (length(p) >= k && identical(p[k], "201")) { p[k] <- "200"; y[i] <- paste(p, collapse = ",") } } }
  if (!identical(x, y)) { writeLines(y, f, useBytes = TRUE); cat(sprintf("%-60s %d lines removed, %d changed\n", sub(paste0(d, "/"), "", f), length(x) - length(y),
                                                                         sum(x[x %in% y | TRUE][seq_len(min(length(x), length(y)))] != y[seq_len(min(length(x), length(y)))]))) } }
left <- unlist(lapply(fs, function(f) grep("Douglas-fir (Inland|Coastal)", readLines(f, warn = FALSE), value = TRUE)))
cat(if (length(left)) paste("still named:", head(left, 5)) else "no Douglas-fir Inland or Coastal left in defaults/", "\n")
