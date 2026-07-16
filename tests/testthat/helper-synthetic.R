make_test_points <- function(metadata = FALSE) {
  data("synthetic_wells", package = "potentiomap")
  args <- list(
    data = synthetic_wells, x = "x", y = "y", value = "gw_elevation",
    name_col = "well_id", crs = "EPSG:26916"
  )
  if (metadata) {
    args <- c(args, list(
      head_unit = "m", output_unit = "m",
      vertical_datum = "synthetic example datum",
      surface_reference = "land_surface", metadata_mode = "strict"
    ))
  }
  do.call(ps_make_points, args)
}

make_plane <- function(direction = c("east", "west", "north", "south"),
                       n = 20L) {
  direction <- match.arg(direction)
  r <- terra::rast(ncols = n, nrows = n, xmin = 0, xmax = n,
                   ymin = 0, ymax = n, crs = "EPSG:3857")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  terra::values(r) <- switch(
    direction,
    east = -xy[, 1], west = xy[, 1],
    north = -xy[, 2], south = xy[, 2]
  )
  names(r) <- "head"
  r
}

make_curved_surface <- function(n = 40L) {
  r <- terra::rast(ncols = n, nrows = n, xmin = 0, xmax = n,
                   ymin = 0, ymax = n, crs = "EPSG:3857")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  terra::values(r) <- (xy[, 1] - n / 2)^2 + (xy[, 2] - n / 2)^2
  names(r) <- "head"
  r
}

make_contour_support_fixture <- function() {
  surface <- terra::rast(
    ncols = 30, nrows = 10, xmin = 0, xmax = 3000,
    ymin = 0, ymax = 1000, crs = "EPSG:3857"
  )
  terra::values(surface) <- 1
  names(surface) <- "head"
  points <- terra::vect(
    data.frame(
      x = c(400, 600, 600, 400),
      y = c(400, 400, 600, 600), Z = c(10, 10, 10, 10)
    ),
    geom = c("x", "y"), crs = "EPSG:3857"
  )
  support <- ps_prediction_support(points, surface = surface)
  contour <- function(xmin = 0, xmax = 3000, level = 10,
                      contour_id = "c1", y = 500) {
    line <- terra::vect(
      list(rbind(c(xmin, y), c(xmax, y))),
      type = "lines", crs = terra::crs(surface)
    )
    terra::values(line) <- data.frame(
      level = level, contour_id = contour_id, stringsAsFactors = FALSE
    )
    line
  }
  list(surface = surface, points = points, support = support, contour = contour)
}
