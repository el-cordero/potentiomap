test_that("ensemble and disagreement obey exact metamorphic identities", {
  r <- expansion_raster()
  identical_ensemble <- ps_surface_ensemble(list(a = r, b = r))
  expect_equal(as.numeric(terra::values(identical_ensemble$ensemble)), as.numeric(terra::values(r)))
  expect_equal(as.numeric(terra::values(identical_ensemble$standard_deviation)), rep(0, 9))
  weighted <- c(a = 0.25, b = 0.75)
  e <- ps_surface_ensemble(list(a = r, b = r + 4), "weighted_mean", weights = weighted)
  expect_equal(as.numeric(terra::values(e$ensemble)), as.numeric(terra::values(r + 3)))
  expect_true(all(terra::values(e$ensemble) >= terra::values(e$minimum) &
                  terra::values(e$ensemble) <= terra::values(e$maximum)))
  expect_error(ps_surface_ensemble(list(a = r, b = r), "weighted_mean",
                                   weights = c(a = 1, b = -1)),
               class = "potentiomap_ensemble_error")
  d0 <- ps_method_disagreement(list(a = r, b = r))
  expect_equal(as.numeric(terra::values(d0$rasters$range)), rep(0, 9))
  d1 <- ps_method_disagreement(list(a = r, b = r + 2))
  expect_equal(d1$pairwise_summary$mean_absolute_head_difference, 2)
  direction <- terra::values(d1$rasters$median_gradient_direction)
  expect_true(all(direction[is.finite(direction)] >= 0 & direction[is.finite(direction)] <= 180))
  expect_match(d1$warnings, "not statistical uncertainty")
})

test_that("surface comparison is antisymmetric on common support", {
  a <- expansion_raster(); b <- a + 2
  ab <- ps_compare_surfaces(a, b); ba <- ps_compare_surfaces(b, a)
  expect_equal(terra::values(ab$signed_difference), -terra::values(ba$signed_difference))
  same <- ps_compare_surfaces(a, a)
  expect_equal(as.numeric(terra::values(same$signed_difference)), rep(0, 9))
  expect_equal(ab$support_summary$common_cells, ba$support_summary$common_cells)
  shifted <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 300,
                         ymin = 0, ymax = 300, crs = "EPSG:26920", vals = 1:4)
  expect_error(ps_compare_surfaces(a, shifted), class = "potentiomap_input_error")
})

test_that("depth and vertical gradient preserve equations and sign", {
  head <- expansion_raster(rep(c(9, 10, 11), each = 3)); land <- head * 0 + 10
  depth <- ps_depth_to_water_surface(head, land, "potentiometric")
  expect_equal(as.numeric(terra::values(depth$depth)), 10 - as.numeric(terra::values(head)))
  expect_true(any(terra::values(depth$negative_mask) == 1))
  vg <- ps_vertical_gradient(upper_head = 10, lower_head = 12,
                             upper_elevation = 100, lower_elevation = 80,
                             positive = "upward")
  expect_equal(vg$signed_gradient, 0.1)
  expect_equal(vg$direction_class, "upward")
  zero <- ps_vertical_gradient(10, 10, 100, 80, tolerance = 0)
  expect_equal(zero$direction_class, "near_zero")
  expect_error(ps_vertical_gradient(10, 12, 80, 100),
               class = "potentiomap_vertical_gradient_error")
  expect_false("flux" %in% names(vg))
})

test_that("kriging variance, simulation, and contour probability are bounded", {
  p <- expansion_points(16)
  fit <- suppressWarnings(ps_interpolate(p, methods = "OK", grid_res = 350,
                                        return = "result"))
  u <- ps_surface_uncertainty(fit, approach = "kriging_variance",
                              exceedance_levels = 168)
  expect_s3_class(u, "potentiomap_uncertainty")
  expect_true(all(terra::values(u$standard_deviation) >= 0, na.rm = TRUE))
  expect_true(all(terra::values(u$lower) <= terra::values(u$upper), na.rm = TRUE))
  expect_true(all(terra::values(u$exceedance) >= 0 & terra::values(u$exceedance) <= 1, na.rm = TRUE))
  sim1 <- suppressMessages(ps_surface_uncertainty(fit, approach = "conditional_simulation",
                                                  nsim = 3, keep_realizations = TRUE, seed = 6))
  sim2 <- suppressMessages(ps_surface_uncertainty(fit, approach = "conditional_simulation",
                                                  nsim = 3, keep_realizations = TRUE, seed = 6))
  expect_equal(terra::values(sim1$realizations), terra::values(sim2$realizations))
  expect_equal(terra::nlyr(sim1$realizations), 3)
  contour <- ps_contour_uncertainty(u, 168, method = "gaussian_pointwise",
                                    accept_gaussian = TRUE)
  expect_s3_class(contour, "potentiomap_contour_uncertainty")
  prob <- terra::values(contour$levels[[1]]$exceedance_probability)
  expect_true(all(prob >= 0 & prob <= 1, na.rm = TRUE))
  expect_match(contour$warnings, "not simultaneous")
  expect_error(ps_contour_uncertainty(u, 168, method = "gaussian_pointwise"),
               class = "potentiomap_contour_uncertainty_error")
})

test_that("case-resampling uncertainty records duplicate-coordinate handling", {
  p <- expansion_points(12)
  template <- suppressWarnings(ps_interpolate(
    p, methods = "IDW", grid_res = 500, return = "result"
  ))$template

  u <- suppressWarnings(ps_surface_uncertainty(
    points = p,
    method = "IDW",
    approach = "resampling_sensitivity",
    nsim = 3,
    template = template,
    seed = 18
  ))

  expect_s3_class(u, "potentiomap_uncertainty")
  expect_true(all(u$realization_manifest$status == "success"))
  expect_equal(unique(u$realization_manifest$duplicate_policy), "mean")
  expect_equal(u$summary$successful_realizations, 3)
})
