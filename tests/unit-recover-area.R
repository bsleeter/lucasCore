# Fast test of recover_area (no SyncroSim). Run: Rscript tests/unit-recover-area.R (from the package root)
source("src/recover-area.R")
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-9))
nr <- 5L; nc <- 5L; of <- recover_offsets(0.15, 1)
blank <- function(x = 0) rep(x, nr * nc); cell <- function(r, c) (r - 1L) * nc + c
U <- blank(1);
# one lost cell in the middle, forest everywhere else
can <- rep(TRUE, 25); can[cell(3, 3)] <- FALSE; v <- blank(); v[cell(3, 3)] <- 0.4; room <- 1 - v; room[!can] <- 0
x <- recover_area(v, can, can, U, room, nr, nc, of)
check("the lost cell ends at zero", x$v[cell(3, 3)] == 0)
check("the whole amount goes to one directly adjacent cell", near(sum(x$v), 0.4) && sum(x$v > 0) == 1 && near(x$km, 0.15))
check("reported lost and placed agree, nothing unplaced", near(x$lost, 0.4) && near(x$placed, 0.4) && x$unplaced == 0)
check("room falls by what was placed", near(sum(x$room), sum(room) - 0.4))
# a neighbour with little room: the amount spreads
room2 <- room; room2[c(cell(2, 3), cell(3, 2), cell(3, 4), cell(4, 3))] <- 0.05
x <- recover_area(v, can, can, U, room2, nr, nc, of)
check("full neighbours spill to the next nearest, never above their room", near(sum(x$v), 0.4) && all(x$v <= pmax(room2, 0) + 1e-12) && max(x$km) > 0.15)
# another unit is not used
U2 <- U; U2[-cell(3, 3)] <- 2; U2[cell(1, 1)] <- 1
x <- recover_area(v, can, can, U2, room, nr, nc, of)
check("stays in the cell's unit", near(x$v[cell(1, 1)], 0.4) && near(sum(x$v), 0.4))
# no place at all: unplaced, and the fraction is not left on the lost cell
U3 <- blank(2); U3[cell(3, 3)] <- 1
x <- recover_area(v, can, can, U3, room, nr, nc, of)
check("no receiver: all unplaced and removed", near(x$unplaced, 0.4) && x$placed == 0 && sum(x$v) == 0)
# receivers excluded by age
ok <- can; ok[c(cell(2, 3), cell(3, 2), cell(3, 4), cell(4, 3))] <- FALSE
x <- recover_area(v, can, ok, U, room, nr, nc, of)
check("a cell too young does not receive", all(x$v[c(cell(2, 3), cell(3, 2), cell(3, 4), cell(4, 3))] == 0) && near(sum(x$v), 0.4))
# cells off the land stay NA, cuts already on eligible cells stay and add
v2 <- v; v2[cell(1, 1)] <- NA; can2 <- can; can2[cell(1, 1)] <- FALSE; U4 <- U; U4[cell(1, 1)] <- NA; v2[cell(3, 4)] <- 0.3; room4 <- 1 - ifelse(is.na(v2), 1, v2); room4[!can2] <- 0
x <- recover_area(v2, can2, can2, U4, room4, nr, nc, of)
check("off-land stays NA; existing amounts keep; total held", is.na(x$v[cell(1, 1)]) && x$v[cell(3, 4)] >= 0.3 && near(sum(x$v, na.rm = TRUE), 0.7) && all(x$v <= 1 + 1e-12, na.rm = TRUE))
# a corner (grid edge), two lost cells sharing a receiver
can5 <- rep(FALSE, 25); can5[cell(1, 2)] <- TRUE; v5 <- blank(); v5[cell(1, 1)] <- 0.7; v5[cell(1, 3)] <- 0.7; room5 <- blank(); room5[cell(1, 2)] <- 1
x <- recover_area(v5, can5, can5, U, room5, nr, nc, of)
check("two cells share one receiver up to 1; the rest is unplaced", near(x$v[cell(1, 2)], 1) && near(x$unplaced, 0.4) && near(x$lost, 1.4))
# nothing lost
x <- recover_area(blank(), rep(TRUE, 25), rep(TRUE, 25), U, blank(1), nr, nc, of)
check("nothing lost: nothing changes", x$lost == 0 && x$placed == 0 && sum(x$v) == 0 && length(x$km) == 0)
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
