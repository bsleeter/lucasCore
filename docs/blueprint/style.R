# =============================================================================
# style.R - what the blueprint drawings share: text and path helpers, colour tokens, the SVG classes, and the PNG export
# =============================================================================
# Sourced by build.R (stages and datasheets) and build-data.R (national data). One set of tokens and classes, so both drawings look
# alike in print, light and dark.
# =============================================================================
esc <- function(s) gsub(">", "&gt;", gsub("<", "&lt;", gsub("&", "&amp;", s, fixed = TRUE), fixed = TRUE), fixed = TRUE)
TX <- function(x, y, s, cls, anchor = NULL) sprintf('<text x="%s" y="%s" class="%s"%s>%s</text>', x, y, cls,
  if (is.null(anchor)) "" else sprintf(' text-anchor="%s"', anchor), esc(s))
PATH <- function(d, cls = "edge", arrow = TRUE) sprintf('<path d="%s" class="%s"%s/>', d, cls, if (arrow) ' marker-end="url(#ah)"' else "")
box <- function(x, y, w, h, eyebrow, name = NULL) paste0(sprintf('<rect class="box" x="%d" y="%d" width="%d" height="%d" rx="7"/>', x, y, w, h),
  TX(x + 16, y + 22, toupper(eyebrow), "eyebrow"), if (!is.null(name)) TX(x + 16, y + 42, name, "sname"))
defs <- '<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" class="ah"/></marker></defs>'
# stage families (both drawings colour a stage, its chips and its wires by these)
fam <- c(`0` = "setup", `1` = "setup", `2` = "carbon", `3` = "carbon", `4` = "carbon", `8` = "carbon", `5` = "land", `6` = "land",
         `9` = "land", `10` = "land", `7` = "climate", `11` = "climate", `12` = "fig", `13` = "fig", `14` = "fig")

rules <- "
.bg{fill:var(--bg)} .box{fill:var(--surface);stroke:var(--line);stroke-width:1}
.h1{font:700 22px var(--sans);fill:var(--ink)} .sub{font:400 12px var(--sans);fill:var(--muted)}
.eyebrow{font:500 9.5px var(--mono);letter-spacing:.08em;fill:var(--muted)} .sname{font:700 14px var(--sans);fill:var(--ink)}
.ghead{font:600 9px var(--mono);letter-spacing:.08em;fill:var(--muted)} .gt{font:600 12px var(--sans);fill:var(--ink)}
.item{font:400 10px var(--sans);fill:var(--ink2)} .txt{font:400 11px var(--sans);fill:var(--ink2)}
.mono{font:400 10px var(--mono);fill:var(--muted)} .lbl{font:400 9.5px var(--mono);fill:var(--muted)}
.foot{font:400 10.5px var(--sans);fill:var(--muted)} .lgt{font:400 11px var(--sans);fill:var(--ink2)}
.f-setup{--c:var(--setup);--t:var(--setup-t)} .f-land{--c:var(--land);--t:var(--land-t)} .f-carbon{--c:var(--carbon);--t:var(--carbon-t)}
.f-climate{--c:var(--climate);--t:var(--climate-t)} .f-fig{--c:var(--fig);--t:var(--fig-t)}
.lg{fill:var(--c)} .stage .sb{fill:var(--t);stroke:var(--c);stroke-width:1.2} .stage.ghost .sb{stroke-dasharray:4 3}
.badge{fill:var(--c)} .badge-t{font:600 11px var(--mono);fill:var(--on)} .sn{font:600 11.5px var(--sans);fill:var(--ink)}
.ss{font:400 9px var(--mono);fill:var(--muted)} .chip rect{fill:var(--c)} .chip-t{font:600 8.5px var(--mono);fill:var(--on)}
.sheet rect{fill:var(--carbon-t);stroke:var(--line);stroke-width:.8} .sheet-t{font:400 10px var(--sans);fill:var(--ink2)}
.edge{fill:none;stroke:var(--edge);stroke-width:1.3} .dep{fill:none;stroke:var(--edge);stroke-width:1.2;stroke-dasharray:5 4}
.lead{fill:none;stroke:var(--muted);stroke-width:.8;stroke-dasharray:1.5 2.5} .halo{fill:none;stroke:var(--surface);stroke-width:7}
.bus{fill:none;stroke:var(--setup);stroke-width:3.5;stroke-linecap:round} .tap{fill:none;stroke:var(--setup);stroke-width:1.5}
.dot{fill:var(--setup)} .ah{fill:var(--edge)} .rule{stroke:var(--line);stroke-width:1}
.engine rect{fill:var(--ink)} .engine-t{font:600 9.5px var(--mono);fill:var(--surface)}
.rowbg{fill:transparent} .rowt{font:400 10.5px var(--sans);fill:var(--ink2)}
.dsbg{fill:transparent} .dsn{font:600 11.5px var(--sans);fill:var(--ink)} .dsv{font:400 9.5px var(--mono);fill:var(--muted)}
.wire{fill:none;stroke:var(--c);stroke-width:1.3;opacity:.75} .wire.alt{stroke-dasharray:4 3}
.sport{fill:var(--edge)} .port{fill:var(--c)}
.sn2{font:600 13px var(--sans);fill:var(--ink)} .mk{font:400 11px var(--sans);fill:var(--ink2)} .ch{font:400 10px var(--sans);fill:var(--muted)}
"
light <- "--bg:#f4f6f6;--surface:#ffffff;--line:#cfd6d8;--ink:#17242a;--ink2:#34444b;--muted:#5f6e74;--edge:#3b4a51;--on:#ffffff;
--setup:#56666e;--setup-t:#eceff0;--land:#2d7650;--land-t:#e4f1e9;--carbon:#94561f;--carbon-t:#f7ece2;--climate:#2b679a;--climate-t:#e3edf6;--fig:#6a5293;--fig-t:#eee9f5;"
dark <- "--bg:#101619;--surface:#172024;--line:#304048;--ink:#e3eaec;--ink2:#c3cfd3;--muted:#8fa0a6;--edge:#a8b7bc;--on:#101619;
--setup:#9eb0b8;--setup-t:#1f2a2f;--land:#6dc59b;--land-t:#15291f;--carbon:#e3a46d;--carbon-t:#2d2118;--climate:#79b3e3;--climate-t:#15253a;--fig:#b9a0e6;--fig-t:#251f33;"
fonts <- "--sans:'IBM Plex Sans',Arial,Helvetica,sans-serif;--mono:'IBM Plex Mono',Consolas,'Courier New',monospace;"
gf <- "https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;600;700&display=swap"

svg_head <- function(W, H, title) paste0(sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d" role="img" aria-labelledby="bp-title">', W, H, W, H),
  "\n<title id=\"bp-title\">", esc(title), "</title>")
# the print figure: light tokens inside the SVG (CDATA, since the font URL has &)
standalone_svg <- function(head, body) paste0(head, "\n<style><![CDATA[@import url('", gf, "');\nsvg{", fonts, light, "}", rules, "]]></style>\n", body, "\n</svg>\n")
fill <- function(t, k, v) paste(strsplit(t, k, fixed = TRUE)[[1]], collapse = v)
fill_page <- function(tpl, svg_inline, json, version, n) {
  p <- fill(fill(fill(fill(fill(fill(tpl, "{{RULES}}", rules), "{{LIGHT}}", light), "{{DARK}}", dark), "{{FONTS}}", fonts), "{{SVG}}", svg_inline), "{{DATA}}", json)
  fill(fill(p, "{{VERSION}}", version), "{{N}}", as.character(n)) }
render_png <- function(svg_file, png_file, W, H) {
  browser <- Filter(file.exists, c("C:/Program Files/Google/Chrome/Application/chrome.exe", "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"))
  if (!length(browser)) return(cat("png: no Chrome or Edge found; open the SVG in a browser to export one\n"))
  png <- normalizePath(png_file, winslash = "\\", mustWork = FALSE)
  system2(browser[1], c("--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2", "--virtual-time-budget=4000",
                        sprintf("--window-size=%d,%d", W, H), shQuote(paste0("--screenshot=", png)),
                        paste0("file:///", normalizePath(svg_file, winslash = "/"))), stdout = FALSE, stderr = FALSE)
  cat(if (file.exists(png)) paste("png:", png) else "png: headless browser wrote nothing", "\n") }
