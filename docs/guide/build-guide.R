# =============================================================================
# build-guide.R - the public copy of the lucasCore User Guide (a Claude Doc) for GitHub
# =============================================================================
# The guide is written and edited as a Claude Doc (https://claude.ai/artifact/Xt2xiTJxHnduXtCARdPYc9). This makes a snapshot of it:
#   user-guide.md   rendered by GitHub in the repo view (its outline menu lists the sections)
#   index.html      the same guide styled like the blueprints, with a contents sidebar, served by GitHub Pages at .../lucasCore/guide/
#   images/         the guide's figures, named by figure number (fig-3.2.png)
# from source/: the doc's Markdown and HTML exports (user-guide.md, user-guide.html; Docs export of the one tab) and blob-assets.csv
# (each image blob of the HTML export -> its asset id in the doc's asset store). The Markdown export marks each image as
# "&#91;image: <alt>\]" and the HTML export as <img src="blob/<id>">, both in document order; the build pairs them in that order
# and stops when the counts differ.
# To refresh after the doc changes: export both formats into source/, map the blobs (Docs read of each blob -> value.asset), download
# the assets (Artifact read with paths = the asset ids) into a folder, then: Rscript docs/guide/build-guide.R <assets folder>.
# Without the folder the build reuses images/ (it stops if one is missing).
# =============================================================================
here <- tryCatch(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) "docs/guide")
pkg <- normalizePath(file.path(here, "..", ".."), winslash = "/")
args <- commandArgs(TRUE); assets <- if (length(args)) args[1] else NA_character_
source(file.path(pkg, "docs", "blueprint", "style.R"))
src <- file.path(here, "source"); img_dir <- file.path(here, "images"); dir.create(img_dir, showWarnings = FALSE)
rd <- function(f) paste(readLines(file.path(src, f), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
md <- rd("user-guide.md"); html <- rd("user-guide.html")
map <- read.csv(file.path(src, "blob-assets.csv"), colClasses = "character")
exported <- format(file.mtime(file.path(src, "user-guide.html")), "%Y-%m-%d")
# a mention in the HTML export carries the person's internal Claude account id: the repo is public, so the export is scrubbed in place
mention <- '<span data-atom="mention"[^>]*>[^<]*</span>'
if (grepl(mention, html)) { html <- gsub(mention, "@author", html); writeLines(html, file.path(src, "user-guide.html"), useBytes = TRUE); cat("scrubbed mentions from source/user-guide.html\n") }
if (grepl("data-principal|\\bu_[A-Za-z0-9]{15,}", paste(html, md))) stop("an account id is still in the exports: remove it before building")
DOC <- "https://claude.ai/artifact/Xt2xiTJxHnduXtCARdPYc9"

# ---- images: pair the two exports' images in order, name each by the figure caption that follows it ----------------------------
md_img <- gregexpr("(?m)^&#91;image: (.*)\\\\\\]$", md, perl = TRUE)[[1]]         # one per line; the alt text may hold escaped \[ \]
blobs <- regmatches(html, gregexpr('src="blob/[0-9a-f-]+"', html))[[1]]; blobs <- sub('src="blob/([^"]+)"', "\\1", blobs)
if (length(md_img) != length(blobs)) stop(sprintf("the Markdown export has %d images and the HTML export %d", length(md_img), length(blobs)))
if (!all(blobs %in% map$blob) || any(!nzchar(map$asset[match(blobs, map$blob)]))) stop("blob-assets.csv does not map every image blob to an asset")
after <- substring(md, md_img + attr(md_img, "match.length"), md_img + attr(md_img, "match.length") + 120)
num <- sub("^\\s*\\*Figure ([0-9]+(\\.[0-9]+)*[a-z]?)\\..*$", "\\1", after)
name <- ifelse(grepl("^\\s*\\*Figure", after), paste0("fig-", num, ".png"), sprintf("img-%03d.png", seq_along(after)))
if (anyDuplicated(name)) stop("two images take the same figure name: ", paste(unique(name[duplicated(name)]), collapse = ", "))
asset <- map$asset[match(blobs, map$blob)]
for (i in seq_along(name)) { dest <- file.path(img_dir, name[i])
  if (!is.na(assets)) { f <- file.path(assets, paste0(asset[i], ".png")); if (!file.exists(f)) stop("asset not downloaded: ", f); file.copy(f, dest, overwrite = TRUE) }
  else if (!file.exists(dest)) stop("missing ", dest, " (pass the assets folder)") }
stale <- setdiff(list.files(img_dir), name); if (length(stale)) { file.remove(file.path(img_dir, stale)); cat("removed", length(stale), "unused images\n") }

# the doc's one embedded diagram (the scenario chain) does not export: the package blueprint shows the same chain
chain_md <- sprintf("[![The package blueprint: lucasCore's scenarios and stages](../blueprint/lucascore-blueprint.png)](%s)\n\n*The scenario chain, from the [package blueprint](%s) (the interactive diagram of the guide's Claude Doc does not export).*", PAGES, PAGES)
chain_html <- sprintf('<figure><a href="%s"><img src="../blueprint/lucascore-blueprint.png" alt="The package blueprint: lucasCore\'s scenarios, stages and datasheets" loading="lazy"></a><figcaption>The scenario chain, from the <a href="%s">package blueprint</a>.</figcaption></figure>', PAGES, PAGES)
note_md <- sprintf("*A snapshot of the lucasCore User Guide, exported %s. Also as a [web page](%sguide/), beside the [package](%s) and [data](%sdata.html) blueprints.*", exported, SITE, PAGES, PAGES)
note_html <- sprintf('<p class="snapshot">A snapshot of the lucasCore User Guide, exported %s. Figures are SyncroSim Studio 3.1 on Windows; the worked example is the Northern Sierra Nevada pyrome (P26).</p>', exported)

# ---- user-guide.md ------------------------------------------------------------------------------------------------------------------
alts <- sub("^&#91;image: (.*)\\\\\\]$", "\\1", regmatches(md, list(md_img))[[1]], perl = TRUE)   # brackets in it are already escaped
pieces <- regmatches(md, list(md_img), invert = TRUE)[[1]]
out <- pieces[1]; for (i in seq_along(name)) out <- paste0(out, sprintf("![%s](images/%s)", alts[i], name[i]), pieces[i + 1])
out <- sub("&#91;embedded content: [^\n]*\\\\\\]", chain_md, out, perl = TRUE)
lines <- strsplit(out, "\n", fixed = TRUE)[[1]]
by <- which(grepl("^[A-Z][a-z]{2} [0-9]{1,2}, [0-9]{4} · @", lines))[1]       # the doc's byline (date · author) becomes the snapshot note
if (is.na(by)) stop("no byline under the title in the Markdown export") else lines[by] <- note_md
writeLines(lines, file.path(here, "user-guide.md"), useBytes = TRUE)

# ---- index.html ---------------------------------------------------------------------------------------------------------------------
body <- html
for (i in seq_along(blobs)) body <- sub(sprintf('src="blob/%s"', blobs[i]), sprintf('src="images/%s" loading="lazy"', name[i]), body, fixed = TRUE)
body <- sub('<figure data-embed="[^"]*">.*?</figure>', chain_html, body, perl = TRUE)
body <- sub("<p><time data-atom=\"date\".*?</p>", note_html, body, perl = TRUE)
body <- sub('<h1 id="[^"]*">[^<]*</h1>', "", body)                                   # the page header carries the title
h <- regmatches(body, gregexpr('<h([23]) id="([^"]+)">(.*?)</h\\1>', body, perl = TRUE))[[1]]
lvl <- sub("^<h([23]).*", "\\1", h); hid <- sub('^<h[23] id="([^"]+)".*', "\\1", h); txt <- gsub("<[^>]+>", "", sub("^<h[23][^>]*>(.*)</h[23]>$", "\\1", h))
toc <- character(); open <- FALSE
for (i in seq_along(h)) { a <- sprintf('<a href="#%s">%s</a>', hid[i], txt[i])
  if (lvl[i] == "2") { if (open) toc <- c(toc, "</ol></li>"); toc <- c(toc, paste0("<li>", a, "<ol>")); open <- TRUE } else toc <- c(toc, paste0("<li>", a, "</li>")) }
if (open) toc <- c(toc, "</ol></li>")
toc <- gsub("<ol></ol>", "", paste0('<ol class="toc">', paste(toc, collapse = ""), "</ol>"))
tpl <- paste(readLines(file.path(here, "template-guide.html"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
page <- fill(fill(fill(fill(fill(fill(fill(tpl, "{{LIGHT}}", light), "{{DARK}}", dark), "{{FONTS}}", fonts), "{{NAV}}", nav("guide")), "{{TOC}}", toc), "{{BODY}}", body), "{{DOC}}", DOC)
writeLines(paste0(page_head, page), file.path(here, "index.html"), useBytes = TRUE)
mb <- sum(file.size(file.path(img_dir, name))) / 1e6
cat(sprintf("guide: %d images (%.1f MB), %d sections\nmd: %s\nhtml: %s\n", length(name), mb, sum(lvl == "2"), file.path(here, "user-guide.md"), file.path(here, "index.html")))
