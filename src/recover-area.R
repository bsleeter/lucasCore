# =============================================================================
# recover-area.R - keep a fractional transition's mapped area when part of it falls on cells that cannot take it
# =============================================================================
# 30 m disturbances reach the model grid as the fraction of each cell's pixels. Part of that lands on cells whose class has no pathway for
# the transition, so ST-Sim cannot apply it. recover_area() takes that part off those cells and puts it on the nearest cells of the
# same secondary stratum unit that can take it, up to what each has left in the year (one transition per cell per timestep).
#   v     the group's fractions, one per cell (NA off the land)
#   can   TRUE where the group's pathways can leave the cell's class
#   ok    TRUE where the cell may receive now (can, and old enough)
#   unit  secondary stratum unit per cell (NA off the land)
#   room  what each cell has left this year, 1 - the fractions already on it; updated and returned
# Returns v, room, the lost and placed amounts in cell units, and moved: distance (km) and amount of each placement.
# =============================================================================
recover_offsets <- function(res_km, max_km = 10) { R <- ceiling(max_km / res_km)
  o <- expand.grid(dr = -R:R, dc = -R:R); o$km <- sqrt(o$dr^2 + o$dc^2) * res_km; o <- o[o$km > 0 & o$km <= max_km, ]; o[order(o$km), ] }

recover_area <- function(v, can, ok, unit, room, nr, nc, offsets) {
  from <- which(!is.na(v) & v > 0 & !can); n <- length(from)
  km <- vector("list", n); amt <- vector("list", n); unplaced <- 0
  amount <- v[from]; v[from] <- 0
  for (ii in seq_len(n)) { i <- from[ii]; need <- amount[ii]; r <- (i - 1L) %/% nc + 1L; cl <- (i - 1L) %% nc + 1L
    rw <- r + offsets$dr; cc <- cl + offsets$dc; k <- which(rw >= 1L & rw <= nr & cc >= 1L & cc <= nc); j <- (rw[k] - 1L) * nc + cc[k]
    hit <- which(ok[j] & !is.na(unit[j]) & unit[j] == unit[i] & room[j] > 0)
    a <- numeric(0); d <- numeric(0)
    for (s in hit) { t <- j[s]; g <- min(need, room[t]); v[t] <- v[t] + g; room[t] <- room[t] - g; need <- need - g; a <- c(a, g); d <- c(d, offsets$km[k[s]]); if (need <= 1e-9) break }
    km[[ii]] <- d; amt[[ii]] <- a; if (need > 1e-9) unplaced <- unplaced + need }
  list(v = v, room = room, lost = sum(amount), placed = sum(amount) - unplaced, unplaced = unplaced, km = unlist(km), amount = unlist(amt)) }
