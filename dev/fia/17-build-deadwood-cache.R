# =============================================================================
# 17-build-deadwood-cache.R - build the FIA dead wood cache (src/fia.R fia_dead_wood: DWM conditions and remeasured snags, all states)
# outside SyncroSim, so stage 3 finds it ready. Usage: Rscript dev/fia/17-build-deadwood-cache.R
# =============================================================================
suppressPackageStartupMessages(library(data.table))
say <- function(...) cat(sprintf(...), "\n"); fail <- function(...) stop(sprintf(...), call. = FALSE)
source("F:/lucasCore/src/fia.R")
dm <- "F:/lucas-master/Data Sources/FIA/DataMart"
con <- DBI::dbConnect(RSQLite::SQLite(), "F:/lucasCore/dev/libs/LUCAS P26 Demo Library.ssim", flags = RSQLite::SQLITE_RO)
eco <- DBI::dbGetQuery(con, "SELECT EcodivisionFile FROM lucasCore_DataSource")$EcodivisionFile; DBI::dbDisconnect(con)
base <- fia_datamart(dm, eco); dw <- fia_dead_wood(dm, base)
cat(sprintf("DWM conditions %d (%d states), remeasured snags %d\n", nrow(dw$dwm), length(dw$states), nrow(dw$fall)))
print(dw$dwm[, .N, by = .(has_age = !is.na(stdage))]); print(summary(dw$dwm[, .(cwd, fwd, litter, duff, standing)]))
