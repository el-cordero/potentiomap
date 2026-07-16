test_that("prediction support classifies hull, distance, mask, and missing cells", {
  pts <- make_test_points()
  surface <- ps_interpolate(pts, methods = "IDW", grid_res = 300)$IDW
  surface[1] <- NA
  mask <- ps_sample_aoi()
  support <- ps_prediction_support(
    pts, surface = surface, mask = mask, max_distance = 800
  )

  expect_s3_class(support, "potentiomap_support")
  expect_s4_class(support$rasters, "SpatRaster")
  expect_named(support, c("rasters", "lookup", "records", "summary",
                          "max_distance", "call"))
  expect_true(all(c(
    "supported", "outside_training_hull", "beyond_maximum_distance",
    "outside_mask", "prediction_unavailable", "multiple_limitations"
  ) %in% support$lookup$support_class))
  expect_equal(sum(support$summary$cells), terra::ncell(surface))
  expect_true(any(!support$records$finite_prediction))
  expect_output(print(support), "potentiomap_support")
})

test_that("support rejects CRS errors and geographic distances by default", {
  pts <- make_test_points()
  surface <- ps_interpolate(pts, methods = "IDW", grid_res = 300)$IDW
  wrong <- pts
  terra::crs(wrong) <- "EPSG:3857"
  expect_error(ps_prediction_support(wrong, surface = surface),
               class = "potentiomap_crs_error")

  geographic <- ps_make_points(
    data.frame(
      lon = c(-66.0, -65.9, -65.8, -65.7, -65.6),
      lat = c(18.0, 18.1, 18.05, 18.2, 18.15), head = 1:5
    ),
    x = "lon", y = "lat", value = "head", crs = "EPSG:4326"
  )
  geo_template <- terra::rast(ncols = 5, nrows = 5, extent = terra::ext(geographic),
                              crs = "EPSG:4326")
  expect_error(ps_prediction_support(geographic, template = geo_template),
               class = "potentiomap_crs_error")
  expect_warning(
    ps_prediction_support(geographic, template = geo_template,
                          allow_geographic = TRUE),
    class = "potentiomap_support_warning"
  )
})
