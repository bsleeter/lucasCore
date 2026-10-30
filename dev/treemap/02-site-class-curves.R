# =============================================================================
# 02-site-class-curves.R - to-do 35 phase 0 (a): does FIA site class explain carbon at age around stage 2's OWN curves?
# =============================================================================
# The fitting plots exactly as stage 2 filters them (src/carbon.R carbon_data on the FIA cache, the P26 Build's Growth Options), each
# plot's live carbon divided by the carbon curve of its forest type and ecodivision at its age (lucasCore_CarbonCurve of the latest P26
# Build result, all 19 ecodivisions), and its condition's SITECLCD from every state's DataMart COND. For each forest type (all
# ecodivisions, then P26's two) and site class: plots, mean ratio, the multiplier m = mean ratio / the type's mean ratio (so the
# plot-weighted mean of m is 1), and how much of the variance of log(carbon / curve) site class explains.
# Writes dev/treemap/out/site-class-ratios.csv and prints the summary. Read only.
# Usage: Rscript dev/treemap/02-site-class-curves.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table) })
pkg <- "F:/lucasCore"; dm <- "F:/lucas-master/Data Sources/FIA/DataMart"; out <- file.path(pkg, "dev/treemap/out"); dir.create(out, showWarnings = FALSE)
lib <- file.path(pkg, "dev/libs/LUCAS P26 Northern Sierra Nevada.ssim")
source(file.path(pkg, "src", "carbon.R"))
con <- DBI::dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO)
bid <- DBI::dbGetQuery(con, "SELECT MAX(ScenarioId) id FROM lucasCore_CarbonCurve")$id
cc <- as.data.table(DBI::dbGetQuery(con, sprintf("SELECT * FROM lucasCore_CarbonCurve WHERE ScenarioId = %d", bid)))
go <- as.data.table(DBI::dbGetQuery(con, sprintf("SELECT * FROM lucasCore_GrowthOptions WHERE ScenarioId = %d", bid)))
st <- as.data.table(DBI::dbGetQuery(con, "SELECT StratumId, Name, Id FROM stsim_Stratum"))
sc <- as.data.table(DBI::dbGetQuery(con, "SELECT StateClassId, Name FROM stsim_StateClass"))
p26 <- as.data.table(DBI::dbGetQuery(con, sprintf("SELECT * FROM lucasCore_OutputStrataSummary WHERE ScenarioId = %d", bid)))
DBI::dbDisconnect(con)
opt <- list(MinInventoryYear = if (nrow(go) && !is.na(go$MinInventoryYear[1])) go$MinInventoryYear[1] else 2000,
            VolumeCapQuantile = if (nrow(go) && !is.na(go$VolumeCapQuantile[1])) go$VolumeCapQuantile[1] else 0.99)
cat(sprintf("P26 Build result %d; Growth Options: MinInventoryYear %s, VolumeCapQuantile %s\n", bid, opt$MinInventoryYear, opt$VolumeCapQuantile))

# curves: library ids -> ecodivision code (as the FIA cache spells it) and FIA forest type group codes
code <- function(id) ifelse(id >= 1000, paste0("M", id %/% 10), as.character(id))
cc[, ecodiv := code(st$Id[match(StratumId, st$StratumId)])][, scname := sub("^Forest: ", "", sc$Name[match(StateClassId, sc$StateClassId)])]
cw <- fread(file.path(pkg, "defaults/growth/forest-type-crosswalk.csv"), colClasses = "character")
grp <- cw[, .(fortyp_grp = as.integer(strsplit(FiaTypeGroups, ";")[[1]])), by = .(scname = StateClassName)]
# a plot belongs to the type whose own group it is; a pooled type (Western White Pine fits 12 western groups) only takes plots no
# single-group type claims
grp[, k := .N, by = scname]; setorder(grp, k)
age_col <- intersect(c("Age", "AgeMin", "StandAge"), names(cc))[1]
cv <- cc[, .(scname, ecodiv, age = get(age_col), curve = TotalLive)]

# fitting plots, as stage 2 filters them
x <- readRDS(file.path(dm, "fia-conditions.rds"))
body(carbon_data)[[length(body(carbon_data))]] <- quote(x[, .(plt_cn, condid, pid, ecodiv, fortyp_grp, stdage, c_live)])   # keep the plot ids; filters as stage 2
d <- carbon_data(x$cond, x$dist, opt)
cat(sprintf("Fitting plots (carbon_data): %d conditions; ecodiv codes %s\n", nrow(d), paste(head(sort(unique(d$ecodiv)), 25), collapse = " ")))
d[, scname := grp$scname[match(fortyp_grp, grp$fortyp_grp)]]
d <- merge(d, cv, by.x = c("scname", "ecodiv", "stdage"), by.y = c("scname", "ecodiv", "age"))
d <- d[curve > 0.5]
cat(sprintf("Matched to a curve value: %d\n", nrow(d)))

# site class from every state's COND
cf <- list.files(dm, "^[A-Z]{2}_COND[.]csv$", full.names = TRUE)
sc_tab <- rbindlist(lapply(cf, function(f) fread(f, select = c("PLT_CN", "CONDID", "SITECLCD"), colClasses = list(character = "PLT_CN"), showProgress = FALSE)))
d <- merge(d, sc_tab, by.x = c("plt_cn", "condid"), by.y = c("PLT_CN", "CONDID"), all.x = TRUE)
cat(sprintf("Site class on %.1f%% of the fitting plots (%d of %d)\n", 100 * mean(!is.na(d$SITECLCD)), sum(!is.na(d$SITECLCD)), nrow(d)))
d <- d[!is.na(SITECLCD) & c_live > 0]
d[, r := c_live / curve]

summ <- function(z, by) {
  z[, rt := mean(r), by = by]
  t <- z[, .(n = .N, mean_ratio = mean(r)), by = c(by, "SITECLCD")]
  t <- merge(t, unique(z[, c(by, "rt"), with = FALSE]), by = by)[, m := mean_ratio / rt][order(get(by[1]), SITECLCD)]
  r2 <- z[, { a <- log(r); b <- tryCatch(summary(lm(a ~ factor(SITECLCD)))$r.squared, error = function(e) NA_real_); .(plots = .N, r2_site = round(b, 3), sd_log_ratio = round(sd(a), 2)) }, by = by]
  list(t = t, r2 = r2) }

big <- d[, .N, by = scname][N >= 200, scname]
a <- summ(d[scname %in% big], "scname")
cat("\n== By forest type, all ecodivisions: share of log(carbon / curve) variance site class explains ==\n"); print(a$r2[order(-plots)])
w <- dcast(a$t[n >= 20], scname ~ SITECLCD, value.var = "m"); setnames(w, -1, paste0("sc", names(w)[-1]))
cat("\n== Multiplier m by site class (classes with >= 20 plots), all ecodivisions ==\n"); print(w[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])

pe <- code(st$Id[match(unique(p26[Level == "Primary", Id]), st$Id)])
pe <- unique(code(as.integer(p26[Level == "Primary", Id])))
cat(sprintf("\nP26 ecodivisions: %s\n", paste(pe, collapse = ", ")))
pp <- d[ecodiv %in% pe]; big2 <- pp[, .N, by = .(scname, ecodiv)][N >= 50]
b <- summ(pp[paste(scname, ecodiv) %in% big2[, paste(scname, ecodiv)]], c("scname", "ecodiv"))
cat("== P26 ecodivisions, type x ecodivision with >= 50 plots ==\n"); print(b$r2[order(-plots)])
w2 <- dcast(b$t[n >= 15], scname + ecodiv ~ SITECLCD, value.var = "m"); setnames(w2, -(1:2), paste0("sc", names(w2)[-(1:2)]))
print(w2[, lapply(.SD, function(v) if (is.numeric(v)) round(v, 2) else v)])
fwrite(rbind(a$t[, level := "type"], b$t[, level := "type x ecodivision"], fill = TRUE), file.path(out, "site-class-ratios.csv"))
cat("\nwrote", file.path(out, "site-class-ratios.csv"), "\n")
