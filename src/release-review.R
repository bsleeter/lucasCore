# =============================================================================
# release-review.R - stage 17's content checks and the review packet of a data release (to-do 14, Phase 5)
# =============================================================================
# rl_review_checks(...)  what the stage can check for itself, from the files it wrote. Level "must": a Provisional or Approved release fails on it, a Draft
#                        lists it. Level "should": advice for the reviewer (a long file name, a link that did not answer), never a failure.
# rl_review_packet(...)  the review/ folder, which is not published and is not in contents.csv: the two USGS review checklists with the stage's answers beside
#                        each item it could answer, a one-page reviewer's summary, the checks, and mp's findings with each record as text.
# The stage never ticks a box. The reviewers read, judge and sign, and IPDS records it (SM 502.8). The checklists are defaults/metadata/review-checklists.csv:
# USGS Data Review Checklist 2.8 and Metadata Review Checklist 2.6, word for word. When USGS issues new versions, replace the rows and keep each Check id.
# =============================================================================
RL_NAME_MAX <- 35L   # USGS Data Review Checklist: file names of no more than 25-35 characters

rl_review_checks <- function(out, contents, records, runs, defs, dict, base, info, links = TRUE) {
  row <- function(id, level, pass, what, detail = "") data.table(Check = id, Level = level, Pass = if (length(pass) == 1) as.logical(pass) else NA, What = what, Detail = paste(detail, collapse = "; "))
  docs <- lapply(records, xml2::read_xml); names(docs) <- sub(paste0(out, "/"), "", records, fixed = TRUE); parent <- docs[["release.xml"]]
  tx <- function(d, p) xml2::xml_text(xml2::xml_find_all(d, p)); all_tx <- function(p) unlist(lapply(docs, tx, p), use.names = FALSE)
  each <- function(p, f) vapply(docs, function(d) f(tx(d, p)), TRUE)
  raw <- lapply(records, function(f) readChar(f, file.size(f), useBytes = TRUE))
  res <- list(); add <- function(...) res[[length(res) + 1]] <<- row(...)
  zips <- contents[grepl("/maps/[^/]+[.]zip$", file), file]; inner <- unlist(lapply(file.path(out, zips), function(z) utils::unzip(z, list = TRUE)$Name), use.names = FALSE)

  # ---- files ------------------------------------------------------------------------------------------------------------
  nm <- c(basename(contents$file), inner); long <- unique(nm[nchar(nm) > RL_NAME_MAX]); odd <- unique(nm[grepl("[^A-Za-z0-9._-]", nm)])
  add("names", "should", !length(long) && !length(odd), "file names are short, with no spaces or special characters",
      c(if (length(long)) sprintf("%d names over %d characters, the longest %d: %s", length(long), RL_NAME_MAX, max(nchar(long)), long[which.max(nchar(long))]), if (length(odd)) sprintf("with spaces or special characters: %s", paste(head(odd, 3), collapse = ", "))))
  ext <- tolower(tools::file_ext(contents$file)); bad <- setdiff(ext, c("csv", "zip", "xml", "png", "txt", "ssimbak"))
  add("formats", "must", !length(bad) && all(tolower(tools::file_ext(inner)) == "tif"), "files are in open formats: CSV, GeoTIFF in zip, PNG, XML, text", c(if (length(bad)) paste("other types:", paste(bad, collapse = ", ")), if ("ssimbak" %in% ext) "the model archive is a SyncroSim backup, kept to rerun the simulations"))
  rd <- file.path(out, "README.txt"); add("compressed", "must", !length(zips) || (file.exists(rd) && any(grepl("zip", readLines(rd, warn = FALSE)))), "the README says what the zips hold", sprintf("%d map zips", length(zips)))

  # ---- maps: one from each zip -------------------------------------------------------------------------------------------
  tmp <- tempfile("review"); dir.create(tmp); probs <- character(); crs_bad <- character(); nd_bad <- character(); cog_bad <- character()
  for (z in zips) { l <- utils::unzip(file.path(out, z), list = TRUE)$Name; if (!length(l)) { probs <- c(probs, paste(basename(z), "is empty")); next }
    utils::unzip(file.path(out, z), files = l[1], exdir = tmp); f <- file.path(tmp, l[1])
    r <- tryCatch(terra::rast(f), error = function(e) NULL); if (is.null(r)) { probs <- c(probs, paste(l[1], "does not open")); next }
    d <- paste(terra::describe(f), collapse = " "); if (!identical(as.character(terra::crs(r, describe = TRUE)$code), "5070")) crs_bad <- c(crs_bad, l[1])
    if (!grepl("NoData Value=-9999", d, fixed = TRUE)) nd_bad <- c(nd_bad, l[1]); if (!grepl("LAYOUT=COG", d, fixed = TRUE)) cog_bad <- c(cog_bad, l[1]); rm(r); unlink(f) }
  add("open", "must", if (length(zips)) !length(probs) && !length(cog_bad) else NA, "every map zip opens, and its first map is a cloud-optimized GeoTIFF", c(sprintf("%d zips, one map each; the tables are read in full below", length(zips)), probs, if (length(cog_bad)) paste("not cloud-optimized:", paste(head(cog_bad, 3), collapse = ", "))))
  add("crs", "must", if (length(zips)) !length(crs_bad) && !length(nd_bad) else NA, "the maps are in EPSG:5070 with no data -9999, as the records say", c(if (length(crs_bad)) paste("other projection:", paste(head(crs_bad, 3), collapse = ", ")), if (length(nd_bad)) paste("other no data:", paste(head(nd_bad, 3), collapse = ", "))))
  sc <- grep("state-class-[^/]+[.]zip$", zips, value = TRUE)
  if (length(sc)) { l <- utils::unzip(file.path(out, sc[1]), list = TRUE)$Name; f <- l[length(l)]; utils::unzip(file.path(out, sc[1]), files = f, exdir = tmp); r <- terra::rast(file.path(tmp, f))
    ll <- terra::ext(terra::project(terra::as.polygons(terra::ext(r), crs = terra::crs(r)), "EPSG:4326")); want <- c(west = ll$xmin, east = ll$xmax, south = ll$ymin, north = ll$ymax); names(want) <- c("west", "east", "south", "north")
    off <- vapply(docs, function(d) suppressWarnings(max(abs(as.numeric(c(tx(d, "//westbc"), tx(d, "//eastbc"), tx(d, "//southbc"), tx(d, "//northbc"))) - want))), 0); off[is.na(off)] <- Inf   # an unreadable coordinate fails
    add("bounding", "must", all(off < 0.1), "each record's bounding coordinates match the maps, within 0.1 degree", sprintf("largest difference %.3f degrees, from %s", max(off), basename(f)))
    v <- terra::unique(r)[[1]]; v <- v[!is.na(v) & v != 0]; codes <- defs[kind == "StateClass" & !is.na(code), code]; miss <- setdiff(v, codes)
    add("vat", "must", !length(miss), "every state class value in the map is defined", if (length(miss)) paste("not defined:", paste(head(miss, 8), collapse = ", ")) else sprintf("%d classes in %s", length(v), basename(f))); rm(r)
  } else { add("bounding", "must", NA, "each record's bounding coordinates match the maps", "no state class maps in this release"); add("vat", "must", NA, "every state class value in the map is defined", "no state class maps in this release") }
  unlink(tmp, recursive = TRUE)

  # ---- tables, read in full ----------------------------------------------------------------------------------------------
  csv <- contents[grepl("/tables/[^/]+[.]csv$|^comparison/[^/]+[.]csv$", file), file]; tb <- character(); nulls <- character(); rng <- character(); lab <- character()
  for (p in csv) { f <- basename(p); x <- fread(file.path(out, p), showProgress = FALSE, encoding = "UTF-8", na.strings = "NA", strip.white = FALSE); dc <- dict[File == f]
    if (anyDuplicated(x)) tb <- c(tb, sprintf("%s has duplicate rows", f))
    for (k in names(x)) { v <- x[[k]]; if (all(is.na(v)) && !all(dc[Column == k, NullValue] %in% "NA")) tb <- c(tb, sprintf("%s: %s is empty", f, k))
      if (is.character(v)) { u <- unique(v[!is.na(v)]); if (any(u != trimws(u))) tb <- c(tb, sprintf("%s: %s has leading or trailing spaces", f, k)); if (!all(validUTF8(u))) tb <- c(tb, sprintf("%s: %s is not UTF-8", f, k)) }
      ty <- dc[Column == k, Type][1]; if (!is.na(ty) && ty %in% c("integer", "real") && !is.numeric(v) && !all(is.na(v))) tb <- c(tb, sprintf("%s: %s should be numeric", f, k))
      if (anyNA(v)) { nv <- dc[Column == k, NullValue][1]; if (is.na(nv) || !nzchar(nv)) nulls <- c(nulls, sprintf("%s: %s has blanks the dictionary does not define", f, k)) }
      if (!grepl("^[A-Za-z0-9_]+$", k)) lab <- c(lab, sprintf("%s: %s", f, k)) }
    if ("area_ha" %in% names(x) && any(x$area_ha < 0, na.rm = TRUE)) rng <- c(rng, sprintf("%s: negative area", f))
    if ("year" %in% names(x)) for (r in runs) if (grepl(paste0("/", r$slug, "/tables/"), p, fixed = TRUE) && any(x$year < r$years[1] | x$year > r$years[2], na.rm = TRUE)) rng <- c(rng, sprintf("%s: a year outside %s-%s", f, r$years[1], r$years[2]))
    rm(x); gc(FALSE) }
  add("tables", "must", !length(tb), "tables have no duplicate rows, empty columns, stray spaces or encoding errors, and each column holds one type", c(sprintf("%d tables read in full", length(csv)), head(tb, 8)))
  add("labels", "must", !length(lab), "column names hold no spaces or special characters", head(lab, 5))
  ha <- any(grepl("-9999", unlist(lapply(setdiff(names(docs), c("release.xml", "model/model.xml")), function(n) as.character(docs[[n]]))), fixed = TRUE))
  add("nulls", "must", !length(nulls) && (!length(zips) || ha), "blanks in the tables and -9999 in the maps are defined", head(nulls, 8))
  add("ranges", "must", !length(rng), "areas are not negative and years lie within the run", head(rng, 8))

  # ---- the records -------------------------------------------------------------------------------------------------------
  enc <- all(vapply(raw, function(s) validUTF8(s), TRUE)); add("encoding", "must", enc, "the records are valid UTF-8")
  dts <- c(all_tx("//pubdate"), all_tx("//begdate"), all_tx("//enddate"), all_tx("//caldate"), all_tx("//procdate"), all_tx("//metd")); baddt <- unique(dts[!md_valid_date(dts)])
  pd <- unique(all_tx("//idinfo/citation/citeinfo/pubdate")); md <- unique(all_tx("//metainfo/metd")); y0 <- as.integer(substr(tx(parent, "//idinfo/timeperd//begdate"), 1, 4)); y1 <- as.integer(substr(tx(parent, "//idinfo/timeperd//enddate"), 1, 4))
  out_range <- Filter(function(r) r$years[1] < y0 || r$years[2] > y1, runs)
  add("dates", "must", !length(baddt) && length(pd) == 1 && length(md) == 1 && !length(out_range), "dates are in YYYYMMDD and agree across the records", c(if (length(baddt)) paste("not valid:", paste(head(baddt, 5), collapse = ", ")), if (length(pd) > 1) paste("publication dates differ:", paste(pd, collapse = ", ")), if (length(md) > 1) paste("metadata dates differ:", paste(md, collapse = ", "))))
  kw <- vapply(docs, function(d) { t <- xml2::xml_find_all(d, "//theme[themekt='USGS Thesaurus']/themekey"); length(t) > 0 && any(tx(d, "//placekt") != "None") }, TRUE)
  add("keywords", "must", all(kw), "each record has a USGS Thesaurus theme term and a place keyword from a named thesaurus", if (!all(kw)) paste("missing in", paste(names(docs)[!kw], collapse = ", ")))
  nat <- each("//native", function(t) length(t) == 1 && all(vapply(c("SyncroSim", "ST-Sim", "lucasCore"), grepl, TRUE, x = t, fixed = TRUE)))
  add("native", "must", all(nat), "the software versions are in Native Data Set Environment", tx(parent, "//native"))
  src <- vapply(docs, function(d) length(xml2::xml_find_all(d, "//srcinfo")), 0L); add("lineage", "must", all(src > 0), "every record cites its sources", sprintf("%d sources in the model record", src[["model/model.xml"]]))
  add("license", "must", all(each("//useconst", function(t) length(t) == 1 && grepl("CC0", t, fixed = TRUE))), "Use Constraints names the CC0 license")
  st <- all(each("//accconst", function(t) length(t) == 1 && nzchar(t))) && all(each("//useconst", function(t) length(t) == 1 && nzchar(t))) && all(each("//distliab", function(t) length(t) == 1 && nzchar(t)))
  add("statements", "must", st, "access, use and liability statements are in every record", sprintf("release status %s", info$ReleaseStatus %||% "Draft"))
  fakes <- function(t) grepl("PLACEHOLDER|xxxxxxxx", t, ignore.case = TRUE)
  add("network", "must", all(each("//networkr", function(t) length(t) >= 1 && all(grepl("^https://doi[.]org/", t)) && !any(fakes(t)))), "the DOI is in Network Resource Name, and is not a placeholder", tx(parent, "//networkr")[1])
  mail <- all_tx("//cntemail"); pers <- each("//ptcontac//cntvoice", function(t) length(t) == 1 && !grepl("^0+-0+-0+$", t))
  add("contact", "must", all(pers) && !any(grepl("placeholder@", mail, fixed = TRUE)) && all(grepl("^[^@ ]+@[^@ ]+[.][^@ ]+$", mail)), "the contacts have a real phone and email", paste(unique(mail), collapse = ", "))
  add("methods", "must", md_supplied(info, "MethodsCitation"), "the methods citation is in the larger work citation", if (md_supplied(info, "MethodsCitation")) "" else "still the placeholder")
  add("revision", "should", NA, "the version is in the citation edition", sprintf("version %s%s", tx(parent, "//idinfo/citation/citeinfo/edition")[1], if (md_supplied(info, "RevisionNotes")) "; revision notes in the parent record" else ""))
  add("pid", "should", NA, "the metadata identifier", if (md_supplied(info, "MetadataId")) paste("the parent carries", info$MetadataId) else "none: the ScienceBase Data Release team assigns it during publication")
  # every file named in the records: tables and map variables by name, the rest in the parent's overview
  over <- paste(tx(parent, "//eaover"), collapse = " "); ent <- all_tx("//enttypl"); un <- character()
  for (f in contents$file) { b <- basename(f); known <- if (grepl("/maps/", f)) any(startsWith(b, sub("-<.*$", "-", ent)) & grepl("<", ent)) else if (grepl("/tables/", f)) b %in% ent else if (grepl("/figures/", f)) grepl("figures", over, fixed = TRUE) else if (grepl("ssimbak$", b)) grepl("ssimbak", over, fixed = TRUE) else grepl(b, over, fixed = TRUE) || b %in% ent
    if (!known) un <- c(un, f) }
  named <- ent[grepl("[.]csv$", ent) & !ent %in% basename(contents$file)]
  add("files", "must", !length(un) && !length(named), "every file is named in the records, and every record names only files that exist", c(if (length(un)) paste("not named:", paste(head(un, 5), collapse = ", ")), if (length(named)) paste("named but absent:", paste(head(unique(named), 5), collapse = ", "))))
  if (links) { u <- unique(c(all_tx("//onlink"), all_tx("//networkr"))); u <- u[grepl("^https?://", u) & !fakes(u)]
    st <- vapply(u, function(a) tryCatch(as.integer(attr(curlGetHeaders(a, timeout = 15L), "status")), error = function(e) NA_integer_), 0L); dead <- u[!is.na(st) & st >= 400 & !st %in% c(401L, 403L, 405L, 429L)]; un2 <- u[is.na(st) | st %in% c(401L, 403L, 405L, 429L)]
    add("links", "should", if (!length(u) || all(is.na(st))) NA else !length(dead) && !length(un2), "the links resolve", c(sprintf("%d links tried", length(u)), if (length(dead)) paste("do not resolve:", paste(head(dead, 6), collapse = ", ")), if (length(un2)) paste("no clear answer, try by hand:", paste(head(un2, 6), collapse = ", "))))
  } else add("links", "should", NA, "the links resolve", "not tried")
  bb <- function(id, what) add(id, "must", base[Check == what, Pass][1], what, base[Check == what, Detail][1])
  bb("definitions", "every name has a definition"); bb("dictionary", "every table's columns match the data dictionary"); bb("maptable", "a table's area matches its state class map")
  rbindlist(res) }

# ---- the packet --------------------------------------------------------------------------------------------------------------
rl_h <- function(x) { x <- gsub("&", "&amp;", as.character(x), fixed = TRUE); x <- gsub("<", "&lt;", x, fixed = TRUE); gsub(">", "&gt;", x, fixed = TRUE) }
rl_page <- function(title, body, f) writeLines(enc2utf8(c("<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'><title>", rl_h(title), "</title><style>",
  "body{font:14px/1.45 Segoe UI,Arial,sans-serif;max-width:60em;margin:1.5em auto;padding:0 1em;color:#222}h1{font-size:1.5em}h2{font-size:1.1em;margin-top:1.4em;border-bottom:1px solid #bbb}",
  "table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:3px 6px;vertical-align:top;text-align:left}th{background:#eee}.note{color:#555}",
  ".yes{color:#17612b;font-weight:600}.no{color:#a11d1d;font-weight:600}.you{color:#555}.box{width:4.2em;text-align:center}</style></head><body>", body, "</body></html>")), f, useBytes = TRUE)
rl_tbl <- function(head, rows) paste0("<table><tr>", paste0("<th>", rl_h(head), "</th>", collapse = ""), "</tr>", paste0(apply(rows, 1, function(r) paste0("<tr>", paste0("<td>", r, "</td>", collapse = ""), "</tr>")), collapse = ""), "</table>")

rl_checklist_rows <- function(dir, checks) {
  d <- fread(file.path(dir, "review-checklists.csv"), na.strings = "NA", encoding = "UTF-8")
  m <- checks[match(d$Check, Check)]
  d[, Finding := ifelse(Applies == "No", "Not applicable to this release", ifelse(is.na(Check), "For the reviewer", ifelse(is.na(m$Pass), "Stage note", ifelse(m$Pass, "Stage: yes", "Stage: no"))))]
  d[, Evidence := ifelse(is.na(Check) | Applies == "No", "", ifelse(nzchar(m$Detail) & !is.na(m$Detail), paste0(m$What, ". ", m$Detail), as.character(m$What)))]
  d[] }

rl_checklist_page <- function(rows, name, title, info, f) {
  x <- rows[Checklist == name]; cl <- function(s) ifelse(s == "Stage: yes", "yes", ifelse(s == "Stage: no", "no", "you"))
  sec <- paste(vapply(unique(x$Section), function(s) { y <- x[Section == s]
    if (y$Applies[1] == "No") return(sprintf("<h2>%s</h2><p class='note'>Section not applicable: this release holds no such data.</p>", rl_h(s)))
    paste0("<h2>", rl_h(s), "</h2>", rl_tbl(c("Item", "Stage's finding", "Yes", "No", "NA"), cbind(paste0(rl_h(y$Item), ifelse(nzchar(y$Evidence), paste0("<br><span class='note'>", rl_h(y$Evidence), "</span>"), "")), sprintf("<span class='%s'>%s</span>", cl(y$Finding), rl_h(y$Finding)), "&#9744;", "&#9744;", "&#9744;")), "<p class='note'>Comments:</p>") }, ""), collapse = "\n")
  rl_page(title, paste0("<h1>", rl_h(title), " (USGS version ", rl_h(x$Version[1]), ")</h1><p>Pre-filled by the lucasCore Data Release stage. The stage answers what it can check from the files, but the boxes are the reviewer's: read, judge and tick them, then record the review in IPDS.</p>",
    "<p>IPDS number: ", rl_h(if (md_supplied(info, "IpdsNumber")) info$IpdsNumber else "(not yet entered)"), "<br>Reviewer: <br>Review date: </p>", sec), f) }

rl_review_packet <- function(out, dir, contents, checks, mp, runs, compare, facts, model, parent, draft, info, records, mp_path) {
  rv <- file.path(out, "review"); dir.create(rv, showWarnings = FALSE)
  fwrite(checks[, .(check = Check, level = Level, pass = Pass, what = What, detail = Detail)], file.path(rv, "checks.csv"), na = "NA"); fwrite(mp, file.path(rv, "mp-report.csv"), na = "NA")
  if (!is.na(mp_path) && file.exists(mp_path)) { tt <- file.path(rv, "records-as-text"); dir.create(tt, showWarnings = FALSE)
    for (f in records) { o <- file.path(tt, paste0(gsub("[/\\\\]", "-", sub(paste0(out, "/"), "", tools::file_path_sans_ext(f), fixed = TRUE)), ".txt")); e <- tempfile(); suppressWarnings(system2(mp_path, c("-t", shQuote(o), "-e", shQuote(e), shQuote(f)), stdout = FALSE, stderr = FALSE)); unlink(e) } }
  rows <- rl_checklist_rows(dir, checks); fwrite(rows, file.path(rv, "checklist-answers.csv"), na = "NA")
  rl_checklist_page(rows, "Data review", "Data Review Checklist", info, file.path(rv, "data-review-checklist.html"))
  rl_checklist_page(rows, "Metadata review", "Metadata Review Checklist", info, file.path(rv, "metadata-review-checklist.html"))

  v <- facts$validation; g <- format(sum(contents$bytes) / 1e9, digits = 3)
  held <- rbindlist(lapply(runs, function(r) data.table(Run = r$name, Kind = r$kind, Years = sprintf("%s-%s", r$years[1], r$years[2]), Iterations = r$iterations[2],
    Files = contents[startsWith(file, paste0(r$folder, "/", r$slug, "/")), .N], GB = round(contents[startsWith(file, paste0(r$folder, "/", r$slug, "/")), sum(bytes)] / 1e9, 2))))
  acc <- rbindlist(lapply(names(compare), function(n) { c1 <- compare[[n]]; if (!nrow(c1)) return(NULL); data.table(Run = n, Group = c1$TransitionGroup, Years = paste0(c1$Y0, "-", c1$Y1), Simulated = round(c1$Simulated), Recorded = round(c1$Recorded), Pct = round(100 * (c1$Simulated - c1$Recorded) / c1$Recorded)) }))
  far <- if (nrow(acc)) acc[abs(Pct) > 10] else acc
  nb <- v[Status != "Pass"]; failed <- checks[Level == "must" & Pass %in% FALSE]; adv <- checks[Level == "should" & Pass %in% FALSE]
  limits <- c(if (nrow(far)) sprintf("%s, %s: simulated area %+d%% from the record (%s against %s km2).", far$Run, far$Group, as.integer(far$Pct), format(far$Simulated, big.mark = ",", trim = TRUE), format(far$Recorded, big.mark = ",", trim = TRUE)),
              if (nrow(nb)) sprintf("Build check not passed: %s - %s (%s).", nb$Stage, nb$Check, nb$Status), if (length(model$notes)) paste("The model record had to infer:", model$notes),
              if (any(vapply(runs, function(r) r$iterations[2] == 1, TRUE))) "A run with one Monte Carlo iteration shows one draw of the land change, with no spread across draws.")
  li <- function(x) if (length(x)) paste0("<ul>", paste0("<li>", rl_h(x), "</li>", collapse = ""), "</ul>") else "<p>None.</p>"
  ans <- rows[Applies == "Yes"]; n_all <- nrow(ans); n_ans <- sum(!is.na(ans$Check))
  body <- paste0("<h1>Reviewer's summary</h1><p class='note'>For the data and metadata reviewers. Not part of the published release. Upload the folder without review/.</p>",
    "<p><b>", rl_h(parent$citation$title), "</b><br>Release status: ", rl_h(info$ReleaseStatus %||% "Draft"), " &middot; IPDS: ", rl_h(if (md_supplied(info, "IpdsNumber")) info$IpdsNumber else "not yet entered"), " &middot; DOI: ", rl_h(if (md_supplied(info, "Doi")) info$Doi else "not yet reserved"), " &middot; written ", format(Sys.Date(), "%Y-%m-%d"), "</p>",
    "<h2>What it holds</h2>", rl_tbl(names(held), as.matrix(held[, lapply(.SD, function(x) rl_h(x))])), sprintf("<p>%d files, %s GB in all, listed with checksums in contents.csv. Each map variable of a run is one zip of yearly cloud-optimized GeoTIFFs.</p>", nrow(contents), g),
    "<h2>How it was made</h2><p>", rl_h(model$native), ". The model record cites ", length(model$quality$sources), " input datasets and has ", length(model$quality$steps), " process steps. ", rl_h(model$quality$logic), "</p>",
    "<h2>Key numbers</h2>", if (nrow(acc)) paste0("<p>Area of each transition group, simulated against the record the Build read, in km2:</p>", rl_tbl(c("Run", "Group", "Years", "Simulated", "Recorded", "Difference (%)"), as.matrix(acc[, lapply(.SD, function(x) rl_h(x))]))) else "<p>No historical run in this release to compare with a record.</p>",
    "<h2>Limits to weigh</h2>", li(limits),
    "<h2>What the stage's checks found</h2>", sprintf("<p>%d of %d must-pass checks passed. The stage's answers cover %d of the %d checklist items that apply; the rest need a person, including whether anything in the release is interpretive.</p>", sum(checks[Level == "must", Pass] %in% TRUE), sum(checks$Level == "must"), n_ans, n_all),
    if (nrow(failed)) paste0("<p class='no'>Not passed:</p>", li(sprintf("%s. %s", failed$What, failed$Detail))) else "", if (nrow(adv)) paste0("<p>For the reviewer's judgment:</p>", li(sprintf("%s. %s", adv$What, adv$Detail))) else "",
    "<h2>Still to supply</h2>", li(draft), "<h2>In this folder</h2>", li(c("data-review-checklist.html and metadata-review-checklist.html: the USGS checklists with the stage's answers", "checks.csv and checklist-answers.csv: the same, as tables", "mp-report.csv: what the USGS metadata parser found", "records-as-text/: each metadata record in readable form, when mp is available")))
  rl_page("Reviewer's summary", body, file.path(rv, "reviewer-summary.html"))
  invisible(rv) }
