# =============================================================================
# unit-package-description.R - the package description survives rsyncrosim's reading of the installed-package list
# =============================================================================
# rsyncrosim::ssimLibrary() first lists the installed packages (SyncroSim.PackageManager --installed, a table aligned with spaces)
# and reads it by turning runs of 2+ spaces into commas, then read.csv. A comma or a double space in the description adds columns,
# and read.table sizes the columns from the first 5 lines: on a machine with few packages installed every stage then failed with
# "more columns than column names" (a colleague's clean install, 2026-11-09; fixed in 1.1.1). Usage: Rscript tests/unit-package-description.R
# =============================================================================
suppressPackageStartupMessages(library(xml2))
pkg <- normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), ".."), winslash = "/")
p <- xml_find_first(read_xml(file.path(pkg, "package.xml")), "/package")
bad <- 0L; chk <- function(ok, what) { cat(sprintf("%s: %s\n", if (ok) "ok" else "FAIL", what)); if (!ok) bad <<- bad + 1L }
for (a in c("description", "displayName")) { v <- xml_attr(p, a)
  chk(!grepl(",", v, fixed = TRUE), sprintf("%s has no comma", a))
  chk(!grepl("  ", v, fixed = TRUE), sprintf("%s has no double space", a))
  chk(!grepl('"', v, fixed = TRUE), sprintf("%s has no quote mark", a)) }
# the package manager's table with lucasCore near the top, read the way rsyncrosim reads it (.dataframeFromSSim, csv = FALSE)
d <- xml_attr(p, "description")
tab <- rbind(c("Name", "Version", "Description", "Location", "Status"),
             c("lucasCore", xml_attr(p, "version"), d, "C:/Users/me/AppData/Local/SyncroSim/Packages/lucasCore/x", "OK"),
             c("stsim", "4.5.4", "The ST-Sim state-and-transition simulation model", "C:/Users/me/AppData/Local/SyncroSim/Packages/stsim/4.5.4", "OK"))
for (j in seq_len(ncol(tab))) tab[, j] <- formatC(tab[, j], width = -(max(nchar(tab[, j])) + 3))   # each column padded past its widest entry
tt <- apply(tab, 1, paste0, collapse = "")
while (any(grepl("   ", tt, fixed = TRUE))) tt <- gsub("   ", "  ", tt, fixed = TRUE)
tt <- gsub("  ", ",", tt, fixed = TRUE)
r <- tryCatch(read.csv(textConnection(tt), stringsAsFactors = FALSE), error = function(e) e)
chk(!inherits(r, "error"), sprintf("the installed-package list parses (%s)", if (inherits(r, "error")) conditionMessage(r) else "ok"))
if (!inherits(r, "error")) chk(identical(r$Description[1], d) && identical(r$Status[1], "OK"), "lucasCore's row reads back whole")
cat(sprintf("%d failed\n", bad)); if (bad) quit(status = 1)
