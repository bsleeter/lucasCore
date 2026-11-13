# =============================================================================
# add-definitions.R - add the package's project definitions a library lacks (rows only; nothing existing is changed)
# =============================================================================
# Between releases a library made with an earlier lucasCore can be moved to the dev package (SyncroSim.Console --add --package, then
# tools/sync-library.R --schema-only for its columns and stages), but neither adds the new rows of the ST-Sim definition sheets that
# the release's library update would (1.4: the Disturbed state label and classes, the twins' Y labels, the Post-disturbance and
# Reforestation transition types and groups, Live Forest). This appends, sheet by sheet in defaults/stsim/manifest.csv order, every
# default row whose Name the library lacks (membership sheets: every missing type-group pair), and the transition simulation groups.
# Existing rows, Ids and scenario data are left as they are; a new row whose Id another row already uses stops the script first.
# Close the library in SyncroSim Studio first. Usage: Rscript tools/add-definitions.R <library.ssim> [--dry-run]
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); pos <- a[!grepl("^--", a)]; if (!length(pos)) stop("usage: Rscript tools/add-definitions.R <library.ssim> [--dry-run]")
dry <- "--dry-run" %in% a
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
rd <- function(...) fread(file.path(pkg, "defaults", ...), colClasses = "character", na.strings = "", encoding = "UTF-8")
L <- ssimLibrary(normalizePath(pos[1], winslash = "/"), summary = FALSE); P <- rsyncrosim::project(L, 1)
man <- rd("stsim", "manifest.csv")[order(as.integer(Order))]
add_n <- 0
for (sheet in man$Datasheet) {
  x <- rd("stsim", paste0(sheet, ".csv")); x <- x[, which(vapply(x, function(v) any(!is.na(v) & nzchar(v)), TRUE)), with = FALSE]
  have <- suppressWarnings(as.data.table(datasheet(P, sheet, optional = TRUE, lookupsAsFactors = FALSE)))
  new <- if ("Name" %in% names(x)) x[!Name %in% have$Name] else if (all(c("TransitionTypeId", "TransitionGroupId") %in% names(x)))
    x[!paste(TransitionTypeId, TransitionGroupId) %in% paste(have$TransitionTypeId, have$TransitionGroupId)] else x[0]
  if (!nrow(new)) next
  if ("Id" %in% names(new) && "Id" %in% names(have)) { cl <- new[as.numeric(Id) %in% as.numeric(have$Id)]
    if (nrow(cl)) stop(sprintf("%s: new rows' Ids are used by other rows of the library (%s)", sheet, paste(head(cl$Name, 3), collapse = ", "))) }
  for (k in intersect(c("Id", "AgeMin", "AgeMax", "Frequency", "MaximumAge"), names(new))) set(new, j = k, value = as.numeric(new[[k]]))
  keep <- intersect(names(new), names(have)); if (!length(keep)) keep <- names(new)
  cat(sprintf("%-34s %3d rows to add: %s%s\n", sheet, nrow(new), paste(head(if ("Name" %in% names(new)) new$Name else paste(new[[1]], new[[2]], sep = " / "), 3), collapse = "; "), if (nrow(new) > 3) " ..." else ""))
  if (!dry) saveDatasheet(P, as.data.frame(new[, ..keep]), sheet, append = TRUE)
  add_n <- add_n + nrow(new) }
sgt <- unique(c(rd("stsim", "stsim_TransitionSimulationGroup.csv")$TransitionGroupId, rd("stsim", "stsim_TransitionSimulationGroup-types.csv")$TransitionGroupId))
have <- suppressWarnings(as.data.table(datasheet(P, "stsim_TransitionSimulationGroup", optional = TRUE, lookupsAsFactors = FALSE)))
sg <- setdiff(sgt, have$TransitionGroupId); if (length(sg)) { cat(sprintf("%-34s %3d rows to add: %s\n", "stsim_TransitionSimulationGroup", length(sg), paste(sg, collapse = "; ")))
  if (!dry) saveDatasheet(P, data.frame(TransitionGroupId = sg), "stsim_TransitionSimulationGroup", append = TRUE); add_n <- add_n + length(sg) }
cat(sprintf("%s %d rows%s\n", if (dry) "would add" else "added", add_n, if (dry) " (dry run)" else ""))
