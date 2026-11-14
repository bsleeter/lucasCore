# To-do 58 test (user 2026-11-13: "rebuild the UI and run the Lassen test"): a Projection Setup with Management Actions on a Lassen
# Build and historical run, and its projection, to compare with the baseline projection of dev/reforestation/lassen-chain.sh.
# Replanting 300 ha a year (survival 0.8, pile and burn, far from live forest first) and salvage 200 ha a year, 2024-2050. A national
# park would do neither: this tests the mechanics.
# Usage: Rscript dev/management/lassen-management.R <Build result> <historical result> <baseline projection result>
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- as.integer(commandArgs(TRUE)); B <- a[1]; H <- a[2]; P0 <- a[3]
LIB <- "F:/lucasCore/dev/libs/lassen/Lassen.ssim"; R <- file.path(R.home("bin"), "Rscript.exe")
sh <- function(...) { o <- system2(R, c(...), stdout = TRUE, stderr = TRUE); tail(grep("^[0-9]+$", trimws(o), value = TRUE), 1) }
SS <- as.integer(sh("tools/new-projection-setup.R", LIB, sprintf("--build=%d", B), sprintf("--historical=%d", H), "--resolution=150", "--end=2050",
                    "--name=\"Projection Setup management test\"", "--replace"))
invisible(system2(R, c("dev/reforestation/lassen-setup-options.R", SS), stdout = TRUE, stderr = TRUE))
L <- ssimLibrary(LIB, summary = FALSE); S <- scenario(L, SS)
saveDatasheet(S, data.frame(ActionId = c("Replanting", "Salvage logging"), Amount = c(300, 200), StartYear = 2024L, EndYear = 2050L,
                            Priority = c("Far from live forest (least likely to return on its own)", NA), Survival = c(0.8, NA),
                            SitePreparation = c("Pile and burn", NA)), "lucasCore_ManagementAction")
cat("setup scenario", SS, "\n"); r <- run(S); cat("SETUP RESULT", scenarioId(r), "\n")
x <- runLog(r); cat(grep("Management Actions|10 Transition Suitability - |9 Projection Transitions - ", x, value = TRUE), sep = "\n")
print(datasheet(r, "lucasCore_OutputManagementAction"))
PS <- as.integer(sh("tools/new-projection.R", LIB, sprintf("--build=%d", scenarioId(r)), "--years=27", "--iterations=1", "--name=\"Projection 2024-2050 management test\"", "--replace"))
p <- run(scenario(L, PS)); cat("PROJECTION RESULT", scenarioId(p), "\n")
# compare with the baseline: transitions and carbon
tr <- function(id) { d <- as.data.table(datasheet(scenario(L, id), "stsim_OutputStratumTransition"))
  d[!grepl("[Type]", TransitionGroupId, fixed = TRUE) & Timestep > 2023, .(ha = round(sum(Amount))), by = TransitionGroupId] }
cmp <- merge(tr(P0), tr(scenarioId(p)), by = "TransitionGroupId", all = TRUE, suffixes = c(".baseline", ".management")); print(cmp[order(-ha.management)])
ty <- as.data.table(datasheet(scenario(L, scenarioId(p)), "stsim_OutputStratumTransition"))[grepl("Management|Salvage", TransitionGroupId) & grepl("[Type]", TransitionGroupId, fixed = TRUE)]
print(dcast(ty[, .(ha = round(sum(Amount))), by = .(Timestep, g = sub(" \\[Type\\]", "", TransitionGroupId))], Timestep ~ g, value.var = "ha", fill = 0))
st <- function(id) { d <- as.data.table(datasheet(scenario(L, id), "stsim_OutputStratumState"))
  d[Timestep %in% c(2023, 2030, 2040, 2050), .(forest = round(sum(Amount[grepl("^Forest:", StateClassId)])), disturbed_forest = round(sum(Amount[grepl("^Disturbed", StateClassId) & grepl("Group", StateClassId)]))), by = Timestep] }
cat("disturbed forest, baseline:\n"); print(st(P0)); cat("disturbed forest, management:\n"); print(st(scenarioId(p)))
cs <- function(id) { d <- as.data.table(datasheet(scenario(L, id), "stsim_OutputStock"))
  d[Timestep %in% c(2023, 2030, 2040, 2050), .(TgC = round(sum(Amount) / 1e6, 3)), by = .(Timestep, g = sub(":.*", "", StockGroupId))] }
cat("carbon (Tg C) by pool group, baseline vs management:\n"); print(merge(cs(P0), cs(scenarioId(p)), by = c("Timestep", "g"), suffixes = c(".base", ".mgmt")))
# the management maps (transition maps by group and year): the replanting family, its types, salvage
sp <- as.data.table(datasheet(scenario(L, scenarioId(p)), "stsim_OutputSpatialTransition", lookupsAsFactors = FALSE))
if (nrow(sp)) { cat("transition maps written for management groups:\n"); print(sp[grepl("Replant|Salvage", TransitionGroupId), .(maps = .N, years = paste(range(Timestep), collapse = "-")), by = TransitionGroupId]) } else cat("no transition maps (transition map output off)\n")
# costs (transition attributes): the ST-Sim total per year against hectares treated x cost per hectare
cat("cost values written by stage 9:\n"); print(datasheet(r, "stsim_TransitionAttributeValue"))
ta <- as.data.table(datasheet(scenario(L, scenarioId(p)), "stsim_OutputTransitionAttribute", lookupsAsFactors = FALSE))
cat("transition attribute output (USD) by year and type:\n"); print(dcast(ta[, .(USD = round(sum(Amount))), by = .(Timestep, TransitionAttributeTypeId)], Timestep ~ TransitionAttributeTypeId, value.var = "USD"))
cd <- setNames(fread("defaults/management/costs.csv")$CostPerHa, fread("defaults/management/costs.csv")$Item)
ha <- ty[, .(rep = sum(Amount[grepl("Replanting", TransitionGroupId)]), sal = sum(Amount[grepl("Salvage", TransitionGroupId)])), by = Timestep]
ex <- ha[, .(Timestep, Planting = rep * cd[["Planting"]], Prep = rep * cd[["Site preparation: Pile and burn"]], Salvage = sal * cd[["Salvage logging"]])]
cat("expected (ha x default cost per ha):\n"); print(ex[order(Timestep)])
