test_that("contours are split into local supported, approximate, and unsupported sections", {
  f <- make_contour_support_fixture()
  whole_supported <- suppressWarnings(ps_contour_support(
    f$contour(400, 600), support = f$support,
    supported_distance = 300, approximate_distance = 1000,
    require_inside_hull = FALSE
  ))
  expect_setequal(terra::values(whole_supported$segments)$support_class,
                  "supported")

  two_classes <- suppressWarnings(ps_contour_support(
    f$contour(0, 1500), support = f$support,
    supported_distance = 300, approximate_distance = 1000,
    require_inside_hull = FALSE
  ))
  expect_setequal(terra::values(two_classes$segments)$support_class,
                  c("supported", "approximate"))
  expect_true(all(terra::values(two_classes$segments)$contour_level == 10))
  expect_true(all(terra::values(two_classes$segments)$source_contour_id == "c1"))

  three_classes <- suppressWarnings(ps_contour_support(
    f$contour(), support = f$support,
    supported_distance = 300, approximate_distance = 1000
  ))
  values <- terra::values(three_classes$segments)
  expect_setequal(values$support_class,
                  c("supported", "approximate", "unsupported"))
  expect_setequal(values$line_type, c("solid", "dashed", "dotted"))
  expect_true(all(c(
    "contour_level", "source_contour_id", "segment_id", "support_class",
    "classification_basis", "classification_reason",
    "nearest_distance_min", "nearest_distance_mean", "nearest_distance_max",
    "inside_hull_fraction", "finite_support_fraction",
    "local_point_count_min", "uncertainty_min", "uncertainty_mean",
    "uncertainty_max", "segment_length", "threshold_reference", "line_type"
  ) %in% names(values)))
  expect_equal(sum(three_classes$summary$total_line_length), 3000,
               tolerance = 1e-6)
})

test_that("unsupported sections can be omitted while removed length is retained", {
  f <- make_contour_support_fixture()
  result <- suppressWarnings(ps_contour_support(
    f$contour(), support = f$support,
    supported_distance = 300, approximate_distance = 1000,
    keep_unsupported = FALSE
  ))
  expect_false(any(terra::values(result$segments)$support_class == "unsupported"))
  unsupported <- result$summary$support_class == "unsupported"
  expect_true(any(result$summary$removed_line_length[unsupported] > 0))
  expect_equal(result$summary$retained_line_length[unsupported], 0)
})

test_that("training hull remains separate and user controlled", {
  f <- make_contour_support_fixture()
  near_outside <- f$contour(100, 300)
  required <- suppressWarnings(ps_contour_support(
    near_outside, support = f$support,
    supported_distance = 300, approximate_distance = 1000,
    require_inside_hull = TRUE
  ))
  ignored <- suppressWarnings(ps_contour_support(
    near_outside, support = f$support,
    supported_distance = 300, approximate_distance = 1000,
    require_inside_hull = FALSE
  ))
  expect_setequal(terra::values(required$segments)$support_class, "approximate")
  expect_setequal(terra::values(ignored$segments)$support_class, "supported")
  expect_true(all(terra::values(required$segments)$inside_hull_fraction < 1))
})

test_that("absolute and relative thresholds are recorded and change classes", {
  f <- make_contour_support_fixture()
  absolute <- suppressWarnings(ps_contour_support(
    f$contour(), support = f$support,
    supported_distance = 300, approximate_distance = 1000,
    require_inside_hull = FALSE
  ))
  relative <- suppressWarnings(ps_contour_support(
    f$contour(), support = f$support,
    supported_distance = 1.5, approximate_distance = 5,
    distance_reference = "median_nearest_neighbor",
    require_inside_hull = FALSE
  ))
  expect_equal(relative$thresholds$median_nearest_neighbor, 200)
  expect_equal(relative$thresholds$supported_distance_actual, 300)
  expect_equal(relative$thresholds$approximate_distance_actual, 1000)
  expect_equal(
    aggregate(segment_length ~ support_class,
              terra::values(relative$segments), sum),
    aggregate(segment_length ~ support_class,
              terra::values(absolute$segments), sum),
    tolerance = 1e-6
  )

  tighter <- suppressWarnings(ps_contour_support(
    f$contour(), support = f$support,
    supported_distance = 100, approximate_distance = 400,
    require_inside_hull = FALSE
  ))
  expect_gt(
    sum(terra::values(tighter$segments)$segment_length[
      terra::values(tighter$segments)$support_class == "unsupported"
    ]),
    sum(terra::values(absolute$segments)$segment_length[
      terra::values(absolute$segments)$support_class == "unsupported"
    ])
  )
})

test_that("threshold, geometry, CRS, and empty-input errors are classed", {
  f <- make_contour_support_fixture()
  expect_error(
    ps_contour_support(f$contour(), support = f$support,
                       supported_distance = 1000, approximate_distance = 300),
    class = "potentiomap_contour_threshold_error"
  )
  expect_error(
    ps_contour_support(f$contour(), support = f$support),
    class = "potentiomap_contour_threshold_error"
  )
  expect_error(
    ps_contour_support(f$contour()[0], support = f$support,
                       supported_distance = 300, approximate_distance = 1000),
    class = "potentiomap_contour_support_error"
  )
  missing_level <- f$contour()
  terra::values(missing_level) <- data.frame(name = "x")
  expect_error(
    ps_contour_support(missing_level, support = f$support,
                       supported_distance = 300, approximate_distance = 1000),
    class = "potentiomap_contour_support_error"
  )
  mismatched <- f$contour()
  terra::crs(mismatched) <- "EPSG:26916"
  expect_error(
    ps_contour_support(mismatched, support = f$support,
                       supported_distance = 300, approximate_distance = 1000),
    class = "potentiomap_contour_support_error"
  )
  geographic <- terra::vect(
    list(rbind(c(-66, 18), c(-65.9, 18.1))),
    type = "lines", crs = "EPSG:4326"
  )
  terra::values(geographic) <- data.frame(level = 10)
  expect_error(
    ps_contour_support(geographic, support = f$support,
                       supported_distance = 0.1, approximate_distance = 0.2),
    class = "potentiomap_contour_support_error"
  )

  empty_points <- f$points[0]
  expect_error(
    ps_contour_support(f$contour(), points = empty_points, surface = f$surface,
                       supported_distance = 300, approximate_distance = 1000),
    class = "potentiomap_error"
  )
})

test_that("finite surface and mask status cannot be hidden by good distance", {
  f <- make_contour_support_fixture()
  limited <- f$surface
  xy <- terra::xyFromCell(limited, seq_len(terra::ncell(limited)))
  values <- terra::values(limited, mat = FALSE)
  values[xy[, 1] > 2500] <- NA
  terra::values(limited) <- values
  limited_support <- ps_prediction_support(f$points, surface = limited)
  result <- suppressWarnings(ps_contour_support(
    f$contour(2000, 3000), support = limited_support,
    supported_distance = 10000, approximate_distance = 20000,
    require_inside_hull = FALSE
  ))
  expect_true(any(terra::values(result$segments)$support_class == "unsupported"))
  unsupported <- terra::values(result$segments)$support_class == "unsupported"
  expect_true(any(terra::values(result$segments)$finite_support_fraction[
    unsupported
  ] < 1))

  constant <- f$surface
  terra::values(constant) <- 7
  constant_support <- ps_prediction_support(f$points, surface = constant)
  expect_s3_class(suppressWarnings(ps_contour_support(
    f$contour(400, 600), support = constant_support,
    supported_distance = 300, approximate_distance = 1000,
    require_inside_hull = FALSE
  )), "potentiomap_contour_support")
})

test_that("local-neighbor and uncertainty criteria affect cell classes", {
  f <- make_contour_support_fixture()
  neighbor <- suppressWarnings(ps_contour_support(
    f$contour(0, 1200), support = f$support,
    supported_distance = 10000, approximate_distance = 20000,
    require_inside_hull = FALSE, neighbor_radius = 250,
    minimum_neighbors = 3
  ))
  neighbor_values <- terra::values(neighbor$segments)
  expect_true(any(neighbor_values$support_class == "approximate"))
  expect_true(any(is.finite(neighbor_values$local_point_count_min)))
  expect_equal(neighbor$settings$neighbor_rule$minimum_neighbors, 3)

  uncertainty <- f$surface
  cell_xy <- terra::xyFromCell(uncertainty, seq_len(terra::ncell(uncertainty)))
  terra::values(uncertainty) <- cell_xy[, 1] / 1000
  names(uncertainty) <- "user_uncertainty_index"
  classified <- suppressWarnings(ps_contour_support(
    f$contour(), support = f$support, uncertainty = uncertainty,
    supported_distance = 10000, approximate_distance = 20000,
    supported_uncertainty = 0.8, approximate_uncertainty = 1.8,
    uncertainty_type = "synthetic user uncertainty index",
    uncertainty_units = "index units", combine = "worst",
    require_inside_hull = FALSE
  ))
  uncertainty_values <- terra::values(classified$segments)
  expect_setequal(uncertainty_values$support_class,
                  c("supported", "approximate", "unsupported"))
  expect_true(any(is.finite(uncertainty_values$uncertainty_mean)))
  expect_equal(classified$settings$uncertainty_rule$type,
               "synthetic user uncertainty index")
  expect_equal(classified$settings$combination_rule, "worst")

  incompatible <- terra::aggregate(uncertainty, fact = 2)
  expect_error(
    ps_contour_support(
      f$contour(), support = f$support, uncertainty = incompatible,
      supported_uncertainty = 0.8, approximate_uncertainty = 1.8,
      uncertainty_type = "synthetic index", combine = "uncertainty"
    ),
    class = "potentiomap_contour_uncertainty_error"
  )
})

test_that("identifiers are stable to feature order and segment returns are optional", {
  f <- make_contour_support_fixture()
  lines <- rbind(f$contour(0, 1500, 10, "ten", 450),
                 f$contour(0, 1500, 20, "twenty", 550))
  a <- suppressWarnings(ps_contour_support(
    lines, support = f$support,
    supported_distance = 300, approximate_distance = 1000
  ))
  b <- suppressWarnings(ps_contour_support(
    lines[2:1], support = f$support,
    supported_distance = 300, approximate_distance = 1000
  ))
  expect_setequal(terra::values(a$segments)$segment_id,
                  terra::values(b$segments)$segment_id)
  expect_setequal(terra::values(a$segments)$source_contour_id,
                  c("ten", "twenty"))
  expect_setequal(terra::values(a$segments)$contour_level, c(10, 20))
  only_segments <- suppressWarnings(ps_contour_support(
    lines, support = f$support,
    supported_distance = 300, approximate_distance = 1000,
    return = "segments"
  ))
  expect_s4_class(only_segments, "SpatVector")
})

test_that("classified contours plot and export without forced colors", {
  f <- make_contour_support_fixture()
  result <- suppressWarnings(ps_contour_support(
    f$contour(), support = f$support,
    supported_distance = 300, approximate_distance = 1000
  ))
  expect_false(any(c("color", "colour", "line_color") %in%
                     names(terra::values(result$segments))))
  expect_identical(plot(result, legend_position = NULL), result)

  out <- file.path(tempdir(), "potentiomap-contour-support-export")
  unlink(out, recursive = TRUE)
  manifest <- ps_export_contour_support(result, out, out_stub = "test map")
  expect_true(all(file.exists(manifest$path)))
  vector <- terra::vect(manifest$path[manifest$product == "segments"])
  expect_true(all(c("support_class", "line_type", "contour_level",
                    "source_contour_id", "segment_id") %in% names(vector)))
  summary <- utils::read.csv(manifest$path[manifest$product == "summary"])
  expect_true(all(c("total_line_length", "removed_line_length") %in%
                    names(summary)))
  expect_error(
    ps_export_contour_support(result, out, out_stub = "test map",
                              overwrite = FALSE),
    class = "potentiomap_export_error"
  )
})

test_that("all-unsupported classification emits a stable warning", {
  f <- make_contour_support_fixture()
  warning_classes <- character()
  withCallingHandlers(
    ps_contour_support(
      f$contour(2500, 3000), support = f$support,
      supported_distance = 0, approximate_distance = 0,
      require_inside_hull = FALSE
    ),
    warning = function(w) {
      warning_classes <<- c(warning_classes, class(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true("potentiomap_contour_support_warning" %in% warning_classes)
})
