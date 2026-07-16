#' Classify modeled contour sections by local prediction support
#'
#' Divides modeled contour lines according to user-defined spatial-support
#' criteria. Sections close to groundwater observations may be classified as
#' supported, while sections crossing larger monitoring gaps may be classified
#' as approximate or unsupported. Classification occurs at the resolution of
#' the supplied prediction-support raster and does not move, smooth, close, or
#' convert the contour lines.
#'
#' Distance thresholds can be expressed in projected map units or as multiples
#' of the median nearest-neighbor spacing among unique observation locations.
#' Optional training-hull, local-neighbor, and user-identified uncertainty
#' criteria can modify the result. With combine = "worst", the least supported
#' active criterion determines the cell class. Finite prediction and mask
#' status are always enforced.
#'
#' These classes describe local observation support for the mapped contour.
#' They are not statistical confidence intervals. Proximity to wells does not
#' prove that a contour is correct, and distance from wells does not prove that
#' it is wrong. A solid contour remains an interpolation between observations;
#' an approximate contour is still generated from the modeled surface.
#' Appropriate criteria depend on network geometry, hydrogeology, interpolation
#' method, raster resolution, and intended map use.
#'
#' @param contours Nonempty line SpatVector or line-vector input readable by
#'   terra::vect(). A recognizable contour-level field is required.
#' @param points Optional groundwater observation points. Required when
#'   support is not supplied and for relative-spacing or neighbor criteria
#'   unless the support result retains its training points.
#' @param surface Optional one-layer potentiometric-surface SpatRaster.
#'   Required with points when support is not supplied. When both a surface
#'   and support result are supplied, their geometry must match.
#' @param support Optional [ps_prediction_support()] result. Its existing
#'   distance, training-hull, mask, and finite-prediction layers are reused.
#' @param uncertainty Optional one-layer raster containing a user-identified
#'   uncertainty measure. It is never resampled and must match support geometry.
#' @param supported_distance,approximate_distance Optional paired nonnegative
#'   distance thresholds. The approximate threshold must be at least the
#'   supported threshold. No default distances are assumed.
#' @param distance_reference Either "map_units" or
#'   "median_nearest_neighbor". In the latter case, supplied thresholds are
#'   multipliers of the calculated median nearest-neighbor spacing.
#' @param require_inside_hull When TRUE, cells outside the training convex
#'   hull cannot be supported but may remain approximate when other criteria
#'   permit. A convex hull is not an aquifer boundary.
#' @param neighbor_radius,minimum_neighbors Optional paired local-density
#'   criterion in projected map units and unique observation locations.
#' @param supported_uncertainty,approximate_uncertainty Optional paired
#'   thresholds in the units or scale of uncertainty.
#' @param combine "worst" combines all active primary criteria, "distance"
#'   uses distance, and "uncertainty" uses uncertainty. Finite prediction,
#'   mask, requested hull, and neighbor rules remain applicable.
#' @param keep_unsupported Retain unsupported line sections when TRUE.
#' @param minimum_segment_length Nonnegative minimum retained line length in
#'   projected map units.
#' @param return "result" for a potentiomap_contour_support object or
#'   "segments" for only the classified line SpatVector.
#' @param uncertainty_type Required description when uncertainty is supplied,
#'   such as "kriging prediction variance" or "user support index".
#' @param uncertainty_units Optional units or scale description for the supplied
#'   uncertainty raster.
#'
#' @return A potentiomap_contour_support list with segments, a line-length
#'   summary, thresholds, the support information used, settings, and
#'   captured conditions; or only segments. Segment attributes include the
#'   original contour level and source ID, support class and reason, distance,
#'   hull and finite-support statistics, optional neighbor and uncertainty
#'   statistics, length, threshold reference, and a line_type style hint.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' wells <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                         "well_id", "EPSG:26916")
#' surface <- ps_interpolate(wells, methods = "IDW", grid_res = 300)$IDW
#' support <- ps_prediction_support(wells, surface = surface)
#' contours <- ps_contours(surface, interval = 1)
#' classified <- suppressWarnings(ps_contour_support(
#'   contours, support = support,
#'   supported_distance = 500, approximate_distance = 1200,
#'   require_inside_hull = TRUE
#' ))
#' classified$summary
ps_contour_support <- function(
    contours, points = NULL, surface = NULL, support = NULL,
    uncertainty = NULL, supported_distance = NULL,
    approximate_distance = NULL,
    distance_reference = c("map_units", "median_nearest_neighbor"),
    require_inside_hull = TRUE, neighbor_radius = NULL,
    minimum_neighbors = NULL, supported_uncertainty = NULL,
    approximate_uncertainty = NULL,
    combine = c("worst", "distance", "uncertainty"),
    keep_unsupported = TRUE, minimum_segment_length = 0,
    return = c("result", "segments"), uncertainty_type = NULL,
    uncertainty_units = NULL) {
  call <- match.call()
  distance_reference <- match.arg(distance_reference)
  combine <- match.arg(combine)
  return <- match.arg(return)
  .contour_support_logical(require_inside_hull, "require_inside_hull")
  .contour_support_logical(keep_unsupported, "keep_unsupported")
  .validate_number(minimum_segment_length, "minimum_segment_length",
                   lower = 0, inclusive = TRUE)

  lines <- tryCatch(
    if (inherits(contours, "SpatVector")) contours else terra::vect(contours),
    error = function(e) .ps_abort(
      "contours must be line geometry readable by terra.",
      "potentiomap_contour_support_error",
      data = list(parent_message = conditionMessage(e))
    )
  )
  if (!nrow(lines)) {
    .ps_abort("contours must contain at least one line feature.",
              "potentiomap_contour_support_error")
  }
  if (terra::geomtype(lines) != "lines") {
    .ps_abort("contours must contain line geometry.",
              "potentiomap_contour_support_error")
  }
  .require_crs(lines, "contours")
  if (terra::is.lonlat(lines)) {
    .ps_abort(
      "Contour-support distances require a projected CRS; longitude and latitude degrees are not linear map units.",
      "potentiomap_contour_support_error"
    )
  }
  level_field <- .contour_level_field(lines)
  if (is.null(level_field)) {
    .ps_abort(
      "No contour-level field was found; use contour_level, level, levels, value, or elevation.",
      "potentiomap_contour_support_error"
    )
  }

  distance_active <- .contour_threshold_pair(
    supported_distance, approximate_distance,
    "supported_distance", "approximate_distance",
    "potentiomap_contour_threshold_error"
  )
  uncertainty_active <- .contour_threshold_pair(
    supported_uncertainty, approximate_uncertainty,
    "supported_uncertainty", "approximate_uncertainty",
    "potentiomap_contour_uncertainty_error"
  )
  neighbor_active <- !is.null(neighbor_radius) || !is.null(minimum_neighbors)
  if (neighbor_active && (is.null(neighbor_radius) || is.null(minimum_neighbors))) {
    .ps_abort("Supply both neighbor_radius and minimum_neighbors.",
              "potentiomap_contour_threshold_error")
  }
  if (neighbor_active) {
    .validate_number(neighbor_radius, "neighbor_radius", lower = 0,
                     inclusive = TRUE)
    .validate_integer(minimum_neighbors, "minimum_neighbors", lower = 0)
  }
  if (combine == "distance" && !distance_active) {
    .ps_abort("combine = distance requires both distance thresholds.",
              "potentiomap_contour_threshold_error")
  }
  if (combine == "uncertainty" && !uncertainty_active) {
    .ps_abort("combine = uncertainty requires both uncertainty thresholds.",
              "potentiomap_contour_uncertainty_error")
  }
  if (combine == "worst" && !distance_active && !uncertainty_active) {
    .ps_abort(
      "Supply distance or uncertainty thresholds; potentiomap does not assume universal contour-support criteria.",
      "potentiomap_contour_threshold_error"
    )
  }

  if (is.null(support)) {
    if (is.null(points) || is.null(surface)) {
      .ps_abort("Supply support, or supply both points and surface.",
                "potentiomap_contour_support_error")
    }
    support <- ps_prediction_support(points, surface = surface)
  }
  if (!inherits(support, "potentiomap_support")) {
    .ps_abort("support must be a result from ps_prediction_support().",
              "potentiomap_contour_support_error")
  }
  required_layers <- c(
    "inside_training_hull", "nearest_observation_distance", "inside_mask",
    "finite_prediction"
  )
  missing_layers <- setdiff(required_layers, names(support$rasters))
  if (length(missing_layers)) {
    .ps_abort(
      paste0("Support information is missing layer(s): ",
             paste(missing_layers, collapse = ", "), "."),
      "potentiomap_contour_support_error"
    )
  }
  base <- support$rasters[["nearest_observation_distance"]]
  if (!.same_crs(lines, base)) {
    .ps_abort("contours and support rasters must use the same CRS.",
              "potentiomap_contour_support_error")
  }
  if (!is.null(surface)) {
    surface <- .as_surface(surface)
    if (!isTRUE(terra::compareGeom(surface, base, stopOnError = FALSE))) {
      .ps_abort("surface and support raster geometry are incompatible.",
                "potentiomap_contour_support_error")
    }
  }

  pts <- points %||% support$points
  if (!is.null(pts)) {
    pts <- .as_points(pts)
    if (!nrow(pts)) {
      .ps_abort("points must contain at least one observation.",
                "potentiomap_contour_support_error")
    }
    .require_projected(pts, "points")
    if (!.same_crs(pts, base)) {
      .ps_abort("points and support rasters must use the same CRS.",
                "potentiomap_contour_support_error")
    }
  }
  if ((distance_reference == "median_nearest_neighbor" || neighbor_active) &&
      is.null(pts)) {
    .ps_abort(
      "Training points are required for relative-distance or local-neighbor criteria.",
      "potentiomap_contour_support_error"
    )
  }

  uncertainty_raster <- NULL
  if (!is.null(uncertainty)) {
    uncertainty_raster <- .as_surface(uncertainty, "uncertainty")
    if (is.null(uncertainty_type) || !is.character(uncertainty_type) ||
        length(uncertainty_type) != 1L || is.na(uncertainty_type) ||
        !nzchar(trimws(uncertainty_type))) {
      .ps_abort(
        "uncertainty_type must identify what the uncertainty raster represents.",
        "potentiomap_contour_uncertainty_error"
      )
    }
    if (!isTRUE(terra::compareGeom(
      uncertainty_raster, base, stopOnError = FALSE
    ))) {
      .ps_abort(
        "uncertainty must match support CRS, extent, origin, resolution, and dimensions; it is not resampled automatically.",
        "potentiomap_contour_uncertainty_error"
      )
    }
  } else if (uncertainty_active) {
    .ps_abort("Uncertainty thresholds require an uncertainty raster.",
              "potentiomap_contour_uncertainty_error")
  }
  if (!is.null(uncertainty_units) &&
      (!is.character(uncertainty_units) || length(uncertainty_units) != 1L ||
       is.na(uncertainty_units) || !nzchar(trimws(uncertainty_units)))) {
    .ps_abort("uncertainty_units must be one nonempty description or NULL.",
              "potentiomap_contour_uncertainty_error")
  }

  point_spacing <- if (distance_reference == "median_nearest_neighbor") {
    .median_nearest_neighbor(pts)
  } else NA_real_
  supported_distance_actual <- if (distance_active) {
    if (distance_reference == "median_nearest_neighbor") {
      supported_distance * point_spacing
    } else supported_distance
  } else NA_real_
  approximate_distance_actual <- if (distance_active) {
    if (distance_reference == "median_nearest_neighbor") {
      approximate_distance * point_spacing
    } else approximate_distance
  } else NA_real_

  nearest_r <- support$rasters[["nearest_observation_distance"]]
  nearest <- terra::values(nearest_r, mat = FALSE)
  inside_hull_r <- support$rasters[["inside_training_hull"]]
  inside_mask_r <- support$rasters[["inside_mask"]]
  finite_r <- support$rasters[["finite_prediction"]]
  inside_hull <- terra::values(inside_hull_r, mat = FALSE) == 1
  inside_mask <- terra::values(inside_mask_r, mat = FALSE) == 1
  finite_prediction <- terra::values(finite_r, mat = FALSE) == 1
  n_cells <- terra::ncell(base)

  neighbor_count_r <- NULL
  neighbor_count <- rep(NA_integer_, n_cells)
  neighbor_met <- rep(TRUE, n_cells)
  if (neighbor_active) {
    neighbor_count <- .local_neighbor_count(base, pts, neighbor_radius)
    neighbor_met <- neighbor_count >= minimum_neighbors
    neighbor_count_r <- base
    terra::values(neighbor_count_r) <- neighbor_count
    names(neighbor_count_r) <- "local_point_count"
  }

  uncertainty_values <- rep(NA_real_, n_cells)
  if (!is.null(uncertainty_raster)) {
    uncertainty_values <- terra::values(uncertainty_raster, mat = FALSE)
  }

  distance_code <- rep(1L, n_cells)
  if (distance_active) {
    distance_code <- ifelse(
      is.finite(nearest) & nearest <= supported_distance_actual, 1L,
      ifelse(is.finite(nearest) & nearest <= approximate_distance_actual, 2L, 3L)
    )
  }
  hull_code <- if (require_inside_hull) ifelse(inside_hull, 1L, 2L) else rep(1L, n_cells)
  neighbor_code <- if (neighbor_active) ifelse(neighbor_met, 1L, 2L) else rep(1L, n_cells)
  uncertainty_code <- rep(1L, n_cells)
  if (uncertainty_active) {
    uncertainty_code <- ifelse(
      is.finite(uncertainty_values) &
        uncertainty_values <= supported_uncertainty, 1L,
      ifelse(
        is.finite(uncertainty_values) &
          uncertainty_values <= approximate_uncertainty, 2L, 3L
      )
    )
  }
  hard_code <- ifelse(finite_prediction & inside_mask, 1L, 3L)
  primary <- switch(
    combine,
    distance = distance_code,
    uncertainty = uncertainty_code,
    worst = pmax(
      if (distance_active) distance_code else 1L,
      if (uncertainty_active) uncertainty_code else 1L
    )
  )
  class_code <- pmax(primary, hull_code, neighbor_code, hard_code)
  class_names <- c("supported", "approximate", "unsupported")
  reasons <- vapply(seq_len(n_cells), function(i) {
    .contour_cell_reason(
      i, distance_active, distance_code, require_inside_hull, inside_hull,
      neighbor_active, neighbor_met, uncertainty_active, uncertainty_code,
      finite_prediction, inside_mask, combine
    )
  }, character(1))
  combinations <- paste(class_code, reasons, sep = "|")
  combination_levels <- unique(combinations)
  combination_code <- match(combinations, combination_levels)

  class_r <- base
  terra::values(class_r) <- class_code
  names(class_r) <- "contour_support_code"
  combination_r <- base
  terra::values(combination_r) <- combination_code
  names(combination_r) <- "support_region_code"
  polygons <- terra::as.polygons(
    combination_r, dissolve = TRUE, values = TRUE, na.rm = TRUE
  )
  polygon_values <- terra::values(polygons)
  polygon_combo <- combination_levels[polygon_values$support_region_code]
  polygon_values$support_class <- class_names[
    as.integer(sub("\\|.*$", "", polygon_combo))
  ]
  polygon_values$classification_reason <- sub("^[^|]*\\|", "", polygon_combo)
  terra::values(polygons) <- polygon_values

  line_values <- terra::values(lines)
  line_values$contour_level <- line_values[[level_field]]
  line_values$source_contour_id <- .source_contour_ids(lines, line_values)
  terra::values(lines) <- line_values
  original_lengths <- as.numeric(terra::perim(lines))

  warnings <- list()
  add_warning <- function(message) {
    warnings[[length(warnings) + 1L]] <<- .ps_condition(
      message, "potentiomap_contour_support_warning", "warning"
    )
  }
  cell_diagonal <- sqrt(sum(terra::res(base)^2))
  if (length(original_lengths) && is.finite(stats::median(original_lengths)) &&
      cell_diagonal > stats::median(original_lengths) / 4) {
    add_warning(
      "Support raster resolution is coarse relative to contour length; solid-to-dashed transition locations may shift by about a cell."
    )
  }
  if (uncertainty_active && any(!is.finite(uncertainty_values))) {
    add_warning(
      "Some support cells have nonfinite uncertainty values and are classified unsupported where uncertainty criteria apply."
    )
  }

  segments_all <- tryCatch(
    terra::intersect(lines, polygons),
    error = function(e) .ps_abort(
      paste0("Could not split contours at support boundaries: ",
             conditionMessage(e)),
      "potentiomap_contour_support_error"
    )
  )
  if (!nrow(segments_all)) {
    add_warning(
      "No contour section overlaps the support raster extent; no classified segment was returned."
    )
    .emit_contour_support_warnings(warnings)
    out <- .empty_contour_support_result(
      lines, support, supported_distance, approximate_distance,
      supported_distance_actual, approximate_distance_actual,
      distance_reference, point_spacing, supported_uncertainty,
      approximate_uncertainty, require_inside_hull, neighbor_radius,
      minimum_neighbors, uncertainty_type, uncertainty_units, combine,
      minimum_segment_length, warnings, call
    )
    if (return == "segments") return(out$segments)
    return(out)
  }
  segment_lengths <- as.numeric(terra::perim(segments_all))
  positive <- is.finite(segment_lengths) & segment_lengths > 0
  segments_all <- segments_all[positive]
  segment_lengths <- segment_lengths[positive]
  values_all <- terra::values(segments_all)
  values_all$segment_id <- .segment_ids(segments_all, values_all$source_contour_id)
  values_all$classification_basis <- .contour_basis(
    combine, distance_active, require_inside_hull, neighbor_active,
    uncertainty_active
  )
  values_all$segment_length <- segment_lengths
  values_all$threshold_reference <- distance_reference
  values_all$line_type <- c(
    supported = "solid", approximate = "dashed", unsupported = "dotted"
  )[values_all$support_class]
  terra::values(segments_all) <- values_all

  stat_rasters <- c(nearest_r, inside_hull_r, finite_r, inside_mask_r)
  names(stat_rasters) <- c(
    "nearest_observation_distance", "inside_training_hull",
    "finite_prediction", "inside_mask"
  )
  if (neighbor_active) stat_rasters <- c(stat_rasters, neighbor_count_r)
  if (!is.null(uncertainty_raster)) {
    u <- uncertainty_raster
    names(u) <- "contour_uncertainty"
    stat_rasters <- c(stat_rasters, u)
  }
  stats_by_segment <- terra::extract(
    stat_rasters, segments_all, cells = TRUE, touches = TRUE
  )
  values_all <- terra::values(segments_all)
  segment_stats <- lapply(seq_len(nrow(segments_all)), function(i) {
    .contour_segment_stats(stats_by_segment[stats_by_segment$ID == i, ],
                           neighbor_active, !is.null(uncertainty_raster))
  })
  stats_frame <- do.call(rbind, segment_stats)
  values_all <- cbind(values_all, stats_frame)
  terra::values(segments_all) <- values_all

  retained <- segment_lengths >= minimum_segment_length
  if (!keep_unsupported) {
    retained <- retained & values_all$support_class != "unsupported"
  }
  summary <- .contour_support_summary(values_all, retained)
  segments <- segments_all[retained]
  if (!nrow(segments)) {
    add_warning("All contour sections were removed by the requested criteria.")
  } else if (all(terra::values(segments)$support_class == "unsupported")) {
    add_warning("All retained contour sections are classified unsupported.")
  } else if (!any(terra::values(segments)$support_class == "supported")) {
    add_warning("No retained contour section is classified supported.")
  }
  if (.has_single_cell_support_artifact(class_r)) {
    add_warning(
      "The support classification contains disconnected single-cell regions; inspect raster resolution and thresholds."
    )
  }

  thresholds <- list(
    supported_distance_supplied = supported_distance,
    approximate_distance_supplied = approximate_distance,
    supported_distance_actual = supported_distance_actual,
    approximate_distance_actual = approximate_distance_actual,
    distance_reference = distance_reference,
    median_nearest_neighbor = point_spacing,
    supported_uncertainty = supported_uncertainty,
    approximate_uncertainty = approximate_uncertainty
  )
  support_used <- list(
    source = support,
    classification_raster = class_r,
    support_region_raster = combination_r,
    region_lookup = data.frame(
      support_region_code = seq_along(combination_levels),
      support_class = class_names[
        as.integer(sub("\\|.*$", "", combination_levels))
      ],
      classification_reason = sub("^[^|]*\\|", "", combination_levels),
      stringsAsFactors = FALSE
    ),
    local_point_count = neighbor_count_r,
    uncertainty = uncertainty_raster
  )
  settings <- list(
    crs = terra::crs(base, proj = TRUE),
    distance_units = .projected_distance_units(base),
    classification_resolution = terra::res(base),
    hull_rule = if (require_inside_hull) {
      "outside hull cannot be supported but may be approximate"
    } else "training hull reported but not used for class assignment",
    neighbor_rule = if (neighbor_active) list(
      radius = neighbor_radius, minimum_neighbors = minimum_neighbors,
      count_basis = "unique observation locations"
    ) else NULL,
    uncertainty_rule = if (!is.null(uncertainty_raster)) list(
      source_name = names(uncertainty_raster)[1],
      type = uncertainty_type, units = uncertainty_units,
      supported_threshold = supported_uncertainty,
      approximate_threshold = approximate_uncertainty
    ) else NULL,
    combination_rule = combine,
    keep_unsupported = keep_unsupported,
    minimum_segment_length = minimum_segment_length,
    package_version = .package_version_string(),
    original_call = call
  )
  conditions <- .condition_table(warnings = warnings, method = "contour_support")
  out <- list(
    segments = segments, summary = summary, thresholds = thresholds,
    support = support_used, settings = settings, conditions = conditions
  )
  class(out) <- "potentiomap_contour_support"
  .emit_contour_support_warnings(warnings)
  if (return == "segments") return(segments)
  out
}

#' Plot classified contour support
#'
#' Draws supported sections as solid, approximate sections as dashed, and
#' optionally unsupported sections as dotted. Colors and line widths are not
#' assigned by the result and can be supplied through .... The title and
#' legend identify the classes as user-defined support criteria, not statistical
#' confidence.
#'
#' @param x A potentiomap_contour_support result.
#' @param show_unsupported Draw unsupported sections.
#' @param label_levels Label contour values where possible.
#' @param legend_position Base-graphics legend position, or NULL to omit it.
#' @param main Plot title.
#' @param ... Additional arguments passed to terra::plot().
#'
#' @return Invisibly returns x.
#' @export
plot.potentiomap_contour_support <- function(
    x, show_unsupported = TRUE, label_levels = FALSE,
    legend_position = "topright",
    main = "Contour support (user-defined criteria)", ...) {
  if (!inherits(x, "potentiomap_contour_support")) {
    .ps_abort("x must be a potentiomap_contour_support result.",
              "potentiomap_contour_support_error")
  }
  .contour_support_logical(show_unsupported, "show_unsupported")
  .contour_support_logical(label_levels, "label_levels")
  segments <- x$segments
  if (!nrow(segments)) {
    .ps_abort("No retained contour segments are available to plot.",
              "potentiomap_contour_support_error")
  }
  discard_device <- FALSE
  if (!interactive() && grDevices::dev.cur() == 1L) {
    grDevices::pdf(file = NULL)
    discard_device <- TRUE
    on.exit(if (discard_device) grDevices::dev.off(), add = TRUE)
  }
  classes <- c("supported", "approximate",
               if (show_unsupported) "unsupported")
  lty <- c(supported = 1, approximate = 2, unsupported = 3)
  dots <- list(...)
  dots[c("x", "lty", "add", "main")] <- NULL
  drawn <- character()
  for (class_name in classes) {
    keep <- terra::values(segments)$support_class == class_name
    if (!any(keep)) next
    args <- c(
      list(x = segments[keep], lty = unname(lty[class_name]),
           add = length(drawn) > 0L,
           main = if (!length(drawn)) main else ""),
      dots
    )
    do.call(terra::plot, args)
    if (label_levels) .label_contours(segments[keep])
    drawn <- c(drawn, class_name)
  }
  if (!is.null(legend_position) && length(drawn)) {
    graphics::legend(
      legend_position, legend = drawn, lty = unname(lty[drawn]),
      col = graphics::par("fg"), bty = "n", title = "User-defined support"
    )
  }
  invisible(x)
}

#' Export classified contour-support products
#'
#' Writes the classified line layer and optional CSV summaries. GeoPackage is
#' recommended because it preserves long field names more reliably than a
#' shapefile. The line_type field is a portable style suggestion; the support
#' class and reasons remain explicit attributes.
#'
#' @param x A potentiomap_contour_support result.
#' @param out_dir Output directory.
#' @param out_stub Safe output filename prefix.
#' @param vector_format "gpkg" or "shapefile".
#' @param write_summary,write_thresholds Write CSV sidecars.
#' @param overwrite Overwrite existing files.
#'
#' @return A data frame listing written products.
#' @export
#'
#' @examples
#' # See ps_contour_support() for classification. GeoPackage is recommended.
ps_export_contour_support <- function(
    x, out_dir, out_stub = "gw", vector_format = c("gpkg", "shapefile"),
    write_summary = TRUE, write_thresholds = TRUE, overwrite = TRUE) {
  vector_format <- match.arg(vector_format)
  if (!inherits(x, "potentiomap_contour_support")) {
    .ps_abort("x must be a potentiomap_contour_support result.",
              "potentiomap_contour_support_error")
  }
  if (!nrow(x$segments)) {
    .ps_abort("No contour-support segments are available to export.",
              "potentiomap_export_error")
  }
  if (!is.character(out_dir) || length(out_dir) != 1L || !nzchar(out_dir)) {
    .ps_abort("out_dir must be one nonempty path.",
              "potentiomap_export_error")
  }
  for (name in c("write_summary", "write_thresholds", "overwrite")) {
    .contour_support_logical(get(name), name)
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(out_dir)) {
    .ps_abort(sprintf("Could not create output directory %s.", out_dir),
              "potentiomap_export_error")
  }
  stub <- .safe_name(out_stub)
  extension <- if (vector_format == "gpkg") "gpkg" else "shp"
  vector_file <- file.path(
    out_dir, paste0(stub, "_contour_support.", extension)
  )
  summary_file <- file.path(out_dir, paste0(stub, "_contour_support_summary.csv"))
  threshold_file <- file.path(out_dir, paste0(stub, "_contour_support_thresholds.csv"))
  intended <- c(vector_file, if (write_summary) summary_file,
                if (write_thresholds) threshold_file)
  if (!overwrite && any(file.exists(intended))) {
    .ps_abort("Contour-support output exists and overwrite = FALSE.",
              "potentiomap_export_error")
  }
  written <- character()
  tryCatch({
    terra::writeVector(x$segments, vector_file, overwrite = overwrite)
    written <- c(written, vector_file)
    if (write_summary) {
      utils::write.csv(x$summary, summary_file, row.names = FALSE, na = "")
      written <- c(written, summary_file)
    }
    if (write_thresholds) {
      threshold_table <- data.frame(
        field = names(x$thresholds),
        value = vapply(x$thresholds, function(value) {
          if (is.null(value) || !length(value)) "" else paste(value, collapse = ";")
        }, character(1)),
        stringsAsFactors = FALSE
      )
      utils::write.csv(threshold_table, threshold_file,
                       row.names = FALSE, na = "")
      written <- c(written, threshold_file)
    }
  }, error = function(e) {
    .remove_export_files(written)
    .ps_abort(
      paste0("Could not export contour-support products: ",
             conditionMessage(e)),
      "potentiomap_export_error"
    )
  })
  data.frame(
    product = c("segments", if (write_summary) "summary",
                if (write_thresholds) "thresholds"),
    path = intended, stringsAsFactors = FALSE
  )
}

#' @export
print.potentiomap_contour_support <- function(x, ...) {
  cat("<potentiomap_contour_support>\n")
  cat("  retained segments:", nrow(x$segments), "\n")
  cat("  classification resolution:",
      paste(format(x$settings$classification_resolution), collapse = " x "),
      x$settings$distance_units, "\n")
  print(x$summary, row.names = FALSE)
  invisible(x)
}

.contour_support_logical <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    .ps_abort(sprintf("%s must be TRUE or FALSE.", name),
              "potentiomap_contour_support_error")
  }
  invisible(x)
}

.contour_threshold_pair <- function(supported, approximate,
                                    supported_name, approximate_name,
                                    error_class) {
  active <- !is.null(supported) || !is.null(approximate)
  if (!active) return(FALSE)
  if (is.null(supported) || is.null(approximate)) {
    .ps_abort(sprintf("Supply both %s and %s.",
                      supported_name, approximate_name), error_class)
  }
  values <- c(supported, approximate)
  if (!is.numeric(values) || length(values) != 2L ||
      anyNA(values) || any(!is.finite(values)) || any(values < 0)) {
    .ps_abort(
      sprintf("%s and %s must be finite nonnegative numbers.",
              supported_name, approximate_name),
      error_class
    )
  }
  if (approximate < supported) {
    .ps_abort(sprintf("%s must be greater than or equal to %s.",
                      approximate_name, supported_name), error_class)
  }
  TRUE
}

.contour_level_field <- function(x) {
  candidates <- c("contour_level", "level", "levels", "value", "elevation")
  fields <- names(terra::values(x))
  found <- candidates[candidates %in% fields]
  if (length(found)) found[1] else NULL
}

.median_nearest_neighbor <- function(points) {
  xy <- unique(as.data.frame(terra::crds(points, df = TRUE)))
  if (nrow(xy) < 2L) {
    .ps_abort(
      "At least two unique observation locations are required for median-nearest-neighbor thresholds.",
      "potentiomap_contour_threshold_error"
    )
  }
  distances <- as.matrix(stats::dist(xy))
  diag(distances) <- Inf
  nearest <- apply(distances, 1, min)
  spacing <- stats::median(nearest)
  if (!is.finite(spacing) || spacing <= 0) {
    .ps_abort("Median nearest-neighbor spacing is not positive and finite.",
              "potentiomap_contour_threshold_error")
  }
  spacing
}

.local_neighbor_count <- function(raster, points, radius) {
  xy <- terra::xyFromCell(raster, seq_len(terra::ncell(raster)))
  point_xy <- unique(as.data.frame(terra::crds(points, df = TRUE)))
  counts <- integer(nrow(xy))
  radius_squared <- radius^2
  for (i in seq_len(nrow(point_xy))) {
    counts <- counts + as.integer(
      (xy[, 1] - point_xy[i, 1])^2 +
        (xy[, 2] - point_xy[i, 2])^2 <= radius_squared
    )
  }
  counts
}

.contour_cell_reason <- function(
    i, distance_active, distance_code, require_inside_hull, inside_hull,
    neighbor_active, neighbor_met, uncertainty_active, uncertainty_code,
    finite_prediction, inside_mask, combine) {
  reason <- character()
  if (!finite_prediction[i]) reason <- c(reason, "prediction_unavailable")
  if (!inside_mask[i]) reason <- c(reason, "outside_mask")
  if (distance_active && combine %in% c("worst", "distance")) {
    reason <- c(reason, c("distance_supported", "distance_approximate",
                          "distance_unsupported")[distance_code[i]])
  }
  if (require_inside_hull && !inside_hull[i]) {
    reason <- c(reason, "outside_training_hull")
  }
  if (neighbor_active && !neighbor_met[i]) {
    reason <- c(reason, "minimum_local_neighbors_not_met")
  }
  if (uncertainty_active && combine %in% c("worst", "uncertainty")) {
    reason <- c(reason, c("uncertainty_supported", "uncertainty_approximate",
                          "uncertainty_unsupported")[uncertainty_code[i]])
  }
  if (!length(reason)) reason <- "active_criteria_supported"
  paste(reason, collapse = ";")
}

.contour_basis <- function(combine, distance_active, hull_active,
                           neighbor_active, uncertainty_active) {
  primary <- if (combine == "worst") {
    c(if (distance_active) "distance", if (uncertainty_active) "uncertainty")
  } else combine
  paste(c(primary, if (hull_active) "training_hull",
          if (neighbor_active) "local_neighbors",
          "finite_prediction", "analysis_mask"), collapse = ";")
}

.source_contour_ids <- function(lines, values) {
  candidates <- c("source_contour_id", "contour_id", "feature_id", "id", "ID")
  existing <- candidates[candidates %in% names(values)]
  if (length(existing)) {
    ids <- as.character(values[[existing[1]]])
    ids[is.na(ids) | !nzchar(ids)] <- "missing"
    if (!anyDuplicated(ids)) return(ids)
  }
  vapply(seq_len(nrow(lines)), function(i) {
    paste0("contour_", .geometry_hash(lines[i]))
  }, character(1))
}

.segment_ids <- function(lines, source_ids) {
  ids <- vapply(seq_len(nrow(lines)), function(i) {
    paste0(source_ids[i], "_segment_", .geometry_hash(lines[i]))
  }, character(1))
  if (anyDuplicated(ids)) ids <- make.unique(ids, sep = "_")
  ids
}

.geometry_hash <- function(x) {
  xy <- terra::crds(x, df = FALSE)
  text_value <- paste(format(as.numeric(t(xy)), digits = 16, scientific = FALSE,
                             trim = TRUE), collapse = ",")
  ints <- utf8ToInt(text_value)
  hash <- 0
  for (value in ints) hash <- (hash * 131 + value) %% 2147483629
  sprintf("%08x", as.integer(hash))
}

.contour_segment_stats <- function(x, neighbor_active, uncertainty_present) {
  finite_summary <- function(value, fun) {
    value <- value[is.finite(value)]
    if (length(value)) fun(value) else NA_real_
  }
  data.frame(
    nearest_distance_min = finite_summary(x$nearest_observation_distance, min),
    nearest_distance_mean = finite_summary(x$nearest_observation_distance, mean),
    nearest_distance_max = finite_summary(x$nearest_observation_distance, max),
    inside_hull_fraction = if (nrow(x)) mean(x$inside_training_hull == 1,
                                             na.rm = TRUE) else NA_real_,
    finite_support_fraction = if (nrow(x)) mean(x$finite_prediction == 1,
                                                na.rm = TRUE) else NA_real_,
    local_point_count_min = if (neighbor_active) {
      finite_summary(x$local_point_count, min)
    } else NA_real_,
    uncertainty_min = if (uncertainty_present) {
      finite_summary(x$contour_uncertainty, min)
    } else NA_real_,
    uncertainty_mean = if (uncertainty_present) {
      finite_summary(x$contour_uncertainty, mean)
    } else NA_real_,
    uncertainty_max = if (uncertainty_present) {
      finite_summary(x$contour_uncertainty, max)
    } else NA_real_,
    stringsAsFactors = FALSE
  )
}

.contour_support_summary <- function(values, retained) {
  rows <- data.frame(
    contour_level = values$contour_level,
    support_class = values$support_class,
    segment_count = 1L,
    total_line_length = values$segment_length,
    retained_line_length = ifelse(retained, values$segment_length, 0),
    removed_line_length = ifelse(retained, 0, values$segment_length),
    stringsAsFactors = FALSE
  )
  summary <- stats::aggregate(
    rows[c("segment_count", "total_line_length", "retained_line_length",
           "removed_line_length")],
    by = rows[c("contour_level", "support_class")], FUN = sum
  )
  order_class <- match(summary$support_class,
                       c("supported", "approximate", "unsupported"))
  summary[order(summary$contour_level, order_class), , drop = FALSE]
}

.projected_distance_units <- function(x) {
  units <- tryCatch(sf::st_crs(terra::crs(x))$units_gdal,
                    error = function(e) NULL)
  if (is.null(units) || is.na(units) || !nzchar(units)) "projected map units" else units
}

.has_single_cell_support_artifact <- function(class_r) {
  for (code in 1:3) {
    candidate <- terra::ifel(class_r == code, 1, NA)
    patches <- try(terra::patches(candidate, directions = 8), silent = TRUE)
    if (inherits(patches, "try-error")) next
    frequencies <- terra::freq(patches)
    if (!is.null(frequencies) && nrow(frequencies) && any(frequencies$count == 1L)) {
      return(TRUE)
    }
  }
  FALSE
}

.emit_contour_support_warnings <- function(warnings) {
  for (warning_condition in warnings) warning(warning_condition)
  invisible(NULL)
}

.empty_contour_support_result <- function(
    lines, support, supported_distance, approximate_distance,
    supported_distance_actual, approximate_distance_actual,
    distance_reference, point_spacing, supported_uncertainty,
    approximate_uncertainty, require_inside_hull, neighbor_radius,
    minimum_neighbors, uncertainty_type, uncertainty_units, combine,
    minimum_segment_length, warnings, call) {
  segments <- .empty_lines(terra::crs(lines))
  summary <- data.frame(
    contour_level = numeric(), support_class = character(),
    segment_count = integer(), total_line_length = numeric(),
    retained_line_length = numeric(), removed_line_length = numeric(),
    stringsAsFactors = FALSE
  )
  thresholds <- list(
    supported_distance_supplied = supported_distance,
    approximate_distance_supplied = approximate_distance,
    supported_distance_actual = supported_distance_actual,
    approximate_distance_actual = approximate_distance_actual,
    distance_reference = distance_reference,
    median_nearest_neighbor = point_spacing,
    supported_uncertainty = supported_uncertainty,
    approximate_uncertainty = approximate_uncertainty
  )
  settings <- list(
    crs = terra::crs(lines, proj = TRUE),
    distance_units = .projected_distance_units(lines),
    classification_resolution = terra::res(support$rasters[[1]]),
    hull_rule = require_inside_hull,
    neighbor_rule = list(radius = neighbor_radius,
                         minimum_neighbors = minimum_neighbors),
    uncertainty_rule = list(type = uncertainty_type, units = uncertainty_units),
    combination_rule = combine, keep_unsupported = TRUE,
    minimum_segment_length = minimum_segment_length,
    package_version = .package_version_string(), original_call = call
  )
  out <- list(
    segments = segments, summary = summary, thresholds = thresholds,
    support = list(source = support), settings = settings,
    conditions = .condition_table(warnings = warnings,
                                  method = "contour_support")
  )
  class(out) <- "potentiomap_contour_support"
  out
}
