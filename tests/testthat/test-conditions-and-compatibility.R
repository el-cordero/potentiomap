test_that("important validation failures inherit stable parent classes", {
  d <- data.frame(x = 1:5, y = 1:5, z = 1:5)
  expect_error(ps_make_points(d, value = "missing", crs = "EPSG:3857"),
               class = "potentiomap_input_error")
  expect_error(ps_make_points(d, value = "z"),
               class = "potentiomap_crs_error")
  condition <- tryCatch(
    ps_make_points(d, value = "z", crs = "EPSG:3857",
                   metadata_mode = "strict"),
    error = identity
  )
  expect_s3_class(condition, "potentiomap_metadata_error")
  expect_s3_class(condition, "potentiomap_error")
})

test_that("all public accessors reject incompatible objects clearly", {
  expect_error(ps_surfaces(list()), class = "potentiomap_input_error")
  expect_error(ps_diagnostics(list()), class = "potentiomap_input_error")
  expect_null(ps_metadata(list()))
})

test_that("exported functions have help topics", {
  exports <- getNamespaceExports("potentiomap")
  topics <- c(
    ps_make_points = "ps_make_points", ps_potentiometric_points = "ps_potentiometric_points",
    ps_interpolate = "ps_interpolate", ps_interpolate_grouped = "ps_interpolate_grouped",
    ps_diagnostics = "ps_diagnostics", ps_surfaces = "ps_surfaces",
    ps_metadata = "ps_metadata", ps_prediction_support = "ps_prediction_support",
    ps_contours = "ps_contours", ps_contour_support = "ps_contour_support",
    ps_export_contour_support = "ps_export_contour_support",
    ps_flow_arrows = "ps_flow_arrows",
    ps_validate_arrows = "ps_validate_arrows", ps_arrow_vertices = "ps_arrow_vertices",
    ps_quicklook = "ps_quicklook", ps_export_surfaces = "ps_export_surfaces",
    ps_smooth_surface = "ps_smooth_surface", ps_sample_aoi = "ps_sample_aoi"
  )
  expect_setequal(exports, names(topics))
  for (topic in topics) {
    rd <- testthat::test_path("..", "..", "man", paste0(topic, ".Rd"))
    expect_true(file.exists(rd), info = topic)
  }
})
