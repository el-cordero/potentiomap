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
  iterations <- as.integer(iterations)
  if (!is.finite(iterations) || iterations < 1) {
    stop("`iterations` must be a positive integer.", call. = FALSE)
  }

  if (is.null(weights)) {
    window_size <- as.integer(window_size)
    if (!is.finite(window_size) || window_size < 3 || window_size %% 2 == 0) {
      stop("`window_size` must be an odd integer of 3 or greater.",
           call. = FALSE)
    }
    weights <- window_size
  } else {
    if (!is.matrix(weights) || !is.numeric(weights)) {
      stop("`weights` must be a numeric matrix.", call. = FALSE)
    }
    if (any(dim(weights) %% 2 == 0)) {
      stop("`weights` must have odd row and column dimensions.", call. = FALSE)
    }
  }

  original <- if (inherits(surface, "SpatRaster")) surface else terra::rast(surface)
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
    result <- terra::writeRaster(result, filename, overwrite = overwrite)
  }
  names(result) <- names(original)
  result
}
