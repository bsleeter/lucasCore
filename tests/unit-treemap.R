# =============================================================================
# unit-treemap.R - fast checks of src/treemap.R (to-do 35 step 1), no SyncroSim run
# =============================================================================
#   1. fia_sites: every state's forested conditions with site class; the second call reads the cache and gives the same table
#   2. treemap_plots on a made-up attribute table: TreeMap's type wins over a larger condition; otherwise the largest; a plot FIA
#      does not have stays unmatched
#   3. P26 (read only): TreeMap over the latest P26 Build's study area reproduces phase 0 (21.0 M pixels, every one joined with a
#      site class, stand age on about 94.5%, 6,377 plots)
# Usage: Rscript tests/unit-treemap.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(terra) }); pkg <- "F:/lucasCore"; ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
source(file.path(pkg, "src", "treemap.R"))
dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; tmd <- "F:/lucas-master/Data Sources/TreeMap/Data"

# 1. the site cache
t0 <- Sys.time(); s1 <- fia_sites(dm); t1 <- as.numeric(Sys.time() - t0, units = "secs")
t0 <- Sys.time(); s2 <- fia_sites(dm); t2 <- as.numeric(Sys.time() - t0, units = "secs")
expect("fia_sites: forested conditions of 48 states", s1[, uniqueN(st)] == 48 && nrow(s1) > 500000, sprintf("%d conditions, %d states", nrow(s1), s1[, uniqueN(st)]))
expect("fia_sites: site classes are 1-7", all(s1$siteclcd %in% c(1:7, NA)), paste(sort(unique(s1$siteclcd)), collapse = " "))
expect("fia_sites: forest type group for every typed condition", s1[!is.na(fortypcd) & fortypcd > 0, mean(!is.na(fortyp_grp))] > 0.999)
expect("fia_sites: the second call reads the cache, same table", isTRUE(all.equal(s1, s2, check.attributes = FALSE)) && t2 < t1, sprintf("%.0f s, then %.1f s", t1, t2))

# 2. the condition choice, on a made-up attribute table
td <- file.path(tempdir(), "tm"); dir.create(td, showWarnings = FALSE)
writeRaster(rast(nrows = 1, ncols = 3, vals = 1:3), file.path(td, "TreeMap2016.tif"), overwrite = TRUE)
foreign::write.dbf(data.frame(Value = 1:3, CN = c("A", "B", "C"), FORTYPCD = c(201L, 371L, 221L)), file.path(td, "TreeMap2016.tif.vat.dbf"))
fs <- data.table(plt_cn = c("A", "A", "B", "B"), condid = c(1L, 2L, 1L, 2L), condprop = c(0.7, 0.3, 0.4, 0.6), fortypcd = c(221L, 201L, 261L, 281L),
                 fortyp_grp = c(220L, 200L, 260L, 280L), stdage = c(40L, 80L, 60L, 90L), siteclcd = c(5L, 3L, 4L, 6L), st = "CA")
p <- treemap_plots(td, 1:3, fs)
expect("TreeMap's type wins over a larger condition", p[Value == 1, condid == 2 && matched && siteclcd == 3])
expect("no condition of TreeMap's type: the largest", p[Value == 2, condid == 2 && !matched && stdage == 90])
expect("a plot FIA does not have stays unmatched", p[Value == 3, is.na(condid) && !matched])

# 3. P26
lib <- file.path(pkg, "dev/libs/LUCAS P26 Northern Sierra Nevada.ssim")
if (file.exists(lib)) {
  con <- DBI::dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO)
  ic <- DBI::dbGetQuery(con, "SELECT ScenarioId, StratumFileName FROM stsim_InitialConditionsSpatial WHERE StratumFileName IS NOT NULL ORDER BY ScenarioId DESC LIMIT 1"); DBI::dbDisconnect(con)
  P <- rast(file.path(paste0(lib, ".data"), paste0("Scenario-", ic$ScenarioId), "stsim_InitialConditionsSpatial", ic$StratumFileName))
  t0 <- Sys.time(); x <- treemap_crop(tmd, P); x <- mask(x, project(P, x, method = "near"))
  px <- as.data.table(freq(x))[, .(Value = as.integer(value), n = count)]
  pl <- treemap_plots(tmd, px$Value, s1); cv <- treemap_coverage(px, pl)
  cat(sprintf("P26: %.1f M pixels, %d plots, joined %.1f%%, TreeMap's type %.1f%%, site class %.1f%%, stand age %.1f%% (%.1f min)\n", cv$pixels / 1e6, cv$plots,
              100 * cv$joined, 100 * cv$matched, 100 * cv$site, 100 * cv$age, as.numeric(Sys.time() - t0, units = "mins")))
  expect("P26: phase 0's coverage (21.0 M pixels, all joined with a site class, ~94.5% with an age, 6,377 plots)",
         abs(cv$pixels / 1e6 - 21.0) < 0.1 && cv$joined > 0.999 && cv$site > 0.999 && abs(cv$age - 0.945) < 0.005 && cv$plots == 6377)
} else cat("SKIP  P26 check: no", lib, "\n")
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
