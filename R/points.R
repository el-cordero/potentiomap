#' Make groundwater observation points
#'
#' Convert a coordinate table, `sf` point object, or `terra` vector to a
#' `SpatVector` with standard `Z` and `Name` fields.
#'
#' @param data A data frame, `sf` object, or `terra::SpatVector`.
#' @param x,y Coordinate column names for tabular data.
#' @param value Groundwater elevation column name.
#' @param name_col Optional well or station name column.
#' @param crs Coordinate reference system for tabular data, such as
#'   `"EPSG:26916"`.
#'
#' @return A point `terra::SpatVector` with standardized attributes.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(
#'   synthetic_wells,
#'   x = "x", y = "y",
#'   value = "gw_elevation",
#'   name_col = "well_id",
#'   crs = "EPSG:26916"
#' )
#' pts
ps_make_points <- function(data, x = "x", y = "y", value, name_col = NULL,
                           crs = NULL) {
  if (missing(value) || length(value) != 1) {
    stop("`value` must be one column name.", call. = FALSE)
  }

  if (inherits(data, "SpatVector")) {
    pts <- data
    if (terra::geomtype(pts) != "points") {
      stop("`data` must contain point geometries.", call. = FALSE)
    }
  } else if (inherits(data, "sf")) {
    pts <- terra::vect(data)
  } else if (is.data.frame(data)) {
    missing_cols <- setdiff(c(x, y, value, name_col), names(data))
    if (length(missing_cols) > 0) {
      stop("Missing column(s): ", paste(missing_cols, collapse = ", "),
           call. = FALSE)
    }
    if (is.null(crs)) {
      stop("`crs` is required when `data` is a coordinate table.",
           call. = FALSE)
    }
    df <- data
    df[[x]] <- suppressWarnings(as.numeric(df[[x]]))
    df[[y]] <- suppressWarnings(as.numeric(df[[y]]))
    df[[value]] <- suppressWarnings(as.numeric(df[[value]]))
    keep <- is.finite(df[[x]]) & is.finite(df[[y]]) & is.finite(df[[value]])
    df <- df[keep, , drop = FALSE]
    pts <- terra::vect(df, geom = c(x, y), crs = crs)
  } else {
    stop("`data` must be a data frame, sf object, or terra SpatVector.",
         call. = FALSE)
  }

  vals <- terra::values(pts)
  if (!value %in% names(vals)) {
    stop("Column `", value, "` was not found.", call. = FALSE)
  }
  vals$Z <- suppressWarnings(as.numeric(vals[[value]]))
  if (is.null(name_col)) {
    vals$Name <- paste0("P", seq_len(nrow(vals)))
  } else {
    if (!name_col %in% names(vals)) {
      stop("Column `", name_col, "` was not found.", call. = FALSE)
    }
    vals$Name <- as.character(vals[[name_col]])
  }
  terra::values(pts) <- vals
  pts <- pts[is.finite(terra::values(pts)$Z)]

  if (terra::crs(pts) == "" && !is.null(crs)) {
    terra::crs(pts) <- crs
  }
  if (terra::crs(pts) == "") {
    stop("Input points must have a coordinate reference system.", call. = FALSE)
  }
  pts
}

#' Build potentiometric points from depth-to-water measurements
#'
#' Calculates groundwater elevation as surface elevation minus depth to water.
#' Surface elevation can come from a DEM raster, a column in the depth table, or
#' separate surface-elevation points. Separate surface points are matched by name
#' when possible; otherwise their elevations are interpolated to the depth
#' points with inverse distance weighting.
#'
#' @param data Depth-to-water observations as a data frame, `sf`, or
#'   `terra::SpatVector`.
#' @param x,y Coordinate column names for tabular depth data.
#' @param depth_col Depth-to-water column name. Positive values are assumed to be
#'   depth below land surface.
#' @param surface A DEM `SpatRaster`, separate surface-elevation observations,
#'   or `NULL` when `surface_col` is used.
#' @param surface_col Surface-elevation column in `data`, or in `surface` when
#'   `surface` is a point/table object.
#' @param name_col Optional name column in `data`.
#' @param surface_name_col Optional name column in separate surface observations.
#' @param crs CRS for tabular depth data.
#' @param idw_power Power used when interpolating separate surface points.
#'
#' @return A point `terra::SpatVector` with `surface_elevation`,
#'   `depth_to_water`, and `Z` groundwater elevation fields.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' data("synthetic_dem")
#' gw <- ps_potentiometric_points(
#'   synthetic_wells,
#'   x = "x", y = "y",
#'   depth_col = "depth_to_water",
#'   surface = synthetic_dem,
#'   name_col = "well_id",
#'   crs = "EPSG:26916"
#' )
#' head(terra::values(gw))
ps_potentiometric_points <- function(data, x = "x", y = "y", depth_col,
                                     surface = NULL, surface_col = NULL,
                                     name_col = NULL,
                                     surface_name_col = name_col,
                                     crs = NULL, idw_power = 2) {
  depth_pts <- ps_make_points(
    data = data, x = x, y = y, value = depth_col,
    name_col = name_col, crs = crs
  )
  vals <- terra::values(depth_pts)
  vals$depth_to_water <- vals$Z

  if (!is.null(surface_col) && surface_col %in% names(vals)) {
    vals$surface_elevation <- suppressWarnings(as.numeric(vals[[surface_col]]))
  } else if (inherits(surface, "SpatRaster") ||
             inherits(surface, "PackedSpatRaster")) {
    if (inherits(surface, "PackedSpatRaster")) {
      surface <- terra::rast(surface)
    }
    extracted <- terra::extract(surface[[1]], depth_pts)[, 2]
    vals$surface_elevation <- as.numeric(extracted)
  } else if (!is.null(surface)) {
    surf_pts <- ps_make_points(
      surface, x = x, y = y, value = surface_col,
      name_col = surface_name_col, crs = crs
    )
    surf_vals <- terra::values(surf_pts)
    matched <- rep(NA_real_, nrow(vals))
    if (!is.null(name_col) && !is.null(surface_name_col)) {
      idx <- match(vals$Name, surf_vals$Name)
      matched <- surf_vals$Z[idx]
    }
    need_interp <- !is.finite(matched)
    if (any(need_interp)) {
      matched[need_interp] <- .predict_idw_to_points(
        surf_pts, depth_pts[need_interp], idw_power = idw_power
      )
    }
    vals$surface_elevation <- matched
  } else {
    stop("Provide `surface`, or provide `surface_col` in `data`.",
         call. = FALSE)
  }

  vals$Z <- vals$surface_elevation - vals$depth_to_water
  keep <- is.finite(vals$surface_elevation) & is.finite(vals$depth_to_water) &
    is.finite(vals$Z)
  terra::values(depth_pts) <- vals
  depth_pts[keep]
}

.predict_idw_to_points <- function(source_pts, target_pts, idw_power = 2) {
  src <- sf::st_as_sf(source_pts)
  trg <- sf::st_as_sf(target_pts)
  model <- gstat::gstat(
    id = "Z", formula = Z ~ 1, data = src,
    set = list(idp = idw_power)
  )
  pred <- stats::predict(model, trg)
  if ("Z.pred" %in% names(pred)) {
    return(as.numeric(pred$Z.pred))
  }
  pred_col <- grep("\\.pred$", names(pred), value = TRUE)[1]
  as.numeric(pred[[pred_col]])
}
