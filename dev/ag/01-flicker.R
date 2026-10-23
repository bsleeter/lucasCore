# =============================================================================
# 01-flicker.R - how much of the 30 m agriculture change in the P26 pyrome is NLCD flicker, 1986-2023
# =============================================================================
# Ag expansion event (stage 10 default) = natural (31, 41-43, 52, 71, 90, 95) the year before -> 81 or 82. A "return" is an event on a
# pixel that was 81/82 in any of the 5 years before the year it was natural. Ag contraction event = 81/82 -> natural; a "bounce" is one
# that is 81/82 again within the next 5 years. Uses the stage 10 cache of the phaseQ setup (P26 region, 30 m).
# =============================================================================
suppressPackageStartupMessages({ library(terra); library(data.table) })
CA <- "F:/lucasCore/dev/libs/lucasCore-suitability.ssim.data/lucasCore-suitability/r30_-2170395_1863765_5539_11473_1985-2023"
nl <- function(y) values(rast(file.path(CA, sprintf("nlcd_%d.tif", y))), mat = FALSE)
YRS <- 1985:2023; NAT <- c(31, 41:43, 52, 71, 90, 95); AG <- c(81, 82); km2 <- 900 / 1e6
# ag-ness of every pixel by year, kept only for pixels that are ever ag (memory)
rg <- values(rast(file.path(CA, "region.tif")), mat = FALSE); gp <- values(rast(file.path(CA, "gap.tif")), mat = FALSE)
inreg <- if ("--box" %in% commandArgs(TRUE)) rep(TRUE, length(rg)) else !is.na(rg)   # default: the fitting region (P26) only
everag <- Reduce(`|`, lapply(YRS, function(y) nl(y) %in% AG)) & inreg; idx <- which(everag)
M <- sapply(YRS, function(y) nl(y)[idx]); colnames(M) <- YRS
cat(sprintf("pixels ever agriculture 1985-2023: %.0f km2\n", length(idx) * km2))
isag <- M %in% AG; dim(isag) <- dim(M); isnat <- M %in% NAT; dim(isnat) <- dim(M)
ex <- list(); co <- list()
for (j in 2:length(YRS)) { y <- YRS[j]
  e <- which(isnat[, j - 1] & isag[, j]); if (length(e)) { back <- if (j > 2) rowSums(isag[e, max(1, j - 6):(j - 2), drop = FALSE]) > 0 else rep(FALSE, length(e))
    ex[[length(ex) + 1]] <- data.table(Year = y, Return = back, To = M[e, j], From = M[e, j - 1]) }
  c <- which(isag[, j - 1] & isnat[, j]); if (length(c)) { fwd <- if (j < length(YRS)) rowSums(isag[c, (j + 1):min(length(YRS), j + 5), drop = FALSE]) > 0 else rep(NA, length(c))
    co[[length(co) + 1]] <- data.table(Year = y, Bounce = fwd, From = M[c, j - 1], To = M[c, j]) } }
ex <- rbindlist(ex); co <- rbindlist(co)
cat(sprintf("\nag expansion events: %.1f km2; %.0f%% were agriculture in the 5 years before (returns)\n", nrow(ex) * km2, 100 * mean(ex$Return)))
print(ex[, .(km2 = round(.N * km2, 2), returns = sprintf("%.0f%%", 100 * mean(Return))), by = .(From)][order(-km2)])
cat("\n... by period:\n"); print(ex[, .(km2_per_yr = round(.N * km2 / uniqueN(Year), 2), returns = sprintf("%.0f%%", 100 * mean(Return))), by = .(Period = ifelse(Year < 2005, "1986-2004", "2005-2023"))])
cat(sprintf("\nag contraction events: %.1f km2; %.0f%% are agriculture again within 5 years (bounces; events to 2018)\n", nrow(co) * km2, 100 * co[Year <= 2018, mean(Bounce, na.rm = TRUE)]))
print(co[Year <= 2018, .(km2 = round(.N * km2, 2), bounce = sprintf("%.0f%%", 100 * mean(Bounce))), by = .(To)][order(-km2)])
cat(sprintf("\nnet ag change 1985-2023: %.1f km2 (ag area %.1f -> %.1f km2)\n", (sum(isag[, ncol(isag)]) - sum(isag[, 1])) * km2, sum(isag[, 1]) * km2, sum(isag[, ncol(isag)]) * km2))
cat(sprintf("persistent change (expansion that is not a return and is still ag in 2023): %.1f km2\n",
            ex[Return == FALSE, .N] * km2 * mean(isag[cbind(match(seq_len(nrow(M)), seq_len(nrow(M))), ncol(isag))])))
