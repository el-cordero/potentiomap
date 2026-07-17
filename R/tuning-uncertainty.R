.ps_candidate_rows <- function(candidates, search = c("grid", "random"), seed = 1) {
  search <- match.arg(search)
  if (is.data.frame(candidates)) {
    out <- candidates
  } else if (is.list(candidates) && !is.null(names(candidates)) &&
             all(nzchar(names(candidates)))) {
    if (search == "grid") out <- do.call(expand.grid, c(candidates, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE))
    else {
      lengths <- lengths(candidates)
      if (length(unique(lengths)) != 1L) {
        .ps_abort("Random candidate lists must have equal-length parameter vectors or be supplied as a table.",
                  "potentiomap_tuning_error")
      }
      out <- as.data.frame(candidates, stringsAsFactors = FALSE)
    }
  } else {
    .ps_abort("`candidates` must be a data frame or a named parameter list.",
              "potentiomap_tuning_error")
  }
  if (!nrow(out)) .ps_abort("`candidates` is empty.", "potentiomap_tuning_error")
  if (is.null(names(out)) || any(!nzchar(names(out))) || anyDuplicated(names(out))) {
    .ps_abort("Candidate parameters require unique nonempty names.", "potentiomap_tuning_error")
  }
  out$candidate_id <- .ps_stable_ids("candidate", nrow(out))
  out
}

.ps_candidate_control <- function(row, method) {
  row <- as.list(row)
  row$candidate_id <- NULL
  drop <- vapply(row, function(z) length(z) == 1L && is.na(z), logical(1))
  row <- row[!drop]
  control <- row[intersect(names(row), c("idw_power", "idw_nmax", "tps_lambda",
                                        "kr_auto_cutoff", "kr_cutoff", "kr_width",
                                        "uk_coordinate_scaling", "trend", "covariates",
                                        "variogram_model", "anisotropy"))]
  neighborhood <- row[intersect(names(row), c("nmax", "nmin", "maxdist"))]
  if (length(neighborhood)) control$kriging_control <- neighborhood
  if (!is.null(control$idw_power) && (!is.numeric(control$idw_power) ||
      length(control$idw_power) != 1L || !is.finite(control$idw_power) ||
      control$idw_power <= 0)) {
    .ps_abort("Candidate `idw_power` must be finite and positive.",
              "potentiomap_tuning_error")
  }
  if (!is.null(control$idw_nmax) && (!is.numeric(control$idw_nmax) ||
      length(control$idw_nmax) != 1L || !is.finite(control$idw_nmax) ||
      control$idw_nmax < 1 || control$idw_nmax != as.integer(control$idw_nmax))) {
    .ps_abort("Candidate `idw_nmax` must be a positive integer.",
              "potentiomap_tuning_error")
  }
  if (!is.null(control$tps_lambda) && (!is.numeric(control$tps_lambda) ||
      length(control$tps_lambda) != 1L || !is.finite(control$tps_lambda) ||
      control$tps_lambda < 0)) {
    .ps_abort("Candidate `tps_lambda` must be finite and nonnegative.",
              "potentiomap_tuning_error")
  }
  if (!is.null(control$trend) && is.character(control$trend)) {
    control$trend <- stats::as.formula(control$trend)
  }
  if (is.null(control$variogram_model) && method %in% c("OK", "UK") &&
      any(c("model", "nugget", "partial_sill", "range", "kappa",
            "anisotropy_angle", "anisotropy_ratio") %in% names(row))) {
    model <- as.character(row$model %||% "Sph")
    psill <- as.numeric(row$partial_sill %||% 1)
    range <- as.numeric(row$range %||% 1)
    nugget <- as.numeric(row$nugget %||% 0)
    kappa <- as.numeric(row$kappa %||% 0.5)
    anis <- if (!is.null(row$anisotropy_angle) || !is.null(row$anisotropy_ratio)) {
      c(as.numeric(row$anisotropy_angle %||% 0), as.numeric(row$anisotropy_ratio %||% 1))
    } else c(0, 1)
    if (any(!is.finite(c(psill, range, nugget, kappa, anis))) ||
        psill < 0 || range <= 0 || nugget < 0 || anis[2] <= 0 || anis[2] > 1) {
      .ps_abort("Candidate variogram parameters are invalid.", "potentiomap_tuning_error")
    }
    control$variogram_model <- gstat::vgm(psill, model, range, nugget,
                                           anis = anis, kappa = kappa)
  }
  control
}

.ps_tuning_evaluate <- function(points, method, candidate_table, design, folds,
                                repeats, metric, minimum_coverage, template,
                                mask, grid_res, seed, progress = NULL,
                                prefix = "inner") {
  result_rows <- list(); fold_rows <- list(); condition_rows <- list()
  total <- nrow(candidate_table)
  for (i in seq_len(total)) {
    candidate_id <- candidate_table$candidate_id[i]
    .ps_progress(progress, i, total, candidate_id, "started")
    cap <- .ps_capture_run({
      control <- .ps_candidate_control(candidate_table[i, , drop = FALSE], method)
      ps_validate(
        points, methods = method, design = design, folds = folds, repeats = repeats,
        template = template, mask = mask, grid_res = grid_res,
        prediction_mode = if (is.null(control$covariates)) "direct" else "raster",
        interpolation_control = control, seed = seed
      )
    })
    validation <- cap$value
    pooled <- if (!is.null(validation)) {
      validation$metrics[validation$metrics$scope == "pooled" &
                           validation$metrics$support_subset == "all", , drop = FALSE]
    } else data.frame()
    value <- if (nrow(pooled) && metric %in% names(pooled)) pooled[[metric]][1] else NA_real_
    coverage <- if (nrow(pooled)) pooled$finite_coverage[1] else 0
    status <- if (!is.null(cap$error)) "failed" else if (!is.finite(value)) "nonfinite_metric" else "success"
    result_rows[[i]] <- data.frame(
      candidate_id = candidate_id, status = status, metric = value,
      coverage = coverage, eligible = status == "success" && coverage >= minimum_coverage,
      warning_count = length(cap$warnings) + if (!is.null(validation)) nrow(validation$conditions[validation$conditions$type == "warning", , drop = FALSE]) else 0L,
      error_count = as.integer(!is.null(cap$error)),
      warning_text = paste(vapply(cap$warnings, conditionMessage, character(1)), collapse = " | "),
      error_text = if (is.null(cap$error)) "" else conditionMessage(cap$error),
      stringsAsFactors = FALSE
    )
    if (!is.null(validation)) {
      fr <- validation$metrics[validation$metrics$scope == "fold", , drop = FALSE]
      if (nrow(fr)) {
        fr$candidate_id <- candidate_id
        fr$stage <- prefix
        fold_rows[[length(fold_rows) + 1L]] <- fr
      }
      condition_rows[[length(condition_rows) + 1L]] <- validation$conditions
    }
    condition_rows[[length(condition_rows) + 1L]] <- .ps_condition_rows(
      c(cap$warnings, if (!is.null(cap$error)) list(cap$error) else list()),
      "ps_tune_interpolation", method = method, candidate_id = candidate_id
    )
    .ps_progress(progress, i, total, candidate_id, status)
  }
  scores <- do.call(rbind, result_rows)
  scores$rank <- rank(ifelse(scores$eligible, scores$metric, NA_real_),
                      ties.method = "min", na.last = "keep")
  scores$selected <- FALSE
  if (any(scores$eligible)) scores$selected[which.min(ifelse(scores$eligible, scores$metric, Inf))] <- TRUE
  list(scores = scores,
       folds = if (length(fold_rows)) do.call(rbind, fold_rows) else data.frame(),
       conditions = if (length(condition_rows)) do.call(rbind, condition_rows) else .ps_empty_conditions())
}

#' Tune interpolation parameters under recorded validation partitions
#'
#' Compares explicit candidate configurations using the same deterministic
#' inner partitions. With an outer design, tuning occurs only inside each outer
#' training partition and the selected configuration is evaluated on its outer
#' holdout. Without an outer design, reported performance is tuning performance,
#' not an unbiased estimate of final predictive performance.
#'
#' @param points Groundwater-head points.
#' @param method One of `"TPS"`, `"IDW"`, `"OK"`, or `"UK"`.
#' @param candidates Candidate table or named parameter list.
#' @param inner_design,outer_design Inner and optional outer validation designs.
#' @param inner_folds,outer_folds,repeats Fold and repeat counts.
#' @param metric Objective metric minimized during selection.
#' @param minimum_coverage Minimum finite-prediction coverage.
#' @param template,mask,grid_res Fixed mapping controls.
#' @param refit Refit the selected configuration to all observations.
#' @param seed Deterministic seed.
#' @param progress Optional callback.
#' @param search Exhaustive grid or reproducible row sampling.
#' @param maximum_runs Maximum candidate-by-fold run guard.
#' @return A `potentiomap_tuning` object.
#' @examples
#' data("synthetic_wells")
#' p <- ps_make_points(synthetic_wells[1:12, ], "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' tuned <- ps_tune_interpolation(p, "IDW", list(idw_power = c(1.5, 2)),
#'                                inner_design = "kfold", inner_folds = 3,
#'                                refit = FALSE, seed = 4)
#' tuned$candidates[, c("candidate_id", "metric", "coverage", "selected")]
#' # These are tuning scores, not unbiased final performance estimates.
#' @export
ps_tune_interpolation <- function(points, method, candidates,
                                  inner_design = "spatial_block",
                                  outer_design = NULL, inner_folds = 5,
                                  outer_folds = 5, repeats = 1,
                                  metric = "rmse", minimum_coverage = 0.9,
                                  template = NULL, mask = NULL, grid_res = NULL,
                                  refit = TRUE, seed = 1, progress = NULL,
                                  search = c("grid", "random"),
                                  maximum_runs = 1000) {
  call <- match.call(); search <- match.arg(search); method <- toupper(method)
  if (length(method) != 1L || !method %in% c("TPS", "IDW", "OK", "UK")) {
    .ps_abort("`method` must be TPS, IDW, OK, or UK.", "potentiomap_tuning_error")
  }
  .validate_integer(inner_folds, "inner_folds", lower = 1)
  .validate_integer(outer_folds, "outer_folds", lower = 1)
  .validate_integer(repeats, "repeats", lower = 0)
  .validate_integer(maximum_runs, "maximum_runs", lower = 0)
  .validate_number(minimum_coverage, "minimum_coverage", lower = 0, inclusive = TRUE)
  if (minimum_coverage > 1) .ps_abort("`minimum_coverage` cannot exceed one.", "potentiomap_tuning_error")
  table <- .ps_candidate_rows(candidates, search, seed)
  planned <- nrow(table) * inner_folds * repeats * if (is.null(outer_design)) 1 else outer_folds
  if (planned > maximum_runs) .ps_abort(sprintf("Planned tuning runs (%d) exceed `maximum_runs` (%d).", planned, maximum_runs), "potentiomap_tuning_error")
  if (planned > 100L) .ps_warn(sprintf("Tuning will schedule approximately %d candidate-fold fits.", planned), "potentiomap_large_analysis_warning")
  pts <- .ps_standard_points(points); .require_projected(pts, "points")
  outer_results <- data.frame(); selected_by_outer <- data.frame()
  if (is.null(outer_design)) {
    evaluated <- .ps_tuning_evaluate(pts, method, table, inner_design,
                                     inner_folds, repeats, metric,
                                     minimum_coverage, template, mask,
                                     grid_res, seed, progress)
  } else {
    outer_design <- match.arg(outer_design, c("loocv", "kfold", "spatial_block", "leave_cluster_out", "user_folds"))
    plans <- .ps_fold_plan(pts, outer_design, NULL, NULL, outer_folds,
                           repeats, NULL, seed)
    outer_score_rows <- list(); outer_pred_rows <- list(); all_conditions <- list()
    values <- terra::values(pts)
    for (i in seq_along(plans)) {
      plan <- plans[[i]]; train <- pts[match(plan$train, values$Name)]
      hold <- pts[match(plan$validate, values$Name)]
      inner <- .ps_tuning_evaluate(train, method, table, inner_design,
                                   inner_folds, 1, metric, minimum_coverage,
                                   template, mask, grid_res, seed + i * 10000L,
                                   progress, prefix = "nested_inner")
      chosen <- inner$scores$candidate_id[inner$scores$selected]
      if (!length(chosen)) {
        outer_score_rows[[i]] <- data.frame(outer_fold_id = i, candidate_id = NA_character_,
                                             status = "no_eligible_candidate", metric = NA_real_, coverage = 0)
      } else {
        control <- .ps_candidate_control(table[table$candidate_id == chosen, , drop = FALSE], method)
        cap <- .ps_capture_run(.ps_direct_predict(train, hold, method, control))
        pred <- if (is.null(cap$error)) cap$value$predicted else rep(NA_real_, nrow(hold))
        observed <- terra::values(hold)$Z
        vals <- .ps_metric_values(observed, pred, metric)
        outer_score_rows[[i]] <- data.frame(outer_fold_id = i, candidate_id = chosen,
                                             status = if (is.null(cap$error)) "success" else "failed",
                                             metric = unname(vals[[metric]]),
                                             coverage = mean(is.finite(pred)))
        outer_pred_rows[[i]] <- data.frame(outer_fold_id = i, candidate_id = chosen,
                                            record_id = terra::values(hold)$Name,
                                            observed = observed, predicted = pred,
                                            residual = pred - observed)
        all_conditions[[length(all_conditions) + 1L]] <- .ps_condition_rows(
          c(cap$warnings, if (!is.null(cap$error)) list(cap$error) else list()),
          "ps_tune_interpolation", method = method, candidate_id = chosen,
          fold_id = sprintf("outer_%03d", i))
      }
      selected_by_outer <- rbind(selected_by_outer,
                                 data.frame(outer_fold_id = i,
                                            candidate_id = chosen %||% NA_character_,
                                            stringsAsFactors = FALSE))
      all_conditions[[length(all_conditions) + 1L]] <- inner$conditions
    }
    outer_results <- list(metrics = do.call(rbind, outer_score_rows),
                          predictions = if (length(outer_pred_rows)) do.call(rbind, outer_pred_rows) else data.frame(),
                          selected_parameters = merge(selected_by_outer, table, by = "candidate_id", all.x = TRUE))
    # A final tuning pass on all eligible observations selects the refit configuration.
    evaluated <- .ps_tuning_evaluate(pts, method, table, inner_design,
                                     inner_folds, repeats, metric,
                                     minimum_coverage, template, mask,
                                     grid_res, seed, progress)
    evaluated$conditions <- do.call(rbind, c(list(evaluated$conditions), all_conditions))
  }
  selected_id <- evaluated$scores$candidate_id[evaluated$scores$selected]
  selection <- if (length(selected_id)) merge(evaluated$scores[evaluated$scores$selected, , drop = FALSE], table, by = "candidate_id") else data.frame()
  final <- NULL
  if (isTRUE(refit) && length(selected_id)) {
    control <- .ps_candidate_control(table[table$candidate_id == selected_id, , drop = FALSE], method)
    final_grid_res <- grid_res
    if (is.null(template) && is.null(final_grid_res)) {
      xy <- terra::crds(pts)
      final_grid_res <- max(diff(range(xy[, 1])), diff(range(xy[, 2]))) / 50
    }
    args <- c(list(points = pts, methods = method, template = template,
                   mask = mask, grid_res = final_grid_res, return = "result"), control)
    final <- do.call(ps_interpolate, args)
  }
  parameter_text <- vapply(seq_len(nrow(table)), function(i) paste(
    sprintf("%s=%s", setdiff(names(table), "candidate_id"),
            vapply(table[i, setdiff(names(table), "candidate_id"), drop = FALSE],
                   function(z) paste(z, collapse = ","), character(1))), collapse = "; "), character(1))
  candidates_out <- merge(table, transform(evaluated$scores, parameters = parameter_text), by = "candidate_id", sort = FALSE)
  .ps_new_result(list(candidates = candidates_out,
                      fold_results = evaluated$folds,
                      outer_results = outer_results,
                      selection = selection,
                      final_result = final),
                 "potentiomap_tuning", call,
                 settings = list(method = method, inner_design = inner_design,
                                 outer_design = outer_design, inner_folds = inner_folds,
                                 outer_folds = outer_folds, repeats = repeats,
                                 metric = metric, minimum_coverage = minimum_coverage,
                                 search = search, planned_runs = planned,
                                 refit = refit),
                 metadata = .ps_surface_metadata(pts),
                 conditions = evaluated$conditions,
                 warnings = if (is.null(outer_design)) "Scores are tuning performance, not unbiased final predictive performance." else "Outer scores estimate performance of the full nested selection procedure under the stated partitions.",
                 summary = evaluated$scores, seed = seed)
}

.ps_uncertainty_layers <- function(realizations, probabilities, exceedance_levels = NULL) {
  if (!inherits(realizations, "SpatRaster") || terra::nlyr(realizations) < 1L) {
    .ps_abort("No finite uncertainty realizations are available.", "potentiomap_uncertainty_error")
  }
  central <- terra::app(realizations, mean, na.rm = TRUE); names(central) <- "central_estimate"
  standard_deviation <- terra::app(realizations, stats::sd, na.rm = TRUE); names(standard_deviation) <- "standard_deviation"
  quantiles <- terra::app(realizations, function(z) stats::quantile(z, probabilities, na.rm = TRUE, names = FALSE))
  names(quantiles) <- paste0("q", formatC(probabilities * 100, format = "fg", flag = "0"))
  finite_count <- terra::app(realizations, function(z) sum(is.finite(z))); names(finite_count) <- "finite_realization_count"
  exceedance <- NULL
  if (length(exceedance_levels)) {
    exceedance <- terra::app(realizations, function(z) vapply(exceedance_levels, function(level) mean(z > level, na.rm = TRUE), numeric(1)))
    names(exceedance) <- paste0("exceedance_", make.names(exceedance_levels))
  }
  list(central = central, standard_deviation = standard_deviation,
       quantiles = quantiles, lower = quantiles[[1]],
       upper = quantiles[[terra::nlyr(quantiles)]], finite_count = finite_count,
       support_count = finite_count, exceedance = exceedance)
}

#' Quantify model-conditional or resampling surface variability
#'
#' @param x A structured interpolation result.
#' @param points Points used for resampling sensitivity when `x` is absent.
#' @param method Interpolation method for resampling.
#' @param approach Uncertainty or sensitivity approach.
#' @param nsim Number of simulations or resamples.
#' @param probabilities Pointwise quantile probabilities.
#' @param resampling_design `"case"`, `"jackknife"`, or a list with a
#'   `type` and spatial `group` vector.
#' @param template,mask Mapping geometry controls.
#' @param keep_realizations Retain realization rasters in memory.
#' @param output_directory Optional realization directory.
#' @param seed Deterministic seed.
#' @param progress Optional callback.
#' @param exceedance_levels Optional head levels for exceedance probability.
#' @return A `potentiomap_uncertainty` object. Resampling products are
#'   sensitivity summaries, not formal confidence intervals.
#' @examples
#' data("synthetic_wells")
#' p <- ps_make_points(synthetic_wells[1:14, ], "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' fit <- suppressWarnings(ps_interpolate(p, methods = "OK", grid_res = 250,
#'                                        return = "result"))
#' uncertainty <- ps_surface_uncertainty(fit, approach = "kriging_variance")
#' uncertainty$method_manifest
#' # Kriging variance is conditional on the retained covariance model.
#' @export
ps_surface_uncertainty <- function(x = NULL, points = NULL, method = NULL,
                                   approach = c("kriging_variance", "conditional_simulation",
                                                "tps_standard_error", "resampling_sensitivity"),
                                   nsim = 100, probabilities = c(0.05, 0.5, 0.95),
                                   resampling_design = NULL, template = NULL,
                                   mask = NULL, keep_realizations = FALSE,
                                   output_directory = NULL, seed = 1,
                                   progress = NULL, exceedance_levels = NULL) {
  call <- match.call(); approach <- match.arg(approach)
  .validate_integer(nsim, "nsim", lower = 0); .validate_integer(seed, "seed", lower = 0)
  .ps_scalar_logical(keep_realizations, "keep_realizations")
  if (!is.numeric(probabilities) || any(!is.finite(probabilities)) ||
      any(probabilities <= 0 | probabilities >= 1) || is.unsorted(probabilities, strictly = TRUE)) {
    .ps_abort("`probabilities` must be increasing values strictly between zero and one.", "potentiomap_uncertainty_error")
  }
  result_method <- if (inherits(x, "potentiomap_result")) names(x$surfaces)[1] else toupper(method %||% "")
  fit <- if (inherits(x, "potentiomap_result")) x$fits[[result_method]] %||% x$fits[[1]] else NULL
  output_manifest <- data.frame(); realization_manifest <- list(); realization_raster <- NULL
  if (approach == "kriging_variance") {
    if (!result_method %in% c("OK", "UK") || is.null(fit$prediction_variance) || is.null(fit$variogram_model)) {
      .ps_abort("Kriging variance requires an OK or UK result retaining prediction variance and its fitted variogram.", "potentiomap_uncertainty_error")
    }
    variance <- fit$prediction_variance; names(variance) <- "prediction_variance"
    standard_error <- sqrt(variance); names(standard_error) <- "prediction_standard_error"
    central <- x$surfaces[[result_method]]; names(central) <- "central_estimate"
    quantiles <- do.call(c, lapply(probabilities, function(p) central + stats::qnorm(p) * standard_error))
    names(quantiles) <- paste0("q", probabilities * 100)
    finite <- !is.na(central); names(finite) <- "finite_support"
    layers <- list(central = central, standard_deviation = standard_error,
                   quantiles = quantiles, lower = quantiles[[1]],
                   upper = quantiles[[terra::nlyr(quantiles)]],
                   finite_count = finite, support_count = finite,
                   exceedance = if (length(exceedance_levels)) do.call(c, lapply(exceedance_levels, function(level) terra::app(c(central, standard_error), function(z) stats::pnorm((z[1] - level) / z[2])))) else NULL)
    assumptions <- "Model-conditional kriging variance under the fitted trend and variogram; this is not total hydrogeologic uncertainty."
  } else if (approach == "tps_standard_error") {
    if (result_method != "TPS" || is.null(fit$fit) || is.null(fit$grid)) {
      .ps_abort("TPS standard error requires a TPS result retaining its fields fit and prediction grid.", "potentiomap_uncertainty_error")
    }
    se <- fields::predictSE(fit$fit, as.matrix(fit$grid)); standard_error <- fit$template
    terra::values(standard_error) <- as.numeric(se); names(standard_error) <- "tps_standard_error"
    central <- x$surfaces[[result_method]]; names(central) <- "central_estimate"
    quantiles <- do.call(c, lapply(probabilities, function(p) central + stats::qnorm(p) * standard_error))
    names(quantiles) <- paste0("q", probabilities * 100)
    finite <- !is.na(central) & !is.na(standard_error)
    layers <- list(central = central, standard_deviation = standard_error,
                   quantiles = quantiles, lower = quantiles[[1]],
                   upper = quantiles[[terra::nlyr(quantiles)]],
                   finite_count = finite, support_count = finite, exceedance = NULL)
    assumptions <- "Pointwise fields smoothing-model standard errors; these do not represent all sources of uncertainty."
  } else if (approach == "conditional_simulation") {
    if (!result_method %in% c("OK", "UK") || is.null(fit$variogram_model) ||
        is.null(fit$data) || is.null(fit$newdata) || is.null(fit$formula) || is.null(fit$template)) {
      .ps_abort("Conditional simulation requires a retained supported kriging fit, trend, variogram, prediction grid, and template.", "potentiomap_uncertainty_error")
    }
    set.seed(seed)
    cap <- .ps_capture_run(gstat::krige(fit$formula, ~ X + Y, data = fit$data,
                                        newdata = fit$newdata,
                                        model = fit$variogram_model, nsim = nsim))
    if (!is.null(cap$error)) stop(cap$error)
    sim <- as.data.frame(cap$value)[, grep("^sim", names(cap$value)), drop = FALSE]
    realization_raster <- fit$template
    realization_raster <- do.call(c, replicate(ncol(sim), fit$template, simplify = FALSE))
    terra::values(realization_raster) <- as.matrix(sim)
    names(realization_raster) <- sprintf("simulation_%04d", seq_len(ncol(sim)))
    layers <- .ps_uncertainty_layers(realization_raster, probabilities, exceedance_levels)
    realization_manifest <- data.frame(realization_id = names(realization_raster),
                                       status = "success", seed = seed,
                                       random_path = "gstat conditional Gaussian sequential simulation")
    assumptions <- "Conditional Gaussian simulation under the retained trend and variogram; nugget treatment follows the supplied gstat covariance model."
  } else {
    pts <- .ps_standard_points(points %||% if (inherits(x, "potentiomap_result")) fit$points else NULL)
    method <- toupper(method %||% result_method)
    if (!method %in% c("TPS", "IDW", "OK", "UK")) .ps_abort("Resampling sensitivity supports TPS, IDW, OK, and UK.", "potentiomap_uncertainty_error")
    type <- if (is.list(resampling_design)) resampling_design$type %||% "spatial_group" else resampling_design %||% "case"
    if (!type %in% c("case", "jackknife", "spatial_group")) .ps_abort("Unknown resampling design.", "potentiomap_uncertainty_error")
    if (is.null(template)) template <- if (inherits(x, "potentiomap_result")) x$template else NULL
    if (is.null(template)) .ps_abort("Resampling sensitivity requires a fixed `template` or an interpolation result.", "potentiomap_uncertainty_error")
    ids <- terra::values(pts)$Name; groups <- if (is.list(resampling_design)) resampling_design$group else NULL
    if (type == "spatial_group" && (is.null(groups) || length(groups) != nrow(pts))) .ps_abort("Spatial-group resampling requires one explicit group per point.", "potentiomap_uncertainty_error")
    runs <- if (type == "jackknife") min(nsim, nrow(pts)) else if (type == "spatial_group") min(nsim, length(unique(groups))) else nsim
    surfaces <- list(); manifests <- list(); set.seed(seed)
    for (i in seq_len(runs)) {
      .ps_progress(progress, i, runs, sprintf("realization_%04d", i), "started")
      idx <- if (type == "case") sample.int(nrow(pts), nrow(pts), replace = TRUE) else if (type == "jackknife") setdiff(seq_len(nrow(pts)), i) else which(groups != unique(groups)[i])
      sampled <- pts[idx]; duplicated_locations <- anyDuplicated(as.data.frame(terra::crds(sampled))) > 0L
      duplicate_policy <- if (type == "case") "mean" else "error"
      cap <- .ps_capture_run(ps_interpolate(sampled, methods = method,
                                            template = template, mask = mask,
                                            return = "result",
                                            duplicate_action = duplicate_policy))
      if (!is.null(cap$value)) surfaces[[length(surfaces) + 1L]] <- cap$value$surfaces[[1]]
      manifests[[i]] <- data.frame(realization_id = sprintf("realization_%04d", i),
                                   status = if (is.null(cap$error)) "success" else "failed",
                                   retained_ids = paste(ids[idx], collapse = "|"),
                                   duplicate_locations = duplicated_locations,
                                   duplicate_policy = duplicate_policy,
                                   warning_text = paste(vapply(cap$warnings, conditionMessage, character(1)), collapse = " | "),
                                   error_text = if (is.null(cap$error)) "" else conditionMessage(cap$error),
                                   stringsAsFactors = FALSE)
      .ps_progress(progress, i, runs, sprintf("realization_%04d", i), manifests[[i]]$status)
    }
    if (!length(surfaces)) .ps_abort("Every resampling fit failed.", "potentiomap_uncertainty_error")
    realization_raster <- do.call(c, surfaces); names(realization_raster) <- sprintf("realization_%04d", seq_along(surfaces))
    layers <- .ps_uncertainty_layers(realization_raster, probabilities, exceedance_levels)
    realization_manifest <- do.call(rbind, manifests)
    assumptions <- paste0(
      "Resampling variability/sensitivity under the recorded resampling design; ",
      "case-resample duplicate coordinates are collapsed by their mean and the policy is recorded; ",
      "pointwise intervals are not formal confidence intervals."
    )
  }
  if (!is.null(output_directory) && !is.null(realization_raster)) {
    dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
    files <- file.path(output_directory, paste0(names(realization_raster), ".tif"))
    written <- character(); on.exit(if (length(written) && !all(file.exists(written))) unlink(written), add = TRUE)
    for (i in seq_len(terra::nlyr(realization_raster))) {
      terra::writeRaster(realization_raster[[i]], files[i], overwrite = FALSE)
      written <- c(written, files[i])
    }
    output_manifest <- data.frame(realization_id = names(realization_raster), file = normalizePath(files), stringsAsFactors = FALSE)
  }
  kept <- if (keep_realizations) realization_raster else NULL
  method_manifest <- data.frame(method = result_method %||% method,
                                approach = approach, assumptions = assumptions,
                                simulation_count = if (is.null(realization_raster)) 0L else terra::nlyr(realization_raster),
                                seed = seed, stringsAsFactors = FALSE)
  summary <- data.frame(approach = approach,
                        requested_realizations = if (approach %in% c("conditional_simulation", "resampling_sensitivity")) nsim else 0L,
                        successful_realizations = if (is.null(realization_raster)) 0L else terra::nlyr(realization_raster))
  .ps_new_result(c(layers, list(realizations = kept,
                               realization_manifest = realization_manifest,
                               method_manifest = method_manifest,
                               output_manifest = output_manifest)),
                 "potentiomap_uncertainty", call,
                 settings = list(approach = approach, nsim = nsim,
                                 probabilities = probabilities,
                                 resampling_design = resampling_design,
                                 keep_realizations = keep_realizations,
                                 exceedance_levels = exceedance_levels),
                 metadata = if (inherits(x, "potentiomap_result")) .ps_surface_metadata(x) else .ps_surface_metadata(points),
                 warnings = assumptions, summary = summary, seed = seed)
}

.ps_crossing_cells <- function(r, level) {
  local_min <- terra::focal(r, w = 3, fun = min, na.policy = "omit", na.rm = TRUE)
  local_max <- terra::focal(r, w = 3, fun = max, na.policy = "omit", na.rm = TRUE)
  out <- local_min <= level & local_max >= level
  names(out) <- "crossing"
  out
}

#' Construct pointwise contour-uncertainty bands
#'
#' @param uncertainty A `potentiomap_uncertainty` object.
#' @param levels Contour head levels.
#' @param probability Central pointwise probability.
#' @param method Empirical realization crossing or Gaussian pointwise method.
#' @param keep_realized_contours Retain contours for each realization.
#' @param minimum_realizations Minimum successful empirical realizations.
#' @param accept_gaussian Explicitly accept the Gaussian pointwise assumption.
#' @return A `potentiomap_contour_uncertainty` object. Bands are pointwise, not
#'   simultaneous confidence regions.
#' @examples
#' data("synthetic_wells")
#' p <- ps_make_points(synthetic_wells[1:14, ], "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' fit <- suppressWarnings(ps_interpolate(p, methods = "OK", grid_res = 300,
#'                                        return = "result"))
#' u <- ps_surface_uncertainty(fit, approach = "kriging_variance")
#' cu <- ps_contour_uncertainty(u, levels = 168, method = "gaussian_pointwise",
#'                              accept_gaussian = TRUE)
#' cu$level_manifest
#' # This is a pointwise band, not a simultaneous confidence region.
#' @export
ps_contour_uncertainty <- function(uncertainty, levels, probability = 0.9,
                                   method = c("empirical_crossing", "gaussian_pointwise"),
                                   keep_realized_contours = FALSE,
                                   minimum_realizations = 20,
                                   accept_gaussian = FALSE) {
  call <- match.call(); method <- match.arg(method)
  if (!inherits(uncertainty, "potentiomap_uncertainty")) .ps_abort("`uncertainty` must be a potentiomap uncertainty result.", "potentiomap_contour_uncertainty_error")
  if (!is.numeric(levels) || !length(levels) || any(!is.finite(levels))) .ps_abort("`levels` must be finite numeric values.", "potentiomap_contour_uncertainty_error")
  .validate_number(probability, "probability", lower = 0); if (probability >= 1) .ps_abort("`probability` must be below one.", "potentiomap_contour_uncertainty_error")
  .validate_integer(minimum_realizations, "minimum_realizations", lower = 0)
  .ps_scalar_logical(keep_realized_contours, "keep_realized_contours")
  .ps_scalar_logical(accept_gaussian, "accept_gaussian")
  realizations <- uncertainty$realizations
  if (method == "empirical_crossing" && (is.null(realizations) || terra::nlyr(realizations) < minimum_realizations)) {
    .ps_abort("Empirical contour crossing requires retained realizations meeting `minimum_realizations`.", "potentiomap_contour_uncertainty_error")
  }
  if (method == "gaussian_pointwise" && !accept_gaussian) .ps_abort("Set `accept_gaussian = TRUE` to accept pointwise Gaussian assumptions explicitly.", "potentiomap_contour_uncertainty_error")
  alpha <- (1 - probability) / 2
  central <- uncertainty$central
  lower <- if (method == "gaussian_pointwise") central + stats::qnorm(alpha) * uncertainty$standard_deviation else terra::app(realizations, function(z) stats::quantile(z, alpha, na.rm = TRUE))
  upper <- if (method == "gaussian_pointwise") central + stats::qnorm(1 - alpha) * uncertainty$standard_deviation else terra::app(realizations, function(z) stats::quantile(z, 1 - alpha, na.rm = TRUE))
  results <- list(); manifests <- list(); realized <- list()
  cell_area_values <- .ps_cell_area_values(central)
  for (i in seq_along(levels)) {
    level <- levels[i]
    contour <- terra::as.contour(central, levels = level)
    band <- lower <= level & upper >= level; names(band) <- paste0("pointwise_band_", level)
    exceed <- if (method == "gaussian_pointwise") terra::app(c(central, uncertainty$standard_deviation), function(z) stats::pnorm((z[1] - level) / z[2])) else terra::app(realizations, function(z) mean(z > level, na.rm = TRUE))
    crossing <- NULL
    if (!is.null(realizations)) {
      cross_layers <- do.call(c, lapply(seq_len(terra::nlyr(realizations)), function(j) .ps_crossing_cells(realizations[[j]], level)))
      crossing <- terra::app(cross_layers, mean, na.rm = TRUE)
      names(crossing) <- paste0("crossing_frequency_", level)
      if (keep_realized_contours) realized[[as.character(level)]] <- lapply(seq_len(terra::nlyr(realizations)), function(j) terra::as.contour(realizations[[j]], levels = level))
    }
    band_values <- terra::values(band, mat = FALSE)
    area <- sum(cell_area_values[is.finite(band_values) & band_values != 0], na.rm = TRUE)
    results[[as.character(level)]] <- list(central_contour = contour,
                                          exceedance_probability = exceed,
                                          crossing_frequency = crossing,
                                          pointwise_band = band,
                                          lower_surface = lower,
                                          upper_surface = upper)
    manifests[[i]] <- data.frame(level = level, probability = probability,
                                 method = method, pointwise_band_area_m2 = area,
                                 finite_realizations = if (is.null(realizations)) 0L else terra::nlyr(realizations),
                                 gaussian_assumption = method == "gaussian_pointwise",
                                 stringsAsFactors = FALSE)
  }
  manifest <- do.call(rbind, manifests)
  .ps_new_result(list(levels = results, realized_contours = if (keep_realized_contours) realized else NULL,
                      level_manifest = manifest),
                 "potentiomap_contour_uncertainty", call,
                 settings = list(levels = levels, probability = probability,
                                 method = method, minimum_realizations = minimum_realizations,
                                 keep_realized_contours = keep_realized_contours),
                 metadata = uncertainty$metadata,
                 warnings = if (method == "gaussian_pointwise") "Pointwise Gaussian bands omit spatial covariance of contour location and are not simultaneous confidence regions." else "Empirical products are pointwise contour-uncertainty bands, not simultaneous confidence regions.",
                 summary = manifest, seed = uncertainty$seed)
}

#' @export
as.data.frame.potentiomap_tuning <- function(x, ...) x$candidates
#' @export
as.data.frame.potentiomap_uncertainty <- function(x, ...) x$realization_manifest
#' @export
as.data.frame.potentiomap_contour_uncertainty <- function(x, ...) x$level_manifest
