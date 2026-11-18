# Unit test: the Wood Products page's diagram model (ui/WoodProductsFate.cs, C#) against src/wood-products.R.
# The diagram follows 100 units of harvested carbon of one region, wood type and log size with the published values, the tables
# held at their last year and the page's levers in full effect. The same case here: one removal row in a year past the tables' end,
# through wp_inputs and wp_pools with wp_levers from that year. The C# values come from tests/wood-products-fate.ps1, which loads
# lucasCoreUI.dll (the package's, or the one given: a build made with tools/build_ui.ps1 -Out while Studio has the package's open).
# Usage: Rscript tests/unit-wood-products-fate.R [lucasCoreUI.dll [diagram.png]]   (from the package folder; Windows)
suppressPackageStartupMessages(library(data.table))
source(file.path("src", "wood-products.R"))
a <- commandArgs(TRUE); dll <- if (length(a)) a[1] else "lucasCoreUI.dll"; png <- if (length(a) > 1) a[2] else ""
n_ok <- 0; n_bad <- 0
check <- function(what, ok) { if (isTRUE(ok)) n_ok <<- n_ok + 1 else { n_bad <<- n_bad + 1; cat("FAIL", what, "\n") } }
P <- wp_params(); C <- wp_draws(P, central = TRUE); Y0 <- 2030L

cases <- rbind(
  data.table(Case = "PWW softwood sawlog, defaults", Region = "PWW", Wood = "SW", LogSize = "Sawlog", Years = 50L, Long = NA, Life = NA, Energy = NA, RecWood = NA, RecPaper = NA, DiscEnergy = NA),
  data.table(Case = "PWW softwood sawlog, every lever", Region = "PWW", Wood = "SW", LogSize = "Sawlog", Years = 50L, Long = 0.4, Life = 1.25, Energy = 0.1, RecWood = 0.3, RecPaper = 0.7, DiscEnergy = 0.2),
  data.table(Case = "PWW softwood pulpwood, long-lived shift (no solid wood: softwood lumber's building mix)", Region = "PWW", Wood = "SW", LogSize = "Pulpwood", Years = 30L, Long = 0.5, Life = NA, Energy = NA, RecWood = NA, RecPaper = NA, DiscEnergy = NA),
  data.table(Case = "SE hardwood pulpwood, energy and recovery", Region = "SE", Wood = "HW", LogSize = "Pulpwood", Years = 100L, Long = NA, Life = NA, Energy = 0.5, RecWood = NA, RecPaper = 0.8, DiscEnergy = NA),
  data.table(Case = "NE hardwood sawlog, the harvest year", Region = "NE", Wood = "HW", LogSize = "Sawlog", Years = 0L, Long = 0.2, Life = 0.8, Energy = NA, RecWood = NA, RecPaper = NA, DiscEnergy = 0.5),
  data.table(Case = "RMN softwood sawlog, lifetime only", Region = "RMN", Wood = "SW", LogSize = "Sawlog", Years = 75L, Long = NA, Life = 2, Energy = NA, RecWood = NA, RecPaper = NA, DiscEnergy = NA))

r_side <- function(k) {
  Pk <- P; L <- wp_levers(from = Y0, long = k$Long, life = k$Life, energy = k$Energy, rec_wood = k$RecWood, rec_paper = k$RecPaper, disc_energy = k$DiscEnergy)
  if (L$active) Pk$levers <- L
  years <- Y0 + 0:k$Years
  x <- data.table(Iteration = 1L, Year = Y0, Region = k$Region, Wood = k$Wood, LogSize = k$LogSize, Cause = "Harvest", Source = "Run", Carbon = 100)
  inp <- wp_inputs(x, Pk, C, 1L, years); pl <- wp_pools(inp, Pk, C, 1L, years); o <- pl$out; n <- length(years)
  h <- P$half_life$HalfLife[match(P$end_uses, P$half_life$EndUse)]
  data.table(Case = k$Case, InUse = sum(pl$inuse[n, ]), Buildings = sum(pl$inuse[n, h >= WP_LONG_LIFE]), Paper = pl$inuse[n, WP_PAPER_USE], Recovered = o[n, "Recovered"],
             Landfill = o[n, "LandfillDecaying"] + o[n, "LandfillFixed"], Dump = o[n, "Dump"], EmitEnergy = sum(o[, "EmittedEnergy"]), EmitNo = sum(o[, "EmittedNoEnergy"]),
             AtHarvest = inp$emit_ec[1], Made = sum(inp$eu_in[1, ]) + inp$loss_wood[1] + inp$loss_paper[1], Discarded = sum(o[, "Discarded"]))
}
R <- rbindlist(lapply(seq_len(nrow(cases)), function(i) r_side(cases[i])))
check("R: every case adds to 100 (stored + emitted)", all(abs(R$InUse + R$Recovered + R$Landfill + R$Dump + R$EmitEnergy + R$EmitNo - 100) < 1e-9))

if (!file.exists(dll)) { cat(sprintf("no %s: the C# side was not compared (build it with tools/build_ui.ps1)\n", dll))
} else {
  fin <- tempfile(fileext = ".csv"); fout <- tempfile(fileext = ".csv"); fwrite(cases, fin, na = "")
  args <- c("-ExecutionPolicy", "Bypass", "-File", shQuote(file.path("tests", "wood-products-fate.ps1")), "-Dll", shQuote(normalizePath(dll)),
            "-Dir", shQuote(normalizePath(file.path("defaults", "wood-products"))), "-Cases", shQuote(fin), "-Out", shQuote(fout), if (nzchar(png)) c("-Png", shQuote(png)))
  st <- system2("powershell", args)
  check("the C# model runs", st == 0 && file.exists(fout))
  if (file.exists(fout)) { S <- fread(fout)
    for (v in setdiff(names(R), "Case")) { d <- max(abs(S[[v]] - R[[v]]))
      check(sprintf("C# = R for %s in all %d cases (largest difference %.2g)", v, nrow(R), d), d < 1e-9) }
    print(cbind(R[, .(Case = substr(Case, 1, 34))], round(R[, .(InUse, Recovered, Landfill, EmitEnergy, EmitNo)], 2), CsInUse = round(S$InUse, 2))) }
}
cat(sprintf("%d passed, %d failed\n", n_ok, n_bad)); if (n_bad) quit(status = 1)
