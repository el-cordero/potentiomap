test_that("depth to water can be converted using bundled DEM", {
  data("synthetic_wells", package = "potentiomap")
  data("synthetic_dem", package = "potentiomap")
  synthetic_dem <- terra::rast(synthetic_dem)

  pts <- ps_potentiometric_points(
    synthetic_wells,
    x = "x",
    y = "y",
    depth_col = "depth_to_water",
    surface = synthetic_dem,
    name_col = "well_id",
    crs = "EPSG:26916"
  )

  expect_s4_class(pts, "SpatVector")
  expect_equal(nrow(pts), nrow(synthetic_wells))
  expect_true(all(is.finite(terra::values(pts)$Z)))
})

test_that("IDW interpolation and contours produce spatial outputs", {
  data("synthetic_wells", package = "potentiomap")

  pts <- ps_make_points(
    synthetic_wells,
    x = "x",
    y = "y",
    value = "gw_elevation",
    name_col = "well_id",
    crs = "EPSG:26916"
  )
  surfaces <- ps_interpolate(pts, methods = "IDW", grid_res = 150)
  contours <- ps_contours(surfaces$IDW, interval = 1)

  expect_s4_class(surfaces$IDW, "SpatRaster")
  expect_s4_class(contours, "SpatVector")
  expect_gt(nrow(contours), 0)
})

test_that("flow arrows and vertices are generated", {
  data("synthetic_wells", package = "potentiomap")

  pts <- ps_make_points(
    synthetic_wells,
    x = "x",
    y = "y",
    value = "gw_elevation",
    name_col = "well_id",
    crs = "EPSG:26916"
  )
  surfaces <- ps_interpolate(pts, methods = "IDW", grid_res = 150)
  flow <- ps_flow_arrows(surfaces$IDW, res_factor = 4, scale = 50)
  tips <- ps_arrow_vertices(flow$arrows)

  expect_s4_class(flow$arrows, "SpatVector")
  expect_s4_class(tips, "SpatVector")
  expect_equal(nrow(tips), nrow(flow$arrows))
})
