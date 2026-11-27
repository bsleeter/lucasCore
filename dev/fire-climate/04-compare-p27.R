# =============================================================================
# 04-compare-p27.R - to-do 9: projections with the fire years from climate (the analog draw) against the same projections with the
# setup's random draw, by SSP: burned area, fire emissions and carbon, read straight from the library (SQLite, read-only)
# =============================================================================
# Usage: Rscript dev/fire-climate/04-compare-p27.R <library.ssim> <out folder> --pairs="SSP2-4.5:26:41,SSP5-8.5:18:39" [--iterations=5]
#   --pairs   label:random-draw projection result:analog projection result, comma-separated
# Writes compare-years.csv, compare-summary.csv and compare-burned.png; prints the summary.
# =============================================================================
suppressPackageStartupMessages({ library(data.table); library(ggplot2) }); options(width = 200)
a <- commandArgs(TRUE); opt <- function(k, d) { m <- grep(sprintf("^--%s=", k), a, value = TRUE); if (length(m)) sub(sprintf("^--%s=", k), "", m[1]) else d }
pos <- a[!grepl("^--", a)]; lib <- pos[1]; odir <- pos[2]; dir.create(odir, showWarnings = FALSE, recursive = TRUE)
pr <- rbindlist(lapply(strsplit(strsplit(opt("pairs", ""), ",")[[1]], ":"), function(x) data.table(ssp = x[1], random = as.integer(x[2]), analog = as.integer(x[3]))))
con <- DBI::dbConnect(RSQLite::SQLite(), lib, flags = RSQLite::SQLITE_RO); on.exit(DBI::dbDisconnect(con)); q <- function(s) as.data.table(DBI::dbGetQuery(con, s))
ids <- paste(c(pr$random, pr$analog), collapse = ",")
# burned area (hectares) by run, iteration and year: the three severity types
ba <- q(sprintf("select o.ScenarioId, o.Iteration, o.Timestep, g.Name, sum(o.Amount) ha from stsim_OutputStratumTransition o join stsim_TransitionGroup g on g.TransitionGroupId = o.TransitionGroupId
  where o.ScenarioId in (%s) and g.Name like 'Fire: %% Severity [Type]' group by o.ScenarioId, o.Iteration, o.Timestep, g.Name", ids))
# fire emissions (t C): the LULC: Emission flow group on the fire transition types
fe <- q(sprintf("select o.ScenarioId, o.Iteration, o.Timestep, sum(o.Amount) tc from stsim_OutputFlow o join stsim_FlowGroup f on f.FlowGroupId = o.FlowGroupId join stsim_TransitionType t on t.TransitionTypeId = o.TransitionTypeId
  where o.ScenarioId in (%s) and f.Name = 'LULC: Emission' and t.Name like 'Fire: %%' group by o.ScenarioId, o.Iteration, o.Timestep", ids))
nb <- q(sprintf("select o.ScenarioId, o.Iteration, o.Timestep, sum(o.Amount) tc from stsim_OutputFlow o join stsim_FlowGroup f on f.FlowGroupId = o.FlowGroupId
  where o.ScenarioId in (%s) and f.Name = 'Net Biome Productivity' group by o.ScenarioId, o.Iteration, o.Timestep", ids))
te <- q(sprintf("select o.ScenarioId, o.Iteration, o.Timestep, sum(o.Amount) tc from stsim_OutputStock o join stsim_StockGroup g on g.StockGroupId = o.StockGroupId
  where o.ScenarioId in (%s) and g.Name = 'Total Ecosystem' group by o.ScenarioId, o.Iteration, o.Timestep", ids))
lab <- rbind(pr[, .(ScenarioId = random, ssp, draw = "Random draw (no climate)")], pr[, .(ScenarioId = analog, ssp, draw = "Climate analog draw")])
yr <- merge(merge(ba[, .(km2 = sum(ha) / 100, high = sum(ha[grepl("High", Name)]) / 100), by = .(ScenarioId, Iteration, Timestep)], fe[, .(ScenarioId, Iteration, Timestep, fire_tc = tc)], all = TRUE, by = c("ScenarioId", "Iteration", "Timestep")),
            nb[, .(ScenarioId, Iteration, Timestep, nbp_tc = tc)], all = TRUE, by = c("ScenarioId", "Iteration", "Timestep"))
for (k in c("km2", "high", "fire_tc")) yr[is.na(get(k)), (k) := 0]
yr <- merge(yr, lab, by = "ScenarioId"); fwrite(yr, file.path(odir, "compare-years.csv"))
y0 <- min(yr$Timestep); yN <- max(te$Timestep)
s1 <- yr[, .(burned_km2_yr = mean(km2), burned_sd_between_iterations = sd(.SD[, sum(km2), by = Iteration]$V1 / uniqueN(Timestep)), high_share = sum(high) / sum(km2),
             fire_emission_TgC = sum(fire_tc) / uniqueN(Iteration) / 1e6, nbp_TgC = sum(nbp_tc, na.rm = TRUE) / uniqueN(Iteration) / 1e6), by = .(ssp, draw)]
s2 <- merge(te[Timestep == yN, .(ScenarioId, Iteration, tc)], lab, by = "ScenarioId")[, .(total_ecosystem_end_TgC = mean(tc) / 1e6), by = .(ssp, draw)]
sm <- merge(s1, s2, by = c("ssp", "draw"))[order(ssp, -draw)]; fwrite(sm, file.path(odir, "compare-summary.csv"))
cat(sprintf("Projection years %d-%d, mean over iterations (%s)\n", y0, max(yr$Timestep), paste(sprintf("%s: %d iterations", lab$ScenarioId, yr[, uniqueN(Iteration), by = ScenarioId][match(lab$ScenarioId, ScenarioId), V1]), collapse = "; ")))
print(sm[, lapply(.SD, function(v) if (is.numeric(v)) signif(v, 4) else v)])
dd <- yr[, .(km2 = mean(km2)), by = .(ssp, draw, Timestep)]
ragg::agg_png(file.path(odir, "compare-burned.png"), width = 2400, height = 1300, res = 220, background = "#fcfcfb")
print(ggplot(dd, aes(Timestep, km2, colour = draw)) + geom_line(linewidth = 0.7) + geom_point(size = 1.6, stroke = 0) + facet_wrap(~ ssp, ncol = 2) +
  scale_colour_manual(values = c(`Climate analog draw` = "#eb6834", `Random draw (no climate)` = "#1baf7a")) + scale_y_continuous(labels = scales::label_comma()) +
  labs(title = "Pyrome 27: projected burned area, fire years from climate against random", subtitle = sprintf("ACCESS-CM2, mean of the iterations, %d-%d", y0, max(dd$Timestep)), x = NULL, y = "Burned area (km2)") +
  theme_minimal(base_size = 11) + theme(legend.position = "top", legend.title = element_blank(), panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
    plot.background = element_rect(fill = "#fcfcfb", colour = NA), strip.text = element_text(face = "bold", size = 11), plot.title = element_text(face = "bold")))
invisible(dev.off()); cat("wrote", file.path(odir, "compare-burned.png"), "\n")
