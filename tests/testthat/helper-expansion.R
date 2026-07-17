expansion_points <- function(n = 16L) {
  data("synthetic_wells", package = "potentiomap", envir = environment())
  ps_make_points(synthetic_wells[seq_len(n), ], "x", "y", "gw_elevation",
                 "well_id", "EPSG:26916")
}

expansion_raster <- function(values = 1:9) {
  terra::rast(nrows = 3, ncols = 3, xmin = 0, xmax = 300,
              ymin = 0, ymax = 300, crs = "EPSG:26920", vals = values)
}
