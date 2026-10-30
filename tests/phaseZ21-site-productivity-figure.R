# =============================================================================
# phaseZ21-site-productivity-figure.R - to-do 35 step 7: stage 12 maps site productivity (2026-10-30)
# =============================================================================
# On the test library lucasCore-suitability.ssim: stage 12 alone, as its own scenario depending on the newest "Build test (site
# productivity)" result (tests/phaseZ20-site-productivity-build.R), then on the off Build. Checks: stage 12's checks pass; the on Build
# draws a "Site productivity" figure (a PNG), the off Build none.
# Usage: Rscript tests/phaseZ21-site-productivity-figure.R
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
f <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim"; L <- suppressWarnings(ssimLibrary(f)); P1 <- rsyncrosim::project(L, 1); ok <- TRUE
expect <- function(what, cond, detail = "") { cat(sprintf("%s  %s %s\n", if (isTRUE(cond)) "PASS" else "FAIL", what, detail)); if (!isTRUE(cond)) ok <<- FALSE }
sc <- as.data.table(scenario(L, summary = TRUE))
newest <- function(nm) max(sc[IsResult == "Yes" & (Name == nm | startsWith(Name, paste0(nm, " ([")))]$ScenarioId)
figures <- function(k, bid) { nm <- sprintf("Build Figures test (site productivity %s)", k)
  for (id in sc[IsResult == "No" & Name == nm, ScenarioId]) delete(L, scenario = id, force = TRUE)
  S <- scenario(P1, nm); dependency(S) <- bid
  saveDatasheet(S, data.frame(StageNameId = "12 - Build Figures", RunOrder = 1L), "core_Pipeline")
  t0 <- Sys.time(); R <- run(S); cat(sprintf("%s (Build %d): %.1f min\n", k, bid, as.numeric(Sys.time() - t0, units = "mins")))
  lg <- trimws(strsplit(paste(runLog(R), collapse = "\n"), "\n")[[1]]); cat(unique(lg[grepl("figures drawn|Site productivity", lg)]), sep = "\n")
  v <- as.data.table(datasheet(R, "lucasCore_OutputValidation"))[Stage == "12 Build Figures"]
  expect(sprintf("%s: stage 12 checks pass", k), nrow(v) > 0 && all(v$Status == "Pass"), paste(v[Status != "Pass", paste(Check, Detail)], collapse = "; "))
  as.data.table(datasheet(R, "lucasCore_OutputBuildFigure", lookupsAsFactors = FALSE)) }
on <- figures("on", newest("Build test (site productivity)")); off <- figures("off", newest("Build test (site productivity off)"))
sp <- on[Title == "Site productivity"]
expect("on: a Site productivity figure, written as a PNG", nrow(sp) == 1 && file.exists(sp$FileName) && identical(readBin(sp$FileName, "raw", 4), as.raw(c(0x89, 0x50, 0x4e, 0x47))), if (nrow(sp)) sp$FileName else "")
expect("off: no Site productivity figure", !nrow(off[Title == "Site productivity"]))
if (nrow(sp)) file.copy(sp$FileName, "F:/lucasCore/dev/treemap/out/site-productivity-figure.png", overwrite = TRUE)
cat(if (ok) "\nALL PASS\n" else "\nSOME CHECKS FAILED\n")
