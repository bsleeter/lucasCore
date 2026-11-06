# Fast test of realized_area (no SyncroSim). Run: Rscript tests/unit-targets-from-run.R (from the package root)
suppressPackageStartupMessages(library(data.table))
source("src/targets-from-run.R")
fails <- 0L; n <- 0L
check <- function(what, ok) { n <<- n + 1L; if (!isTRUE(ok)) fails <<- fails + 1L; cat(if (isTRUE(ok)) "PASS " else "FAIL ", what, "\n", sep = "") }
out <- data.table(Iteration = c(1L, 1L, 2L, 2L, 1L, 1L, 1L), Timestep = c(2001L, 2001L, 2001L, 2002L, 2002L, 2001L, 1999L),
                  SecondaryStratumId = c("A", "A", "A", "B", "B", "C", "A"), TransitionGroupId = c("G", "G", "G", "G", "G", "G", "G"), Amount = c(10, 5, 9, 4, 6, 7, 100))
out <- rbind(out, data.table(Iteration = 1L, Timestep = 2001L, SecondaryStratumId = "A", TransitionGroupId = "H", Amount = 50))
M <- realized_area(out, "G", "SecondaryStratumId", c("A", "B"), c(11L, 12L), c(2001L, 2002L))
check("rows are the units, columns the reference years", identical(dim(M), c(2L, 2L)) && identical(rownames(M), c("11", "12")) && identical(colnames(M), c("2001", "2002")))
check("amounts summed per unit and year, the mean over iterations", isTRUE(all.equal(unname(M[1, 1]), (10 + 5 + 9) / 2)) && isTRUE(all.equal(unname(M[2, 2]), (4 + 6) / 2)))
check("a unit or year with nothing realized is 0", M[1, 2] == 0 && M[2, 1] == 0)
check("years outside the reference period are left out", sum(M) < 100)
check("another group is not counted", !any(M == 25))
check("a unit not in this level is reported, not lost silently", isTRUE(all.equal(attr(M, "unmatched"), 7 / 2)))
check("a group with no output gives zeros", sum(realized_area(out, "none", "SecondaryStratumId", c("A", "B"), c(11L, 12L), c(2001L, 2002L))) == 0)
cat(sprintf("%d checks, %d failed\n", n, fails)); if (fails) quit(status = 1)
