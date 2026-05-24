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

test_that("all interpolation methods return finite rasters", {
  data("synthetic_wells", package = "potentiomap")

  pts <- ps_make_points(
    synthetic_wells,
    x = "x",
    y = "y",
    value = "gw_elevation",
    name_col = "well_id",
    crs = "EPSG:26916"
  )

  surfaces <- suppressWarnings(ps_interpolate(
    pts,
    methods = c("IDW", "TPS", "OK", "UK"),
    grid_res = 150,
    mask = ps_sample_aoi(),
    padding = 150
  ))

  expect_named(surfaces, c("IDW", "TPS", "OK", "UK"))
  for (method in names(surfaces)) {
    expect_s4_class(surfaces[[method]], "SpatRaster")
    vals <- terra::values(surfaces[[method]], mat = FALSE)
    expect_true(any(is.finite(vals)), info = method)
  }
})

test_that("surface export writes rasters contours and quicklooks", {
  data("synthetic_wells", package = "potentiomap")

  pts <- ps_make_points(
    synthetic_wells,
    x = "x",
    y = "y",
    value = "gw_elevation",
    name_col = "well_id",
    crs = "EPSG:26916"
  )

  surfaces <- ps_interpolate(
    pts,
    methods = c("IDW", "TPS"),
    grid_res = 150,
    mask = ps_sample_aoi()
  )
  out_dir <- file.path(tempdir(), "potentiomap-test-export")
  outputs <- ps_export_surfaces(
    surfaces,
    points = pts,
    out_dir = out_dir,
    out_stub = "test",
    contour_interval = 1
  )

  expect_equal(nrow(outputs), 2)
  expect_true(all(file.exists(outputs$raster)))
  expect_true(all(file.exists(outputs$contours)))
  expect_true(all(file.exists(outputs$quicklook)))
  expect_true(all(file.info(outputs$quicklook)$size > 0))

  exported_raster <- terra::rast(outputs$raster[1])
  exported_contours <- terra::vect(outputs$contours[1])
  expect_true(any(is.finite(terra::values(exported_raster, mat = FALSE))))
  expect_gt(nrow(exported_contours), 0)
})

test_that("flow arrow export writes gradient products and vertices", {
  data("synthetic_wells", package = "potentiomap")

  pts <- ps_make_points(
    synthetic_wells,
    x = "x",
    y = "y",
    value = "gw_elevation",
    name_col = "well_id",
    crs = "EPSG:26916"
  )
  surfaces <- ps_interpolate(pts, methods = "TPS", grid_res = 150)
  out_dir <- file.path(tempdir(), "potentiomap-test-flow")
  flow <- ps_flow_arrows(
    surfaces$TPS,
    res_factor = 4,
    scale = 50,
    out_dir = out_dir,
    out_stub = "test_TPS"
  )

  hgrad_file <- file.path(out_dir, "test_TPS_hgrad.tif")
  arrow_file <- file.path(out_dir, "test_TPS_hgrad_arrows.shp")
  point_file <- file.path(out_dir, "test_TPS_hgrad_points.shp")
  tip_file <- file.path(out_dir, "test_TPS_arrow_tips.shp")
  base_file <- file.path(out_dir, "test_TPS_arrow_bases.shp")

  tips <- ps_arrow_vertices(flow$arrows, which = "last", out_file = tip_file)
  bases <- ps_arrow_vertices(flow$arrows, which = "first", out_file = base_file)

  expect_true(file.exists(hgrad_file))
  expect_true(file.exists(arrow_file))
  expect_true(file.exists(point_file))
  expect_true(file.exists(tip_file))
  expect_true(file.exists(base_file))

  hgrad <- terra::rast(hgrad_file)
  arrows <- terra::vect(arrow_file)
  expect_equal(names(hgrad), c("gwe", "igrad", "aspect"))
  expect_gt(nrow(arrows), 0)
  expect_equal(nrow(tips), nrow(arrows))
  expect_equal(nrow(bases), nrow(arrows))
})
