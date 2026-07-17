test_that("contour-support input contracts identify incomplete criteria", {
  f <- make_contour_support_fixture()
  line <- f$contour()
  thresholds <- list(supported_distance = 300, approximate_distance = 1000)

  polygon <- terra::as.polygons(f$surface > -Inf, dissolve = TRUE)
  terra::values(polygon) <- data.frame(level = 10)
  expect_error(
    do.call(ps_contour_support, c(list(contours = polygon, support = f$support),
                                  thresholds)),
    class = "potentiomap_error"
  )
  expect_error(
    ps_contour_support(line, support = f$support, neighbor_radius = 250,
                       supported_distance = 300, approximate_distance = 1000),
    class = "potentiomap_contour_threshold_error"
  )
  expect_error(
    ps_contour_support(line, support = f$support, combine = "distance"),
    class = "potentiomap_contour_threshold_error"
  )
  expect_error(
    ps_contour_support(line, support = f$support, combine = "uncertainty"),
    class = "potentiomap_contour_uncertainty_error"
  )
  expect_error(
    do.call(ps_contour_support, c(list(contours = line), thresholds)),
    class = "potentiomap_contour_support_error"
  )
  expect_error(
    do.call(ps_contour_support, c(list(contours = line, support = list()),
                                  thresholds)),
    class = "potentiomap_contour_support_error"
  )

  incomplete <- f$support
  incomplete$rasters <- incomplete$rasters[["nearest_observation_distance"]]
  class(incomplete) <- "potentiomap_support"
  expect_error(
    do.call(ps_contour_support, c(list(contours = line, support = incomplete),
                                  thresholds)),
    class = "potentiomap_contour_support_error"
  )

  coarse <- terra::aggregate(f$surface, fact = 2)
  expect_error(
    do.call(ps_contour_support, c(list(contours = line, support = f$support,
                                       surface = coarse), thresholds)),
    class = "potentiomap_contour_support_error"
  )
  empty <- f$points[0]
  expect_error(
    do.call(ps_contour_support, c(list(contours = line, support = f$support,
                                       points = empty), thresholds)),
    class = "potentiomap_error"
  )
  other_crs <- f$points
  terra::crs(other_crs) <- "EPSG:26916"
  expect_error(
    do.call(ps_contour_support, c(list(contours = line, support = f$support,
                                       points = other_crs), thresholds)),
    class = "potentiomap_contour_support_error"
  )
  no_points <- f$support
  no_points$points <- NULL
  expect_error(
    ps_contour_support(line, support = no_points,
                       supported_distance = 1, approximate_distance = 2,
                       distance_reference = "median_nearest_neighbor"),
    class = "potentiomap_contour_support_error"
  )
})

test_that("uncertainty and threshold contracts fail before classification", {
  f <- make_contour_support_fixture()
  line <- f$contour()
  uncertainty <- f$surface
  terra::values(uncertainty) <- seq_len(terra::ncell(uncertainty))

  expect_error(
    ps_contour_support(line, support = f$support, uncertainty = uncertainty,
                       supported_uncertainty = 10,
                       approximate_uncertainty = 20,
                       combine = "uncertainty"),
    class = "potentiomap_contour_uncertainty_error"
  )
  expect_error(
    ps_contour_support(line, support = f$support,
                       supported_uncertainty = 10,
                       approximate_uncertainty = 20,
                       combine = "uncertainty"),
    class = "potentiomap_contour_uncertainty_error"
  )
  expect_error(
    ps_contour_support(line, support = f$support,
                       supported_distance = 100,
                       approximate_distance = NULL),
    class = "potentiomap_contour_threshold_error"
  )
  expect_error(
    ps_contour_support(line, support = f$support,
                       supported_distance = -1, approximate_distance = 2),
    class = "potentiomap_contour_threshold_error"
  )
  expect_error(
    ps_contour_support(line, support = f$support,
                       supported_distance = 100, approximate_distance = 200,
                       uncertainty_units = ""),
    class = "potentiomap_contour_uncertainty_error"
  )
  expect_error(
    ps_contour_support(line, support = f$support,
                       supported_distance = 100, approximate_distance = 200,
                       keep_unsupported = NA),
    class = "potentiomap_contour_support_error"
  )

  one_location <- f$points[1]
  expect_error(
    ps_contour_support(line, points = one_location, surface = f$surface,
                       supported_distance = 1, approximate_distance = 2,
                       distance_reference = "median_nearest_neighbor"),
    class = "potentiomap_contour_threshold_error"
  )
})

test_that("empty and filtered contour-support results remain inspectable", {
  f <- make_contour_support_fixture()
  outside <- f$contour(5000, 6000)
  empty <- suppressWarnings(ps_contour_support(
    outside, support = f$support,
    supported_distance = 300, approximate_distance = 1000
  ))
  expect_s3_class(empty, "potentiomap_contour_support")
  expect_equal(nrow(empty$segments), 0)
  expect_equal(nrow(empty$summary), 0)
  expect_identical(capture.output(print(empty))[1],
                   "<potentiomap_contour_support>")
  expect_error(plot(empty), class = "potentiomap_contour_support_error")
  expect_error(ps_export_contour_support(empty, tempdir()),
               class = "potentiomap_export_error")

  filtered <- suppressWarnings(ps_contour_support(
    f$contour(), support = f$support,
    supported_distance = 300, approximate_distance = 1000,
    minimum_segment_length = 1e9
  ))
  expect_equal(nrow(filtered$segments), 0)
  expect_true(any(filtered$conditions$type == "warning"))
})

test_that("contour-support plots and alternate exports honor options", {
  f <- make_contour_support_fixture()
  result <- suppressWarnings(ps_contour_support(
    f$contour(), support = f$support,
    supported_distance = 300, approximate_distance = 1000
  ))
  expect_error(potentiomap:::plot.potentiomap_contour_support(list()),
               class = "potentiomap_contour_support_error")

  plot_file <- tempfile(fileext = ".pdf")
  grDevices::pdf(plot_file)
  expect_identical(plot(result, label_levels = TRUE), result)
  grDevices::dev.off()
  expect_gt(file.info(plot_file)$size, 0)

  out <- tempfile("potentiomap-contour-shape-")
  manifest <- ps_export_contour_support(
    result, out, out_stub = "shape", vector_format = "shapefile",
    write_summary = FALSE, write_thresholds = FALSE
  )
  expect_equal(manifest$product, "segments")
  expect_true(file.exists(manifest$path))
  expect_identical(capture.output(print(result))[1],
                   "<potentiomap_contour_support>")

  expect_error(ps_export_contour_support(list(), out),
               class = "potentiomap_contour_support_error")
  expect_error(ps_export_contour_support(result, ""),
               class = "potentiomap_export_error")
  expect_error(ps_export_contour_support(result, out, write_summary = NA),
               class = "potentiomap_contour_support_error")

  blocked <- tempfile("potentiomap-not-a-dir-")
  writeLines("occupied", blocked)
  expect_error(ps_export_contour_support(result, blocked),
               class = "potentiomap_export_error")
})
