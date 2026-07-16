test_that("TPS records automatic and user-supplied smoothing information", {
  pts <- make_test_points()
  auto <- suppressWarnings(ps_interpolate(
    pts, methods = "TPS", grid_res = 300, return = "result"
  ))
  fixed <- ps_interpolate(
    pts, methods = "TPS", grid_res = 300, tps_lambda = 0.01,
    return = "result"
  )
  expect_equal(auto$diagnostics$TPS$selection_mode, "GCV")
  expect_true(is.finite(auto$diagnostics$TPS$selected_lambda))
  expect_true(is.finite(auto$diagnostics$TPS$effective_degrees_of_freedom))
  expect_equal(fixed$diagnostics$TPS$selection_mode, "user_supplied")
  expect_equal(fixed$diagnostics$TPS$selected_lambda, 0.01)
})

test_that("ordinary kriging retains variogram and attributed conditions", {
  pts <- make_test_points()
  result <- suppressWarnings(ps_interpolate(
    pts, methods = "OK", grid_res = 300, return = "result"
  ))
  d <- result$diagnostics$OK
  expect_equal(d$requested_method, "OK")
  expect_s3_class(d$empirical_variogram, "gstatVariogram")
  expect_true(all(c("nugget", "partial_sill", "fitted_range", "cutoff",
                    "lag_width", "fit_method", "return_status") %in% names(d)))
  expect_true(all(result$conditions$method == "OK"))
  expect_true(all(result$conditions$class[result$conditions$type == "warning"] ==
                    "potentiomap_kriging_convergence_warning"))
})

test_that("universal kriging scales coordinates and reports range behavior", {
  pts <- make_test_points()
  scaled <- suppressWarnings(ps_interpolate(
    pts, methods = "UK", grid_res = 300, return = "result"
  ))
  d <- scaled$diagnostics$UK
  expect_equal(d$coordinate_scaling, "center_scale")
  expect_false(d$rank_deficient)
  expect_equal(d$model_matrix_rank, 6)
  expect_true(is.finite(d$condition_number))
  expect_true(all(c(
    "coordinate_center", "coordinate_scale", "trend_coefficients",
    "observed_range", "predicted_range",
    "predicted_range_to_observed_range_ratio", "overshoot_below",
    "overshoot_above", "nonfinite_prediction_count"
  ) %in% names(d)))
  expect_named(scaled$surfaces, "UK")

  local <- terra::crds(pts)
  local[, 1] <- local[, 1] - min(local[, 1])
  local[, 2] <- local[, 2] - min(local[, 2])
  local_pts <- terra::vect(
    cbind(data.frame(x = local[, 1], y = local[, 2]), terra::values(pts)),
    geom = c("x", "y"), crs = "EPSG:3857"
  )
  legacy <- suppressWarnings(ps_interpolate(
    local_pts, methods = "UK", grid_res = 300, return = "result",
    uk_coordinate_scaling = "none"
  ))
  expect_equal(legacy$diagnostics$UK$coordinate_scaling, "none")
})

test_that("rank-deficient quadratic drift fails without fallback", {
  d <- data.frame(x = 1:7, y = 2 * (1:7), z = seq(10, 16))
  pts <- ps_make_points(d, value = "z", crs = "EPSG:3857")
  template <- terra::rast(ncols = 8, nrows = 8, xmin = 0, xmax = 8,
                          ymin = 0, ymax = 16, crs = "EPSG:3857")
  expect_error(
    ps_interpolate(pts, methods = "UK", template = template),
    class = "potentiomap_input_error"
  )
})

test_that("heuristic UK thresholds produce a classed warning", {
  pts <- make_test_points()
  expect_warning(
    ps_interpolate(
      pts, methods = "UK", grid_res = 300,
      diagnostic_control = list(condition_number_warning = 1)
    ),
    class = "potentiomap_uk_instability_warning"
  )
})
