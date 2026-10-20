# =============================================================================
# curves.R - candidate merchantable-volume growth curves and fitting helpers (development; the chosen ones move to src/)
# =============================================================================
# Every form gives V(0) = 0 and rises to an asymptote A (m3/ha). t = stand age (years).
FORMS <- list(
  weibull_t10 = list(f = function(t, p) ifelse(t <= 10, 0, p[["A"]] * (1 - exp(-p[["k"]] * pmax(t - 10, 0)^p[["c"]]))),
                     start = function(A) list(c(A = A, k = 0.01, c = 0.8), c(A = A, k = 0.001, c = 1.3), c(A = A * 1.3, k = 0.03, c = 0.6)),
                     lower = c(A = 1, k = 1e-6, c = 0.1), upper = c(A = 5000, k = 1, c = 4), label = "Weibull, 10-yr lag (current)"),
  weibull     = list(f = function(t, p) p[["A"]] * (1 - exp(-p[["k"]] * t^p[["c"]])),
                     start = function(A) list(c(A = A, k = 0.001, c = 1.5), c(A = A, k = 0.01, c = 1), c(A = A * 1.3, k = 1e-4, c = 2)),
                     lower = c(A = 1, k = 1e-8, c = 0.1), upper = c(A = 5000, k = 1, c = 5), label = "Weibull"),
  richards    = list(f = function(t, p) p[["A"]] * (1 - exp(-p[["k"]] * t))^p[["c"]],
                     start = function(A) list(c(A = A, k = 0.02, c = 2), c(A = A, k = 0.05, c = 4), c(A = A * 1.3, k = 0.01, c = 1.5)),
                     lower = c(A = 1, k = 1e-5, c = 0.5), upper = c(A = 5000, k = 1, c = 30), label = "Chapman-Richards"),
  schumacher  = list(f = function(t, p) p[["A"]] * exp(-p[["b"]] / t),
                     start = function(A) list(c(A = A, b = 30), c(A = A * 1.5, b = 60), c(A = A, b = 10)),
                     lower = c(A = 1, b = 0.1), upper = c(A = 8000, b = 1000), label = "Schumacher"),
  korf        = list(f = function(t, p) p[["A"]] * exp(-p[["b"]] * t^(-p[["c"]])),
                     start = function(A) list(c(A = A, b = 30, c = 1), c(A = A, b = 10, c = 0.6), c(A = A * 1.5, b = 50, c = 1.2)),
                     lower = c(A = 1, b = 0.01, c = 0.05), upper = c(A = 8000, b = 2000, c = 4), label = "Korf (Lundqvist)")
)

# least squares fit of one form to (t, v) with several starts and bounds; returns the parameters of the best fit or NULL
fit_form <- function(form, t, v, w = NULL) {
  F <- FORMS[[form]]; A0 <- max(stats::quantile(v, 0.95), 5)
  if (is.null(w)) w <- rep(1, length(v))
  best <- NULL
  for (s in F$start(A0)) {
    pn <- names(s)
    obj <- function(par) { p <- setNames(par, pn); r <- v - F$f(t, p); sum(w * r^2) }
    o <- tryCatch(stats::optim(s, obj, method = "L-BFGS-B", lower = F$lower[pn], upper = F$upper[pn], control = list(maxit = 2000)), error = function(e) NULL)
    if (!is.null(o) && is.finite(o$value) && (is.null(best) || o$value < best$value)) best <- o
  }
  if (is.null(best)) return(NULL)
  p <- setNames(best$par, names(F$start(A0)[[1]]))
  attr(p, "sse") <- best$value; attr(p, "at_bound") <- any(abs(p - F$lower[names(p)]) < 1e-9 | abs(p - F$upper[names(p)]) < 1e-9)
  p }

predict_form <- function(form, p, t) if (is.null(p)) rep(NA_real_, length(t)) else FORMS[[form]]$f(t, p)

# the current method: median volume by stand age, then the fit to those medians
median_by_age <- function(t, v) { m <- tapply(v, t, stats::median); list(t = as.numeric(names(m)), v = as.numeric(m)) }

# grouped k-fold ids (by plot) - deterministic
fold_ids <- function(pid, k = 5, seed = 20261019) { u <- unique(pid); set.seed(seed); f <- sample(rep_len(seq_len(k), length(u))); f[match(pid, u)] }
