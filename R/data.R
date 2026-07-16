#' Synthetic groundwater monitoring wells
#'
#' A small artificial monitoring dataset with coordinates, land-surface
#' elevation, positive depth below land surface, and calculated groundwater
#' elevation. Elevations and depths are synthetic metres relative to a
#' synthetic example datum.
#'
#' @format A data frame with 32 rows and 6 columns:
#' \describe{
#'   \item{well_id}{Synthetic well identifier.}
#'   \item{x}{Synthetic easting in EPSG:26916 metres.}
#'   \item{y}{Synthetic northing in EPSG:26916 metres.}
#'   \item{surface_elevation}{Synthetic land-surface elevation in metres.}
#'   \item{depth_to_water}{Positive depth below land surface in metres.}
#'   \item{gw_elevation}{Synthetic groundwater elevation in metres.}
#' }
#' @examples
#' data("synthetic_wells")
#' head(synthetic_wells)
"synthetic_wells"

#' Synthetic DEM raster
#'
#' A small artificial DEM matching `synthetic_wells`, stored as a packed
#' `terra` raster. Use `terra::rast(synthetic_dem)` to unpack it.
#'
#' @format A `terra::PackedSpatRaster` with one layer named
#'   `surface_elevation`.
#' @examples
#' data("synthetic_dem")
#' dem <- terra::rast(synthetic_dem)
#' dem
"synthetic_dem"

#' Synthetic surface elevation measurement points
#'
#' Artificial land-surface elevation points for analyses that do not start with
#' a DEM raster.
#'
#' @format A data frame with coordinate, surface-elevation, and name columns.
#' @examples
#' data("synthetic_surface_points")
#' head(synthetic_surface_points)
"synthetic_surface_points"

#' Make the sample area-of-interest polygon
#'
#' @return A `terra::SpatVector` polygon in EPSG:26916. Coordinates are
#'   synthetic and expressed in metres.
#' @export
#'
#' @examples
#' aoi <- ps_sample_aoi()
#' aoi
ps_sample_aoi <- function() {
  xy <- rbind(
    c(500150, 4640100),
    c(503000, 4640200),
    c(503400, 4642650),
    c(500450, 4643000),
    c(499850, 4641400),
    c(500150, 4640100)
  )
  terra::vect(list(xy), type = "polygons", crs = "EPSG:26916")
}
