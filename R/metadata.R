.normalize_length_unit <- function(unit, name, allow_null = TRUE) {
  if (is.null(unit) || !length(unit) || is.na(unit) || !nzchar(trimws(unit))) {
    if (allow_null) return(NULL)
    .ps_abort(sprintf("`%s` must specify a supported length unit.", name),
              "potentiomap_metadata_error")
  }
  key <- tolower(trimws(as.character(unit)[1]))
  metres <- c("m", "metre", "metres", "meter", "meters")
  feet <- c("ft", "foot", "feet", "international foot",
            "international-foot", "international feet")
  if (key %in% metres) return("m")
  if (key %in% feet) return("ft")
  .ps_abort(
    sprintf("Unsupported `%s` value `%s`; use m, metre, meter, ft, or international foot.",
            name, unit),
    "potentiomap_metadata_error"
  )
}

.convert_length <- function(x, from, to) {
  from <- .normalize_length_unit(from, "from", allow_null = FALSE)
  to <- .normalize_length_unit(to, "to", allow_null = FALSE)
  if (identical(from, to)) return(as.numeric(x))
  if (identical(from, "ft") && identical(to, "m")) return(as.numeric(x) * 0.3048)
  if (identical(from, "m") && identical(to, "ft")) return(as.numeric(x) / 0.3048)
  .ps_abort("Unsupported length-unit conversion.", "potentiomap_metadata_error")
}

.metadata_issue <- function(message, mode) {
  if (identical(mode, "strict")) {
    .ps_abort(message, "potentiomap_metadata_error")
  }
  if (identical(mode, "warn")) {
    .ps_warn(message, "potentiomap_metadata_warning")
  }
  invisible(NULL)
}

.metadata_mode <- function(mode) {
  match.arg(mode, c("legacy", "warn", "strict"))
}

.metadata_value <- function(explicit, metadata, name) {
  if (!is.null(explicit)) return(explicit)
  if (!is.null(metadata) && !is.null(metadata[[name]])) return(metadata[[name]])
  NULL
}

.attach_metadata <- function(x, metadata) {
  attr(x, "potentiomap_metadata") <- metadata
  x
}

#' Inspect scientific metadata
#'
#' Returns the length-unit, vertical-reference, measurement-reference, and
#' depth-sign information attached by [ps_make_points()] or
#' [ps_potentiometric_points()]. Structured interpolation results also retain
#' this information in their input summary.
#'
#' R-level attributes are not guaranteed to survive export to every GIS vector
#' format. Use an output manifest or sidecar table when these details must
#' accompany exported files. Matching units do not establish that two vertical
#' datums are compatible, and potentiomap does not transform vertical datums.
#'
#' @param x A potentiomap point object or structured result.
#'
#' @return A named list, or `NULL` when no metadata are attached.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(
#'   synthetic_wells, "x", "y", "gw_elevation", "well_id", "EPSG:26916",
#'   head_unit = "m", output_unit = "m", vertical_datum = "synthetic datum"
#' )
#' ps_metadata(pts)
ps_metadata <- function(x) {
  if (inherits(x, "potentiomap_result")) {
    return(x$input_summary$metadata)
  }
  attr(x, "potentiomap_metadata", exact = TRUE)
}

.prepare_direct_metadata <- function(metadata = NULL, head_unit = NULL,
                                     output_unit = NULL,
                                     vertical_datum = NULL,
                                     surface_reference = NULL,
                                     metadata_mode = "legacy") {
  mode <- .metadata_mode(metadata_mode)
  if (!is.null(metadata) && !is.list(metadata)) {
    .ps_abort("`metadata` must be a named list.", "potentiomap_metadata_error")
  }
  head_unit <- .metadata_value(head_unit, metadata, "head_unit")
  output_unit <- .metadata_value(output_unit, metadata, "output_unit")
  vertical_datum <- .metadata_value(vertical_datum, metadata, "vertical_datum")
  surface_reference <- .metadata_value(surface_reference, metadata,
                                       "surface_reference")
  if (is.null(head_unit)) .metadata_issue("Groundwater head unit is not supplied.", mode)
  if (is.null(vertical_datum)) .metadata_issue("Vertical datum is not supplied.", mode)
  if (is.null(surface_reference)) {
    .metadata_issue("Measurement or surface reference is not supplied.", mode)
  }
  if (!is.null(head_unit)) head_unit <- .normalize_length_unit(head_unit, "head_unit")
  if (is.null(output_unit)) output_unit <- head_unit
  if (!is.null(output_unit)) output_unit <- .normalize_length_unit(output_unit, "output_unit")
  list(
    head_unit = head_unit,
    output_unit = output_unit,
    vertical_datum = if (is.null(vertical_datum)) NULL else as.character(vertical_datum)[1],
    surface_reference = if (is.null(surface_reference)) NULL else as.character(surface_reference)[1],
    metadata_mode = mode
  )
}

.prepare_depth_metadata <- function(metadata = NULL, depth_unit = NULL,
                                    surface_unit = NULL, output_unit = NULL,
                                    vertical_datum = NULL,
                                    surface_reference = NULL,
                                    depth_sign = NULL,
                                    measuring_point_offset = NULL,
                                    metadata_mode = "legacy") {
  mode <- .metadata_mode(metadata_mode)
  if (!is.null(metadata) && !is.list(metadata)) {
    .ps_abort("`metadata` must be a named list.", "potentiomap_metadata_error")
  }
  depth_unit <- .metadata_value(depth_unit, metadata, "depth_unit")
  surface_unit <- .metadata_value(surface_unit, metadata, "surface_unit")
  output_unit <- .metadata_value(output_unit, metadata, "output_unit")
  vertical_datum <- .metadata_value(vertical_datum, metadata, "vertical_datum")
  surface_reference <- .metadata_value(surface_reference, metadata,
                                       "surface_reference")
  depth_sign <- .metadata_value(depth_sign, metadata, "depth_sign")
  measuring_point_offset <- .metadata_value(
    measuring_point_offset, metadata, "measuring_point_offset"
  )
  if (is.null(depth_unit)) .metadata_issue("Depth unit is not supplied.", mode)
  if (is.null(surface_unit)) .metadata_issue("Surface-elevation unit is not supplied.", mode)
  if (is.null(vertical_datum)) .metadata_issue("Vertical datum is not supplied.", mode)
  if (is.null(surface_reference)) .metadata_issue("Depth measurement reference is not supplied.", mode)
  if (is.null(depth_sign)) .metadata_issue("Depth sign convention is not supplied.", mode)

  if (is.null(depth_sign)) depth_sign <- "positive_down"
  depth_sign <- match.arg(depth_sign, c("positive_down", "signed"))
  if (is.null(surface_reference)) surface_reference <- "land_surface"
  surface_reference <- match.arg(
    surface_reference, c("land_surface", "measuring_point")
  )
  if (is.null(measuring_point_offset)) measuring_point_offset <- 0
  .validate_number(measuring_point_offset, "measuring_point_offset",
                   lower = -Inf, inclusive = TRUE, finite = TRUE)
  if (surface_reference == "land_surface" && measuring_point_offset != 0) {
    .metadata_issue(
      "A nonzero measuring-point offset conflicts with `surface_reference = \"land_surface\"`.",
      mode
    )
  }
  if (!is.null(depth_unit)) depth_unit <- .normalize_length_unit(depth_unit, "depth_unit")
  if (!is.null(surface_unit)) surface_unit <- .normalize_length_unit(surface_unit, "surface_unit")
  if (is.null(output_unit)) output_unit <- surface_unit %||% depth_unit
  if (!is.null(output_unit)) output_unit <- .normalize_length_unit(output_unit, "output_unit")
  if (!is.null(depth_unit) && !is.null(surface_unit) && is.null(output_unit)) {
    .metadata_issue("An output unit is required when input units differ.", mode)
  }
  list(
    depth_unit = depth_unit,
    surface_unit = surface_unit,
    output_unit = output_unit,
    vertical_datum = if (is.null(vertical_datum)) NULL else as.character(vertical_datum)[1],
    surface_reference = surface_reference,
    depth_sign = depth_sign,
    measuring_point_offset = as.numeric(measuring_point_offset),
    metadata_mode = mode,
    international_foot_metres = 0.3048
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x
