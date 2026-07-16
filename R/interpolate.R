#' Interpolate potentiometric surfaces
#'
#' Creates one raster for each requested method. Thin-plate splines (`"TPS"`)
#' remain the software default for backward compatibility, but method selection
#' should reflect the hydrogeologic setting, monitoring-network geometry,
#' spatial trend, sample density, prediction support, validation design, and
#' intended map use. Other built-in methods are inverse-distance weighting
#' (`"IDW"`), ordinary kriging (`"OK"`), and universal kriging (`"UK"`) with a
#' quadratic drift. Named custom functions are also supported.
#'
#' Requested methods are never silently replaced. Kriging conditions and fit
#' information, TPS selection information, prediction ranges, and method
#' messages are available in the opt-in structured result.
#'
#' @param points A point `SpatVector`, `sf` object, or coordinate table.
#' @param value Data column name when `points` is not standardized. Defaults to
#'   `"Z"`.
#' @param methods Character vector containing `"TPS"`, `"IDW"`, `"OK"`, `"UK"`,
#'   or names in `custom_methods`.
#' @param grid_res Positive output cell size in projected map units.
#' @param template Optional one-layer template `SpatRaster`; overrides extent
#'   construction from `grid_res`, `padding`, and `mask`.
#' @param mask Optional polygon mask. A convex hull or supplied mask describes
#'   the computational domain, not an aquifer boundary.
#' @param padding Nonnegative padding around the template extent.
#' @param idw_power,idw_nmax Positive IDW power and optional positive maximum
#'   neighbor count.
#' @param tps_lambda Optional nonnegative TPS smoothing parameter. `NULL` uses
#'   the selection performed by `fields::Tps()`.
#' @param kr_auto_cutoff Use an automatically derived variogram cutoff and lag
#'   width.
#' @param kr_cutoff,kr_width Positive manual variogram values when
#'   `kr_auto_cutoff = FALSE`.
#' @param custom_methods Optional named list of functions called as
#'   `fun(points, template, grid)`. Each must return a matching `SpatRaster` or
#'   one numeric value per template cell.
#' @param x,y,name_col,crs Used for a coordinate table.
#' @param return Either `"surfaces"` (the backward-compatible named raster list)
#'   or `"result"` for a [potentiomap_result].
#' @param duplicate_action Handling for duplicate coordinates: `"error"`,
#'   `"mean"`, `"median"`, or `"first"`.
#' @param allow_geographic Allow distance calculations in longitude/latitude
#'   degrees with a classed warning. The default is `FALSE`.
#' @param uk_coordinate_scaling Either `"center_scale"` (the safer default) or
#'   `"none"` for a documented legacy comparison.
#' @param diagnostic_control Optional named list overriding heuristic UK warning
#'   thresholds. Supported names are `condition_number_warning`,
#'   `predicted_range_ratio_warning`, `overshoot_range_ratio_warning`,
#'   `warn_on_rank_deficiency`, and `warn_on_nonfinite_predictions`.
#' @param support Calculate [ps_prediction_support()] for the first returned
#'   surface.
#' @param support_max_distance Optional support distance threshold.
#'
#' @return By default, a named list of `terra::SpatRaster` surfaces. With
#'   `return = "result"`, a documented `potentiomap_result`.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' result <- ps_interpolate(
#'   pts, methods = c("IDW", "TPS"), grid_res = 150,
#'   return = "result", support = TRUE
#' )
#' ps_surfaces(result)
#' ps_diagnostics(result, "TPS")
ps_interpolate <- function(points, value = "Z", methods = "TPS",
                           grid_res = NULL, template = NULL, mask = NULL,
                           padding = NULL, idw_power = 2, idw_nmax = 15,
                           tps_lambda = NULL, kr_auto_cutoff = TRUE,
                           kr_cutoff = NA_real_, kr_width = NA_real_,
                           custom_methods = NULL,
                           x = "x", y = "y", name_col = NULL, crs = NULL,
                           return = c("surfaces", "result"),
                           duplicate_action = c("error", "mean", "median", "first"),
                           allow_geographic = FALSE,
                           uk_coordinate_scaling = c("center_scale", "none"),
                           diagnostic_control = NULL,
                           support = FALSE, support_max_distance = NULL) {
  call <- match.call()
  return <- match.arg(return)
  duplicate_action <- match.arg(duplicate_action)
  uk_coordinate_scaling <- match.arg(uk_coordinate_scaling)
  .validate_interpolation_controls(
    grid_res, template, padding, idw_power, idw_nmax, tps_lambda,
    kr_auto_cutoff, kr_cutoff, kr_width, support_max_distance
  )
  pts <- if (inherits(points, "SpatVector") && "Z" %in% names(terra::values(points))) {
    .as_points(points)
  } else {
    ps_make_points(points, x = x, y = y, value = value,
                   name_col = name_col, crs = crs)
  }
  metadata <- ps_metadata(pts)
  dropped_records <- attr(pts, "dropped_records", exact = TRUE)
  .require_projected(pts, "points", allow_geographic)
  pts <- .resolve_duplicate_points(pts, duplicate_action)
  pts <- .attach_metadata(pts, metadata)
  if (nrow(pts) < 5L) {
    .ps_abort(
      sprintf("At least five valid points are needed; %d were retained.", nrow(pts)),
      "potentiomap_input_error"
    )
  }
  z <- terra::values(pts)$Z
  if (!all(is.finite(z))) {
    .ps_abort("All retained `Z` values must be finite.", "potentiomap_input_error")
  }

  method_spec <- .normalize_methods(methods, custom_methods)
  methods <- method_spec$methods
  custom_methods <- method_spec$custom_methods
  builtins <- toupper(methods)
  if (any(builtins %in% c("OK", "UK")) && length(unique(z)) < 2L) {
    .ps_abort("Kriging requires at least two distinct head values.",
              "potentiomap_input_error")
  }
  if (any(builtins == "UK") && nrow(pts) < 6L) {
    .ps_abort(
      sprintf("UK with quadratic drift requires at least six retained observations; %d are available.",
              nrow(pts)),
      "potentiomap_input_error"
    )
  }

  tmpl <- .surface_template(pts, grid_res, template, mask, padding)
  grid <- as.data.frame(terra::xyFromCell(tmpl, seq_len(terra::ncell(tmpl))))
  names(grid) <- c("X", "Y")
  uk_control <- .uk_diagnostic_control(diagnostic_control)
  surfaces <- diagnostics <- method_parameters <- list()
  condition_rows <- list()

  for (method in methods) {
    builtin <- toupper(method)
    fit <- switch(
      builtin,
      IDW = .interp_idw(pts, tmpl, grid, idw_power, idw_nmax),
      TPS = .interp_tps(pts, tmpl, grid, tps_lambda),
      OK = .interp_ok(pts, tmpl, grid, kr_auto_cutoff, kr_cutoff, kr_width),
      UK = .interp_uk(
        pts, tmpl, grid, kr_auto_cutoff, kr_cutoff, kr_width,
        uk_coordinate_scaling, uk_control
      ),
      .interp_custom(method, custom_methods, pts, tmpl, grid)
    )
    surface <- fit$surface
    names(surface) <- method
    if (!is.null(mask)) surface <- .apply_mask(surface, mask)
    surfaces[[method]] <- surface
    fit$diagnostics$requested_method <- method
    fit$diagnostics$returned_method <- method
    fit$diagnostics$finite_prediction_count <- sum(
      is.finite(terra::values(surface, mat = FALSE))
    )
    fit$diagnostics$nonfinite_prediction_count <- terra::ncell(surface) -
      fit$diagnostics$finite_prediction_count
    diagnostics[[method]] <- fit$diagnostics
    method_parameters[[method]] <- fit$parameters
    if (nrow(fit$conditions)) {
      fit$conditions$method <- method
      condition_rows[[method]] <- fit$conditions
    }
    .emit_method_warnings(fit$warnings_to_emit, builtin)
  }

  if (return == "surfaces") return(surfaces)
  first_surface <- surfaces[[1]]
  support_result <- if (isTRUE(support)) {
    ps_prediction_support(
      pts, surface = first_surface, mask = mask,
      max_distance = support_max_distance,
      allow_geographic = allow_geographic
    )
  } else NULL
  ex <- terra::ext(first_surface)
  grid_geometry <- list(
    nrow = terra::nrow(first_surface), ncol = terra::ncol(first_surface),
    ncell = terra::ncell(first_surface), resolution = terra::res(first_surface),
    extent = c(xmin = ex[1], xmax = ex[2], ymin = ex[3], ymax = ex[4])
  )
  conditions <- if (length(condition_rows)) {
    rownames_out <- do.call(rbind, condition_rows)
    rownames(rownames_out) <- NULL
    rownames_out
  } else {
    data.frame(method = character(), type = character(), class = character(),
               text = character(), stringsAsFactors = FALSE)
  }
  out <- list(
    surfaces = surfaces,
    diagnostics = diagnostics,
    method_parameters = method_parameters,
    input_summary = list(
      original_count = dropped_records$original_count %||% nrow(pts),
      retained_count = nrow(pts), metadata = metadata
    ),
    observation_count = nrow(pts),
    dropped_records = dropped_records %||% list(
      original_count = nrow(pts), retained_count = nrow(pts),
      dropped_count = 0L, reason_counts = list()
    ),
    grid_geometry = grid_geometry,
    crs = terra::crs(first_surface, proj = TRUE),
    mask_summary = list(
      supplied = !is.null(mask),
      feature_count = if (is.null(mask)) 0L else nrow(
        if (inherits(mask, "SpatVector")) mask else terra::vect(mask)
      )
    ),
    support = support_result,
    conditions = conditions,
    package_version = .package_version_string(),
    call = call
  )
  class(out) <- "potentiomap_result"
  out
}

.validate_interpolation_controls <- function(grid_res, template, padding,
                                             idw_power, idw_nmax, tps_lambda,
                                             kr_auto_cutoff, kr_cutoff,
                                             kr_width, support_max_distance) {
  if (is.null(template)) {
    if (is.null(grid_res)) {
      .ps_abort("`grid_res` is required when `template` is not supplied.",
                "potentiomap_input_error")
    }
    .validate_number(grid_res, "grid_res", lower = 0)
  }
  if (!is.null(padding)) {
    if (!is.numeric(padding) || !length(padding) %in% c(1L, 2L) ||
        any(!is.finite(padding)) || any(padding < 0)) {
      .ps_abort("`padding` must contain one or two finite nonnegative numbers.",
                "potentiomap_input_error")
    }
  }
  .validate_number(idw_power, "idw_power", lower = 0)
  if (!is.null(idw_nmax)) .validate_integer(idw_nmax, "idw_nmax", lower = 0)
  if (!is.null(tps_lambda)) .validate_number(tps_lambda, "tps_lambda", lower = 0,
                                             inclusive = TRUE)
  if (!is.logical(kr_auto_cutoff) || length(kr_auto_cutoff) != 1L ||
      is.na(kr_auto_cutoff)) {
    .ps_abort("`kr_auto_cutoff` must be TRUE or FALSE.",
              "potentiomap_input_error")
  }
  if (!kr_auto_cutoff) {
    .validate_number(kr_cutoff, "kr_cutoff", lower = 0)
    .validate_number(kr_width, "kr_width", lower = 0)
  }
  if (!is.null(support_max_distance)) {
    .validate_number(support_max_distance, "support_max_distance", lower = 0)
  }
  invisible(TRUE)
}

.normalize_methods <- function(methods, custom_methods) {
  if (is.function(methods)) {
    custom_methods <- c(list(custom = methods), custom_methods)
    methods <- "custom"
  } else if (is.list(methods) && !is.character(methods)) {
    if (is.null(names(methods)) || any(!nzchar(names(methods)))) {
      .ps_abort("Custom methods supplied in `methods` must all be named.",
                "potentiomap_input_error")
    }
    custom_methods <- c(methods, custom_methods)
    methods <- names(methods)
  }
  if (!is.character(methods) || !length(methods) || anyNA(methods) ||
      any(!nzchar(methods))) {
    .ps_abort("`methods` must contain one or more method names.",
              "potentiomap_input_error")
  }
  if (anyDuplicated(methods)) {
    .ps_abort("`methods` must not contain duplicate names.",
              "potentiomap_input_error")
  }
  if (!is.null(custom_methods)) {
    if (!is.list(custom_methods) || !length(custom_methods) ||
        is.null(names(custom_methods)) || any(!nzchar(names(custom_methods))) ||
        anyDuplicated(names(custom_methods)) ||
        any(!vapply(custom_methods, is.function, logical(1)))) {
      .ps_abort("`custom_methods` must be a uniquely named list of functions.",
                "potentiomap_input_error")
    }
  }
  supported <- c("TPS", "IDW", "OK", "UK")
  unknown <- methods[!toupper(methods) %in% supported &
                       !(methods %in% names(custom_methods))]
  if (length(unknown)) {
    .ps_abort(
      sprintf("Unsupported method(s): %s. Use TPS, IDW, OK, UK, or a named custom method.",
              paste(unknown, collapse = ", ")),
      "potentiomap_input_error"
    )
  }
  list(methods = methods, custom_methods = custom_methods)
}

.resolve_duplicate_points <- function(points, action) {
  xy <- terra::crds(points)
  key <- paste(format(xy[, 1], digits = 17), format(xy[, 2], digits = 17), sep = "|")
  duplicated_group <- duplicated(key) | duplicated(key, fromLast = TRUE)
  if (!any(duplicated_group)) return(points)
  n_dup <- sum(duplicated(key))
  if (action == "error") {
    .ps_abort(
      sprintf("Duplicate coordinates were found for %d observation(s); choose an explicit `duplicate_action`.",
              n_dup),
      "potentiomap_input_error"
    )
  }
  vals <- terra::values(points)
  groups <- split(seq_along(key), factor(key, levels = unique(key)))
  first <- vapply(groups, `[`, integer(1), 1L)
  out_vals <- vals[first, , drop = FALSE]
  out_vals$Z <- vapply(groups, function(i) {
    if (action == "first") vals$Z[i[1]] else if (action == "mean") {
      mean(vals$Z[i])
    } else {
      stats::median(vals$Z[i])
    }
  }, numeric(1))
  out_xy <- xy[first, , drop = FALSE]
  out <- terra::vect(cbind(data.frame(x = out_xy[, 1], y = out_xy[, 2]), out_vals),
                     geom = c("x", "y"), crs = terra::crs(points))
  .ps_warn(
    sprintf("Combined %d duplicate-coordinate observation(s) using `%s`.",
            n_dup, action),
    "potentiomap_input_warning"
  )
  out
}

.surface_template <- function(points, grid_res, template, mask, padding) {
  if (!is.null(template)) {
    tmpl <- .as_surface(template, "template")
    .require_crs(tmpl, "template")
    if (!.same_crs(tmpl, points)) {
      .ps_abort("`template` and `points` must use the same CRS.",
                "potentiomap_crs_error")
    }
    return(tmpl)
  }
  geom <- if (is.null(mask)) {
    terra::convHull(points)
  } else {
    m <- if (inherits(mask, "SpatVector")) mask else terra::vect(mask)
    if (terra::geomtype(m) != "polygons") {
      .ps_abort("`mask` must contain polygon geometry.",
                "potentiomap_input_error")
    }
    if (!.same_crs(m, points)) {
      .ps_abort("`mask` and `points` must use the same CRS.",
                "potentiomap_crs_error")
    }
    m
  }
  ex <- terra::ext(geom)
  if (is.null(padding)) padding <- grid_res * 2
  if (length(padding) == 1L) padding <- rep(padding, 2L)
  ex[1] <- ex[1] - padding[1]
  ex[2] <- ex[2] + padding[1]
  ex[3] <- ex[3] - padding[2]
  ex[4] <- ex[4] + padding[2]
  terra::rast(crs = terra::crs(points), extent = ex, resolution = grid_res)
}

.capture_method <- function(expr) {
  warnings <- list()
  messages <- list()
  value <- NULL
  console <- utils::capture.output(
    value <- withCallingHandlers(
      expr,
      warning = function(w) {
        warnings[[length(warnings) + 1L]] <<- w
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        messages[[length(messages) + 1L]] <<- m
        invokeRestart("muffleMessage")
      }
    )
  )
  console <- trimws(console)
  console <- console[nzchar(console)]
  if (length(console)) {
    messages <- c(messages, lapply(console, simpleMessage))
  }
  list(value = value, warnings = warnings, messages = messages)
}

.condition_table <- function(warnings = list(), messages = list(), method = NA_character_) {
  rows <- c(
    lapply(warnings, .condition_record, method = method),
    lapply(messages, .condition_record, method = method)
  )
  if (!length(rows)) {
    return(data.frame(method = character(), type = character(), class = character(),
                      text = character(), stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, rows)
  upstream <- out$type == "warning" & !grepl("^potentiomap_", out$class)
  if (any(upstream)) {
    out$class[upstream] <- if (!is.na(method) && toupper(method) %in% c("OK", "UK")) {
      "potentiomap_kriging_convergence_warning"
    } else {
      "potentiomap_warning"
    }
  }
  rownames(out) <- NULL
  out
}

.interp_idw <- function(points, template, grid, idw_power, idw_nmax) {
  pts_sf <- sf::st_as_sf(points)
  grid_sf <- sf::st_as_sf(grid, coords = c("X", "Y"), crs = terra::crs(points))
  model <- gstat::gstat(id = "Z", formula = Z ~ 1, data = pts_sf,
                        set = list(idp = idw_power))
  captured <- .capture_method(if (is.null(idw_nmax)) {
    stats::predict(model, grid_sf)
  } else {
    stats::predict(model, grid_sf, nmax = idw_nmax)
  })
  pred <- captured$value
  pred_col <- intersect(c("Z.pred", "var1.pred"), names(pred))[1]
  if (is.na(pred_col)) pred_col <- grep("\\.pred$", names(pred), value = TRUE)[1]
  if (is.na(pred_col)) {
    .ps_abort("IDW did not return a prediction column.",
              "potentiomap_input_error")
  }
  r <- template
  terra::values(r) <- as.numeric(pred[[pred_col]])
  list(
    surface = r,
    diagnostics = list(
      formula = "Z ~ 1", observation_count = nrow(points),
      idw_power = idw_power, idw_nmax = idw_nmax,
      return_status = if (length(captured$warnings)) "success_with_warning" else "success"
    ),
    parameters = list(idw_power = idw_power, idw_nmax = idw_nmax),
    conditions = .condition_table(captured$warnings, captured$messages, "IDW"),
    warnings_to_emit = captured$warnings
  )
}

.interp_tps <- function(points, template, grid, tps_lambda) {
  xy <- as.matrix(terra::crds(points, df = TRUE))
  z <- terra::values(points)$Z
  captured <- .capture_method({
    fit <- fields::Tps(x = xy, Y = z, lambda = tps_lambda)
    pred <- stats::predict(fit, as.matrix(grid))
    list(fit = fit, pred = pred)
  })
  fit <- captured$value$fit
  gcv <- fit$gcv.grid
  boundary <- FALSE
  gcv_score <- NA_real_
  search_range <- c(NA_real_, NA_real_)
  if (is.data.frame(gcv) && all(c("lambda", "GCV") %in% names(gcv)) && nrow(gcv)) {
    idx <- which.min(gcv$GCV)
    boundary <- idx %in% c(1L, nrow(gcv))
    gcv_score <- gcv$GCV[idx]
    search_range <- range(gcv$lambda, finite = TRUE)
  }
  boundary_warning <- list()
  if (is.null(tps_lambda) && boundary) {
    boundary_warning <- list(.ps_condition(
      sprintf("TPS GCV selected lambda %.6g at a search boundary; inspect sensitivity and prediction support.",
              fit$lambda),
      "potentiomap_tps_gcv_boundary_warning", "warning"
    ))
  }
  warnings <- c(captured$warnings, boundary_warning)
  r <- template
  terra::values(r) <- as.numeric(captured$value$pred)
  list(
    surface = r,
    diagnostics = list(
      formula = "thin-plate spline", observation_count = nrow(points),
      selection_mode = if (is.null(tps_lambda)) "GCV" else "user_supplied",
      selected_lambda = as.numeric(fit$lambda),
      effective_degrees_of_freedom = as.numeric(fit$eff.df),
      gcv_score = gcv_score, search_range = search_range,
      selected_at_search_boundary = boundary,
      warning_table_available = !is.null(fit$warningTable),
      warning_text = if (length(warnings)) {
        paste(unique(vapply(warnings, conditionMessage, character(1))), collapse = " | ")
      } else "",
      message_text = if (length(captured$messages)) {
        paste(unique(vapply(captured$messages, conditionMessage, character(1))), collapse = " | ")
      } else "",
      return_status = if (length(warnings)) "success_with_warning" else "success"
    ),
    parameters = list(tps_lambda = tps_lambda),
    conditions = .condition_table(warnings, captured$messages, "TPS"),
    warnings_to_emit = warnings
  )
}

.interp_ok <- function(points, template, grid, kr_auto_cutoff, kr_cutoff,
                       kr_width) {
  pts <- .kriging_frame(points)
  pts$resid <- pts$Z - mean(pts$Z)
  vg <- .build_variogram(pts, kr_auto_cutoff, kr_cutoff, kr_width)
  prediction <- .capture_method(gstat::krige(
    Z ~ 1, locations = ~ X + Y, data = pts, newdata = grid,
    model = vg$fitted
  ))
  r <- template
  terra::values(r) <- prediction$value$var1.pred
  warnings <- c(vg$warnings, prediction$warnings)
  messages <- c(vg$messages, prediction$messages)
  diag <- c(list(
    formula = "Z ~ 1", observation_count = nrow(points),
    requested_method = "OK", return_status = if (length(warnings)) {
      "success_with_warning"
    } else "success"
  ), vg$diagnostics)
  list(
    surface = r, diagnostics = diag,
    parameters = list(kr_auto_cutoff = kr_auto_cutoff,
                      kr_cutoff = vg$diagnostics$cutoff,
                      kr_width = vg$diagnostics$lag_width),
    conditions = .condition_table(warnings, messages, "OK"),
    warnings_to_emit = warnings
  )
}

.interp_uk <- function(points, template, grid, kr_auto_cutoff, kr_cutoff,
                       kr_width, coordinate_scaling, control) {
  pts <- .kriging_frame(points)
  transformed <- .quadratic_terms(pts, scaling = coordinate_scaling)
  pts <- transformed$data
  mm <- stats::model.matrix(~ x + y + x2 + y2 + xy, data = pts)
  qr_mm <- qr(mm)
  rank_deficient <- qr_mm$rank < ncol(mm)
  condition_number <- tryCatch(kappa(mm, exact = TRUE), error = function(e) Inf)
  if (rank_deficient) {
    .ps_abort(
      sprintf("UK quadratic drift is rank deficient (%d of %d columns); add spatially independent observations or use another requested method.",
              qr_mm$rank, ncol(mm)),
      "potentiomap_input_error",
      data = list(method = "UK", rank = qr_mm$rank, columns = ncol(mm))
    )
  }
  trend_fit <- stats::lm(Z ~ x + y + x2 + y2 + xy, data = pts)
  pts$resid <- stats::resid(trend_fit)
  vg <- .build_variogram(pts, kr_auto_cutoff, kr_cutoff, kr_width)
  gd <- .quadratic_terms(grid, scaling = coordinate_scaling,
                         center = transformed$center,
                         scale = transformed$scale)$data
  prediction <- .capture_method(gstat::krige(
    Z ~ x + y + x2 + y2 + xy,
    locations = ~ X + Y, data = pts, newdata = gd, model = vg$fitted
  ))
  pred <- as.numeric(prediction$value$var1.pred)
  r <- template
  terra::values(r) <- pred
  observed <- pts$Z
  finite_pred <- pred[is.finite(pred)]
  observed_range <- diff(range(observed))
  predicted_range <- if (length(finite_pred)) diff(range(finite_pred)) else NA_real_
  range_ratio <- if (observed_range > 0) predicted_range / observed_range else Inf
  overshoot_below <- if (length(finite_pred)) max(0, min(observed) - min(finite_pred)) else NA_real_
  overshoot_above <- if (length(finite_pred)) max(0, max(finite_pred) - max(observed)) else NA_real_
  overshoot_ratio <- if (observed_range > 0) {
    max(overshoot_below, overshoot_above) / observed_range
  } else Inf
  instability <- character()
  if (is.finite(condition_number) &&
      condition_number > control$condition_number_warning) {
    instability <- c(instability, sprintf("trend condition number %.4g exceeds %.4g",
                                          condition_number,
                                          control$condition_number_warning))
  }
  if (is.finite(range_ratio) &&
      range_ratio > control$predicted_range_ratio_warning) {
    instability <- c(instability, sprintf("predicted/observed range ratio %.4g exceeds %.4g",
                                          range_ratio,
                                          control$predicted_range_ratio_warning))
  }
  if (is.finite(overshoot_ratio) &&
      overshoot_ratio > control$overshoot_range_ratio_warning) {
    instability <- c(instability, sprintf("overshoot/observed range ratio %.4g exceeds %.4g",
                                          overshoot_ratio,
                                          control$overshoot_range_ratio_warning))
  }
  if (control$warn_on_nonfinite_predictions && any(!is.finite(pred))) {
    instability <- c(instability, sprintf("%d predictions are nonfinite",
                                          sum(!is.finite(pred))))
  }
  instability_warnings <- if (length(instability)) list(.ps_condition(
    paste0("UK diagnostic warning: ", paste(instability, collapse = "; "),
           ". These thresholds are heuristic review flags, not formal acceptance tests."),
    "potentiomap_uk_instability_warning", "warning"
  )) else list()
  warnings <- c(vg$warnings, prediction$warnings, instability_warnings)
  messages <- c(vg$messages, prediction$messages)
  diag <- c(list(
    formula = "Z ~ x + y + x2 + y2 + xy",
    trend_formula = "quadratic drift",
    observation_count = nrow(points),
    coordinate_scaling = coordinate_scaling,
    coordinate_center = transformed$center,
    coordinate_scale = transformed$scale,
    transformed_coordinate_definition = if (coordinate_scaling == "center_scale") {
      "x=(X-center_X)/scale_X; y=(Y-center_Y)/scale_Y"
    } else "x=X; y=Y",
    model_matrix_dimensions = dim(mm), model_matrix_rank = qr_mm$rank,
    rank_deficient = rank_deficient, condition_number = condition_number,
    trend_coefficients = stats::coef(trend_fit),
    observed_minimum = min(observed), observed_maximum = max(observed),
    observed_range = observed_range,
    predicted_minimum = if (length(finite_pred)) min(finite_pred) else NA_real_,
    predicted_maximum = if (length(finite_pred)) max(finite_pred) else NA_real_,
    predicted_range = predicted_range,
    overshoot_below = overshoot_below, overshoot_above = overshoot_above,
    predicted_range_to_observed_range_ratio = range_ratio,
    overshoot_range_ratio = overshoot_ratio,
    nonfinite_prediction_count = sum(!is.finite(pred)),
    warning_text = if (length(warnings)) {
      paste(unique(vapply(warnings, conditionMessage, character(1))), collapse = " | ")
    } else "",
    message_text = if (length(messages)) {
      paste(unique(vapply(messages, conditionMessage, character(1))), collapse = " | ")
    } else "",
    diagnostic_thresholds = control,
    return_status = if (length(warnings)) "success_with_warning" else "success"
  ), vg$diagnostics)
  list(
    surface = r, diagnostics = diag,
    parameters = list(
      kr_auto_cutoff = kr_auto_cutoff, kr_cutoff = vg$diagnostics$cutoff,
      kr_width = vg$diagnostics$lag_width,
      uk_coordinate_scaling = coordinate_scaling,
      diagnostic_control = control
    ),
    conditions = .condition_table(warnings, messages, "UK"),
    warnings_to_emit = warnings
  )
}

.interp_custom <- function(method, custom_methods, points, template, grid) {
  captured <- .capture_method(custom_methods[[method]](
    points = points, template = template, grid = grid
  ))
  result <- captured$value
  if (inherits(result, "SpatRaster")) {
    if (terra::nlyr(result) != 1L ||
        !isTRUE(terra::compareGeom(result, template, stopOnError = FALSE))) {
      .ps_abort(
        sprintf("Custom method `%s` returned a raster that does not match the template geometry and CRS.",
                method),
        "potentiomap_input_error"
      )
    }
    r <- result
  } else if (is.numeric(result) && length(result) == terra::ncell(template)) {
    r <- template
    terra::values(r) <- result
  } else {
    .ps_abort(
      sprintf("Custom method `%s` must return a matching SpatRaster or one numeric value per template cell.",
              method),
      "potentiomap_input_error"
    )
  }
  list(
    surface = r,
    diagnostics = list(
      formula = NA_character_, observation_count = nrow(points),
      availability_explanation = "Method-specific fit diagnostics are controlled by the custom function.",
      return_status = if (length(captured$warnings)) "success_with_warning" else "success"
    ),
    parameters = list(custom_method = method),
    conditions = .condition_table(captured$warnings, captured$messages, method),
    warnings_to_emit = captured$warnings
  )
}

.kriging_frame <- function(points) {
  pts <- as.data.frame(terra::crds(points, df = TRUE))
  names(pts) <- c("X", "Y")
  pts$Z <- terra::values(points)$Z
  pts
}

.quadratic_terms <- function(df, scaling = c("center_scale", "none"),
                             center = NULL, scale = NULL) {
  scaling <- match.arg(scaling)
  if (is.null(center)) center <- colMeans(df[, c("X", "Y"), drop = FALSE])
  if (is.null(scale)) {
    scale <- if (scaling == "center_scale") {
      vapply(df[, c("X", "Y"), drop = FALSE], stats::sd, numeric(1))
    } else c(X = 1, Y = 1)
  }
  if (any(!is.finite(scale)) || any(scale <= sqrt(.Machine$double.eps))) {
    .ps_abort("UK coordinate scaling is undefined because one coordinate has no usable spread.",
              "potentiomap_input_error")
  }
  if (scaling == "center_scale") {
    df$x <- (df$X - center[["X"]]) / scale[["X"]]
    df$y <- (df$Y - center[["Y"]]) / scale[["Y"]]
  } else {
    center <- c(X = 0, Y = 0)
    scale <- c(X = 1, Y = 1)
    df$x <- df$X
    df$y <- df$Y
  }
  df$x2 <- df$x^2
  df$y2 <- df$y^2
  df$xy <- df$x * df$y
  list(data = df, center = center, scale = scale)
}

.build_variogram <- function(pts, kr_auto_cutoff, kr_cutoff, kr_width) {
  if (kr_auto_cutoff) {
    cutoff <- 0.5 * max(diff(range(pts$X)), diff(range(pts$Y)))
    width <- cutoff / 15
  } else {
    cutoff <- kr_cutoff
    width <- kr_width
  }
  empirical_capture <- .capture_method(gstat::variogram(
    resid ~ 1, ~ X + Y, data = pts, cutoff = cutoff, width = width
  ))
  empirical <- empirical_capture$value
  if (!nrow(empirical) || !any(is.finite(empirical$gamma))) {
    .ps_abort(
      "Kriging could not construct a usable empirical variogram; add spatial pairs or revise the analysis domain.",
      "potentiomap_input_error"
    )
  }
  psill0 <- stats::var(pts$resid)
  if (!is.finite(psill0) || psill0 <= 0) {
    .ps_abort("Kriging residual variance must be positive and finite.",
              "potentiomap_input_error")
  }
  initial <- gstat::vgm(psill = psill0, model = "Sph", range = cutoff / 3,
                        nugget = 0.1 * psill0)
  fit_capture <- .capture_method(gstat::fit.variogram(
    empirical, initial, fit.sills = TRUE, fit.ranges = TRUE, fit.method = 7
  ))
  fitted <- fit_capture$value
  fitted_df <- as.data.frame(fitted)
  nugget <- sum(fitted_df$psill[fitted_df$model == "Nug"], na.rm = TRUE)
  partial <- sum(fitted_df$psill[fitted_df$model != "Nug"], na.rm = TRUE)
  fitted_range <- suppressWarnings(max(fitted_df$range[fitted_df$model != "Nug"],
                                      na.rm = TRUE))
  if (!is.finite(fitted_range)) fitted_range <- NA_real_
  warnings <- c(empirical_capture$warnings, fit_capture$warnings)
  messages <- c(empirical_capture$messages, fit_capture$messages)
  list(
    empirical = empirical, initial = initial, fitted = fitted,
    warnings = warnings, messages = messages,
    diagnostics = list(
      empirical_variogram = empirical,
      initial_variogram_model = initial,
      fitted_variogram_model = fitted,
      nugget = nugget, partial_sill = partial, total_sill = nugget + partial,
      fitted_range = fitted_range, cutoff = cutoff, lag_width = width,
      cutoff_mode = if (kr_auto_cutoff) "automatic" else "manual",
      fit_method = 7,
      convergence_warning_text = if (length(warnings)) {
        paste(unique(vapply(warnings, conditionMessage, character(1))), collapse = " | ")
      } else "",
      variogram_condition_text = paste(
        unique(c(
          vapply(warnings, conditionMessage, character(1)),
          vapply(messages, conditionMessage, character(1))
        )),
        collapse = " | "
      ),
      messages = if (length(messages)) {
        vapply(messages, conditionMessage, character(1))
      } else character(),
      variogram_availability = "Available through documented gstat return objects."
    )
  )
}

.uk_diagnostic_control <- function(control) {
  defaults <- list(
    condition_number_warning = 1e8,
    predicted_range_ratio_warning = 10,
    overshoot_range_ratio_warning = 3,
    warn_on_rank_deficiency = TRUE,
    warn_on_nonfinite_predictions = TRUE
  )
  if (is.null(control)) return(defaults)
  if (!is.list(control) || is.null(names(control)) || any(!nzchar(names(control)))) {
    .ps_abort("`diagnostic_control` must be a named list.",
              "potentiomap_input_error")
  }
  unknown <- setdiff(names(control), names(defaults))
  if (length(unknown)) {
    .ps_abort(sprintf("Unknown diagnostic control(s): %s.",
                      paste(unknown, collapse = ", ")),
              "potentiomap_input_error")
  }
  out <- utils::modifyList(defaults, control)
  for (nm in c("condition_number_warning", "predicted_range_ratio_warning",
               "overshoot_range_ratio_warning")) {
    .validate_number(out[[nm]], paste0("diagnostic_control$", nm), lower = 0)
  }
  for (nm in c("warn_on_rank_deficiency", "warn_on_nonfinite_predictions")) {
    if (!is.logical(out[[nm]]) || length(out[[nm]]) != 1L || is.na(out[[nm]])) {
      .ps_abort(sprintf("`diagnostic_control$%s` must be TRUE or FALSE.", nm),
                "potentiomap_input_error")
    }
  }
  out
}

.emit_method_warnings <- function(warnings, method) {
  if (!length(warnings)) return(invisible(NULL))
  for (w in warnings) {
    if (inherits(w, "potentiomap_warning")) {
      warning(w)
    } else {
      class_name <- if (method %in% c("OK", "UK")) {
        "potentiomap_kriging_convergence_warning"
      } else "potentiomap_warning"
      .ps_warn(sprintf("%s: %s", method, conditionMessage(w)), class_name)
    }
  }
  invisible(NULL)
}

.apply_mask <- function(raster, mask) {
  m <- if (inherits(mask, "SpatVector")) mask else terra::vect(mask)
  if (!.same_crs(m, raster)) {
    .ps_abort("`mask` and surface must use the same CRS.",
              "potentiomap_crs_error")
  }
  m <- terra::aggregate(m, dissolve = TRUE)
  terra::mask(terra::crop(raster, m), m)
}
