test_that("quicklooks write only when requested and handle empty overlays", {
  r <- make_plane("east")
  empty_contours <- suppressWarnings(ps_contours(r, levels = 100))
  empty_points <- terra::vect(
    data.frame(x = numeric(), y = numeric()), geom = c("x", "y"),
    crs = terra::crs(r)
  )
  expect_null(ps_quicklook(r, contours = empty_contours,
                           points = empty_points))
  file <- file.path(tempdir(), "potentiomap-quicklook.png")
  unlink(file)
  expect_identical(
    ps_quicklook(r, contours = empty_contours, points = empty_points,
                 file = file, contour_units = "m", label_points = FALSE),
    file
  )
  expect_true(file.exists(file))
  expect_gt(file.info(file)$size, 0)
  expect_error(ps_quicklook(r, file = file, overwrite = FALSE),
               class = "potentiomap_export_error")
})

test_that("surface exports include deterministic manifests and optional products", {
  pts <- make_test_points()
  result <- ps_interpolate(
    pts, methods = "IDW", grid_res = 300, return = "result",
    support = TRUE, support_max_distance = 1000
  )
  out <- file.path(tempdir(), "potentiomap-export-products")
  unlink(out, recursive = TRUE)
  manifest <- ps_export_surfaces(
    result, out, out_stub = "safe name", points = pts,
    vector_format = "gpkg", write_support = TRUE,
    write_diagnostics = TRUE
  )
  expect_equal(manifest$method, "IDW")
  expect_true(all(file.exists(unlist(manifest[1, -1]))))
  expect_true(file.exists(file.path(out, "safe_name_prediction_support.tif")))
  expect_true(file.exists(file.path(out, "safe_name_diagnostics.csv")))
  expect_true(file.exists(file.path(out, "safe_name_output_manifest.csv")))
  expect_error(
    ps_export_surfaces(result, out, out_stub = "safe name", overwrite = FALSE),
    class = "potentiomap_export_error"
  )
})

test_that("smoothing validates controls and preserves raster geometry", {
  r <- make_plane("east")
  r[1:4] <- NA
  smoothed <- ps_smooth_surface(r, window_size = 3, iterations = 2)
  expect_s4_class(smoothed, "SpatRaster")
  expect_true(terra::compareGeom(smoothed, r, stopOnError = FALSE))
  expect_true(all(is.na(terra::values(smoothed)[1:4])))
  expect_error(ps_smooth_surface(r, window_size = 4),
               class = "potentiomap_input_error")
  expect_error(ps_smooth_surface(r, weights = matrix(1, 2, 2)),
               class = "potentiomap_input_error")
  expect_error(ps_smooth_surface(r, iterations = 0),
               class = "potentiomap_input_error")
})

test_that("sample AOI is a projected polygon", {
  aoi <- ps_sample_aoi()
  expect_s4_class(aoi, "SpatVector")
  expect_equal(terra::geomtype(aoi), "polygons")
  expect_false(terra::is.lonlat(aoi))
})
