#' Describe prediction support and extrapolation
#'
#' Classifies raster cells using the training-point convex hull, distance to the
#' nearest observation, an optional maximum distance, mask membership, and
#' finite prediction availability. The convex hull is a training-network
#' geometry, not an aquifer boundary. Predictions are described, not removed.
#'
#' Distance calculations require projected coordinates by default. An explicit
#' override reports that longitude/latitude degrees are not linear ground units.
#'
#' @param points Training observations as a point `SpatVector`, `sf` object, or
#'   object readable by `terra::vect()`.
#' @param surface Optional one-layer prediction `SpatRaster`.
#' @param template Optional one-layer template when `surface` is not supplied.
#' @param mask Optional polygon mask used to classify cells.
#' @param max_distance Optional positive distance threshold in projected map
#'   units.
#' @param allow_geographic Allow longitude/latitude calculations with a classed
#'   warning. The default is `FALSE`.
#'
#' @return A `potentiomap_support` list containing `rasters`, a reason-code
#'   `lookup` table, a cell-level `records` table, `summary`, and `call`.
#'   Stable support classes are `supported`, `outside_training_hull`,
#'   `beyond_maximum_distance`, `outside_mask`, `prediction_unavailable`, and
#'   `multiple_limitations`.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' surface <- ps_interpolate(pts, methods = "IDW", grid_res = 200)$IDW
#' support <- ps_prediction_support(pts, surface = surface,
#'                                  max_distance = 1000)
#' support$summary
ps_prediction_support <- function(points, surface = NULL, template = NULL,
                                  mask = NULL, max_distance = NULL,
                                  allow_geographic = FALSE) {
  call <- match.call()
  pts <- .as_points(points)
  .require_projected(pts, "points", allow_geographic)
  if (nrow(pts) < 1L) {
    .ps_abort("At least one observation is required.", "potentiomap_input_error")
  }
  if (!is.null(max_distance)) {
    .validate_number(max_distance, "max_distance", lower = 0)
  }
  r <- if (!is.null(surface)) .as_surface(surface) else if (!is.null(template)) {
    .as_surface(template, "template")
  } else {
    .ps_abort("Supply `surface` or `template`.", "potentiomap_input_error")
  }
  .require_crs(r, "surface or template")
  if (!.same_crs(pts, r)) {
    .ps_abort("`points` and the raster must use the same CRS.",
              "potentiomap_crs_error")
  }
  base <- r
  terra::values(base) <- NA_real_
  hull <- terra::convHull(pts)
  hull_r <- terra::rasterize(hull, base, field = 1, background = 0,
                             touches = TRUE)
  names(hull_r) <- "inside_training_hull"

  nearest <- terra::distance(base, pts)
  names(nearest) <- "nearest_observation_distance"
  nearest_values <- terra::values(nearest, mat = FALSE)

  if (is.null(mask)) {
    mask_r <- base
    terra::values(mask_r) <- 1
  } else {
    m <- tryCatch(if (inherits(mask, "SpatVector")) mask else terra::vect(mask),
                  error = function(e) .ps_abort(
                    "`mask` must be a polygon object readable by terra.",
                    "potentiomap_input_error",
                    data = list(parent_message = conditionMessage(e))
                  ))
    if (terra::geomtype(m) != "polygons") {
      .ps_abort("`mask` must contain polygon geometry.", "potentiomap_input_error")
    }
    if (!.same_crs(m, r)) {
      .ps_abort("`mask` and the raster must use the same CRS.",
                "potentiomap_crs_error")
    }
    mask_r <- terra::rasterize(m, base, field = 1, background = 0,
                               touches = TRUE)
  }
  names(mask_r) <- "inside_mask"

  finite_r <- base
  finite_prediction <- if (is.null(surface)) rep(TRUE, terra::ncell(base)) else {
    is.finite(terra::values(r, mat = FALSE))
  }
  terra::values(finite_r) <- as.integer(finite_prediction)
  names(finite_r) <- "finite_prediction"

  distance_r <- base
  within_distance <- if (is.null(max_distance)) {
    rep(TRUE, terra::ncell(base))
  } else {
    is.finite(nearest_values) & nearest_values <= max_distance
  }
  terra::values(distance_r) <- as.integer(within_distance)
  names(distance_r) <- "within_maximum_distance"

  inside_hull <- terra::values(hull_r, mat = FALSE) == 1
  inside_mask <- terra::values(mask_r, mat = FALSE) == 1
  limitations <- Map(function(hull_ok, distance_ok, mask_ok, prediction_ok) {
    x <- character()
    if (!hull_ok) x <- c(x, "outside_training_hull")
    if (!distance_ok) x <- c(x, "beyond_maximum_distance")
    if (!mask_ok) x <- c(x, "outside_mask")
    if (!prediction_ok) x <- c(x, "prediction_unavailable")
    x
  }, inside_hull, within_distance, inside_mask, finite_prediction)
  support_class <- vapply(limitations, function(x) {
    if (!length(x)) "supported" else if (length(x) == 1L) x else "multiple_limitations"
  }, character(1))
  reasons <- vapply(limitations, function(x) {
    if (!length(x)) "supported" else paste(x, collapse = ";")
  }, character(1))
  stable_classes <- c(
    "supported", "outside_training_hull", "beyond_maximum_distance",
    "outside_mask", "prediction_unavailable", "multiple_limitations"
  )
  code <- match(support_class, stable_classes)
  class_r <- base
  terra::values(class_r) <- code
  names(class_r) <- "support_class_code"
  lookup <- data.frame(code = seq_along(stable_classes),
                       support_class = stable_classes,
                       stringsAsFactors = FALSE)
  records <- data.frame(
    cell = seq_len(terra::ncell(base)),
    inside_training_hull = inside_hull,
    nearest_observation_distance = nearest_values,
    within_maximum_distance = within_distance,
    inside_mask = inside_mask,
    finite_prediction = finite_prediction,
    support_class = support_class,
    support_reason = reasons,
    stringsAsFactors = FALSE
  )
  counts <- table(factor(support_class, levels = stable_classes))
  summary <- data.frame(
    support_class = stable_classes,
    cells = as.integer(counts),
    percent = 100 * as.integer(counts) / nrow(records),
    stringsAsFactors = FALSE
  )
  out <- list(
    rasters = c(hull_r, nearest, distance_r, mask_r, finite_r, class_r),
    lookup = lookup,
    records = records,
    summary = summary,
    max_distance = max_distance,
    call = call
  )
  class(out) <- "potentiomap_support"
  out
}

#' @export
print.potentiomap_support <- function(x, ...) {
  cat("<potentiomap_support>\n")
  print(x$summary, row.names = FALSE)
  invisible(x)
}
