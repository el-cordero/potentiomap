test_that("ensemble statistics distinguish intersection, union, and weight provenance", {
  a <- expansion_raster(c(1, 2, NA, 4, 5, 6, 7, 8, 9))
  b <- expansion_raster(c(3, NA, 5, 6, 7, 8, 9, 10, 11))
  c <- expansion_raster(c(2, 4, 6, 8, 10, 12, 14, 16, 18))
  attr(a, "potentiomap_metadata") <- list(unit = "m", vertical_datum = "NAVD88")

  median <- ps_surface_ensemble(list(a = a, b = b, c = c), "median",
                                support = "union", minimum_methods = 1)
  quantiles <- ps_surface_ensemble(
    list(a = a, b = b, c = c), "quantile", probabilities = c(.25, .75),
    support = "union", minimum_methods = 2,
    method_metadata = list(a = list(), b = list(), c = list())
  )
  weights <- c(a = 1, b = 2, c = 1)
  attr(weights, "origin") <- "validation_rmse"
  weighted <- ps_surface_ensemble(list(a = a, b = b, c = c),
                                  "weighted_mean", weights = weights,
                                  support = "union", minimum_methods = 1)

  expect_s3_class(median, "potentiomap_ensemble")
  expect_named(quantiles$ensemble, c("q0.25", "q0.75"))
  expect_identical(unique(weighted$method_manifest$weight_origin),
                   "validation_rmse")
  expect_true(all(terra::values(weighted$ensemble) >=
                    terra::values(weighted$minimum), na.rm = TRUE))
  expect_equal(median$support_manifest$eligible_cells, 9)

  expect_error(ps_surface_ensemble(list(a = a, b = b), "quantile",
                                   probabilities = 2),
               class = "potentiomap_ensemble_error")
  expect_error(ps_surface_ensemble(list(a = a, b = b), minimum_methods = 3),
               class = "potentiomap_ensemble_error")
  expect_error(ps_surface_ensemble(list(a = a, b = b),
                                   method_metadata = list(a = list())),
               class = "potentiomap_ensemble_error")
})

test_that("disagreement supports head-only analysis and validates measures", {
  a <- expansion_raster(rep(1, 9))
  b <- expansion_raster(rep(2, 9))
  head_only <- ps_method_disagreement(
    list(a = a, b = b), head_measures = c("range", "sd"),
    gradient = FALSE, support = "union"
  )
  expect_null(head_only$flat_mask)
  expect_equal(as.numeric(terra::values(head_only$rasters$range)), rep(1, 9))

  flat <- ps_method_disagreement(list(a = a, b = b), gradient = TRUE,
                                 min_gradient = 1)
  expect_true(all(terra::values(flat$flat_mask) == 1))
  expect_error(ps_method_disagreement(list(a = a), minimum_methods = 2),
               class = "potentiomap_ensemble_error")
  expect_error(ps_method_disagreement(list(a = a, b = b),
                                      head_measures = "unknown"),
               class = "potentiomap_ensemble_error")
})

test_that("surface comparison records alignment, support masks, contours, and sign", {
  a <- expansion_raster(c(1, 2, 3, 4, 5, NA, 7, 8, 9))
  b <- terra::rast(nrows = 6, ncols = 6, xmin = 0, xmax = 300,
                   ymin = 0, ymax = 300, crs = "EPSG:26920",
                   vals = seq(2, 12, length.out = 36))
  aligned <- ps_compare_surfaces(
    a, b, direction = "a_minus_b", align = "to_a",
    contour_levels = c(5, 100), compare_gradient = FALSE
  )
  expect_equal(terra::ncell(aligned$signed_difference), terra::ncell(a))
  expect_null(aligned$gradient_direction_difference)
  expect_true(all(aligned$contour_displacement$status %in%
                    c("success", "unavailable")))
  expect_identical(aligned$settings$direction, "a_minus_b")

  target <- expansion_raster(rep(NA_real_, 9))
  templated <- ps_compare_surfaces(a, b, align = "template",
                                   template = target, resampling = "near")
  expect_equal(terra::res(templated$signed_difference), terra::res(target))
  reversed <- ps_compare_surfaces(a, a + 2, direction = "a_minus_b")
  expect_equal(as.numeric(terra::values(reversed$signed_difference)),
               ifelse(is.na(as.numeric(terra::values(a))), NA_real_, -2))
})

test_that("depth surfaces enforce metadata and preserve alignment review masks", {
  head <- expansion_raster(c(9, 10, 11, 9, 10, 11, NA, 10, 11))
  land <- terra::rast(nrows = 6, ncols = 6, xmin = 0, xmax = 300,
                      ymin = 0, ymax = 300, crs = "EPSG:26920", vals = 10)
  attr(head, "potentiomap_metadata") <- list(head_unit = "m",
                                               vertical_datum = "NAVD88")
  attr(land, "potentiomap_metadata") <- list(head_unit = "m",
                                               vertical_datum = "NAVD88")
  depth <- ps_depth_to_water_surface(head, land, "water_table",
                                     align = "to_head", tolerance = .1)
  expect_identical(depth$summary$label, "depth to water")
  expect_gt(depth$summary$negative_cells, 0)
  expect_true(any(terra::values(depth$near_zero_mask) == 1, na.rm = TRUE))

  mismatch <- land
  attr(mismatch, "potentiomap_metadata") <- list(head_unit = "ft",
                                                   vertical_datum = "NAVD88")
  expect_error(ps_depth_to_water_surface(head, mismatch, align = "to_head"),
               class = "potentiomap_metadata_error")
})

test_that("raster vertical gradients preserve sign, support, and overlap warnings", {
  upper <- expansion_raster(rep(10, 9))
  lower <- expansion_raster(rep(c(12, 10, 8), each = 3))
  upper_z <- expansion_raster(rep(100, 9))
  lower_z <- expansion_raster(rep(80, 9))
  raster <- ps_vertical_gradient(upper, lower, upper_z, lower_z,
                                 positive = "downward", tolerance = .01)
  expect_s3_class(raster, "potentiomap_vertical_gradient")
  expect_s4_class(raster$gradient, "SpatRaster")
  expect_equal(raster$sign_convention$positive, "downward")
  expect_true(all(terra::values(raster$direction_class) %in% 0:3,
                  na.rm = TRUE))

  expect_warning(ps_vertical_gradient(
    c(10, 10), c(12, 9), c(100, 100), c(80, 80),
    event_metadata = list(overlapping_intervals = TRUE,
                          screen_midpoint_assumption = TRUE)
  ), class = "potentiomap_vertical_gradient_warning")
  expect_error(ps_vertical_gradient(upper, 10, upper_z, lower_z),
               class = "potentiomap_vertical_gradient_error")
  bad_z <- lower_z
  terra::values(bad_z)[1] <- 120
  expect_error(ps_vertical_gradient(upper, lower, upper_z, bad_z),
               class = "potentiomap_vertical_gradient_error")
})
