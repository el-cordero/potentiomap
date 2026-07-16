#' Make groundwater observation points
#'
#' Converts a coordinate table, `sf` point object, or `terra` point vector to a
#' `SpatVector` with standard `Z` and `Name` fields. Optional unit and vertical
#' reference information is retained as package metadata; a horizontal CRS is
#' never interpreted as a vertical datum.
#'
#' @param data A data frame, `sf` object, or `terra::SpatVector` containing
#'   point observations.
#' @param x,y Coordinate column names for tabular data.
#' @param value Groundwater elevation column name.
#' @param name_col Optional well or station name column.
#' @param crs Coordinate reference system for tabular data, such as
#'   `"EPSG:26916"`.
#' @param metadata Optional named list containing scientific metadata.
#' @param head_unit Unit of `value`; accepted spellings represent metres or the
#'   international foot.
#' @param output_unit Desired unit of `Z`. When supplied with `head_unit`, values
#'   are converted using exactly 1 ft = 0.3048 m.
#' @param vertical_datum Documented vertical datum. It is recorded, not
#'   transformed.
#' @param surface_reference Measurement reference, such as `"land_surface"` or
#'   `"measuring_point"`.
#' @param metadata_mode One of `"legacy"`, `"warn"`, or `"strict"`. Legacy mode
#'   accepts numeric data without metadata; warning mode reports omissions;
#'   strict mode rejects them.
#' @param invalid_action Either `"drop"` to report and remove invalid records or
#'   `"error"` to stop.
#'
#' @return A point `terra::SpatVector` with standardized attributes and optional
#'   metadata available through [ps_metadata()]. The `dropped_records`
#'   attribute summarizes invalid observations.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(
#'   synthetic_wells,
#'   x = "x", y = "y",
#'   value = "gw_elevation",
#'   name_col = "well_id",
#'   crs = "EPSG:26916",
#'   head_unit = "m", output_unit = "m",
#'   vertical_datum = "synthetic example datum",
#'   surface_reference = "land_surface"
#' )
#' pts
ps_make_points <- function(data, x = "x", y = "y", value, name_col = NULL,
                           crs = NULL, metadata = NULL, head_unit = NULL,
                           output_unit = NULL, vertical_datum = NULL,
                           surface_reference = NULL,
                           metadata_mode = c("legacy", "warn", "strict"),
                           invalid_action = c("drop", "error")) {
  metadata_mode <- match.arg(metadata_mode)
  invalid_action <- match.arg(invalid_action)
  if (missing(value) || !is.character(value) || length(value) != 1L ||
      is.na(value) || !nzchar(value)) {
    .ps_abort("`value` must be one column name.", "potentiomap_input_error")
  }

  original_count <- if (is.data.frame(data)) nrow(data) else tryCatch(nrow(data), error = function(e) NA_integer_)
  invalid_reason <- character()

  if (inherits(data, "SpatVector")) {
    pts <- .as_points(data, "data")
  } else if (inherits(data, "sf")) {
    pts <- .as_points(terra::vect(data), "data")
  } else if (is.data.frame(data)) {
    needed <- c(x, y, value, if (!is.null(name_col)) name_col)
    missing_cols <- setdiff(needed, names(data))
    if (length(missing_cols)) {
      .ps_abort(
        paste0("Missing column(s): ", paste(missing_cols, collapse = ", "), "."),
        "potentiomap_input_error"
      )
    }
    if (is.null(crs)) {
      .ps_abort("`crs` is required when `data` is a coordinate table.",
                "potentiomap_crs_error")
    }
    df <- data
    x_num <- suppressWarnings(as.numeric(df[[x]]))
    y_num <- suppressWarnings(as.numeric(df[[y]]))
    z_num <- suppressWarnings(as.numeric(df[[value]]))
    reason <- rep(NA_character_, nrow(df))
    reason[!is.finite(x_num) | !is.finite(y_num)] <- "nonfinite_coordinate"
    reason[is.na(reason) & !is.finite(z_num)] <- "nonfinite_head"
    bad <- !is.na(reason)
    if (any(bad) && invalid_action == "error") {
      .ps_abort(
        sprintf("%d observation(s) have nonfinite coordinates or head values.", sum(bad)),
        "potentiomap_input_error",
        data = list(reason_counts = table(reason[bad]))
      )
    }
    if (any(bad)) invalid_reason <- reason[bad]
    df[[x]] <- x_num
    df[[y]] <- y_num
    df[[value]] <- z_num
    df <- df[!bad, , drop = FALSE]
    pts <- terra::vect(df, geom = c(x, y), crs = crs)
  } else {
    .ps_abort("`data` must be a data frame, sf object, or terra SpatVector.",
              "potentiomap_input_error")
  }

  .require_crs(pts, "data")
  vals <- terra::values(pts)
  if (!value %in% names(vals)) {
    .ps_abort(sprintf("Column `%s` was not found.", value),
              "potentiomap_input_error")
  }
  vals$Z <- suppressWarnings(as.numeric(vals[[value]]))
  if (is.null(name_col)) {
    vals$Name <- paste0("P", seq_len(nrow(vals)))
  } else {
    if (!name_col %in% names(vals)) {
      .ps_abort(sprintf("Column `%s` was not found.", name_col),
                "potentiomap_input_error")
    }
    vals$Name <- as.character(vals[[name_col]])
  }
  bad_z <- !is.finite(vals$Z)
  if (any(bad_z) && invalid_action == "error") {
    .ps_abort(sprintf("%d observation(s) have nonfinite head values.", sum(bad_z)),
              "potentiomap_input_error")
  }
  if (any(bad_z)) invalid_reason <- c(invalid_reason, rep("nonfinite_head", sum(bad_z)))
  terra::values(pts) <- vals
  if (any(bad_z)) pts <- pts[!bad_z]

  meta <- .prepare_direct_metadata(
    metadata, head_unit, output_unit, vertical_datum, surface_reference,
    metadata_mode
  )
  vals <- terra::values(pts)
  if (!is.null(meta$head_unit) && !is.null(meta$output_unit)) {
    vals$Z <- .convert_length(vals$Z, meta$head_unit, meta$output_unit)
    terra::values(pts) <- vals
  }
  dropped <- list(
    original_count = as.integer(original_count),
    retained_count = nrow(pts),
    dropped_count = length(invalid_reason),
    reason_counts = if (length(invalid_reason)) as.list(table(invalid_reason)) else list()
  )
  if (dropped$dropped_count > 0L) {
    .ps_warn(
      sprintf("Dropped %d invalid groundwater observation(s).", dropped$dropped_count),
      "potentiomap_input_warning",
      data = list(dropped_records = dropped)
    )
  }
  pts <- .attach_metadata(pts, meta)
  attr(pts, "dropped_records") <- dropped
  pts
}

#' Build potentiometric points from depth-to-water measurements
#'
#' Calculates groundwater elevation from land-surface elevation and a documented
#' depth convention. Surface elevation can come from a DEM, a column in the
#' depth table, or separate surface-elevation points. Separate points are
#' matched by name where possible and otherwise interpolated by IDW.
#'
#' With `depth_sign = "positive_down"`, groundwater elevation equals reference
#' elevation minus depth. With `depth_sign = "signed"`, a negative value denotes
#' water below the reference and is added to the reference elevation. A
#' measuring-point offset is added to land-surface elevation only when
#' `surface_reference = "measuring_point"`. potentiomap converts supported
#' units but does not transform vertical datums or guess measuring-point offsets.
#'
#' @param data Depth-to-water observations as a data frame, `sf`, or
#'   `terra::SpatVector`.
#' @param x,y Coordinate column names for tabular depth data.
#' @param depth_col Depth-to-water column name.
#' @param surface A DEM `SpatRaster`, separate surface-elevation observations,
#'   or `NULL` when `surface_col` is used.
#' @param surface_col Surface-elevation column in `data`, or in `surface` when
#'   `surface` is a point/table object.
#' @param name_col Optional name column in `data`.
#' @param surface_name_col Optional name column in separate surface observations.
#' @param crs CRS for tabular depth data.
#' @param idw_power Positive IDW power for unmatched surface points.
#' @param metadata Optional named list of scientific metadata.
#' @param depth_unit,surface_unit,output_unit Supported length units.
#' @param vertical_datum Documented vertical datum; it is recorded, not
#'   transformed.
#' @param surface_reference Either `"land_surface"` or `"measuring_point"`.
#' @param depth_sign Either `"positive_down"` or `"signed"`.
#' @param measuring_point_offset Height of the measuring point above land surface,
#'   expressed in `surface_unit`. It is not inferred.
#' @param metadata_mode One of `"legacy"`, `"warn"`, or `"strict"`.
#' @param invalid_action Either `"drop"` or `"error"`.
#'
#' @return A point `terra::SpatVector` with `surface_elevation`,
#'   `depth_to_water`, and `Z` in `output_unit`, plus metadata available through
#'   [ps_metadata()].
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' gw <- ps_potentiometric_points(
#'   synthetic_wells, "x", "y", "depth_to_water",
#'   surface_col = "surface_elevation", name_col = "well_id",
#'   crs = "EPSG:26916", depth_unit = "m", surface_unit = "m",
#'   output_unit = "m", vertical_datum = "synthetic example datum",
#'   surface_reference = "land_surface", depth_sign = "positive_down"
#' )
#' head(terra::values(gw))
ps_potentiometric_points <- function(data, x = "x", y = "y", depth_col,
                                     surface = NULL, surface_col = NULL,
                                     name_col = NULL,
                                     surface_name_col = name_col,
                                     crs = NULL, idw_power = 2,
                                     metadata = NULL, depth_unit = NULL,
                                     surface_unit = NULL, output_unit = NULL,
                                     vertical_datum = NULL,
                                     surface_reference = NULL,
                                     depth_sign = NULL,
                                     measuring_point_offset = NULL,
                                     metadata_mode = c("legacy", "warn", "strict"),
                                     invalid_action = c("drop", "error")) {
  metadata_mode <- match.arg(metadata_mode)
  invalid_action <- match.arg(invalid_action)
  .validate_number(idw_power, "idw_power", lower = 0)
  meta <- .prepare_depth_metadata(
    metadata, depth_unit, surface_unit, output_unit, vertical_datum,
    surface_reference, depth_sign, measuring_point_offset, metadata_mode
  )
  depth_pts <- ps_make_points(
    data = data, x = x, y = y, value = depth_col,
    name_col = name_col, crs = crs, metadata_mode = "legacy",
    invalid_action = invalid_action
  )
  vals <- terra::values(depth_pts)
  vals$depth_to_water <- vals$Z

  if (!is.null(surface_col) && surface_col %in% names(vals)) {
    vals$surface_elevation <- suppressWarnings(as.numeric(vals[[surface_col]]))
  } else if (inherits(surface, "SpatRaster") || inherits(surface, "PackedSpatRaster")) {
    if (inherits(surface, "PackedSpatRaster")) surface <- terra::rast(surface)
    surface <- .as_surface(surface)
    if (!.same_crs(surface, depth_pts)) {
      .ps_abort("`surface` and depth observations must use the same CRS.",
                "potentiomap_crs_error")
    }
    vals$surface_elevation <- as.numeric(
      terra::extract(surface, depth_pts, method = "bilinear")[[2]]
    )
  } else if (!is.null(surface)) {
    if (is.null(surface_col)) {
      .ps_abort("`surface_col` is required for separate surface observations.",
                "potentiomap_input_error")
    }
    surf_pts <- ps_make_points(
      surface, x = x, y = y, value = surface_col,
      name_col = surface_name_col, crs = crs,
      metadata_mode = "legacy", invalid_action = invalid_action
    )
    if (!.same_crs(surf_pts, depth_pts)) {
      .ps_abort("Surface and depth observations must use the same CRS.",
                "potentiomap_crs_error")
    }
    surf_vals <- terra::values(surf_pts)
    matched <- rep(NA_real_, nrow(vals))
    if (!is.null(name_col) && !is.null(surface_name_col)) {
      matched <- surf_vals$Z[match(vals$Name, surf_vals$Name)]
    }
    need_interp <- !is.finite(matched)
    if (any(need_interp)) {
      matched[need_interp] <- .predict_idw_to_points(
        surf_pts, depth_pts[need_interp], idw_power
      )
    }
    vals$surface_elevation <- matched
  } else {
    .ps_abort("Provide `surface`, or provide `surface_col` in `data`.",
              "potentiomap_input_error")
  }

  if (meta$depth_sign == "positive_down" && any(vals$depth_to_water < 0, na.rm = TRUE)) {
    .metadata_issue(
      "Negative depth values conflict with `depth_sign = \"positive_down\"`.",
      meta$metadata_mode
    )
  }
  target_unit <- meta$output_unit
  if (!is.null(target_unit) && !is.null(meta$surface_unit)) {
    vals$surface_elevation <- .convert_length(
      vals$surface_elevation, meta$surface_unit, target_unit
    )
  }
  if (!is.null(target_unit) && !is.null(meta$depth_unit)) {
    vals$depth_to_water <- .convert_length(
      vals$depth_to_water, meta$depth_unit, target_unit
    )
  }
  offset <- meta$measuring_point_offset
  if (!is.null(target_unit) && !is.null(meta$surface_unit)) {
    offset <- .convert_length(offset, meta$surface_unit, target_unit)
  }
  reference_elevation <- vals$surface_elevation
  if (meta$surface_reference == "measuring_point") {
    reference_elevation <- reference_elevation + offset
  }
  vals$Z <- if (meta$depth_sign == "positive_down") {
    reference_elevation - vals$depth_to_water
  } else {
    reference_elevation + vals$depth_to_water
  }
  keep <- is.finite(vals$surface_elevation) & is.finite(vals$depth_to_water) &
    is.finite(vals$Z)
  dropped_surface <- sum(!keep)
  if (dropped_surface && invalid_action == "error") {
    .ps_abort(
      sprintf("%d observation(s) lack finite surface elevation or groundwater head.",
              dropped_surface),
      "potentiomap_input_error"
    )
  }
  terra::values(depth_pts) <- vals
  depth_pts <- depth_pts[keep]
  if (dropped_surface) {
    .ps_warn(
      sprintf("Dropped %d observation(s) without a finite calculated head.",
              dropped_surface),
      "potentiomap_input_warning"
    )
  }
  depth_pts <- .attach_metadata(depth_pts, meta)
  attr(depth_pts, "dropped_records") <- list(
    original_count = length(keep), retained_count = sum(keep),
    dropped_count = dropped_surface,
    reason_counts = if (dropped_surface) list(nonfinite_calculated_head = dropped_surface) else list()
  )
  depth_pts
}

.predict_idw_to_points <- function(source_pts, target_pts, idw_power = 2) {
  if (!nrow(target_pts)) return(numeric())
  src <- sf::st_as_sf(source_pts)
  trg <- sf::st_as_sf(target_pts)
  model <- gstat::gstat(
    id = "Z", formula = Z ~ 1, data = src,
    set = list(idp = idw_power)
  )
  pred <- stats::predict(model, trg)
  pred_col <- if ("Z.pred" %in% names(pred)) "Z.pred" else {
    grep("\\.pred$", names(pred), value = TRUE)[1]
  }
  as.numeric(pred[[pred_col]])
}
