test_that("random-row and nested tuning retain outer performance and progress", {
  p <- expansion_points(12)
  events <- list()
  progress <- function(index, total, run_id, status) {
    events[[length(events) + 1L]] <<- c(index = index, total = total,
                                        run_id = run_id, status = status)
  }
  nested <- ps_tune_interpolation(
    p, "IDW",
    list(idw_power = c(1.5, 2), idw_nmax = c(8, 12)),
    search = "random", inner_design = "kfold", inner_folds = 2,
    outer_design = "kfold", outer_folds = 2,
    repeats = 1, refit = FALSE, progress = progress, seed = 23
  )

  expect_s3_class(nested, "potentiomap_tuning")
  expect_equal(nrow(nested$candidates), 2)
  expect_equal(nrow(nested$outer_results$metrics), 2)
  expect_gt(nrow(nested$outer_results$predictions), 0)
  expect_gt(length(events), 0)
  expect_match(nested$warnings, "Outer scores")
  expect_null(nested$final_result)
})

test_that("tuning validates candidate schemas and method-specific controls", {
  p <- expansion_points(10)
  expect_error(ps_tune_interpolation(p, "bad", list(idw_power = 2)),
               class = "potentiomap_tuning_error")
  expect_error(ps_tune_interpolation(p, "IDW", list(c(1, 2))),
               class = "potentiomap_tuning_error")
  expect_error(ps_tune_interpolation(p, "IDW", data.frame()),
               class = "potentiomap_tuning_error")
  expect_error(ps_tune_interpolation(
    p, "IDW", list(idw_power = 1:2, idw_nmax = 1:3), search = "random"
  ), class = "potentiomap_tuning_error")
  bad_integer <- ps_tune_interpolation(
    p, "IDW", data.frame(idw_nmax = 2.5),
    inner_design = "kfold", inner_folds = 2, refit = FALSE
  )
  bad_lambda <- ps_tune_interpolation(
    p, "TPS", data.frame(tps_lambda = -1),
    inner_design = "kfold", inner_folds = 2, refit = FALSE
  )
  bad_variogram <- ps_tune_interpolation(
    p, "OK", data.frame(model = "Sph", partial_sill = -1, range = 100),
    inner_design = "kfold", inner_folds = 2, refit = FALSE
  )
  expect_true(all(bad_integer$candidates$status == "failed"))
  expect_true(all(bad_lambda$candidates$status == "failed"))
  expect_true(all(bad_variogram$candidates$status == "failed"))
  expect_equal(nrow(bad_integer$selection), 0)
  expect_error(ps_tune_interpolation(
    p, "IDW", list(idw_power = c(1, 2)), minimum_coverage = 1.1
  ), class = "potentiomap_tuning_error")
})

test_that("TPS standard errors and resampling designs retain assumptions and files", {
  p <- expansion_points(12)
  tps <- suppressWarnings(ps_interpolate(
    p, methods = "TPS", grid_res = 500, return = "result"
  ))
  tps_uncertainty <- suppressWarnings(ps_surface_uncertainty(
    tps, approach = "tps_standard_error"
  ))
  expect_s3_class(tps_uncertainty, "potentiomap_uncertainty")
  expect_true(all(terra::values(tps_uncertainty$standard_deviation) >= 0,
                  na.rm = TRUE))
  expect_match(tps_uncertainty$warnings, "smoothing-model")

  idw <- ps_interpolate(p, methods = "IDW", grid_res = 500,
                        return = "result")
  output <- tempfile("uncertainty-files-")
  on.exit(unlink(output, recursive = TRUE), add = TRUE)
  progress_events <- list()
  jackknife <- suppressWarnings(ps_surface_uncertainty(
    x = idw, points = p, method = "IDW",
    approach = "resampling_sensitivity", nsim = 3,
    resampling_design = "jackknife", keep_realizations = TRUE,
    output_directory = output, seed = 12,
    progress = function(index, total, run_id, status) {
      progress_events[[length(progress_events) + 1L]] <<-
        list(index = index, total = total, run_id = run_id, status = status)
    }
  ))
  expect_equal(terra::nlyr(jackknife$realizations), 3)
  expect_equal(nrow(jackknife$output_manifest), 3)
  expect_true(all(file.exists(jackknife$output_manifest$file)))
  expect_gt(length(progress_events), 0)

  groups <- rep(1:3, length.out = nrow(p))
  spatial <- suppressWarnings(ps_surface_uncertainty(
    points = p, method = "IDW", approach = "resampling_sensitivity",
    nsim = 2, template = idw$template,
    resampling_design = list(type = "spatial_group", group = groups),
    keep_realizations = TRUE, seed = 13
  ))
  expect_equal(terra::nlyr(spatial$realizations), 2)
  expect_true(all(spatial$realization_manifest$duplicate_policy == "error"))
})

test_that("empirical contour bands use retained realizations and explicit gates", {
  p <- expansion_points(12)
  fit <- ps_interpolate(p, methods = "IDW", grid_res = 500,
                        return = "result")
  uncertainty <- suppressWarnings(ps_surface_uncertainty(
    x = fit, points = p, method = "IDW",
    approach = "resampling_sensitivity", nsim = 3,
    resampling_design = "jackknife", keep_realizations = TRUE, seed = 3
  ))
  level <- as.numeric(stats::median(terra::values(uncertainty$central),
                                    na.rm = TRUE))
  contour <- ps_contour_uncertainty(
    uncertainty, levels = level, method = "empirical_crossing",
    minimum_realizations = 3, keep_realized_contours = TRUE
  )
  expect_s3_class(contour, "potentiomap_contour_uncertainty")
  expect_equal(contour$level_manifest$finite_realizations, 3)
  expect_length(contour$realized_contours[[1]], 3)
  expect_match(contour$warnings, "not simultaneous")

  no_realizations <- ps_surface_uncertainty(
    fit, approach = "resampling_sensitivity", nsim = 2,
    points = p, method = "IDW", resampling_design = "jackknife",
    keep_realizations = FALSE
  )
  expect_error(ps_contour_uncertainty(no_realizations, level,
                                      method = "empirical_crossing"),
               class = "potentiomap_contour_uncertainty_error")
})

test_that("uncertainty inputs fail with classed scientific errors", {
  p <- expansion_points(10)
  idw <- ps_interpolate(p, methods = "IDW", grid_res = 600,
                        return = "result")
  expect_error(ps_surface_uncertainty(idw, approach = "kriging_variance"),
               class = "potentiomap_uncertainty_error")
  expect_error(ps_surface_uncertainty(idw, approach = "tps_standard_error"),
               class = "potentiomap_uncertainty_error")
  expect_error(ps_surface_uncertainty(
    points = p, method = "IDW", approach = "resampling_sensitivity",
    probabilities = c(.9, .1), template = idw$template
  ), class = "potentiomap_uncertainty_error")
  expect_error(ps_surface_uncertainty(
    points = p, method = "IDW", approach = "resampling_sensitivity",
    resampling_design = "unknown", template = idw$template
  ), class = "potentiomap_uncertainty_error")
  expect_error(ps_surface_uncertainty(
    points = p, method = "IDW", approach = "resampling_sensitivity",
    resampling_design = list(type = "spatial_group"), template = idw$template
  ), class = "potentiomap_uncertainty_error")
  expect_error(ps_surface_uncertainty(
    points = p, method = "IDW", approach = "resampling_sensitivity"
  ), class = "potentiomap_uncertainty_error")
  expect_error(ps_contour_uncertainty(idw, 1),
               class = "potentiomap_contour_uncertainty_error")
})
