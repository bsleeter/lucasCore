# To-do 57: give a Lassen Projection Setup scenario the step 8 test's surfaces (only Reforestation fitted, the others None: Lassen
# has too few urbanization events to fit, to-do 60), its suitability options, and one iteration.
# Usage: Rscript dev/reforestation/lassen-setup-options.R <setup scenario id> [<scenario to copy from, default 16>]
suppressPackageStartupMessages(library(rsyncrosim))
a <- as.integer(commandArgs(TRUE)); from <- if (length(a) > 1) a[2] else 16L
L <- ssimLibrary("F:/lucasCore/dev/libs/lassen/Lassen.ssim", summary = FALSE); S <- scenario(L, a[1]); F <- scenario(L, from)
for (n in c("lucasCore_ProjectionAllocation", "lucasCore_SuitabilityOptions")) saveDatasheet(S, datasheet(F, n, empty = FALSE), n)
p <- datasheet(S, "lucasCore_ProjectionOptions", empty = FALSE); if (nrow(p)) { p$Iterations <- 1L; saveDatasheet(S, p, "lucasCore_ProjectionOptions") }
al <- datasheet(S, "lucasCore_ProjectionAllocation", empty = FALSE)
cat(sprintf("scenario %d: %d allocation rows, fitted: %s; iterations %s\n", a[1], nrow(al), paste(al$TransitionGroupId[grepl("^Fitted", al$Method)], collapse = ", "),
            datasheet(S, "lucasCore_ProjectionOptions", empty = FALSE)$Iterations))
