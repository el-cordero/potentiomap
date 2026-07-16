#' Structured potentiometric-surface result
#'
#' A `potentiomap_result` is the opt-in return from
#' `ps_interpolate(..., return = "result")`. It retains the ordinary named
#' surface list together with method diagnostics and processing context.
#'
#' Fields are:
#'
#' - `surfaces`: named `SpatRaster` list.
#' - `diagnostics`: method-attributed fit and prediction diagnostics.
#' - `method_parameters`: interpolation controls used for each method.
#' - `input_summary`: observation counts, metadata, and dropped records.
#' - `observation_count`: retained observation count.
#' - `dropped_records`: summary of excluded input records.
#' - `grid_geometry`: output dimensions, resolution, extent, and cell count.
#' - `crs`: output coordinate reference system.
#' - `mask_summary`: whether and how a mask was supplied.
#' - `support`: optional result from [ps_prediction_support()].
#' - `conditions`: captured warnings and messages by method.
#' - `package_version`: potentiomap version.
#' - `call`: original interpolation call.
#'
#' @name potentiomap_result
NULL

#' @export
print.potentiomap_result <- function(x, ...) {
  cat("<potentiomap_result>\n")
  cat("  observations:", x$observation_count, "\n")
  cat("  methods:", paste(names(x$surfaces), collapse = ", "), "\n")
  statuses <- vapply(x$diagnostics, function(z) z$return_status %||% "unknown",
                     character(1))
  cat("  status:", paste(paste0(names(statuses), "=", statuses),
                          collapse = ", "), "\n")
  if (!is.null(x$support)) cat("  prediction support: available\n")
  invisible(x)
}

#' @export
summary.potentiomap_result <- function(object, ...) {
  ranges <- lapply(object$surfaces, function(r) {
    z <- terra::values(r, mat = FALSE)
    z <- z[is.finite(z)]
    if (length(z)) c(minimum = min(z), maximum = max(z)) else c(minimum = NA, maximum = NA)
  })
  out <- list(
    observation_count = object$observation_count,
    methods = names(object$surfaces),
    surface_ranges = do.call(rbind, ranges),
    statuses = vapply(object$diagnostics,
                      function(z) z$return_status %||% "unknown", character(1)),
    condition_count = if (is.null(object$conditions)) 0L else nrow(object$conditions),
    support_summary = if (is.null(object$support)) NULL else object$support$summary
  )
  class(out) <- "summary.potentiomap_result"
  out
}

#' @export
print.summary.potentiomap_result <- function(x, ...) {
  cat("potentiomap interpolation summary\n")
  cat("  observations:", x$observation_count, "\n")
  cat("  methods:", paste(x$methods, collapse = ", "), "\n")
  print(x$surface_ranges)
  cat("  captured conditions:", x$condition_count, "\n")
  invisible(x)
}

#' Extract interpolation diagnostics
#'
#' @param x A `potentiomap_result`.
#' @param method Optional method name. When omitted, all method diagnostics are
#'   returned.
#'
#' @return A named diagnostic list, or one method-specific list.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' result <- ps_interpolate(pts, methods = "IDW", grid_res = 150,
#'                          return = "result")
#' ps_diagnostics(result, "IDW")
ps_diagnostics <- function(x, method = NULL) {
  if (!inherits(x, "potentiomap_result")) {
    .ps_abort("`x` must be a potentiomap_result.", "potentiomap_input_error")
  }
  if (is.null(method)) return(x$diagnostics)
  if (!is.character(method) || length(method) != 1L ||
      !method %in% names(x$diagnostics)) {
    .ps_abort(sprintf("No diagnostics are available for method `%s`.", method),
              "potentiomap_input_error")
  }
  x$diagnostics[[method]]
}

#' Extract interpolated surfaces
#'
#' @param x A `potentiomap_result` or named list of `SpatRaster` surfaces.
#'
#' @return A named list of `terra::SpatRaster` objects.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' result <- ps_interpolate(pts, methods = "IDW", grid_res = 150,
#'                          return = "result")
#' ps_surfaces(result)
ps_surfaces <- function(x) {
  if (inherits(x, "potentiomap_result")) return(x$surfaces)
  if (is.list(x) && length(x) && all(vapply(x, inherits, logical(1), "SpatRaster"))) {
    return(x)
  }
  .ps_abort("`x` must be a potentiomap_result or named SpatRaster list.",
            "potentiomap_input_error")
}
