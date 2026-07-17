.ps_fold_plan <- function(points, design, fold_id, cluster, folds, repeats,
                          block_size, seed, validation_points = NULL) {
  vals <- terra::values(points); ids <- vals$Name; n <- nrow(points)
  xy <- terra::crds(points)
  rows <- list(); k <- 0L
  add <- function(repeat_id, fold_label, train, validate, source) {
    k <<- k + 1L
    rows[[k]] <<- list(repeat_id = repeat_id, fold_label = as.character(fold_label),
                       train = train, validate = validate, source = source)
  }
  if (design == "independent") {
    vid <- terra::values(validation_points)$Name
    for (rep in seq_len(repeats)) add(rep, 1L, ids, vid, "independent")
  } else if (design == "loocv") {
    for (rep in seq_len(repeats)) for (i in seq_len(n)) add(rep, i, ids[-i], ids[i], "loocv")
  } else {
    assignment <- NULL
    if (design == "user_folds") assignment <- if (length(fold_id) == 1L && is.character(fold_id) && fold_id %in% names(vals)) vals[[fold_id]] else fold_id
    if (design == "leave_cluster_out") assignment <- if (length(cluster) == 1L && is.character(cluster) && cluster %in% names(vals)) vals[[cluster]] else cluster
    if (!is.null(assignment) && length(assignment) != n) .ps_abort("Fold/cluster assignment length must equal the observation count.", "potentiomap_validation_error")
    for (rep in seq_len(repeats)) {
      if (design == "kfold") {
        set.seed(seed + rep - 1L); assignment <- rep(seq_len(min(folds, n)), length.out = n)[sample.int(n)]
      }
      if (design == "spatial_block") {
        size <- block_size
        if (is.null(size)) size <- max(diff(range(xy[, 1])), diff(range(xy[, 2]))) / max(1, sqrt(folds))
        .validate_number(size, "block_size", lower = 0)
        block <- paste(floor((xy[, 1] - min(xy[, 1])) / size), floor((xy[, 2] - min(xy[, 2])) / size), sep = "_")
        unique_blocks <- unique(block)
        set.seed(seed + rep - 1L); shuffled <- sample(unique_blocks)
        block_fold <- setNames(rep(seq_len(min(folds, length(unique_blocks))), length.out = length(unique_blocks)), shuffled)
        assignment <- unname(block_fold[block])
      }
      if (is.null(assignment) || anyNA(assignment)) .ps_abort("Fold assignments must be complete.", "potentiomap_validation_error")
      levels <- unique(as.character(assignment))
      for (lev in levels) {
        validation <- ids[as.character(assignment) == lev]
        training <- ids[as.character(assignment) != lev]
        add(rep, lev, training, validation, design)
      }
    }
  }
  rows
}

.ps_direct_predict <- function(train, validate, method, control) {
  method <- toupper(method); grid <- as.data.frame(terra::crds(validate, df = TRUE)); names(grid) <- c("X", "Y")
  if (method == "TPS") {
    xy <- terra::crds(train); fit <- fields::Tps(xy, terra::values(train)$Z,
                                                 lambda = control$tps_lambda %||% NULL)
    return(list(predicted = as.numeric(stats::predict(fit, as.matrix(grid))), variance = rep(NA_real_, nrow(grid)), fit = fit))
  }
  if (method == "IDW") {
    tr <- sf::st_as_sf(train); va <- sf::st_as_sf(validate)
    model <- gstat::gstat(id = "Z", formula = Z ~ 1, data = tr,
                          set = list(idp = control$idw_power %||% 2))
    pred <- stats::predict(model, va, nmax = control$idw_nmax %||% 15)
    column <- intersect(c("Z.pred", "var1.pred"), names(pred))[1]
    return(list(predicted = as.numeric(pred[[column]]), variance = rep(NA_real_, nrow(grid)), fit = model))
  }
  if (method %in% c("OK", "UK")) {
    pts <- .kriging_frame(train)
    if (method == "OK") {
      formula <- Z ~ 1; pts$resid <- pts$Z - mean(pts$Z); gd <- grid
    } else {
      transformed <- .quadratic_terms(pts, control$uk_coordinate_scaling %||% "center_scale")
      pts <- transformed$data; pts$resid <- stats::resid(stats::lm(Z ~ x + y + x2 + y2 + xy, pts))
      gd <- .quadratic_terms(grid, control$uk_coordinate_scaling %||% "center_scale",
                             transformed$center, transformed$scale)$data
      formula <- Z ~ x + y + x2 + y2 + xy
    }
    if (!is.null(control$trend) || !is.null(control$covariates)) {
      .ps_abort("Direct prediction for explicit external-drift covariates requires a documented compatible direct predictor; use raster mode.", "potentiomap_validation_error")
    }
    model <- control$variogram_model %||% .build_variogram(
      pts, control$kr_auto_cutoff %||% TRUE,
      control$kr_cutoff %||% NA_real_, control$kr_width %||% NA_real_
    )$fitted
    pred <- gstat::krige(formula, ~ X + Y, data = pts, newdata = gd, model = model,
                         nmax = control$kriging_control$nmax %||% Inf,
                         nmin = control$kriging_control$nmin %||% 0,
                         maxdist = control$kriging_control$maxdist %||% Inf)
    return(list(predicted = pred$var1.pred, variance = pred$var1.var,
                fit = list(formula = formula, model = model, data = pts)))
  }
  .ps_abort(sprintf("Direct prediction is unavailable for method `%s`.", method),
            "potentiomap_validation_error")
}

.ps_holdout_support <- function(train, validate, predicted, mask = NULL) {
  trsf <- sf::st_as_sf(train); vasf <- sf::st_as_sf(validate)
  hull <- sf::st_convex_hull(sf::st_union(trsf))
  inside <- as.logical(sf::st_within(vasf, hull, sparse = FALSE)[, 1])
  d <- matrix(as.numeric(sf::st_distance(vasf, trsf)), nrow = nrow(vasf))
  nearest <- apply(d, 1, min, na.rm = TRUE)
  in_mask <- rep(TRUE, nrow(validate))
  if (!is.null(mask)) {
    m <- if (inherits(mask, "SpatVector")) mask else terra::vect(mask)
    if (!.same_crs(m, validate)) .ps_abort("Validation mask and points use different CRS.", "potentiomap_crs_error")
    in_mask <- apply(sf::st_intersects(sf::st_as_sf(validate),
                                       sf::st_as_sf(m), sparse = FALSE), 1, any)
  }
  data.frame(inside_training_hull = inside, nearest_training_distance = nearest,
             finite_prediction = is.finite(predicted), mask_membership = in_mask,
             supported = inside & is.finite(predicted) & in_mask)
}

.ps_validation_metric_rows <- function(predictions, metrics, weights = NULL) {
  groups <- split(seq_len(nrow(predictions)), interaction(predictions$method, predictions$design,
                                                          drop = TRUE, lex.order = TRUE))
  rows <- list(); k <- 0L
  for (idx in groups) {
    for (subset in c("all", "finite", "supported")) {
      use <- if (subset == "all") rep(TRUE, length(idx)) else if (subset == "finite") predictions$finite_prediction[idx] else predictions$supported[idx]
      scheduled <- length(idx); chosen <- idx[use]
      vals <- .ps_metric_values(predictions$observed[chosen], predictions$predicted[chosen], metrics,
                                if (is.null(weights)) NULL else weights[chosen])
      k <- k + 1L
      row <- data.frame(method = predictions$method[idx[1]], design = predictions$design[idx[1]],
                        scope = "pooled", fold_id = NA_character_, support_subset = subset,
                        scheduled_count = scheduled,
                        evaluated_count = sum(is.finite(predictions$observed[chosen]) &
                                                is.finite(predictions$predicted[chosen])),
                        finite_count = sum(predictions$finite_prediction[idx]),
                        supported_count = sum(predictions$supported[idx]), stringsAsFactors = FALSE)
      for (nm in names(vals)) row[[nm]] <- vals[[nm]]
      row$finite_coverage <- mean(predictions$finite_prediction[idx]); row$support_coverage <- mean(predictions$supported[idx])
      rows[[k]] <- row
    }
    fold_groups <- split(idx, predictions$fold_id[idx])
    for (fid in names(fold_groups)) {
      j <- fold_groups[[fid]]; vals <- .ps_metric_values(predictions$observed[j], predictions$predicted[j], metrics,
                                                        if (is.null(weights)) NULL else weights[j])
      k <- k + 1L
      row <- data.frame(method = predictions$method[j[1]], design = predictions$design[j[1]],
                        scope = "fold", fold_id = fid, support_subset = "all",
                        scheduled_count = length(j), evaluated_count = sum(is.finite(predictions$predicted[j])),
                        finite_count = sum(predictions$finite_prediction[j]), supported_count = sum(predictions$supported[j]),
                        stringsAsFactors = FALSE)
      for (nm in names(vals)) row[[nm]] <- vals[[nm]]
      row$finite_coverage <- mean(predictions$finite_prediction[j]); row$support_coverage <- mean(predictions$supported[j])
      rows[[k]] <- row
    }
  }
  if (length(rows)) do.call(rbind, rows) else data.frame()
}

#' Validate potentiometric-surface interpolation
#'
#' Evaluates requested methods under an explicit leave-one-out, k-fold, spatial
#' block, cluster, user-fold, or independent validation prediction task.
#' Held-out heads never construct folds and held-out records never enter their
#' training fit. Cross-validation performance is not automatically area-wide map
#' accuracy.
#'
#' @param points Training groundwater-head points with stable IDs.
#' @param methods Interpolation methods.
#' @param design Validation design.
#' @param validation_points Independent compatible validation points.
#' @param fold_id,cluster Assignment vector or column.
#' @param folds,repeats Positive counts.
#' @param block_size Spatial-block size in projected units.
#' @param template,mask,grid_res Fixed mapping geometry controls.
#' @param domain_policy Fixed or fold-training-derived raster domain.
#' @param prediction_mode Full raster/extraction sequence or supported direct
#'   prediction.
#' @param metrics Error metrics; residual is predicted minus observed.
#' @param support Calculate held-out hull/distance/mask support.
#' @param sampling_weight Optional weights for explicitly independent probability
#'   validation records only.
#' @param interpolation_control Named arguments passed to interpolation.
#' @param seed Deterministic master seed.
#' @param progress Optional callback `(index, total, run_id, status)`.
#' @return A `potentiomap_validation` with predictions, metrics, fold/partition/
#'   fit manifests, support summary, settings and captured conditions.
#' @export
#' @references Roberts et al. (2017), \doi{10.1111/ecog.02881}; Wadoux et al.
#'   (2021), \doi{10.1016/j.ecolmodel.2021.109692}.
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' val <- ps_validate(pts, methods = "IDW", design = "kfold", folds = 3,
#'                    prediction_mode = "direct", seed = 7)
#' val$metrics
#' # These scores describe the stated folds, not design-unbiased map accuracy.
ps_validate <- function(points, methods = c("TPS", "IDW", "OK", "UK"),
                        design = c("loocv", "kfold", "spatial_block",
                                   "leave_cluster_out", "user_folds", "independent"),
                        validation_points = NULL, fold_id = NULL, cluster = NULL,
                        folds = 5, repeats = 1, block_size = NULL,
                        template = NULL, mask = NULL, grid_res = NULL,
                        domain_policy = c("fixed", "training"),
                        prediction_mode = c("raster", "direct"),
                        metrics = c("me", "mae", "rmse", "medae", "maxae"),
                        support = TRUE, sampling_weight = NULL,
                        interpolation_control = list(), seed = 1,
                        progress = NULL) {
  call <- match.call(); design <- match.arg(design); domain_policy <- match.arg(domain_policy); prediction_mode <- match.arg(prediction_mode)
  .validate_integer(folds, "folds", lower = 1); .validate_integer(repeats, "repeats", lower = 0)
  .validate_integer(seed, "seed", lower = 0); .ps_scalar_logical(support, "support")
  allowed_metrics <- c("me", "mae", "rmse", "medae", "maxae", "correlation", "r_squared")
  if (!is.character(metrics) || !length(metrics) || any(!metrics %in% allowed_metrics)) .ps_abort("Unknown validation metric.", "potentiomap_validation_error")
  if (!is.list(interpolation_control)) .ps_abort("`interpolation_control` must be a named list.", "potentiomap_validation_error")
  pts <- .ps_standard_points(points); .require_projected(pts, "points")
  vpts <- if (design == "independent") {
    if (is.null(validation_points)) .ps_abort("`validation_points` is required for independent validation.", "potentiomap_validation_error")
    z <- .ps_standard_points(validation_points, name = "validation_points")
    if (!.same_crs(pts, z)) .ps_abort("Training and independent validation CRS differ.", "potentiomap_crs_error")
    z
  } else pts
  if (!is.character(methods) || !length(methods)) .ps_abort("`methods` must contain method names.", "potentiomap_validation_error")
  methods <- toupper(methods)
  if (!all(methods %in% c("TPS", "IDW", "OK", "UK"))) .ps_abort("Validation currently supports TPS, IDW, OK, and UK methods.", "potentiomap_validation_error")
  if (!is.null(sampling_weight) && design != "independent") .ps_abort("Sampling weights are accepted only for independent validation.", "potentiomap_validation_error")
  if (!is.null(sampling_weight) && (length(sampling_weight) != nrow(vpts) || any(!is.finite(sampling_weight)) || any(sampling_weight < 0) || sum(sampling_weight) <= 0)) {
    .ps_abort("`sampling_weight` must be finite nonnegative independent-validation weights.", "potentiomap_validation_error")
  }
  plans <- .ps_fold_plan(pts, design, fold_id, cluster, folds, repeats, block_size, seed, vpts)
  fixed_template <- template
  if (prediction_mode == "raster" && domain_policy == "fixed" && is.null(fixed_template)) {
    if (is.null(grid_res)) grid_res <- max(diff(range(terra::crds(pts)[, 1])), diff(range(terra::crds(pts)[, 2]))) / 25
    fixed_template <- .surface_template(pts, grid_res, NULL, mask, NULL)
  }
  prediction_rows <- list(); fold_rows <- list(); fit_rows <- list(); partition_rows <- list(); condition_rows <- list(); out_index <- 0L
  total_runs <- length(plans) * length(methods); run_index <- 0L
  pvals <- terra::values(pts); vvals <- terra::values(vpts)
  for (f in seq_along(plans)) {
    plan <- plans[[f]]; fold_key <- sprintf("repeat_%03d_fold_%s", plan$repeat_id, .safe_name(plan$fold_label))
    train_idx <- match(plan$train, pvals$Name); valid_idx <- if (design == "independent") match(plan$validate, vvals$Name) else match(plan$validate, pvals$Name)
    train <- pts[train_idx]; validate <- if (design == "independent") vpts[valid_idx] else pts[valid_idx]
    if (!nrow(train) || !nrow(validate) || any(terra::values(validate)$Name %in% terra::values(train)$Name)) .ps_abort("Invalid fold contains leakage or an empty partition.", "potentiomap_validation_error")
    xy <- terra::crds(validate); bbox <- c(xmin = min(xy[, 1]), xmax = max(xy[, 1]), ymin = min(xy[, 2]), ymax = max(xy[, 2]))
    partition_hash <- .ps_stable_hash(list(sort(plan$train), sort(plan$validate)))
    fold_rows[[f]] <- data.frame(fold_id = fold_key, repeat_id = plan$repeat_id, fold_label = plan$fold_label,
      training_count = nrow(train), validation_count = nrow(validate), training_ids = paste(sort(plan$train), collapse = "|"),
      validation_ids = paste(sort(plan$validate), collapse = "|"), partition_hash = partition_hash,
      xmin = bbox[1], xmax = bbox[2], ymin = bbox[3], ymax = bbox[4], balance_ratio = nrow(validate) / nrow(train), stringsAsFactors = FALSE)
    partition_rows[[f]] <- data.frame(fold_id = fold_key, partition_hash = partition_hash, repeat_id = plan$repeat_id,
                                      planned_partition = f, stringsAsFactors = FALSE)
    for (method in methods) {
      run_index <- run_index + 1L; run_id <- sprintf("run_%05d", run_index); derived_seed <- seed + run_index - 1L
      .ps_progress(progress, run_index, total_runs, run_id, "started")
      cap <- .ps_capture_run({
        set.seed(derived_seed)
        if (prediction_mode == "direct") {
          .ps_direct_predict(train, validate, method, interpolation_control)
        } else {
          reserved <- c("points", "methods", "return", "mask", "template", "grid_res")
          control <- interpolation_control[setdiff(names(interpolation_control), reserved)]
          args <- c(list(points = train, methods = method, return = "result", mask = mask), control)
          if (domain_policy == "fixed") args$template <- fixed_template else {
            args$template <- NULL; args$grid_res <- grid_res %||% max(diff(range(terra::crds(train)[, 1])), diff(range(terra::crds(train)[, 2]))) / 25
          }
          result <- do.call(ps_interpolate, args); surface <- result$surfaces[[1]]
          extracted <- terra::extract(surface, validate, method = "bilinear")[[2]]
          variance <- if (!is.null(result$fits[[1]]$prediction_variance)) terra::extract(result$fits[[1]]$prediction_variance, validate, method = "bilinear")[[2]] else rep(NA_real_, nrow(validate))
          list(predicted = as.numeric(extracted), variance = as.numeric(variance), fit = result)
        }
      })
      predicted <- if (is.null(cap$error)) cap$value$predicted else rep(NA_real_, nrow(validate))
      variance <- if (is.null(cap$error)) cap$value$variance else rep(NA_real_, nrow(validate))
      support_table <- .ps_holdout_support(train, validate, predicted, mask)
      observed <- terra::values(validate)$Z; ids <- terra::values(validate)$Name
      for (j in seq_len(nrow(validate))) {
        out_index <- out_index + 1L
        prediction_rows[[out_index]] <- data.frame(
          prediction_id = sprintf("prediction_%06d", out_index), run_id = run_id, fold_id = fold_key,
          repeat_id = plan$repeat_id, design = design, method = method, record_id = ids[j],
          observed = observed[j], predicted = predicted[j], residual = predicted[j] - observed[j],
          prediction_variance = variance[j], prediction_standard_error = if (is.finite(variance[j]) && variance[j] >= 0) sqrt(variance[j]) else NA_real_,
          inside_training_hull = support_table$inside_training_hull[j], nearest_training_distance = support_table$nearest_training_distance[j],
          finite_prediction = support_table$finite_prediction[j], mask_membership = support_table$mask_membership[j], supported = support_table$supported[j],
          status = if (!is.null(cap$error)) "failed_fit" else if (!is.finite(predicted[j])) "nonfinite_prediction" else "success",
          warning_count = length(cap$warnings), error_count = as.integer(!is.null(cap$error)), seed = derived_seed,
          input_count = nrow(pts), retained_count = nrow(train), prediction_count = nrow(validate),
          training_ids = paste(sort(plan$train), collapse = "|"), stringsAsFactors = FALSE)
      }
      fit_rows[[length(fit_rows) + 1L]] <- data.frame(run_id = run_id, fold_id = fold_key, method = method,
        status = if (is.null(cap$error)) "success" else "failed", warning_count = length(cap$warnings), error_count = as.integer(!is.null(cap$error)),
        seed = derived_seed, input_count = nrow(pts), retained_count = nrow(train), prediction_count = nrow(validate),
        warning_text = paste(vapply(cap$warnings, conditionMessage, character(1)), collapse = " | "),
        error_text = if (is.null(cap$error)) "" else conditionMessage(cap$error), stringsAsFactors = FALSE)
      condition_rows[[length(condition_rows) + 1L]] <- .ps_condition_rows(c(cap$warnings, if (!is.null(cap$error)) list(cap$error) else list()),
        "ps_validate", method = method, fold_id = fold_key, run_id = run_id)
      .ps_progress(progress, run_index, total_runs, run_id, if (is.null(cap$error)) "success" else "failed")
    }
  }
  predictions <- do.call(rbind, prediction_rows); folds_df <- do.call(rbind, fold_rows); fits_df <- do.call(rbind, fit_rows); partitions <- do.call(rbind, partition_rows)
  duplicate_hash <- duplicated(partitions$partition_hash) | duplicated(partitions$partition_hash, fromLast = TRUE)
  partitions$duplicate_partition <- duplicate_hash
  partitions$effective_unique_partition <- !duplicated(partitions$partition_hash)
  weight_by_prediction <- NULL
  if (!is.null(sampling_weight)) weight_by_prediction <- sampling_weight[match(predictions$record_id, terra::values(vpts)$Name)]
  metric_table <- .ps_validation_metric_rows(predictions, metrics, weight_by_prediction)
  support_summary <- aggregate(cbind(finite_prediction, supported) ~ method, predictions, mean)
  names(support_summary)[2:3] <- c("finite_prediction_fraction", "supported_prediction_fraction")
  conditions <- if (length(condition_rows)) do.call(rbind, condition_rows) else .ps_empty_conditions()
  summary <- data.frame(design = design, planned_partitions = nrow(partitions), effective_unique_partitions = sum(partitions$effective_unique_partition),
                        duplicate_partitions = sum(duplicated(partitions$partition_hash)), scheduled_predictions = nrow(predictions),
                        finite_predictions = sum(predictions$finite_prediction), supported_predictions = sum(predictions$supported),
                        failed_fits = sum(fits_df$status == "failed"))
  .ps_new_result(list(predictions = predictions, metrics = metric_table,
                      fold_manifest = folds_df, partition_manifest = partitions,
                      fit_manifest = fits_df, support_summary = support_summary),
                 "potentiomap_validation", call,
                 settings = list(methods = methods, design = design, folds = folds,
                                 repeats = repeats, block_size = block_size,
                                 domain_policy = domain_policy, prediction_mode = prediction_mode,
                                 metrics = metrics, support = support,
                                 prediction_task = switch(design, loocv = "predict a measured location surrounded by most of the network",
                                   spatial_block = "transfer into a spatially separated block", independent = "predict an explicitly independent sample",
                                   leave_cluster_out = "transfer to a withheld user-defined cluster", user_folds = "predict user-defined holdouts",
                                   kfold = "predict random held-out subsets")),
                 metadata = .ps_surface_metadata(pts), conditions = conditions,
                 warnings = if (design == "independent") "Independent validation performance is not cross-validation and is not automatically design-unbiased without a probability design." else "Cross-validation performance is conditional on the stated resampling design and is not automatically map accuracy.",
                 summary = summary, seed = seed)
}

#' Compare validated interpolation methods
#'
#' Ranks adequately covered methods within an explicit validation design and
#' support subset. It does not declare a universally best method and does not
#' aggregate multiple objectives unless the user supplies weights.
#'
#' @param validation A `potentiomap_validation` or documented compatible metric
#'   table.
#' @param metric One or more metric columns.
#' @param design One validation design; required when multiple designs exist.
#' @param support_subset All scheduled, finite, or supported predictions.
#' @param minimum_coverage Minimum finite coverage.
#' @param tie_tolerance Nonnegative absolute metric tolerance; default is a
#'   scale-aware square-root machine tolerance.
#' @param objective_weights Explicit named nonnegative weights for multiple
#'   criteria.
#' @param select Select one method only after all selection gates pass.
#' @return A `potentiomap_method_comparison` with ranking, Pareto status and
#'   optional selection.
#' @export
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation", "well_id", "EPSG:26916")
#' val <- ps_validate(pts, "IDW", "kfold", folds = 3, prediction_mode = "direct")
#' ps_compare_methods(val)$ranking
#' # Ranking is specific to this design and objective.
ps_compare_methods <- function(validation, metric = "rmse", design = NULL,
                               support_subset = c("all", "finite", "supported"),
                               minimum_coverage = 0.9, tie_tolerance = NULL,
                               objective_weights = NULL, select = FALSE) {
  call <- match.call(); support_subset <- match.arg(support_subset); .ps_scalar_logical(select, "select")
  .validate_number(minimum_coverage, "minimum_coverage", lower = 0, inclusive = TRUE)
  if (minimum_coverage > 1) .ps_abort("`minimum_coverage` cannot exceed one.", "potentiomap_validation_error")
  tab <- if (inherits(validation, "potentiomap_validation")) validation$metrics else as.data.frame(validation)
  required <- c("method", "design", "scope", "support_subset", "finite_coverage", "support_coverage")
  if (!all(required %in% names(tab))) .ps_abort("`validation` is not a documented compatible validation table.", "potentiomap_validation_error")
  designs <- unique(tab$design)
  if (is.null(design) && length(designs) > 1L) .ps_abort("Choose one `design`; different designs are not pooled implicitly.", "potentiomap_validation_error")
  if (is.null(design)) design <- designs[1]
  if (!design %in% designs) .ps_abort("Requested validation design was not found.", "potentiomap_validation_error")
  metrics <- as.character(metric)
  if (!all(metrics %in% names(tab))) .ps_abort("Requested metric column was not found.", "potentiomap_validation_error")
  rows <- tab[tab$design == design & tab$scope == "pooled" & tab$support_subset == support_subset, , drop = FALSE]
  if (!nrow(rows)) .ps_abort("No validation rows match the selected design/subset.", "potentiomap_validation_error")
  rows$adequate_coverage <- rows$finite_coverage >= minimum_coverage
  if (is.null(tie_tolerance)) {
    tie_tolerance <- sqrt(.Machine$double.eps) *
      max(1, abs(rows[[metrics[1]]]), na.rm = TRUE)
  }
  .validate_number(tie_tolerance, "tie_tolerance", lower = 0, inclusive = TRUE)
  if (length(metrics) == 1L) {
    score <- rows[[metrics]]; score[!rows$adequate_coverage] <- NA_real_
    rows$rank <- rank(score, ties.method = "min", na.last = "keep")
    best <- if (any(is.finite(score))) min(score, na.rm = TRUE) else NA_real_
    rows$tie_status <- ifelse(is.finite(score) & abs(score - best) <= tie_tolerance, "tied_best", "not_best")
    pareto <- rows[, c("method", metrics, "rank", "adequate_coverage"), drop = FALSE]
  } else {
    if (!is.null(objective_weights)) {
      if (is.null(names(objective_weights)) || !setequal(names(objective_weights), metrics) || any(!is.finite(objective_weights)) || any(objective_weights < 0) || sum(objective_weights) <= 0) {
        .ps_abort("`objective_weights` must be named, finite, nonnegative, and positive in total.", "potentiomap_validation_error")
      }
      normalized <- sapply(metrics, function(nm) {
        z <- rows[[nm]]; span <- diff(range(z, finite = TRUE)); if (!is.finite(span) || span == 0) rep(0, length(z)) else (z - min(z, na.rm = TRUE)) / span
      })
      rows$objective_score <- as.numeric(normalized %*% (objective_weights[metrics] / sum(objective_weights)))
      rows$rank <- rank(ifelse(rows$adequate_coverage, rows$objective_score, NA_real_), ties.method = "min", na.last = "keep")
    } else rows$rank <- NA_integer_
    dominated <- vapply(seq_len(nrow(rows)), function(i) any(vapply(setdiff(seq_len(nrow(rows)), i), function(j) {
      all(rows[j, metrics] <= rows[i, metrics]) && any(rows[j, metrics] < rows[i, metrics])
    }, logical(1))), logical(1))
    rows$pareto <- !dominated & rows$adequate_coverage; rows$tie_status <- NA_character_
    pareto <- rows[, c("method", metrics, "pareto", "adequate_coverage"), drop = FALSE]
  }
  selected <- NULL
  if (select) {
    if (length(metrics) != 1L || length(unique(rows$design)) != 1L || support_subset != rows$support_subset[1]) .ps_abort("Selection requires one objective, design, and support subset.", "potentiomap_validation_error")
    successful <- rows$adequate_coverage & is.finite(rows[[metrics]])
    if (sum(successful) < 2L) .ps_abort("Selection requires at least two adequately covered successful methods.", "potentiomap_validation_error")
    selected <- rows$method[which.min(ifelse(successful, rows[[metrics]], Inf))]
  }
  .ps_new_result(list(ranking = rows, pareto = pareto, selection = selected),
                 "potentiomap_method_comparison", call,
                 settings = list(metric = metrics, design = design, support_subset = support_subset,
                                 minimum_coverage = minimum_coverage, tie_tolerance = tie_tolerance,
                                 objective_weights = objective_weights, select = select),
                 metadata = if (inherits(validation, "potentiomap_validation")) validation$metadata else list(),
                 summary = rows,
                 warnings = "Method ranking is conditional on the selected validation design, subset, and objective; it is not universal.")
}

#' Plot validation diagnostics with base graphics
#'
#' @param x A validation or method-comparison result.
#' @param type Diagnostic plot type.
#' @param methods,design Optional subsets.
#' @param support_subset Support subset.
#' @param display_limits Optional explicit axis/value limits. Values remain in
#'   returned plot data and requested clipping is disclosed.
#' @param legend Draw a legend.
#' @param ... Base graphics arguments.
#' @return Plot data invisibly.
#' @export
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation", "well_id", "EPSG:26916")
#' val <- ps_validate(pts, "IDW", "kfold", folds = 3, prediction_mode = "direct")
#' ps_validation_plot(val, "observed_predicted")
ps_validation_plot <- function(x,
                               type = c("metric", "observed_predicted", "residual_map",
                                        "residual_distribution", "fold_map", "support", "coverage",
                                        "method_conditions"),
                               methods = NULL, design = NULL, support_subset = "all",
                               display_limits = NULL, legend = TRUE, ...) {
  type <- match.arg(type); .ps_scalar_logical(legend, "legend")
  predictions <- if (inherits(x, "potentiomap_validation")) x$predictions else NULL
  ranking <- if (inherits(x, "potentiomap_method_comparison")) x$ranking else if (inherits(x, "potentiomap_validation")) x$metrics else NULL
  if (is.null(predictions) && type %in% c("observed_predicted", "residual_map", "residual_distribution", "fold_map", "support")) .ps_abort("This plot type requires a potentiomap_validation object.", "potentiomap_validation_error")
  data <- predictions %||% ranking
  if (!is.null(methods)) data <- data[data$method %in% methods, , drop = FALSE]
  if (!is.null(design) && "design" %in% names(data)) data <- data[data$design %in% design, , drop = FALSE]
  if (!nrow(data)) .ps_abort("The requested plot subset is empty.", "potentiomap_validation_error")
  clipped <- FALSE
  if (!is.null(display_limits)) {
    if (!is.numeric(display_limits) || length(display_limits) != 2L || any(!is.finite(display_limits)) || display_limits[1] >= display_limits[2]) .ps_abort("`display_limits` must be two increasing finite values.", "potentiomap_validation_error")
    clipped <- TRUE; .ps_warn("Display limits clip the drawn view; returned plot data retain all values.", "potentiomap_validation_warning")
  }
  dots <- list(...)
  if (type == "observed_predicted") {
    graphics::plot(data$observed, data$predicted, pch = ifelse(data$supported, 16, 1),
                   col = as.integer(factor(data$method)) + 1L, xlab = "Observed head", ylab = "Predicted head",
                   xlim = display_limits, ylim = display_limits)
    graphics::abline(0, 1, lty = 2)
  } else if (type == "residual_distribution") {
    graphics::boxplot(residual ~ method, data = data, ylab = "Residual (predicted - observed)", ylim = display_limits)
    graphics::abline(h = 0, lty = 2)
  } else if (type == "residual_map") {
    graphics::plot(seq_len(nrow(data)), data$residual, pch = ifelse(data$supported, 16, 1), col = as.integer(factor(data$method)) + 1L,
                   xlab = "Validation record", ylab = "Residual", ylim = display_limits)
  } else if (type == "fold_map") {
    graphics::plot(as.integer(factor(data$fold_id)), data$observed, pch = ifelse(data$supported, 16, 1), xlab = "Fold", ylab = "Observed head")
  } else if (type == "support") {
    graphics::plot(data$nearest_training_distance, abs(data$residual), pch = ifelse(data$supported, 16, 1),
                   col = as.integer(factor(data$method)) + 1L, xlab = "Nearest training distance", ylab = "Absolute residual")
  } else if (type %in% c("metric", "coverage")) {
    tab <- ranking
    if (type == "metric") {
      metric <- intersect(c("rmse", "mae", "me"), names(tab))[1]
      graphics::barplot(tab[[metric]], names.arg = tab$method, ylab = toupper(metric), ylim = display_limits)
    } else graphics::barplot(tab$finite_coverage, names.arg = tab$method, ylab = "Finite prediction fraction", ylim = c(0, 1))
  } else {
    cond <- if (inherits(x, "potentiomap_validation")) x$conditions else .ps_empty_conditions()
    if (!nrow(cond)) {
      graphics::plot.new()
      graphics::title(main = "No captured method conditions")
      data <- data.frame(method = character(), stringsAsFactors = FALSE)
    } else {
      counts <- table(cond$method, cond$type)
      graphics::barplot(t(counts), beside = TRUE, legend.text = legend,
                        ylab = "Condition count")
      data <- as.data.frame.matrix(counts)
    }
  }
  invisible(list(data = data, type = type, display_limits = display_limits, clipped = clipped,
                 support_symbol = c(supported = 16, limited = 1)))
}

#' @export
as.data.frame.potentiomap_validation <- function(x, ...) x$predictions
#' @export
as.data.frame.potentiomap_method_comparison <- function(x, ...) x$ranking
