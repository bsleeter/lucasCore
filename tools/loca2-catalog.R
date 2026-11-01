# =============================================================================
# loca2-catalog.R - list the LOCA2 runs UCSD serves: defaults/download/loca2-catalog.csv, the Data Download page's model, scenario and
# member lists
# =============================================================================
# One row per model, member and run (historical, ssp245, ssp370, ssp585) whose monthly pr, tasmax and tasmin files are all there, with
# whether the CONUS (NAmer) tree and the "west" regional cut each have them. Members differ by model (CNRM-ESM2-1 has only f2 ones,
# CESM2-LENS has many), so the page offers only what exists. Crawls the UCSD directory listings (a few minutes, about 2,000 small
# pages). Rerun when UCSD adds runs. Usage: Rscript tools/loca2-catalog.R [--out=defaults/download/loca2-catalog.csv]
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(curl) })
a <- commandArgs(TRUE); oa <- grep("^--out=", a, value = TRUE)
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "tools")
out <- if (length(oa)) sub("^--out=", "", oa[1]) else file.path(here, "..", "defaults", "download", "loca2-catalog.csv")
B <- "https://cirrus.ucsd.edu/~pierce/LOCA2/"
TREES <- c(Conus = "NAmer/%s/0p0625deg/", West = "CONUS_regions_split/%s/west/0p0625deg/")
VARS <- c("pr", "tasmax", "tasmin")

# fetch many listings at once; each page's sub-folder links, or its file links when files = TRUE
# (the server drops some requests under load: a page that fails or is not 200/404 is asked again, up to 5 rounds, else the crawl stops,
# so a missing run in the catalog means UCSD has no files for it, not a dropped request)
listings <- function(urls, files = FALSE) {
  res <- setNames(rep(list(NULL), length(urls)), urls); todo <- urls
  for (round in 1:5) {
    p <- new_pool(host_con = if (round == 1) 4 else 2)
    for (u in todo) local({ uu <- u; multi_add(new_handle(url = uu), pool = p, data = NULL,
      done = function(r) if (r$status_code == 200) res[[uu]] <<- rawToChar(r$content) else if (r$status_code == 404) res[[uu]] <<- "", fail = function(e) NULL) })
    multi_run(pool = p); todo <- urls[vapply(res, is.null, TRUE)]
    if (!length(todo)) break
    cat(sprintf("  %d pages failed; asking again (round %d)\n", length(todo), round + 1)); Sys.sleep(5 * round)
  }
  if (length(todo)) stop(sprintf("%d listings still fail, e.g. %s", length(todo), todo[1]))
  lapply(res, function(x) { pat <- if (files) '(?<=href=")[^"/?]+[.]nc(?=")' else '(?<=href=")[^"/?]+(?=/")'; unique(regmatches(x, gregexpr(pat, x, perl = TRUE))[[1]]) })
}
monthly <- function(f, v) any(grepl(sprintf("^%s[.].*[.](west[.]monthly|monthly[.]west|monthly)[.]nc$", v), f))

models <- listings(paste0(B, "NAmer/"))[[1]]; cat(length(models), "models\n")
rows <- rbindlist(lapply(names(TREES), function(tr) {
  mu <- paste0(B, sprintf(TREES[[tr]], models)); mem <- listings(mu)
  mm <- rbindlist(lapply(seq_along(models), function(i) if (length(mem[[i]])) data.table(Model = models[i], Member = mem[[i]], u = paste0(mu[i], mem[[i]], "/"))))
  rn <- listings(mm$u)
  mr <- rbindlist(lapply(seq_len(nrow(mm)), function(i) { r <- intersect(rn[[i]], c("historical", "ssp245", "ssp370", "ssp585"))
    if (length(r)) data.table(Model = mm$Model[i], Member = mm$Member[i], Scenario = r, u = paste0(mm$u[i], r, "/")) }))
  vu <- CJ(k = seq_len(nrow(mr)), v = VARS)[, url := paste0(mr$u[k], v, "/")]
  fl <- listings(vu$url, files = TRUE); vu[, ok := mapply(monthly, fl, v)]
  ok <- vu[, .(ok = all(ok)), by = k]
  cat(tr, ":", nrow(mm), "model-members,", sum(ok$ok), "of", nrow(mr), "runs with monthly pr, tasmax and tasmin\n")
  mr[ok$k[ok$ok], .(Model, Member, Scenario, Tree = tr)]
}))
cat_ <- dcast(rows, Model + Member + Scenario ~ Tree, fun.aggregate = length, value.var = "Tree")
for (t in names(TREES)) { if (!t %in% names(cat_)) cat_[, (t) := 0L]; set(cat_, j = t, value = ifelse(cat_[[t]] > 0, "yes", "no")) }
setcolorder(cat_, c("Model", "Member", "Scenario", names(TREES))); setorder(cat_, Model, Member, Scenario)
fwrite(cat_, out); cat(sprintf("wrote %s: %d runs, %d models, %d model-members (checked %s)\n", normalizePath(out, winslash = "/"), nrow(cat_),
  uniqueN(cat_$Model), uniqueN(cat_[, .(Model, Member)]), format(Sys.Date())))
