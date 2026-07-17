.ps_variogram_frame <- function(points) {
  pts <- .ps_standard_points(points)
  .require_projected(pts, "points")
  xy <- terra::crds(pts, df = TRUE); names(xy) <- c("X", "Y")
  cbind(xy, terra::values(pts))
}

#' Calculate an empirical groundwater-head variogram
#'
#' Calculates an ordinary or residual empirical variogram without fitting a
#' covariance model. Directions follow the gstat convention: degrees clockwise
#' from positive Y (North), periodic over 180 degrees. Pair counts and projected
#' coordinate units are retained.
#'
#' @param points Groundwater-head points with a `Z` column.
#' @param formula Head/trend formula, such as `Z ~ 1` or `Z ~ elevation`.
#' @param cutoff Maximum pair distance.
#' @param width Positive lag width.
#' @param boundaries Optional strictly increasing lag upper boundaries.
#' @param directions Direction angles clockwise from North.
#' @param direction_tolerance Horizontal tolerance in degrees.
#' @param robust Use gstat's Cressie robust estimator.
#' @param cloud Return individual pair semivariances.
#' @return A `potentiomap_variogram` with empirical values, formula,
#'   directions, point summary, settings and conditions.
#' @export
#' @references Pebesma (2004), \doi{10.1016/j.cageo.2004.03.012}.
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' v <- ps_variogram(pts, cutoff = 3000, width = 300)
#' head(v$empirical)
#' # An empirical variogram does not establish one correct covariance model.
ps_variogram <- function(points, formula = Z ~ 1, cutoff = NULL, width = NULL,
                         boundaries = NULL, directions = 0,
                         direction_tolerance = NULL, robust = FALSE,
                         cloud = FALSE) {
  call <- match.call(); .ps_scalar_logical(robust, "robust"); .ps_scalar_logical(cloud, "cloud")
  if (!inherits(formula, "formula")) .ps_abort("`formula` must be a formula.", "potentiomap_variogram_error")
  df <- .ps_variogram_frame(points)
  needed <- all.vars(formula)
  if (!all(needed %in% names(df))) .ps_abort("Variogram formula variables were not found in `points`.", "potentiomap_variogram_error")
  if (!is.null(cutoff) && (!is.numeric(cutoff) || length(cutoff) != 1L ||
      !is.finite(cutoff) || cutoff <= 0)) {
    .ps_abort("`cutoff` must be one finite positive number.", "potentiomap_variogram_error")
  }
  if (!is.null(width) && (!is.numeric(width) || length(width) != 1L ||
      !is.finite(width) || width <= 0)) {
    .ps_abort("`width` must be one finite positive number.", "potentiomap_variogram_error")
  }
  if (!is.null(boundaries) && (!is.numeric(boundaries) || any(!is.finite(boundaries)) ||
      any(boundaries <= 0) || is.unsorted(boundaries, strictly = TRUE))) {
    .ps_abort("`boundaries` must be finite, positive, and strictly increasing.", "potentiomap_variogram_error")
  }
  if (!is.numeric(directions) || !length(directions) || any(!is.finite(directions))) {
    .ps_abort("`directions` must contain finite angles.", "potentiomap_variogram_error")
  }
  directions <- directions %% 180
  if (is.null(direction_tolerance)) direction_tolerance <- 90 / length(directions)
  .validate_number(direction_tolerance, "direction_tolerance", lower = 0)
  if (direction_tolerance > 90) .ps_abort("`direction_tolerance` cannot exceed 90 degrees.", "potentiomap_variogram_error")
  if (is.null(cutoff)) {
    cutoff <- sqrt(diff(range(df$X))^2 + diff(range(df$Y))^2) / 3
  }
  if (is.null(width) && is.null(boundaries)) width <- cutoff / 15
  args <- list(object = formula, locations = ~ X + Y, data = df,
               cutoff = cutoff, alpha = directions, tol.hor = direction_tolerance,
               cressie = robust, cloud = cloud)
  if (!is.null(width)) args$width <- width
  if (!is.null(boundaries)) args$boundaries <- boundaries
  captured <- .ps_capture_run(do.call(gstat::variogram, args))
  if (!is.null(captured$error)) .ps_abort(conditionMessage(captured$error), "potentiomap_variogram_error",
                                          data = list(parent_message = conditionMessage(captured$error)))
  empirical <- as.data.frame(captured$value)
  conditions <- .ps_condition_rows(c(captured$warnings, captured$messages), "ps_variogram")
  low_pairs <- if ("np" %in% names(empirical)) empirical$np < 5 else logical()
  if (any(low_pairs)) {
    w <- .ps_condition(sprintf("%d lag-direction bin(s) contain fewer than five pairs.", sum(low_pairs)),
                       "potentiomap_variogram_warning", "warning")
    conditions <- rbind(conditions, .ps_condition_rows(list(w), "ps_variogram"))
    .ps_warn(conditionMessage(w), "potentiomap_variogram_warning")
  }
  unit <- tryCatch(terra::linearUnits(.as_points(points)), error = function(e) NA_character_)
  point_summary <- data.frame(observation_count = nrow(df), pair_count = if ("np" %in% names(empirical)) sum(empirical$np) else nrow(empirical),
                              lag_count = nrow(empirical), minimum_pairs = if ("np" %in% names(empirical) && nrow(empirical)) min(empirical$np) else NA_real_)
  .ps_new_result(list(empirical = empirical, formula = formula, directions = directions,
                      point_summary = point_summary), "potentiomap_variogram", call,
                 settings = list(cutoff = cutoff, width = width, boundaries = boundaries,
                                 direction_tolerance = direction_tolerance,
                                 robust = robust, cloud = cloud,
                                 angle_convention = "degrees clockwise from positive Y (North); periodic over 180 degrees"),
                 metadata = list(distance_unit = unit,
                                 semivariance_unit = paste0((.ps_surface_metadata(points)$head_unit %||% "head"), "^2")),
                 conditions = conditions, summary = point_summary)
}

.ps_initial_variogram <- function(empirical, model, initial = NULL) {
  if (!is.null(initial)) {
    if (inherits(initial, "variogramModel")) return(initial)
    if (is.list(initial) && all(c("psill", "range") %in% names(initial))) {
      return(gstat::vgm(psill = initial$psill, model = model, range = initial$range,
                        nugget = initial$nugget %||% 0, kappa = initial$kappa %||% 0.5))
    }
    .ps_abort("`initial` must be a gstat variogramModel or a parameter list.", "potentiomap_variogram_error")
  }
  gamma <- empirical$gamma[is.finite(empirical$gamma)]
  dist <- empirical$dist[is.finite(empirical$dist)]
  sill <- if (length(gamma)) max(gamma) else 1
  range <- if (length(dist)) stats::median(dist) else 1
  gstat::vgm(psill = max(sill * .9, .Machine$double.eps), model = model,
             range = max(range, .Machine$double.eps), nugget = max(sill * .1, 0))
}

#' Compare fitted variogram models
#'
#' Fits each requested gstat variogram candidate independently and preserves
#' initial values, fitted parameters, singular status, weighted fitting error,
#' warnings, and errors. Smallest variogram SSE is not proof of best predictive
#' performance.
#'
#' @param variogram A `potentiomap_variogram` or gstat empirical variogram.
#' @param models Candidate model abbreviations.
#' @param initial Optional model or named model-specific initial values.
#' @param fit_method gstat fit method.
#' @param anisotropy Optional explicit anisotropy result or `c(angle, ratio)`.
#' @param validation Optional compatible validation result/table.
#' @param select Select a model using an explicitly supplied criterion.
#' @param selection_metric Validation RMSE or weighted variogram SSE.
#' @return A `potentiomap_variogram_comparison` with every fit and ranking.
#' @export
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' cmp <- ps_variogram_compare(ps_variogram(pts), c("Sph", "Exp"))
#' cmp$ranking
#' # Weighted SSE alone is not a predictive-performance guarantee.
ps_variogram_compare <- function(variogram, models = c("Sph", "Exp", "Gau", "Mat"),
                                 initial = NULL, fit_method = 7,
                                 anisotropy = NULL, validation = NULL,
                                 select = FALSE,
                                 selection_metric = c("validation_rmse", "weighted_sse")) {
  call <- match.call(); criterion_missing <- missing(selection_metric); selection_metric <- match.arg(selection_metric)
  .ps_scalar_logical(select, "select")
  empirical <- if (inherits(variogram, "potentiomap_variogram")) variogram$empirical else as.data.frame(variogram)
  if (!all(c("dist", "gamma", "np") %in% names(empirical))) .ps_abort("`variogram` lacks gstat empirical variogram fields.", "potentiomap_variogram_error")
  if (!is.character(models) || !length(models) || anyNA(models) || anyDuplicated(models)) .ps_abort("`models` must contain unique model abbreviations.", "potentiomap_variogram_error")
  if (select && criterion_missing) .ps_abort("Supply `selection_metric` explicitly when `select = TRUE`.", "potentiomap_variogram_error")
  fits <- list(); rows <- list(); condition_rows <- list()
  for (i in seq_along(models)) {
    model <- models[i]; candidate_id <- sprintf("variogram_%04d", i)
    init <- if (is.list(initial) && !inherits(initial, "variogramModel") && model %in% names(initial)) initial[[model]] else initial
    init <- .ps_initial_variogram(empirical, model, init)
    if (any(!is.finite(init$psill) | init$psill < 0) || any(!is.finite(init$range) | init$range < 0)) {
      .ps_abort("Initial variogram parameters must be finite and nonnegative.", "potentiomap_variogram_error")
    }
    if (!is.null(anisotropy)) init <- .ps_apply_anisotropy_model(init, anisotropy)
    cap <- .ps_capture_run(gstat::fit.variogram(empirical, init, fit.method = fit_method))
    fit <- cap$value; status <- if (is.null(cap$error)) "success" else "failed"
    if (!is.null(fit) && (any(!is.finite(fit$psill)) || any(fit$psill < 0) || any(!is.finite(fit$range)) || any(fit$range < 0))) status <- "invalid_fit"
    fits[[candidate_id]] <- list(model = model, initial = init, fitted = fit,
                                 status = status, warnings = cap$warnings, error = cap$error)
    sse <- if (!is.null(fit)) as.numeric(attr(fit, "SSErr") %||% NA_real_) else NA_real_
    singular <- if (!is.null(fit)) isTRUE(attr(fit, "singular")) else NA
    fd <- if (!is.null(fit)) as.data.frame(fit) else data.frame()
    rows[[i]] <- data.frame(candidate_id = candidate_id, model = model, status = status,
      singular = singular, weighted_sse = sse,
      nugget = if (nrow(fd)) sum(fd$psill[fd$model == "Nug"], na.rm = TRUE) else NA_real_,
      partial_sill = if (nrow(fd)) sum(fd$psill[fd$model != "Nug"], na.rm = TRUE) else NA_real_,
      range = if (nrow(fd) && any(fd$model != "Nug")) max(fd$range[fd$model != "Nug"], na.rm = TRUE) else NA_real_,
      kappa = if (nrow(fd) && any(fd$model != "Nug")) fd$kappa[which(fd$model != "Nug")[1]] else NA_real_,
      warning_count = length(cap$warnings), error_count = as.integer(!is.null(cap$error)),
      stringsAsFactors = FALSE)
    condition_rows[[i]] <- .ps_condition_rows(c(cap$warnings, if (!is.null(cap$error)) list(cap$error) else list()),
                                               "ps_variogram_compare", candidate_id = candidate_id)
  }
  ranking <- do.call(rbind, rows)
  if (selection_metric == "validation_rmse") {
    if (is.null(validation)) {
      ranking$validation_rmse <- NA_real_
    } else {
      vt <- if (inherits(validation, "potentiomap_validation")) validation$metrics else as.data.frame(validation)
      if (!all(c("model", "rmse") %in% names(vt))) .ps_abort("Validation comparison requires `model` and `rmse` columns.", "potentiomap_variogram_error")
      ranking$validation_rmse <- vt$rmse[match(ranking$model, vt$model)]
    }
    score <- ranking$validation_rmse
  } else score <- ranking$weighted_sse
  ranking$rank <- rank(score, ties.method = "min", na.last = "keep")
  selected <- if (select && any(is.finite(score) & ranking$status == "success" & !ranking$singular)) {
    ranking$candidate_id[which.min(ifelse(ranking$status == "success" & !ranking$singular, score, Inf))]
  } else NULL
  conditions <- do.call(rbind, condition_rows)
  .ps_new_result(list(fits = fits, ranking = ranking, selection = selected),
                 "potentiomap_variogram_comparison", call,
                 settings = list(models = models, fit_method = fit_method,
                                 selection_metric = selection_metric, select = select),
                 metadata = if (inherits(variogram, "potentiomap_variogram")) variogram$metadata else list(),
                 conditions = conditions, summary = ranking,
                 warnings = "Variogram weighted SSE is a fitting diagnostic, not proof of predictive performance.")
}

#' Explore directional anisotropy in hydraulic head
#'
#' Calculates directional variograms and exploratory fitted ranges. The major
#' continuity direction is periodic over 180 degrees and uses gstat's
#' clockwise-from-North convention. Weak evidence is warned and anisotropy is
#' never activated in interpolation unless supplied explicitly.
#'
#' @param points Groundwater-head points.
#' @param formula Variogram trend formula.
#' @param directions Direction angles.
#' @param tolerance Direction tolerance in degrees.
#' @param cutoff,width Variogram controls.
#' @param model Candidate directional model.
#' @param minimum_pairs Minimum total pairs required for a directional fit.
#' @param validation Optionally request a documented isotropic/anisotropic
#'   validation comparison (recorded as not run when no validation design is
#'   supplied).
#' @return A `potentiomap_anisotropy` with empirical values, directional fits,
#'   major direction, minor-to-major range ratio, and conditions.
#' @export
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' a <- ps_anisotropy(pts, minimum_pairs = 5)
#' a$summary
#' # This exploratory result is not applied automatically.
ps_anisotropy <- function(points, formula = Z ~ 1,
                          directions = seq(0, 135, by = 45), tolerance = 22.5,
                          cutoff = NULL, width = NULL, model = "Sph",
                          minimum_pairs = 20, validation = FALSE) {
  call <- match.call(); .validate_integer(minimum_pairs, "minimum_pairs", lower = 0)
  if (!is.logical(validation) || length(validation) != 1L || is.na(validation)) .ps_abort("`validation` must be TRUE or FALSE.", "potentiomap_anisotropy_error")
  v <- ps_variogram(points, formula, cutoff, width, directions = directions,
                    direction_tolerance = tolerance)
  emp <- v$empirical; fits <- list(); rows <- list()
  for (i in seq_along(directions)) {
    direction <- directions[i] %% 180
    subset <- emp[abs(((emp$dir.hor - direction + 90) %% 180) - 90) < 1e-8, , drop = FALSE]
    pairs <- sum(subset$np, na.rm = TRUE); candidate_id <- sprintf("direction_%04d", i)
    if (nrow(subset) && pairs >= minimum_pairs) {
      init <- .ps_initial_variogram(subset, model)
      cap <- .ps_capture_run(gstat::fit.variogram(subset, init, fit.method = 7))
      fit <- cap$value; fd <- if (!is.null(fit)) as.data.frame(fit) else data.frame()
      range <- if (nrow(fd) && any(fd$model != "Nug")) max(fd$range[fd$model != "Nug"], na.rm = TRUE) else NA_real_
      status <- if (is.null(cap$error) && is.finite(range) && range > 0 && !isTRUE(attr(fit, "singular"))) "success" else "unstable"
      fits[[candidate_id]] <- fit
    } else { range <- NA_real_; status <- "insufficient_pairs"; fits[[candidate_id]] <- NULL }
    rows[[i]] <- data.frame(direction_id = candidate_id, direction = direction,
                            pair_count = pairs, fitted_range = range, status = status)
  }
  directional <- do.call(rbind, rows); usable <- directional$status == "success" & is.finite(directional$fitted_range)
  major <- if (any(usable)) directional$direction[which.max(directional$fitted_range)] else NA_real_
  ratio <- if (sum(usable) >= 2L) min(directional$fitted_range[usable]) / max(directional$fitted_range[usable]) else NA_real_
  conditions <- v$conditions
  warnings <- character()
  if (sum(usable) < 2L || !is.finite(ratio)) {
    msg <- "Directional evidence is weak or unstable; no precise anisotropy estimate is justified."
    .ps_warn(msg, "potentiomap_anisotropy_warning"); warnings <- msg
    conditions <- rbind(conditions, .ps_condition_rows(list(.ps_condition(msg, "potentiomap_anisotropy_warning", "warning")), "ps_anisotropy"))
  }
  summary <- data.frame(major_continuity_direction = major, minor_to_major_range_ratio = ratio,
                        usable_directions = sum(usable), angle_convention = "clockwise from North; modulo 180")
  .ps_new_result(list(empirical = emp, directional_fits = fits,
                      major_direction = major, range_ratio = ratio,
                      validation = if (validation) "requested; call ps_validate with explicit isotropic and anisotropic candidates" else NULL),
                 "potentiomap_anisotropy", call,
                 settings = list(formula = formula, directions = directions %% 180,
                                 tolerance = tolerance, cutoff = v$settings$cutoff,
                                 width = v$settings$width, model = model,
                                 minimum_pairs = minimum_pairs), metadata = v$metadata,
                 conditions = conditions, warnings = warnings, summary = summary)
}

.ps_apply_anisotropy_model <- function(model, anisotropy) {
  if (inherits(anisotropy, "potentiomap_anisotropy")) {
    angle <- anisotropy$major_direction; ratio <- anisotropy$range_ratio
  } else if (is.numeric(anisotropy) && length(anisotropy) == 2L) {
    angle <- anisotropy[1]; ratio <- anisotropy[2]
  } else {
    .ps_abort("`anisotropy` must be a potentiomap_anisotropy result or c(angle, ratio).", "potentiomap_anisotropy_error")
  }
  if (!is.finite(angle) || !is.finite(ratio) || ratio <= 0 || ratio > 1) {
    .ps_abort("Anisotropy requires a finite angle and ratio in (0, 1].", "potentiomap_anisotropy_error")
  }
  idx <- which(as.character(model$model) != "Nug")
  model$ang1[idx] <- angle %% 180; model$anis1[idx] <- ratio
  model
}

.ps_validate_variogram_model <- function(model) {
  if (!inherits(model, "variogramModel")) .ps_abort("`variogram_model` must be a gstat variogramModel.", "potentiomap_variogram_error")
  if (any(!is.finite(model$psill)) || any(model$psill < 0) || any(!is.finite(model$range)) || any(model$range < 0)) {
    .ps_abort("Variogram parameters must be finite and nonnegative.", "potentiomap_variogram_error")
  }
  model
}

.ps_covariate_frames <- function(points, template, grid, covariates, alignment) {
  pdat <- .kriging_frame(points); pvals <- terra::values(points)
  extra <- setdiff(names(pvals), names(pdat)); if (length(extra)) pdat[extra] <- pvals[extra]
  gdat <- grid; manifest <- data.frame()
  if (is.null(covariates)) return(list(points = pdat, grid = gdat, names = character(), manifest = manifest))
  if (inherits(covariates, "SpatRaster")) {
    covariates <- lapply(seq_len(terra::nlyr(covariates)), function(i) covariates[[i]])
    names(covariates) <- names(do.call(c, covariates))
  }
  if (is.list(covariates) && all(vapply(covariates, inherits, logical(1), "SpatRaster"))) {
    if (is.null(names(covariates)) || any(!nzchar(names(covariates))) || anyDuplicated(names(covariates))) {
      .ps_abort("Raster covariates require unique names.", "potentiomap_covariate_error")
    }
    rows <- list()
    for (nm in names(covariates)) {
      r <- .as_surface(covariates[[nm]], nm); .require_crs(r, nm)
      source <- .ps_geometry_record(r, nm)
      if (!.same_crs(r, template)) .ps_abort(sprintf("Covariate `%s` uses a different CRS.", nm), "potentiomap_covariate_error")
      aligned <- isTRUE(terra::compareGeom(r, template, stopOnError = FALSE))
      if (!aligned) {
        if (alignment == "error") .ps_abort(sprintf("Covariate `%s` geometry differs from the prediction template.", nm), "potentiomap_covariate_error")
        r <- terra::resample(r, template, method = if (alignment == "near") "near" else "bilinear")
      }
      pdat[[nm]] <- as.numeric(terra::extract(r, points, method = if (alignment == "near") "simple" else "bilinear")[[2]])
      gdat[[nm]] <- terra::values(r, mat = FALSE)
      rows[[nm]] <- cbind(source, aligned = aligned, alignment = if (aligned) "none" else alignment,
                          target_nrow = terra::nrow(template), target_ncol = terra::ncol(template))
    }
    manifest <- do.call(rbind, rows); rownames(manifest) <- NULL
    return(list(points = pdat, grid = gdat, names = names(covariates), manifest = manifest))
  }
  if (is.list(covariates) && all(c("points", "grid") %in% names(covariates)) &&
      is.data.frame(covariates$points) && is.data.frame(covariates$grid)) {
    if (nrow(covariates$points) != nrow(pdat) || nrow(covariates$grid) != nrow(gdat)) {
      .ps_abort("Point/grid covariate tables must match observation and prediction counts.", "potentiomap_covariate_error")
    }
    cn <- intersect(names(covariates$points), names(covariates$grid))
    if (!length(cn)) .ps_abort("Point/grid covariate tables have no shared columns.", "potentiomap_covariate_error")
    pdat[cn] <- covariates$points[cn]; gdat[cn] <- covariates$grid[cn]
    manifest <- data.frame(source = cn, aligned = TRUE, alignment = "supplied_point_grid", stringsAsFactors = FALSE)
    return(list(points = pdat, grid = gdat, names = cn, manifest = manifest))
  }
  .ps_abort("`covariates` must be named rasters or a list with point and grid tables.", "potentiomap_covariate_error")
}

.interp_kriging_extended <- function(points, template, grid, method, trend,
                                     covariates, alignment, standardize,
                                     variogram_model, anisotropy, control,
                                     kr_auto_cutoff, kr_cutoff, kr_width,
                                     coordinate_scaling = "center_scale") {
  allowed <- c("nmax", "nmin", "maxdist", "allow_na_covariates")
  if (length(control) && (is.null(names(control)) || any(!names(control) %in% allowed))) {
    .ps_abort(sprintf("Unknown `kriging_control` name; supported names are %s.", paste(allowed, collapse = ", ")), "potentiomap_covariate_error")
  }
  ctrl <- utils::modifyList(list(nmax = Inf, nmin = 0, maxdist = Inf, allow_na_covariates = FALSE), control)
  if (!is.numeric(ctrl$nmax) || length(ctrl$nmax) != 1L || is.na(ctrl$nmax) || ctrl$nmax <= 0) .ps_abort("`kriging_control$nmax` must be positive.", "potentiomap_covariate_error")
  if (!is.numeric(ctrl$nmin) || length(ctrl$nmin) != 1L || is.na(ctrl$nmin) || ctrl$nmin < 0) .ps_abort("`kriging_control$nmin` must be nonnegative.", "potentiomap_covariate_error")
  if (!is.numeric(ctrl$maxdist) || length(ctrl$maxdist) != 1L || is.na(ctrl$maxdist) || ctrl$maxdist <= 0) .ps_abort("`kriging_control$maxdist` must be positive.", "potentiomap_covariate_error")
  .ps_scalar_logical(ctrl$allow_na_covariates, "kriging_control$allow_na_covariates")
  cov <- .ps_covariate_frames(points, template, grid, covariates, alignment)
  pdat <- cov$points; gdat <- cov$grid; centers <- scales <- numeric()
  if (method == "UK" && is.null(trend)) {
    pt <- .quadratic_terms(pdat, coordinate_scaling); gt <- .quadratic_terms(gdat, coordinate_scaling, pt$center, pt$scale)
    pdat <- pt$data; gdat <- gt$data; trend <- Z ~ x + y + x2 + y2 + xy
  }
  if (is.null(trend)) trend <- Z ~ 1
  if (!inherits(trend, "formula") || !identical(all.vars(trend)[1], "Z")) {
    .ps_abort("Kriging `trend` must be a formula with response `Z`.", "potentiomap_covariate_error")
  }
  predictors <- setdiff(all.vars(trend), "Z")
  missing_p <- setdiff(predictors, names(pdat)); missing_g <- setdiff(predictors, names(gdat))
  if (length(missing_p) || length(missing_g)) .ps_abort(sprintf("Trend predictor coverage is missing: %s.", paste(unique(c(missing_p, missing_g)), collapse = ", ")), "potentiomap_covariate_error")
  for (nm in predictors) {
    if (!is.numeric(pdat[[nm]]) || !is.numeric(gdat[[nm]])) .ps_abort(sprintf("Trend predictor `%s` must be numeric.", nm), "potentiomap_covariate_error")
    finite <- is.finite(pdat[[nm]])
    if (!all(finite)) .ps_abort(sprintf("Observation covariate `%s` contains missing/nonfinite values.", nm), "potentiomap_covariate_error")
    s <- stats::sd(pdat[[nm]]); if (!is.finite(s) || s <= sqrt(.Machine$double.eps)) .ps_abort(sprintf("Covariate `%s` is constant.", nm), "potentiomap_covariate_error")
    if (standardize && nm %in% cov$names) {
      centers[nm] <- mean(pdat[[nm]]); scales[nm] <- s
      pdat[[nm]] <- (pdat[[nm]] - centers[nm]) / scales[nm]
      gdat[[nm]] <- (gdat[[nm]] - centers[nm]) / scales[nm]
    }
  }
  if (length(predictors) > 1L) {
    signatures <- vapply(pdat[predictors], function(z) .ps_stable_hash(signif(z, 12)), character(1))
    if (anyDuplicated(signatures)) .ps_abort("Duplicate trend covariates were detected.", "potentiomap_covariate_error")
  }
  mm <- stats::model.matrix(trend, pdat); rank <- qr(mm)$rank; condition_number <- tryCatch(kappa(mm, exact = TRUE), error = function(e) Inf)
  if (rank < ncol(mm)) .ps_abort(sprintf("Trend matrix is rank deficient (%d of %d columns).", rank, ncol(mm)), "potentiomap_covariate_error")
  warnings <- list()
  if (is.finite(condition_number) && condition_number > 1e8) warnings <- list(.ps_condition(sprintf("Trend condition number %.4g indicates strong collinearity.", condition_number), "potentiomap_covariate_warning", "warning"))
  complete_grid <- if (length(predictors)) {
    rowSums(!is.finite(as.matrix(gdat[predictors]))) == 0L
  } else rep(TRUE, nrow(gdat))
  if (any(!complete_grid) && !ctrl$allow_na_covariates) .ps_abort(sprintf("%d prediction cell(s) lack trend covariates.", sum(!complete_grid)), "potentiomap_covariate_error")
  trend_fit <- stats::lm(trend, data = pdat); pdat$resid <- stats::resid(trend_fit)
  if (is.null(variogram_model)) {
    vg <- .build_variogram(pdat, kr_auto_cutoff, kr_cutoff, kr_width); model <- vg$fitted
    warnings <- c(warnings, vg$warnings); messages <- vg$messages
    model_origin <- "fitted"
  } else { model <- .ps_validate_variogram_model(variogram_model); vg <- NULL; messages <- list(); model_origin <- "user_supplied_not_refitted" }
  if (!is.null(anisotropy)) model <- .ps_apply_anisotropy_model(model, anisotropy)
  pred <- variance <- rep(NA_real_, nrow(gdat))
  if (any(complete_grid)) {
    args <- list(formula = trend, locations = ~ X + Y, data = pdat,
                 newdata = gdat[complete_grid, , drop = FALSE], model = model,
                 nmax = ctrl$nmax, nmin = ctrl$nmin, maxdist = ctrl$maxdist)
    cap <- .ps_capture_run(do.call(gstat::krige, args))
    if (!is.null(cap$error)) .ps_abort(conditionMessage(cap$error), "potentiomap_covariate_error", data = list(parent_message = conditionMessage(cap$error)))
    pred[complete_grid] <- cap$value$var1.pred; variance[complete_grid] <- cap$value$var1.var
    warnings <- c(warnings, cap$warnings); messages <- c(messages, cap$messages)
  }
  r <- template; terra::values(r) <- pred; vr <- template; terra::values(vr) <- variance
  manifest <- cov$manifest
  if (length(cov$names)) {
    extras <- data.frame(source = cov$names,
      point_missing = vapply(pdat[cov$names], function(z) sum(!is.finite(z)), integer(1)),
      grid_missing = vapply(gdat[cov$names], function(z) sum(!is.finite(z)), integer(1)),
      center = centers[cov$names], scale = scales[cov$names], stringsAsFactors = FALSE)
    manifest <- merge(manifest, extras, by = "source", all = TRUE, sort = FALSE)
  }
  conditions <- .condition_table(warnings, messages, method)
  list(surface = r,
       fitted = list(method = method, formula = trend, data = pdat, newdata = gdat,
                     variogram_model = model, variogram_model_origin = model_origin,
                     prediction_variance = vr, trend_fit = trend_fit,
                     template = template, points = points,
                     covariate_manifest = manifest, coordinate_center = centers,
                     coordinate_scale = scales, kriging_control = ctrl),
       diagnostics = list(formula = paste(deparse(trend), collapse = " "), requested_method = method,
                          returned_method = method, observation_count = nrow(pdat),
                          variogram_model = model, variogram_model_origin = model_origin,
                          model_matrix_rank = rank, model_matrix_columns = ncol(mm),
                          condition_number = condition_number,
                          covariate_manifest = manifest,
                          missing_prediction_covariates = sum(!complete_grid),
                          return_status = if (length(warnings)) "success_with_warning" else "success"),
       parameters = list(trend = trend, standardize_covariates = standardize,
                         variogram_model = model, anisotropy = anisotropy,
                         kriging_control = ctrl, covariate_alignment = alignment),
       conditions = conditions, warnings_to_emit = warnings)
}

#' @export
as.data.frame.potentiomap_variogram <- function(x, ...) x$empirical
#' @export
as.data.frame.potentiomap_variogram_comparison <- function(x, ...) x$ranking
#' @export
as.data.frame.potentiomap_anisotropy <- function(x, ...) x$summary
