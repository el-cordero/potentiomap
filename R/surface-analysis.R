.ps_cell_stats <- function(surfaces, fun, name, minimum_methods = 1L) {
  template <- surfaces[[1]]
  values <- do.call(cbind, lapply(surfaces, terra::values, mat = FALSE))
  finite <- rowSums(is.finite(values))
  out <- apply(values, 1, function(z) {
    z <- z[is.finite(z)]
    if (length(z) < minimum_methods) NA_real_ else fun(z)
  })
  r <- template; terra::values(r) <- out; names(r) <- name
  list(raster = r, count = finite)
}

#' Combine compatible potentiometric surfaces
#'
#' Calculates a cellwise ensemble and method-spread layers from compatible head
#' surfaces. Method spread is disagreement among supplied surfaces, not
#' statistical uncertainty, and an ensemble is not automatically more accurate
#' than a component method.
#'
#' @param surfaces Named compatible one-layer head rasters or a
#'   `potentiomap_result`.
#' @param statistic Cellwise mean, median, named weighted mean, or quantiles.
#' @param weights Named nonnegative weights for `weighted_mean`. Attribute
#'   `origin` may record how they were derived.
#' @param probabilities Quantile probabilities.
#' @param support Use only the intersection or allow the union of finite cells.
#' @param minimum_methods Minimum finite component count. The default is all
#'   methods for intersection and one for union.
#' @param method_metadata Optional named metadata list supplementing raster
#'   metadata.
#' @return A `potentiomap_ensemble` with ensemble, count, extrema, SD, MAD and
#'   method/support manifests.
#' @export
#' @examples
#' r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2,
#'                  crs = "EPSG:26920", vals = 1:4)
#' e <- ps_surface_ensemble(list(a = r, b = r + 2))
#' e$ensemble
#' # The spread records method disagreement, not a confidence interval.
ps_surface_ensemble <- function(surfaces,
                                statistic = c("mean", "median", "weighted_mean", "quantile"),
                                weights = NULL, probabilities = c(0.1, 0.5, 0.9),
                                support = c("intersection", "union"),
                                minimum_methods = NULL, method_metadata = NULL) {
  call <- match.call(); statistic <- match.arg(statistic); support <- match.arg(support)
  surfaces <- .ps_surfaces_input(surfaces); m <- length(surfaces)
  if (m < 1L) .ps_abort("At least one surface is required.", "potentiomap_ensemble_error")
  if (!is.null(method_metadata) && (!is.list(method_metadata) ||
      is.null(names(method_metadata)) || !all(names(surfaces) %in% names(method_metadata)))) {
    .ps_abort("`method_metadata` must be named for every surface.", "potentiomap_ensemble_error")
  }
  for (i in seq_along(surfaces)[-1]) .ps_assert_surface_compatible(surfaces[[1]], surfaces[[i]], TRUE,
                                                                    c(names(surfaces)[1], names(surfaces)[i]))
  if (!is.numeric(probabilities) || any(!is.finite(probabilities)) ||
      any(probabilities < 0 | probabilities > 1)) {
    .ps_abort("`probabilities` must lie between zero and one.", "potentiomap_ensemble_error")
  }
  if (is.null(minimum_methods)) minimum_methods <- if (support == "intersection") m else 1L
  .validate_integer(minimum_methods, "minimum_methods", lower = 0)
  if (minimum_methods > m) .ps_abort("`minimum_methods` exceeds the number of surfaces.", "potentiomap_ensemble_error")
  w <- NULL
  if (statistic == "weighted_mean") {
    if (is.null(weights) || is.null(names(weights)) || !setequal(names(weights), names(surfaces)) ||
        any(!is.finite(weights)) || any(weights < 0) || sum(weights) <= 0) {
      .ps_abort("Weighted means require named finite nonnegative weights with positive total.",
                "potentiomap_ensemble_error")
    }
    w <- as.numeric(weights[names(surfaces)]); w <- w / sum(w)
  }
  values <- do.call(cbind, lapply(surfaces, terra::values, mat = FALSE))
  finite_count <- rowSums(is.finite(values)); valid <- finite_count >= minimum_methods
  summarize <- function(z) {
    ok <- is.finite(z)
    if (sum(ok) < minimum_methods) return(NA_real_)
    switch(statistic, mean = mean(z[ok]), median = stats::median(z[ok]),
           weighted_mean = sum(z[ok] * w[ok]) / sum(w[ok]), NA_real_)
  }
  template <- surfaces[[1]]
  if (statistic == "quantile") {
    ens <- lapply(probabilities, function(prob) {
      r <- template
      terra::values(r) <- apply(values, 1, function(z) {
        z <- z[is.finite(z)]; if (length(z) < minimum_methods) NA_real_ else
          as.numeric(stats::quantile(z, prob, names = FALSE, type = 7))
      })
      names(r) <- paste0("q", format(prob, trim = TRUE)); .ps_set_metadata(r, .ps_get_metadata(template))
    })
    names(ens) <- paste0("q", probabilities)
  } else {
    r <- template; terra::values(r) <- apply(values, 1, summarize); names(r) <- statistic
    ens <- .ps_set_metadata(r, .ps_get_metadata(template))
  }
  stat_r <- function(fun, nm, min_n = minimum_methods) .ps_cell_stats(surfaces, fun, nm, min_n)$raster
  count <- template; terra::values(count) <- finite_count; names(count) <- "finite_method_count"
  minimum <- stat_r(min, "method_minimum"); maximum <- stat_r(max, "method_maximum")
  sd_r <- stat_r(function(z) if (length(z) == 1L) 0 else stats::sd(z), "method_standard_deviation")
  mad_r <- stat_r(function(z) stats::mad(z, constant = 1), "method_mad")
  if (statistic == "weighted_mean") {
    ev <- terra::values(ens, mat = FALSE); lo <- terra::values(minimum, mat = FALSE); hi <- terra::values(maximum, mat = FALSE)
    if (any(ev < lo - 1e-10 | ev > hi + 1e-10, na.rm = TRUE)) {
      .ps_abort("The convex weighted mean fell outside component extrema.", "potentiomap_ensemble_error")
    }
  }
  method_manifest <- data.frame(
    method = names(surfaces), finite_cells = vapply(surfaces, function(z) sum(is.finite(terra::values(z, mat = FALSE))), numeric(1)),
    weight = if (is.null(w)) if (statistic == "mean") rep(1 / m, m) else NA_real_ else w,
    weight_origin = if (is.null(weights)) if (statistic == "mean") "equal" else NA_character_ else attr(weights, "origin") %||% "user_supplied",
    stringsAsFactors = FALSE
  )
  support_manifest <- data.frame(minimum_methods = minimum_methods, support = support,
                                 total_cells = terra::ncell(template), eligible_cells = sum(valid))
  .ps_new_result(list(ensemble = ens, count = count, minimum = minimum, maximum = maximum,
                      standard_deviation = sd_r, mad = mad_r,
                      method_manifest = method_manifest, support_manifest = support_manifest),
                 "potentiomap_ensemble", call,
                 settings = list(statistic = statistic, probabilities = probabilities,
                                 support = support, weights = w),
                 metadata = .ps_surface_metadata(template),
                 summary = support_manifest,
                 warnings = "Spread layers describe method disagreement, not statistical uncertainty.")
}

#' Map disagreement among interpolation methods
#'
#' Computes head and down-gradient-direction differences among compatible
#' surfaces. Directed bearings use circular differences from 0 to 180 degrees;
#' they are not treated as axial orientations.
#'
#' @inheritParams ps_surface_ensemble
#' @param head_measures Requested head-disagreement measures.
#' @param gradient Include gradient-direction disagreement.
#' @param min_gradient Gradients below this magnitude are undefined.
#' @return A `potentiomap_disagreement` with disagreement rasters, pairwise and
#'   direction summaries, a flat mask, and method-pair manifest.
#' @export
#' @examples
#' r <- terra::rast(nrows = 3, ncols = 3, xmin = 0, xmax = 3, ymin = 0, ymax = 3,
#'                  crs = "EPSG:26920", vals = 1:9)
#' d <- ps_method_disagreement(list(a = r, b = r + 1))
#' d$pairwise_summary
#' # Head offsets are method differences, not statistical uncertainty.
ps_method_disagreement <- function(surfaces,
                                   head_measures = c("range", "sd", "mad", "mean_pairwise_absolute"),
                                   gradient = TRUE, min_gradient = 1e-5,
                                   support = c("intersection", "union"),
                                   minimum_methods = 2) {
  call <- match.call(); support <- match.arg(support); .ps_scalar_logical(gradient, "gradient")
  surfaces <- .ps_surfaces_input(surfaces); m <- length(surfaces)
  .validate_integer(minimum_methods, "minimum_methods", lower = 0)
  if (m < minimum_methods) .ps_abort("Fewer surfaces than `minimum_methods`.", "potentiomap_ensemble_error")
  for (i in seq_along(surfaces)[-1]) .ps_assert_surface_compatible(surfaces[[1]], surfaces[[i]], TRUE,
                                                                    c(names(surfaces)[1], names(surfaces)[i]))
  allowed <- c("range", "sd", "mad", "mean_pairwise_absolute")
  if (!is.character(head_measures) || any(!head_measures %in% allowed)) {
    .ps_abort("Unknown `head_measures` value.", "potentiomap_ensemble_error")
  }
  values <- do.call(cbind, lapply(surfaces, terra::values, mat = FALSE)); countv <- rowSums(is.finite(values))
  template <- surfaces[[1]]; count <- template; terra::values(count) <- countv; names(count) <- "finite_method_count"
  funs <- list(range = function(z) diff(range(z)), sd = function(z) if (length(z) == 1L) 0 else stats::sd(z),
               mad = function(z) stats::mad(z, constant = 1),
               mean_pairwise_absolute = function(z) if (length(z) < 2L) NA_real_ else mean(abs(stats::dist(z))))
  rasters <- lapply(head_measures, function(nm) {
    r <- template; terra::values(r) <- apply(values, 1, function(z) {
      z <- z[is.finite(z)]; if (length(z) < minimum_methods) NA_real_ else funs[[nm]](z)
    }); names(r) <- paste0("method_", nm); r
  }); names(rasters) <- head_measures; rasters$count <- count
  pairs <- utils::combn(names(surfaces), 2, simplify = FALSE)
  pair_rows <- lapply(seq_along(pairs), function(i) {
    p <- pairs[[i]]; a <- values[, match(p[1], names(surfaces))]; b <- values[, match(p[2], names(surfaces))]
    ok <- is.finite(a) & is.finite(b)
    data.frame(pair_id = sprintf("pair_%04d", i), method_a = p[1], method_b = p[2],
               finite_cells = sum(ok), mean_absolute_head_difference = if (any(ok)) mean(abs(a[ok] - b[ok])) else NA_real_,
               maximum_absolute_head_difference = if (any(ok)) max(abs(a[ok] - b[ok])) else NA_real_)
  })
  pairwise_summary <- do.call(rbind, pair_rows)
  direction_summary <- data.frame(); flat_mask <- NULL
  if (gradient) {
    gradients <- lapply(surfaces, .ps_gradient, min_gradient = min_gradient)
    directions <- do.call(cbind, lapply(gradients, function(z) terra::values(z$direction, mat = FALSE)))
    flatv <- rowSums(is.finite(directions)) < minimum_methods
    direction_pairs <- list(); direction_values <- matrix(NA_real_, nrow(values), length(pairs))
    for (i in seq_along(pairs)) {
      idx <- match(pairs[[i]], names(surfaces)); d <- .ps_angle_difference(directions[, idx[1]], directions[, idx[2]])
      direction_values[, i] <- d
      direction_pairs[[i]] <- data.frame(pair_id = sprintf("pair_%04d", i), method_a = pairs[[i]][1], method_b = pairs[[i]][2],
        finite_cells = sum(is.finite(d)), median_direction_difference = stats::median(d, na.rm = TRUE),
        maximum_direction_difference = if (any(is.finite(d))) max(d, na.rm = TRUE) else NA_real_)
    }
    direction_summary <- do.call(rbind, direction_pairs)
    med <- template; terra::values(med) <- apply(direction_values, 1, function(z) if (sum(is.finite(z))) stats::median(z, na.rm = TRUE) else NA_real_); names(med) <- "median_direction_disagreement"
    mx <- template; terra::values(mx) <- apply(direction_values, 1, function(z) if (sum(is.finite(z))) max(z, na.rm = TRUE) else NA_real_); names(mx) <- "maximum_direction_disagreement"
    flat_mask <- template; terra::values(flat_mask) <- as.integer(flatv); names(flat_mask) <- "flat_or_undefined_gradient"
    rasters$median_gradient_direction <- med; rasters$maximum_gradient_direction <- mx
  }
  manifest <- if (length(pairs)) data.frame(pair_id = sprintf("pair_%04d", seq_along(pairs)),
                                            method_a = vapply(pairs, `[`, character(1), 1),
                                            method_b = vapply(pairs, `[`, character(1), 2)) else data.frame()
  .ps_new_result(list(rasters = rasters, pairwise_summary = pairwise_summary,
                      direction_summary = direction_summary, flat_mask = flat_mask,
                      method_pair_manifest = manifest),
                 "potentiomap_disagreement", call,
                 settings = list(head_measures = head_measures, gradient = gradient,
                                 min_gradient = min_gradient, support = support,
                                 minimum_methods = minimum_methods),
                 metadata = .ps_surface_metadata(template),
                 summary = pairwise_summary,
                 warnings = "Method disagreement is not statistical uncertainty.")
}

.ps_contour_displacement <- function(a, b, levels) {
  if (is.null(levels)) return(data.frame())
  rows <- lapply(seq_along(levels), function(i) {
    level <- levels[i]
    ca <- tryCatch(terra::as.contour(a, levels = level), error = function(e) NULL)
    cb <- tryCatch(terra::as.contour(b, levels = level), error = function(e) NULL)
    if (is.null(ca) || is.null(cb) || !nrow(ca) || !nrow(cb)) {
      return(data.frame(level_id = sprintf("level_%04d", i), level = level,
                        mean_distance = NA_real_, maximum_distance = NA_real_, status = "unavailable"))
    }
    sa <- sf::st_cast(sf::st_as_sf(ca), "POINT", warn = FALSE)
    sb <- sf::st_cast(sf::st_as_sf(cb), "POINT", warn = FALSE)
    d <- matrix(as.numeric(sf::st_distance(sa, sb)), nrow = nrow(sa))
    nearest <- apply(d, 1, min, na.rm = TRUE)
    data.frame(level_id = sprintf("level_%04d", i), level = level,
               mean_distance = mean(nearest), maximum_distance = max(nearest), status = "success")
  })
  do.call(rbind, rows)
}

#' Compare two potentiometric surfaces
#'
#' Compares compatible surfaces on their common finite support. Alignment is an
#' explicit operation and defaults to an error. The signed default is surface B
#' minus surface A; percentage head change is not calculated.
#'
#' @param surface_a,surface_b One-layer continuous head rasters.
#' @param direction Signed-difference order.
#' @param align Alignment action; mismatch errors by default.
#' @param template Explicit target for `align = "template"`.
#' @param resampling Continuous bilinear or explicit nearest-neighbor alignment.
#' @param contour_levels Optional head contour levels.
#' @param compare_gradient Compare modeled gradient magnitude and direction.
#' @param min_gradient Threshold below which direction is undefined.
#' @return A `potentiomap_surface_comparison` with difference/support/gradient
#'   rasters, contour displacement, summaries, and an alignment manifest.
#' @export
#' @examples
#' a <- terra::rast(nrows = 3, ncols = 3, xmin = 0, xmax = 3, ymin = 0, ymax = 3,
#'                  crs = "EPSG:26920", vals = 1:9)
#' cmp <- ps_compare_surfaces(a, a + 1)
#' cmp$summary
#' # A modeled difference is not a storage or water-budget estimate.
ps_compare_surfaces <- function(surface_a, surface_b,
                                direction = c("b_minus_a", "a_minus_b"),
                                align = c("error", "to_a", "to_b", "template"),
                                template = NULL, resampling = c("bilinear", "near"),
                                contour_levels = NULL, compare_gradient = TRUE,
                                min_gradient = 1e-5) {
  call <- match.call(); direction <- match.arg(direction); align <- match.arg(align); resampling <- match.arg(resampling)
  .ps_scalar_logical(compare_gradient, "compare_gradient")
  aligned <- .ps_align_pair(surface_a, surface_b, align, template, resampling,
                            c("surface_a", "surface_b"))
  a <- aligned$a; b <- aligned$b; support <- .ps_common_support(a, b)
  signed <- if (direction == "b_minus_a") b - a else a - b
  absolute <- abs(signed); names(signed) <- "signed_difference"; names(absolute) <- "absolute_difference"
  sv <- terra::values(signed, mat = FALSE); ok <- support$common_index
  gradient_mag <- gradient_dir <- NULL
  if (compare_gradient) {
    ga <- .ps_gradient(a, min_gradient); gb <- .ps_gradient(b, min_gradient)
    gradient_mag <- gb$magnitude - ga$magnitude; names(gradient_mag) <- "gradient_magnitude_difference"
    d <- .ps_angle_difference(terra::values(ga$direction, mat = FALSE), terra::values(gb$direction, mat = FALSE))
    gradient_dir <- a; terra::values(gradient_dir) <- d; names(gradient_dir) <- "gradient_direction_difference"
  }
  cell_area <- prod(terra::res(a))
  summary <- data.frame(
    direction = direction, common_cells = sum(ok), only_a_cells = sum(support$only_a_index), only_b_cells = sum(support$only_b_index),
    common_area = sum(ok) * cell_area, only_a_area = sum(support$only_a_index) * cell_area,
    only_b_area = sum(support$only_b_index) * cell_area,
    mean_difference = if (any(ok)) mean(sv[ok]) else NA_real_,
    mean_absolute_difference = if (any(ok)) mean(abs(sv[ok])) else NA_real_,
    rmse = if (any(ok)) sqrt(mean(sv[ok]^2)) else NA_real_,
    minimum_difference = if (any(ok)) min(sv[ok]) else NA_real_, maximum_difference = if (any(ok)) max(sv[ok]) else NA_real_
  )
  contours <- .ps_contour_displacement(a, b, contour_levels)
  meta <- .ps_surface_metadata(a); signed <- .ps_set_metadata(signed, meta$source); absolute <- .ps_set_metadata(absolute, meta$source)
  .ps_new_result(list(signed_difference = signed, absolute_difference = absolute,
                      common_support = support$common, only_a = support$only_a,
                      only_b = support$only_b, gradient_magnitude_difference = gradient_mag,
                      gradient_direction_difference = gradient_dir,
                      contour_displacement = contours,
                      support_summary = summary[, c("common_cells", "only_a_cells", "only_b_cells", "common_area", "only_a_area", "only_b_area")],
                      alignment_manifest = aligned$manifest),
                 "potentiomap_surface_comparison", call,
                 settings = list(direction = direction, align = align, resampling = resampling,
                                 contour_levels = contour_levels, compare_gradient = compare_gradient,
                                 min_gradient = min_gradient), metadata = meta, summary = summary,
                 warnings = "Surface difference is not a storage, depletion, recharge, or water-budget estimate.")
}

#' Calculate depth to a water-table or potentiometric surface
#'
#' Calculates land-surface elevation minus modeled head after explicit geometry,
#' unit, and vertical-datum checks. Negative values are preserved. For a
#' confined surface the product is depth to the potentiometric surface, not
#' necessarily depth to the water table.
#'
#' @param head_surface,land_surface One-layer continuous elevation rasters.
#' @param surface_type Water table or potentiometric surface terminology.
#' @param align,template,resampling Explicit alignment controls.
#' @param tolerance Nonnegative absolute depth classified as near zero.
#' @return A `potentiomap_depth_surface` with depth and review/support masks.
#' @export
#' @examples
#' h <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2,
#'                  crs = "EPSG:26920", vals = c(9, 11, 8, 10))
#' land <- h * 0 + 10
#' z <- ps_depth_to_water_surface(h, land, "potentiometric")
#' terra::values(z$depth)
#' # Negative values are retained for hydrogeologic and datum review.
ps_depth_to_water_surface <- function(head_surface, land_surface,
                                      surface_type = c("water_table", "potentiometric"),
                                      align = c("error", "to_head", "to_land", "template"),
                                      template = NULL, resampling = "bilinear",
                                      tolerance = 0) {
  call <- match.call(); surface_type <- match.arg(surface_type); align <- match.arg(align)
  .validate_number(tolerance, "tolerance", lower = 0, inclusive = TRUE)
  align_map <- c(error = "error", to_head = "to_a", to_land = "to_b", template = "template")
  pair <- .ps_align_pair(head_surface, land_surface, unname(align_map[align]), template,
                         match.arg(resampling, c("bilinear", "near")), c("head_surface", "land_surface"))
  h <- pair$a; land <- pair$b
  mh <- .ps_surface_metadata(h); ml <- .ps_surface_metadata(land)
  if (!.ps_metadata_equal(mh, ml, "head_unit") || !.ps_metadata_equal(mh, ml, "vertical_datum")) {
    .ps_abort("Head and land surfaces require compatible units and vertical datum.", "potentiomap_depth_surface_error")
  }
  support <- .ps_common_support(h, land); depth <- land - h; names(depth) <- if (surface_type == "water_table") "depth_to_water" else "depth_to_potentiometric_surface"
  dv <- terra::values(depth, mat = FALSE); negative <- h; terra::values(negative) <- as.integer(is.finite(dv) & dv < -tolerance); names(negative) <- "negative_depth"
  near <- h; terra::values(near) <- as.integer(is.finite(dv) & abs(dv) <= tolerance); names(near) <- "near_zero_depth"
  summary <- data.frame(surface_type = surface_type, finite_cells = sum(is.finite(dv)), negative_cells = sum(dv < -tolerance, na.rm = TRUE),
                        near_zero_cells = sum(abs(dv) <= tolerance, na.rm = TRUE), minimum_depth = if (any(is.finite(dv))) min(dv, na.rm = TRUE) else NA_real_,
                        maximum_depth = if (any(is.finite(dv))) max(dv, na.rm = TRUE) else NA_real_,
                        label = if (surface_type == "water_table") "depth to water" else "depth to the potentiometric surface")
  meta <- mh$source; meta$surface_type <- if (surface_type == "water_table") "depth_to_water" else "depth_to_potentiometric_surface"
  depth <- .ps_set_metadata(depth, meta)
  .ps_new_result(list(depth = depth, negative_mask = negative, near_zero_mask = near,
                      common_support = support$common, only_head = support$only_a,
                      only_land = support$only_b, alignment_manifest = pair$manifest),
                 "potentiomap_depth_surface", call,
                 settings = list(surface_type = surface_type, align = align,
                                 resampling = resampling, tolerance = tolerance),
                 metadata = meta, summary = summary,
                 warnings = if (summary$negative_cells) "Negative depth is preserved for review; it can reflect artesian/discharge conditions, local model behavior, uncertainty, or incompatible references." else character())
}

#' Calculate a vertical hydraulic gradient
#'
#' Uses absolute upper and lower observation elevations. With an upward-positive
#' convention, the primary gradient is `(lower_head - upper_head) /
#' (upper_elevation - lower_elevation)`. The result indicates potential vertical
#' direction and is not vertical groundwater flux.
#'
#' @param upper_head,lower_head Numeric paired heads or one-layer rasters.
#' @param upper_elevation,lower_elevation Matching absolute elevations, not
#'   unidentified depths.
#' @param positive Sign convention.
#' @param tolerance Nonnegative near-zero gradient tolerance.
#' @param align,template Explicit raster alignment controls.
#' @param event_metadata Optional list documenting compatible event, datum,
#'   units, interval and screen-midpoint assumptions.
#' @return A `potentiomap_vertical_gradient` with component products, direction
#'   class, support, and sign convention. No flux field is returned.
#' @export
#' @examples
#' vg <- ps_vertical_gradient(10, 12, 100, 90)
#' vg$gradient
#' # The positive gradient indicates upward driving potential, not flux.
ps_vertical_gradient <- function(upper_head, lower_head, upper_elevation,
                                 lower_elevation, positive = c("upward", "downward"),
                                 tolerance = 0,
                                 align = c("error", "to_upper", "to_lower", "template"),
                                 template = NULL, event_metadata = NULL) {
  call <- match.call(); positive <- match.arg(positive); align <- match.arg(align)
  .validate_number(tolerance, "tolerance", lower = 0, inclusive = TRUE)
  raster_mode <- inherits(upper_head, "SpatRaster") || inherits(lower_head, "SpatRaster")
  if (raster_mode) {
    if (!all(vapply(list(upper_head, lower_head, upper_elevation, lower_elevation), inherits, logical(1), "SpatRaster"))) {
      .ps_abort("Raster mode requires all four inputs to be SpatRaster objects.", "potentiomap_vertical_gradient_error")
    }
    map <- c(error = "error", to_upper = "to_a", to_lower = "to_b", template = "template")
    pair <- .ps_align_pair(upper_head, lower_head, unname(map[align]), template, "bilinear", c("upper_head", "lower_head"))
    up <- pair$a; low <- pair$b
    ue <- .ps_align_pair(upper_elevation, up, if (align == "error") "error" else "to_b", NULL, "bilinear", c("upper_elevation", "upper_head"))$a
    le <- .ps_align_pair(lower_elevation, up, if (align == "error") "error" else "to_b", NULL, "bilinear", c("lower_elevation", "upper_head"))$a
    sep <- ue - le; hd <- up - low; dhdz <- hd / sep; upward <- (low - up) / sep
    sv <- terra::values(sep, mat = FALSE)
    if (any(sv <= 0, na.rm = TRUE)) .ps_abort("Vertical separation must be positive everywhere finite.", "potentiomap_vertical_gradient_error")
    gradient <- if (positive == "upward") upward else -upward; gv <- terra::values(gradient, mat = FALSE)
    cls <- ifelse(!is.finite(gv), "indeterminate", ifelse(gv > tolerance, positive,
      ifelse(gv < -tolerance, if (positive == "upward") "downward" else "upward", "near_zero")))
    direction_class <- up; terra::values(direction_class) <- match(cls, c("indeterminate", "near_zero", "upward", "downward")) - 1L; names(direction_class) <- "direction_class"
    support <- .ps_common_support(up, low)
    products <- list(upper_head = up, lower_head = low, head_difference = hd,
                     vertical_separation = sep, dh_dz = dhdz, gradient = gradient,
                     signed_gradient = gradient,
                     direction_class = direction_class, overlap = support$common,
                     finite_support = support$common)
    summary <- as.data.frame(table(direction = cls), stringsAsFactors = FALSE)
    metadata <- .ps_surface_metadata(up)
    alignment_manifest <- pair$manifest
  } else {
    inputs <- lapply(list(upper_head, lower_head, upper_elevation, lower_elevation), as.numeric)
    len <- unique(vapply(inputs, length, integer(1)))
    if (length(len) != 1L || !len || any(!vapply(inputs, function(z) all(is.finite(z)), logical(1)))) {
      .ps_abort("Numeric inputs must have one common positive length and finite values.", "potentiomap_vertical_gradient_error")
    }
    up <- inputs[[1]]; low <- inputs[[2]]; ue <- inputs[[3]]; le <- inputs[[4]]; sep <- ue - le
    if (any(sep <= 0)) .ps_abort("`upper_elevation - lower_elevation` must be positive.", "potentiomap_vertical_gradient_error")
    hd <- up - low; dhdz <- hd / sep; upward <- (low - up) / sep; gradient <- if (positive == "upward") upward else -upward
    cls <- ifelse(abs(gradient) <= tolerance, "near_zero", ifelse(gradient > 0, positive, if (positive == "upward") "downward" else "upward"))
    products <- list(upper_head = up, lower_head = low, head_difference = hd,
      vertical_separation = sep, dh_dz = dhdz, gradient = gradient,
      signed_gradient = gradient,
      direction_class = cls, overlap = rep(TRUE, length(up)), finite_support = rep(TRUE, length(up)))
    summary <- as.data.frame(table(direction = cls), stringsAsFactors = FALSE)
    metadata <- event_metadata %||% list(); alignment_manifest <- list(action = "numeric_pairing")
  }
  if (!is.null(event_metadata) && isTRUE(event_metadata$overlapping_intervals)) {
    .ps_warn("Representative upper and lower intervals overlap; vertical-gradient interpretation is ambiguous.",
             "potentiomap_vertical_gradient_warning")
  }
  sign_convention <- list(
    positive = positive, vertical_separation = "upper_elevation - lower_elevation",
    dh_dz = "(upper_head - lower_head) / vertical_separation",
    upward_gradient = "(lower_head - upper_head) / vertical_separation",
    interpretation = "Hydraulic-gradient driving potential; not vertical flux.",
    screen_midpoint_assumption = event_metadata$screen_midpoint_assumption %||% FALSE
  )
  .ps_new_result(c(products, list(sign_convention = sign_convention,
                                 alignment_manifest = alignment_manifest)),
                 "potentiomap_vertical_gradient", call,
                 settings = list(positive = positive, tolerance = tolerance, align = align),
                 metadata = metadata, summary = summary,
                 warnings = "Vertical hydraulic gradient is not vertical groundwater flux.")
}

#' @export
as.data.frame.potentiomap_surface_comparison <- function(x, ...) x$summary
#' @export
as.data.frame.potentiomap_disagreement <- function(x, ...) x$pairwise_summary
#' @export
as.data.frame.potentiomap_depth_surface <- function(x, ...) x$summary
