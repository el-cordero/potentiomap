#' Smooth a potentiometric surface raster
#'
#' Applies a focal moving-window smoother to a potentiometric surface raster.
#' This can be useful when an interpolated surface is technically valid but too
#' locally rough for contour development or hydraulic-gradient visualization.
#'
#' @param surface A `terra::SpatRaster` potentiometric surface.
#' @param window_size Odd integer window size used when `weights` is `NULL`.
#' @param method Smoothing statistic. Supported values are `"mean"` and
#'   `"median"`.
#' @param weights Optional odd-dimension numeric matrix of focal weights.
#'   `NA` values in the matrix are ignored by `terra::focal()`.
#' @param iterations Number of smoothing passes.
#' @param na.rm Ignore missing values inside the focal window.
#' @param preserve_na Preserve the original `NA` footprint after smoothing.
#' @param filename Optional output raster filename.
#' @param overwrite Overwrite `filename` when it exists.
#'
#' @return A smoothed `terra::SpatRaster`.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' s <- ps_interpolate(pts, grid_res = 100)
#' smoothed <- ps_smooth_surface(s$TPS, window_size = 5)
#' smoothed
ps_smooth_surface <- function(surface, window_size = 3,
                              method = c("mean", "median"),
                              weights = NULL, iterations = 1,
                              na.rm = TRUE, preserve_na = TRUE,
                              filename = "", overwrite = FALSE) {
  method <- match.arg(method)
  .validate_integer(iterations, "iterations", lower = 0)
  iterations <- as.integer(iterations)

  if (!is.logical(na.rm) || length(na.rm) != 1L || is.na(na.rm) ||
      !is.logical(preserve_na) || length(preserve_na) != 1L || is.na(preserve_na) ||
      !is.logical(overwrite) || length(overwrite) != 1L || is.na(overwrite)) {
    .ps_abort("`na.rm`, `preserve_na`, and `overwrite` must be TRUE or FALSE.",
              "potentiomap_input_error")
  }

  if (is.null(weights)) {
    window_size <- as.integer(window_size)
    if (!is.finite(window_size) || window_size < 3 || window_size %% 2 == 0) {
      .ps_abort("`window_size` must be an odd integer of 3 or greater.",
                "potentiomap_input_error")
    }
    weights <- window_size
  } else {
    if (!is.matrix(weights) || !is.numeric(weights)) {
      .ps_abort("`weights` must be a numeric matrix.",
                "potentiomap_input_error")
    }
    if (any(dim(weights) %% 2 == 0)) {
      .ps_abort("`weights` must have odd row and column dimensions.",
                "potentiomap_input_error")
    }
  }

  original <- .as_surface(surface)
  result <- original
  for (i in seq_len(iterations)) {
    result <- terra::focal(
      result,
      w = weights,
      fun = method,
      na.rm = na.rm,
      na.policy = "all"
    )
  }
  if (preserve_na) {
    result <- terra::mask(result, original)
  }
  if (nzchar(filename)) {
    dir.create(dirname(filename), recursive = TRUE, showWarnings = FALSE)
    result <- tryCatch(
      terra::writeRaster(result, filename, overwrite = overwrite),
      error = function(e) .ps_abort(
        paste0("Could not write smoothed surface: ", conditionMessage(e)),
        "potentiomap_export_error"
      )
    )
  }
  names(result) <- names(original)
  result
}
