# =============================================================================
# 01-nonsage-fix.R - to-do 39: Shrubland: Non-sage's live turnover rates were shifted down one row (2026-10-30, applied once)
# =============================================================================
# In the CONUS 1 km build's "Flow Multipliers - Grassland Shrubland.csv" (and so defaults/stockflow/nonforest-multipliers-grassland-
# shrubland.csv) Non-sage's eight Biomass Turnover rows hold Post Fire Shrub's values moved down one row (coarse roots -> AG fast 0,
# fine roots -> AG very fast 0.01, foliage 0.256, merchantable -> snags 0.508, other wood -> AG fast 0.0045, ...). Fix: Non-sage takes
# Post Fire Shrub's eight turnover rates (its decay rows are its own and unchanged). Its starting pools (defaults/initialstocks/
# grassland-shrubland.csv) came from a spin-up with the shifted rates, so they are rebuilt: an annual simulation in ST-Sim's flow order
# (flows of one order from the stocks at the start of that order, orders in sequence) to equilibrium, which reproduces the package's
# table for the unaffected classes to 4 decimals (deep soil within 0.1%). The script below ran once; rerunning it is harmless.
# =============================================================================
library(data.table, warn.conflicts = FALSE); d <- "F:/lucasCore/defaults/"
m <- fread(paste0(d, "stockflow/nonforest-multipliers-grassland-shrubland.csv"))[StratumId == "Marine"]
p <- fread(paste0(d, "stockflow/nonforest-pathways.csv"))[FromStratumId == "Marine"]
g <- fread(paste0(d, "stockflow/nonforest-net-growth.csv"))[StratumId == "Marine" & StateAttributeTypeId == "Net Growth"]
init <- fread(paste0(d, "initialstocks/grassland-shrubland.csv")); st <- fread(paste0(d, "initialstocks/stock-types.csv")); print(head(st, 3))
ft <- fread(paste0(d, "stockflow/stsim_FlowTypeGroupMembership.csv")); print(head(ft, 3))
ss <- function(cls, mm = m) {
  pp <- p[FromStateClassId == cls]; r <- mm[StateClassId == cls, .(FlowGroupId, Value)]
  pp[, rate := Multiplier * r$Value[match(paste(FlowTypeId, "[Type]"), r$FlowGroupId)]]
  ng <- g[StateClassId == cls, Value]
  pools <- setdiff(unique(c(pp$FromStockTypeId, pp$ToStockTypeId)), "Atmosphere"); n <- length(pools)
  A <- matrix(0, n, n, dimnames = list(pools, pools)); b <- setNames(rep(0, n), pools)
  for (k in seq_len(nrow(pp))) { f <- pp$FromStockTypeId[k]; t <- pp$ToStockTypeId[k]; v <- pp$rate[k]; if (is.na(v)) next
    if (f == "Atmosphere") { if (t %in% pools) b[t] <- b[t] + ng * v } else { A[f, f] <- A[f, f] - v; if (t %in% pools) A[t, f] <- A[t, f] + v } }
  keep <- diag(A) != 0 | b != 0; x <- setNames(rep(0, n), pools); x[keep] <- solve(A[keep, keep, drop = FALSE], -b[keep]); x }
cmp <- function(cls) { x <- ss(cls); t0 <- init[StateClassID == cls][, .(pool = st$StockTypeId[match(StateAttributeTypeID, st$Attribute)], table = Value)]
  merge(t0, data.table(pool = names(x), steady = round(x, 4)), by = "pool", all = TRUE) }
for (cls in c("Shrubland: Native Sage Steppe", "Shrubland: Post Fire Shrub", "Grassland: Natural Perennial")) { cat("\n", cls, "\n"); print(cmp(cls)) }
cat("\nNon-sage (as in the package, shifted):\n"); print(cmp("Shrubland: Non-sage"))
fo <- fread(paste0(d, "stockflow/stsim_FlowOrder.csv"))
# ST-Sim: flows of the same order are computed from the stocks at the start of that order step, orders in sequence
sim <- function(cls, mm = m, years = 3000) {
  pp <- p[FromStateClassId == cls]; r <- mm[StateClassId == cls, .(FlowGroupId, Value)]
  pp[, rate := Multiplier * r$Value[match(paste(FlowTypeId, "[Type]"), r$FlowGroupId)]][, ord := fo$Order[match(FlowTypeId, fo$FlowTypeId)]]
  pp <- pp[!is.na(rate) & rate != 0]; ng <- g[StateClassId == cls, Value]
  pools <- setdiff(unique(c(pp$FromStockTypeId, pp$ToStockTypeId)), "Atmosphere"); S <- setNames(rep(0, length(pools)), pools)
  for (y in seq_len(years)) for (o in sort(unique(pp$ord))) { q <- pp[ord == o]; S0 <- S
    for (k in seq_len(nrow(q))) { f <- q$FromStockTypeId[k]; t <- q$ToStockTypeId[k]
      amt <- if (f == "Atmosphere") ng * q$rate[k] else S0[f] * q$rate[k]
      if (f != "Atmosphere") S[f] <- S[f] - amt; if (t %in% pools) S[t] <- S[t] + amt } }
  S }
cmp2 <- function(cls, mm = m) { x <- sim(cls, mm); t0 <- init[StateClassID == cls][, .(pool = st$StockTypeId[match(StateAttributeTypeID, st$Attribute)], table = Value)]
  merge(t0, data.table(pool = names(x), sim = round(x, 4)), by = "pool", all = TRUE)[table > 0 | sim > 0] }
for (cls in c("Shrubland: Post Fire Shrub", "Grassland: Natural Perennial")) { cat("\n", cls, "\n"); print(cmp2(cls)) }
# ---- the fix: Non-sage's eight turnover rates = Post Fire Shrub's (the source file had them shifted down one row) ----------
NS <- "Shrubland: Non-sage"; PF <- "Shrubland: Post Fire Shrub"
fa <- paste0(d, "stockflow/nonforest-multipliers-grassland-shrubland.csv"); A <- fread(fa, colClasses = "character", na.strings = "")
tg <- unique(A[StateClassId == NS & startsWith(FlowGroupId, "Biomass Turnover:"), FlowGroupId]); stopifnot(length(tg) == 8)
pfv <- A[StateClassId == PF & FlowGroupId %in% tg, .(StratumId, FlowGroupId, v = Value)]
before <- A[StateClassId == NS & FlowGroupId %in% tg & StratumId == "Marine", .(FlowGroupId, Value)]
A[pfv, on = .(StratumId, FlowGroupId), Value := fifelse(StateClassId == NS, i.v, Value)]
print(merge(before, A[StateClassId == NS & FlowGroupId %in% tg & StratumId == "Marine", .(FlowGroupId, fixed = Value)], by = "FlowGroupId"))
fwrite(A, fa, na = "", quote = FALSE)
# ---- Non-sage's starting pools from the ordered simulation with the fixed rates ---------------------------------------------
m2 <- fread(fa)[StratumId == "Marine"]; x <- sim(NS, m2)
fi <- paste0(d, "initialstocks/grassland-shrubland.csv"); I <- fread(fi, colClasses = "character", na.strings = "")
I[, pool := st$StockTypeId[match(StateAttributeTypeID, st$Attribute)]]
old <- I[StateClassID == NS, .(pool, old = Value)]
I[StateClassID == NS, Value := as.character(round(fifelse(pool %in% names(x), x[pool], 0), 4))]
print(merge(old, I[StateClassID == NS, .(pool, new = Value)], by = "pool")[old != "0" | new != "0"])
I[, pool := NULL]; fwrite(I, fi, na = "", quote = FALSE)
