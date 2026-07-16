#' potentiomap condition classes
#'
#' Important warnings and errors raised by potentiomap have stable S3 classes so
#' calling code can respond without matching the complete message text. All
#' package warnings inherit from `potentiomap_warning`; all package errors
#' inherit from `potentiomap_error`.
#'
#' Specific classes include `potentiomap_input_error`,
#' `potentiomap_metadata_error`, `potentiomap_crs_error`,
#' `potentiomap_arrow_endpoint_warning`,
#' `potentiomap_uk_instability_warning`,
#' `potentiomap_kriging_convergence_warning`,
#' `potentiomap_tps_gcv_boundary_warning`,
#' `potentiomap_contour_level_warning`, `potentiomap_support_warning`, and
#' `potentiomap_export_error`.
#'
#' @name potentiomap_conditions
#' @aliases potentiomap_warning potentiomap_error potentiomap_input_error
#'   potentiomap_metadata_error potentiomap_crs_error
#'   potentiomap_arrow_endpoint_warning potentiomap_uk_instability_warning
#'   potentiomap_kriging_convergence_warning
#'   potentiomap_tps_gcv_boundary_warning potentiomap_contour_level_warning
#'   potentiomap_support_warning potentiomap_export_error
NULL

.ps_condition <- function(message, class, type = c("error", "warning"),
                          call = NULL, data = list()) {
  type <- match.arg(type)
  parent <- if (type == "error") "potentiomap_error" else "potentiomap_warning"
  base <- if (type == "error") "error" else "warning"
  structure(
    c(list(message = as.character(message), call = call), data),
    class = unique(c(class, parent, base, "condition"))
  )
}

.ps_abort <- function(message, class = "potentiomap_input_error", call = NULL,
                      data = list()) {
  stop(.ps_condition(message, class, "error", call, data))
}

.ps_warn <- function(message, class, call = NULL, data = list(),
                     immediate. = FALSE) {
  condition <- .ps_condition(message, class, "warning", call, data)
  warning(condition)
}

.condition_record <- function(condition, method = NA_character_) {
  data.frame(
    method = method,
    type = if (inherits(condition, "warning")) "warning" else "message",
    class = class(condition)[1],
    text = conditionMessage(condition),
    stringsAsFactors = FALSE
  )
}

.validate_number <- function(x, name, lower = -Inf, inclusive = FALSE,
                             finite = TRUE) {
  valid <- is.numeric(x) && length(x) == 1L && !is.na(x)
  if (valid && finite) valid <- is.finite(x)
  if (valid) valid <- if (inclusive) x >= lower else x > lower
  if (!valid) {
    relation <- if (inclusive) "greater than or equal to" else "greater than"
    .ps_abort(
      sprintf("`%s` must be one finite number %s %s.", name, relation, lower),
      "potentiomap_input_error"
    )
  }
  invisible(x)
}

.validate_integer <- function(x, name, lower = 0L) {
  .validate_number(x, name, lower = lower, inclusive = FALSE)
  if (x != as.integer(x)) {
    .ps_abort(sprintf("`%s` must be an integer.", name),
              "potentiomap_input_error")
  }
  invisible(as.integer(x))
}

.as_surface <- function(surface, name = "surface") {
  r <- tryCatch(
    if (inherits(surface, "SpatRaster")) surface else terra::rast(surface),
    error = function(e) .ps_abort(
      sprintf("`%s` must be a readable terra SpatRaster.", name),
      "potentiomap_input_error",
      data = list(parent_message = conditionMessage(e))
    )
  )
  if (terra::nlyr(r) != 1L) {
    .ps_abort(sprintf("`%s` must contain exactly one raster layer.", name),
              "potentiomap_input_error")
  }
  r
}

.as_points <- function(x, name = "points") {
  pts <- tryCatch(
    if (inherits(x, "SpatVector")) x else terra::vect(x),
    error = function(e) .ps_abort(
      sprintf("`%s` must be point data readable by terra.", name),
      "potentiomap_input_error",
      data = list(parent_message = conditionMessage(e))
    )
  )
  if (terra::geomtype(pts) != "points") {
    .ps_abort(sprintf("`%s` must contain point geometries.", name),
              "potentiomap_input_error")
  }
  pts
}

.require_crs <- function(x, name = "input") {
  if (!nzchar(terra::crs(x))) {
    .ps_abort(sprintf("`%s` must have a coordinate reference system.", name),
              "potentiomap_crs_error")
  }
  invisible(x)
}

.require_projected <- function(x, name = "input", allow_geographic = FALSE) {
  .require_crs(x, name)
  if (terra::is.lonlat(x)) {
    message <- paste0(
      "`", name, "` uses longitude/latitude coordinates. Distance-based ",
      "calculations require a projected CRS because degrees are not linear ",
      "ground-distance units."
    )
    if (!isTRUE(allow_geographic)) {
      .ps_abort(message, "potentiomap_crs_error")
    }
    .ps_warn(message, "potentiomap_support_warning")
  }
  invisible(x)
}

.same_crs <- function(x, y) {
  isTRUE(terra::same.crs(x, y))
}

.safe_name <- function(x) {
  x <- gsub("[^A-Za-z0-9._-]+", "_", as.character(x))
  x <- gsub("^_+|_+$", "", x)
  ifelse(nzchar(x), x, "output")
}

.empty_lines <- function(crs = "") {
  x <- terra::vect("LINESTRING EMPTY", crs = crs)
  x[0]
}

.empty_points <- function(crs = "") {
  terra::vect(
    data.frame(x = numeric(), y = numeric()),
    geom = c("x", "y"), crs = crs
  )
}

.package_version_string <- function() {
  tryCatch(as.character(utils::packageVersion("potentiomap")),
           error = function(e) "0.2.0")
}
