# =============================================================================
# unit-prism-800m.R - the Data Download's PRISM step at 800 m: names, folders, what a run asks, zips saved by hand (2026-11-23)
# =============================================================================
# Plain R, no SyncroSim, no network. Checks that
#   - an item's zip name, address and folder follow PRISM's 800 m ("us_30s") and 4 km ("us_25m") patterns, and a name reads back
#   - a region asks for annual tmean and ppt, their normals and monthly ppt; all of CONUS asks for the five variables, the monthly
#     normals, and every 800 m zip saved by hand under the home
#   - a zip saved by hand (climate/prism-800m-source or supplied/prism-800m) is unpacked, not fetched, and left where it was
#   - in a home that holds the 4 km grids, the 800 m ones land beside them (no editions folder), the 4 km files stay and stay
#     recorded, the manifest row names the 800 m release, and a rerun is up to date
# Usage: Rscript tests/unit-prism-800m.R
# =============================================================================
suppressPackageStartupMessages({ library(data.table) })
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
for (f in c("datahome.R", "download.R", "download-sources.R")) source(file.path(pkg, "src", f))
ok <- 0; bad <- 0
expect <- function(what, cond) { if (isTRUE(cond)) { ok <<- ok + 1; cat("pass:", what, "\n") } else { bad <<- bad + 1; cat("FAIL:", what, "\n") } }

# ---- names, addresses, folders -------------------------------------------------------------------------------------------
a <- prism_items("800 m", "tmean", 2012L); m <- prism_items("800 m", "ppt", 2012L, 7L); n <- prism_items("800 m", "vpdmax", normal = TRUE); nm <- prism_items("800 m", "ppt", mon = 3L, normal = TRUE)
expect("800 m annual: name and address", a$file == "prism_tmean_us_30s_2012.zip" && a$url == "https://data.prism.oregonstate.edu/time_series/us/an/800m/tmean/monthly/2012/prism_tmean_us_30s_2012.zip")
expect("800 m monthly: name and address", m$file == "prism_ppt_us_30s_201207.zip" && m$url == "https://data.prism.oregonstate.edu/time_series/us/an/800m/ppt/monthly/2012/prism_ppt_us_30s_201207.zip")
expect("800 m normals: names and address", n$file == "prism_vpdmax_us_30s_2020_avg_30y.zip" && nm$file == "prism_ppt_us_30s_202003_avg_30y.zip" &&
       nm$url == "https://data.prism.oregonstate.edu/normals/us/800m/ppt/monthly/prism_ppt_us_30s_202003_avg_30y.zip")
expect("800 m folders", identical(prism_dir(rbind(a, m, n, nm)), c("annual-us30s/tmean", "monthly-us30s/ppt", "normals-us30s/vpdmax", "normals-us30s/ppt")))
o <- rbind(prism_items("4 km", "tmean", 2012L), prism_items("4 km", "ppt", 2012L, 7L), prism_items("4 km", "ppt", normal = TRUE))
expect("4 km: the names, addresses and folders of the earlier version", identical(o$file, c("prism_tmean_us_25m_2012.zip", "prism_ppt_us_25m_201207.zip", "prism_ppt_us_25m_2020_avg_30y.zip")) &&
       o$url[1] == "https://data.prism.oregonstate.edu/time_series/us/an/4km/tmean/monthly/2012/prism_tmean_us_25m_2012.zip" &&
       o$url[3] == "https://data.prism.oregonstate.edu/normals/us/4km/ppt/monthly/prism_ppt_us_25m_2020_avg_30y.zip" &&
       identical(prism_dir(o), c("annual-us25m/tmean", "monthly-us25m/ppt", "normals")))
all4 <- rbind(a, m, n, nm); back <- prism_parse(c(all4$file, "readme.zip", "prism_ppt_us_30s_2012.tif"))
expect("a zip's name reads back into the same item", nrow(back) == 4 && identical(back$file, all4$file) && identical(back$url, all4$url) && identical(prism_dir(back), prism_dir(all4)))

# ---- what a run asks ---------------------------------------------------------------------------------------------------------
root <- file.path(tempdir(), "prism-800m"); unlink(root, recursive = TRUE); dir.create(root); root <- normalizePath(root, winslash = "/")
ctx0 <- function(home, poly) list(home = home, region_home = NULL, region = list(box = c(-2100000, 2000000, -2000000, 2100000), poly = poly, units = if (is.null(poly)) "CONUS" else "P26", buffer_km = NA_real_),
  years = c(2001L, 2005L), keep = FALSE, new_editions = FALSE, connections = 1L, opts = data.table(), log = function(x) invisible())
h0 <- file.path(root, "empty"); dir.create(h0)
r <- prism_plan(ctx0(h0, "polygon"))
expect("a region: annual tmean and ppt for its years, the year before and 1991-2020", setequal(r[is.na(mon) & !normal, unique(var)], c("tmean", "ppt")) && setequal(r[is.na(mon) & !normal & var == "tmean", year], c(2000:2005, 1991:2020)))
expect("a region: the two annual normals, no monthly normals", r[normal == TRUE, .N] == 2 && all(is.na(r[normal == TRUE, mon])))
expect("a region: monthly ppt only, from two years before the first year", identical(r[!is.na(mon) & !normal, unique(var)], "ppt") && r[!is.na(mon) & !normal, min(year)] == 1990 && r[!is.na(mon) & !normal & year == 1999, .N] == 12)
expect("a region: every file is 800 m and is fetched when none is on disk", all(grepl("_us_30s_", r$file)) && all(r$fetch) && all(is.na(r$supplied)))
c4 <- ctx0(h0, "polygon"); c4$opts <- data.table(PrismGrid = "4 km"); r4 <- prism_plan(c4)
expect("PrismGrid 4 km: the 4 km files, monthly from 1981", all(grepl("_us_25m_", r4$file)) && r4[!is.na(mon), min(year)] == 1990 && setequal(unique(prism_dir(r4)), c("annual-us25m/ppt", "annual-us25m/tmean", "monthly-us25m/ppt", "normals")))
w <- prism_plan(ctx0(h0, NULL))
expect("all of CONUS: five variables, annual and monthly, with 13 normals each", setequal(unique(w$var), PRISM_VARS) && all(w[normal == TRUE, .N, by = var]$N == 13) && setequal(w[!is.na(mon) & !normal, unique(var)], PRISM_VARS))

# ---- zips saved by hand, in a home that holds the 4 km grids -------------------------------------------------------------------
wtar <- "C:/Windows/System32/tar.exe"
if (!file.exists(wtar)) cat("skip: no Windows tar to make test zips\n") else {
  home <- file.path(root, "home"); src <- file.path(home, "climate/prism-800m-source"); old <- file.path(home, "climate/prism/annual-us25m/tmean")
  dir.create(file.path(src, "tmean"), recursive = TRUE); dir.create(file.path(src, "normals/ppt"), recursive = TRUE); dir.create(file.path(home, "supplied/prism-800m"), recursive = TRUE); dir.create(old, recursive = TRUE)
  mkzip <- function(dir, name) { tmp <- file.path(root, "mk"); unlink(tmp, recursive = TRUE); dir.create(tmp); t <- sub("[.]zip$", "", name)
    writeLines(paste("grid", t), file.path(tmp, paste0(t, ".tif"))); writeLines("side", file.path(tmp, paste0(t, ".xml")))
    system2(wtar, c("-a", "-cf", shQuote(file.path(dir, name)), "-C", shQuote(tmp), paste0(t, ".tif"), paste0(t, ".xml"))); file.exists(file.path(dir, name)) }
  made <- c(mkzip(file.path(src, "tmean"), "prism_tmean_us_30s_1978.zip"), mkzip(file.path(src, "tmean"), "prism_tmean_us_30s_197801.zip"),
            mkzip(file.path(src, "normals/ppt"), "prism_ppt_us_30s_202003_avg_30y.zip"), mkzip(file.path(home, "supplied/prism-800m"), "prism_vpdmax_us_30s_2004.zip"))
  writeLines("not a prism zip", file.path(src, "done.txt"))
  # the 4 km download an earlier version recorded
  writeLines("grid 4 km", file.path(old, "prism_tmean_us_25m_2004.tif"))
  layout <- home_layout(pkg)[Column == "PrismFolder"]; place <- file.path(home, "climate/prism")
  write_files(home, files_rows(home, "PrismFolder", place, sha = TRUE))
  write_manifest(home, data.table(Column = "PrismFolder", Dataset = "PRISM annual climate and normals", Version = "PRISM AN (us_25m, 4 km)", Method = "direct", Copy = "national", Units = "CONUS",
                                  Xmin = -2400000, Ymin = 200000, Xmax = 2300000, Ymax = 3200000, Files = 1, Status = "done"))
  ctx <- ctx0(home, NULL); ctx$place <- place; p <- prism_plan(ctx)
  expect("test zips made", all(made))
  expect("all of CONUS: zips saved by hand are taken from where they are, whatever their year", p[!is.na(supplied), .N] == 4 && all(!p[!is.na(supplied), fetch]) && "prism_tmean_us_30s_1978.zip" %in% p$file &&
         all(file.exists(p[!is.na(supplied), supplied])))
  expect("the plan notes the 4 km grids kept beside", "note" %in% names(p) && grepl("4 km", p$note[1]))
  fetched <- 0; fetch_files <- function(urls, dest, ...) { fetched <<- fetched + length(urls); stop("the test must not fetch") }
  h <- download_handlers()$PrismFolder; plan0 <- h$plan; h$plan <- function(ctx) plan0(ctx)[!is.na(supplied)]   # only what is on disk: no network in a test
  said <- character(); ctx$log <- function(x) said <<- c(said, x)
  r <- run_dataset(h, ctx, layout); mrow <- read_manifest(home)[Column == "PrismFolder"]; fr <- read_files(home)[Column == "PrismFolder"]
  expect("done, by hand, nothing fetched", identical(r$Status, "done") && fetched == 0 && identical(mrow$Method, "by hand"))
  want <- c("annual-us30s/tmean/prism_tmean_us_30s_1978.tif", "monthly-us30s/tmean/prism_tmean_us_30s_197801.tif", "normals-us30s/ppt/prism_ppt_us_30s_202003_avg_30y.tif", "annual-us30s/vpdmax/prism_vpdmax_us_30s_2004.tif")
  expect("each grid is unpacked into its folder beside the 4 km ones, with its sidecar", all(file.exists(file.path(place, want))) && all(file.exists(file.path(place, sub("[.]tif$", ".xml", want)))) &&
         identical(readLines(file.path(place, want[1])), "grid prism_tmean_us_30s_1978"))
  expect("no editions folder, and the staging folder is gone", !dir.exists(file.path(home, "editions")) && !dir.exists(file.path(home, ".staging", "PrismFolder")))
  expect("the 4 km file is untouched and still recorded", identical(readLines(file.path(old, "prism_tmean_us_25m_2004.tif")), "grid 4 km") && "climate/prism/annual-us25m/tmean/prism_tmean_us_25m_2004.tif" %in% fr$Path)
  expect("files.csv lists the nine files with checksums", nrow(fr) == 9 && all(nchar(fr$Sha256) == 64))
  expect("the manifest row names the 800 m release, national, with PRISM's two directories and the note", identical(mrow$Version, "PRISM AN (us_30s, 800 m)") && identical(mrow$Copy, "national") && identical(mrow$Status, "done") &&
         grepl("time_series/us/an", mrow$Url) && grepl("normals/us", mrow$Url) && grepl("4 km", mrow$Note))
  expect("the zips saved by hand are left where they were", all(file.exists(p[!is.na(supplied), supplied])) && file.exists(file.path(src, "done.txt")))
  expect("the log names the folder, not every zip", any(grepl("4 files under|supplied by hand", said)) && max(nchar(said)) < 1000)
  r2 <- run_dataset(h, ctx, layout)
  expect("a rerun is up to date and unpacks nothing", identical(r2$Status, "skipped") && fetched == 0)
  r3 <- run_dataset(h, ctx, layout, check_only = TRUE)
  expect("Check only on the finished home: nothing to download", identical(r3$Status, "skipped"))
}

cat(sprintf("\n%d passed, %d failed\n", ok, bad)); if (bad) quit(status = 1)
