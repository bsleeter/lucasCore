# =============================================================================
# unit-par-workers.R - parallel raster steps size their workers by the machine's free memory
# =============================================================================
# Stage 5's NLCD workers each left terra at memfrac 0.6, so on a colleague's machine (2026-11-10) they together asked for many times
# the free memory and failed with std::bad_alloc. par_workers() caps the count by free memory and cores; each worker then gets
# memfrac 0.6 / workers. Usage: Rscript tests/unit-par-workers.R
# =============================================================================
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
ex <- parse(file.path(pkg, "src", "shared.R")); keep <- vapply(ex, function(e) is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) && as.character(e[[2]]) %in% c("par_workers", "par_lapply_mem"), TRUE)
for (e in ex[keep]) eval(e); say <- function(...) cat(sprintf(...), "
")
bad <- 0L; chk <- function(ok, what) { cat(sprintf("%s: %s\n", if (ok) "ok" else "FAIL", what)); if (!ok) bad <<- bad + 1L }
w <- par_workers(38); cat(sprintf("this machine: %d workers for 38 years (%d cores)\n", w, parallel::detectCores()))
chk(w >= 1 && w <= 20 && w <= parallel::detectCores() - 1, "within the cap and the cores")
chk(par_workers(3) <= 3, "never more workers than tasks")
# a 16 GB machine with 6 GB free and 16 cores: 3 workers at 2 GB each
sys2 <- system2; system2 <- function(...) "6291456"; dc <- parallel::detectCores
assignInNamespace("detectCores", function(...) 16L, "parallel")
chk(par_workers(38) == 3, sprintf("6 GB free, 16 cores: 3 workers (got %d)", par_workers(38)))
system2 <- function(...) "1048576"; chk(par_workers(38) == 1, "1 GB free: 1 worker")
system2 <- function(...) stop("no powershell"); chk(par_workers(38) >= 1, "no answer from Windows: falls back to terra")
ns <- asNamespace("terra"); fr <- ns$free_RAM; unlockBinding("free_RAM", ns); assign("free_RAM", function() stop("no answer"), ns)
chk(par_workers(38) == 4 && is.na(attr(par_workers(38), "free_gb")), "neither Windows nor terra answers: 4 workers, free memory unknown")
assign("free_RAM", fr, ns); lockBinding("free_RAM", ns)
system2 <- sys2; assignInNamespace("detectCores", dc, "parallel")
# out of memory: the step runs again on half the workers until it fits (here, at 2 or fewer)
tries <- c(); r <- par_lapply_mem(1:6, function(x, nw) if (nw > 2) stop("std::bad_alloc") else x * 2, "test", cap = 8, args = function(nw) { tries <<- c(tries, nw); list(nw = nw) })
chk(identical(unlist(r), (1:6) * 2) && tail(tries, 1) <= 2 && all(diff(tries) < 0), sprintf("bad_alloc: retried on %s workers", paste(tries, collapse = ", ")))
e <- tryCatch(par_lapply_mem(1:2, function(x) stop("some other error"), "test"), error = function(e) conditionMessage(e))
chk(grepl("some other error", e), "another error stops at once, not retried")
# the memory share reaches the workers
cl <- parallel::makeCluster(2); invisible(parallel::clusterCall(cl, function(f) { library(terra); terraOptions(memfrac = f, progress = 0) }, 0.3))
mf <- unlist(parallel::clusterEvalQ(cl, { library(terra); terra::terraOptions(print = FALSE)$memfrac })); parallel::stopCluster(cl)
chk(all(abs(mf - 0.3) < 1e-9), sprintf("workers keep memfrac 0.3 after library(terra) (%s)", paste(mf, collapse = ", ")))
cat(sprintf("%d failed\n", bad)); if (bad) quit(status = 1)
