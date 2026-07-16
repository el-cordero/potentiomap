test_that("legacy and structured interpolation returns remain available", {
  pts <- make_test_points(metadata = TRUE)
  legacy <- ps_interpolate(pts, methods = "IDW", grid_res = 300)
  result <- ps_interpolate(
    pts, methods = "IDW", grid_res = 300, return = "result", support = TRUE
  )

  expect_type(legacy, "list")
  expect_named(legacy, "IDW")
  expect_s4_class(legacy$IDW, "SpatRaster")
  expect_s3_class(result, "potentiomap_result")
  expect_named(result, c(
    "surfaces", "diagnostics", "method_parameters", "input_summary",
    "observation_count", "dropped_records", "grid_geometry", "crs",
    "mask_summary", "support", "conditions", "package_version", "call"
  ))
  expect_identical(ps_surfaces(result), result$surfaces)
  expect_identical(ps_diagnostics(result, "IDW"), result$diagnostics$IDW)
  expect_s3_class(summary(result), "summary.potentiomap_result")
  expect_output(print(result), "observations")
  expect_output(print(summary(result)), "interpolation summary")
  expect_identical(ps_diagnostics(result), result$diagnostics)
  expect_identical(ps_surfaces(result$surfaces), result$surfaces)
  expect_error(ps_diagnostics(result, "missing"),
               class = "potentiomap_input_error")
})

test_that("method and grid controls fail with classed errors", {
  pts <- make_test_points()
  expect_error(ps_interpolate(pts, methods = "not-a-method", grid_res = 200),
               class = "potentiomap_input_error")
  expect_error(ps_interpolate(pts, methods = c("IDW", "IDW"), grid_res = 200),
               class = "potentiomap_input_error")
  expect_error(ps_interpolate(pts, methods = "IDW", grid_res = 0),
               class = "potentiomap_input_error")
  expect_error(ps_interpolate(pts, methods = "IDW", grid_res = 200,
                              idw_nmax = 0),
               class = "potentiomap_input_error")
})

test_that("duplicate-coordinate policies are explicit", {
  data("synthetic_wells", package = "potentiomap")
  d <- rbind(synthetic_wells[1:6, ], synthetic_wells[1, ])
  pts <- ps_make_points(d, "x", "y", "gw_elevation", "well_id", "EPSG:26916")
  expect_error(ps_interpolate(pts, methods = "IDW", grid_res = 300),
               class = "potentiomap_input_error")
  averaged <- NULL
  expect_warning(
    averaged <- ps_interpolate(pts, methods = "IDW", grid_res = 300,
                               duplicate_action = "mean", return = "result"),
    class = "potentiomap_input_warning"
  )
  expect_equal(averaged$observation_count, 6)
})

test_that("geographic distance calculations require an explicit override", {
  d <- data.frame(lon = c(-66, -65.9, -65.8, -65.7, -65.6),
                  lat = c(18, 18.1, 18.05, 18.2, 18.15), z = 1:5)
  pts <- ps_make_points(d, "lon", "lat", "z", crs = "EPSG:4326")
  expect_error(ps_interpolate(pts, methods = "IDW", grid_res = 0.02),
               class = "potentiomap_crs_error")
  expect_warning(
    ps_interpolate(pts, methods = "IDW", grid_res = 0.02,
                   allow_geographic = TRUE),
    class = "potentiomap_support_warning"
  )
})

test_that("custom methods retain identity and validate output geometry", {
  pts <- make_test_points()
  mean_head <- function(points, template, grid) {
    rep(mean(terra::values(points)$Z), terra::ncell(template))
  }
  result <- ps_interpolate(
    pts, methods = "mean_head", custom_methods = list(mean_head = mean_head),
    grid_res = 300, return = "result"
  )
  expect_named(result$surfaces, "mean_head")
  expect_equal(result$diagnostics$mean_head$returned_method, "mean_head")

  bad <- function(points, template, grid) numeric(2)
  expect_error(
    ps_interpolate(pts, methods = "bad", custom_methods = list(bad = bad),
                   grid_res = 300),
    class = "potentiomap_input_error"
  )
})
