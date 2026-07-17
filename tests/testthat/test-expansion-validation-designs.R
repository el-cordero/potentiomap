test_that("all documented validation partitions and raster prediction paths are auditable", {
  p <- expansion_points(12)
  pv <- terra::values(p)
  pv$cluster <- rep(c("north", "central", "south"), length.out = nrow(p))
  pv$user_fold <- rep(1:3, length.out = nrow(p))
  terra::values(p) <- pv

  loo <- ps_validate(p[1:7], "IDW", "loocv", prediction_mode = "direct",
                     support = FALSE, seed = 2)
  clustered <- ps_validate(p, "IDW", "leave_cluster_out",
                           cluster = "cluster", prediction_mode = "direct")
  user <- ps_validate(p, "IDW", "user_folds", fold_id = "user_fold",
                      prediction_mode = "direct")
  blocked <- ps_validate(p, "IDW", "spatial_block", folds = 3,
                         block_size = 700, prediction_mode = "direct", seed = 8)
  raster <- suppressWarnings(ps_validate(
    p, "IDW", "kfold", folds = 2, prediction_mode = "raster",
    domain_policy = "training", grid_res = 500,
    interpolation_control = list(idw_power = 1.5), seed = 5
  ))

  expect_equal(nrow(loo$fold_manifest), 7)
  expect_equal(nrow(clustered$fold_manifest), 3)
  expect_equal(nrow(user$fold_manifest), 3)
  expect_true(nrow(blocked$fold_manifest) >= 2)
  expect_true(all(raster$fit_manifest$status %in% c("success", "failed")))
  expect_identical(raster$settings$domain_policy, "training")
  expect_false(loo$settings$support)
})

test_that("independent weighted validation and support masks retain their design", {
  p <- expansion_points(12)
  data("synthetic_validation_points")
  vp <- ps_make_points(synthetic_validation_points, "x", "y", "head",
                       "validation_id", "EPSG:26916")
  mask <- terra::convHull(p)
  weights <- seq_len(nrow(vp))
  weighted <- ps_validate(
    p, "IDW", "independent", validation_points = vp,
    prediction_mode = "direct", mask = mask,
    sampling_weight = weights,
    metrics = c("me", "rmse", "correlation", "r_squared")
  )

  expect_identical(weighted$settings$design, "independent")
  expect_true(all(weighted$predictions$mask_membership %in% c(TRUE, FALSE)))
  expect_true(all(c("correlation", "r_squared") %in% names(weighted$metrics)))
  expect_match(weighted$warnings, "not cross-validation")

  expect_error(ps_validate(p, "IDW", "independent"),
               class = "potentiomap_validation_error")
  expect_error(ps_validate(p, "IDW", "kfold", sampling_weight = rep(1, nrow(p))),
               class = "potentiomap_validation_error")
  expect_error(ps_validate(p, "IDW", "independent", validation_points = vp,
                           sampling_weight = c(rep(1, nrow(vp) - 1), -1)),
               class = "potentiomap_validation_error")
})

test_that("validation rejects incomplete assignments and captures failed fits", {
  p <- expansion_points(10)
  expect_error(ps_validate(p, "IDW", "user_folds", fold_id = 1:3,
                           prediction_mode = "direct"),
               class = "potentiomap_validation_error")
  expect_error(ps_validate(p, "IDW", "user_folds",
                           fold_id = c(rep(1, 9), NA),
                           prediction_mode = "direct"),
               class = "potentiomap_validation_error")
  expect_error(ps_validate(p, "made_up", "kfold", folds = 2),
               class = "potentiomap_validation_error")
  expect_error(ps_validate(p, "IDW", "kfold", metrics = "not_a_metric"),
               class = "potentiomap_validation_error")
  expect_error(ps_validate(p, "IDW", "kfold", interpolation_control = 1),
               class = "potentiomap_validation_error")

  failed <- ps_validate(p, "IDW", "kfold", folds = 2,
                        prediction_mode = "direct",
                        interpolation_control = list(idw_power = -1))
  expect_true(all(failed$fit_manifest$status == "failed"))
  expect_true(all(failed$predictions$status == "failed_fit"))
  expect_gt(nrow(failed$conditions), 0)
})

test_that("multi-objective method comparisons expose Pareto and selection gates", {
  metrics <- data.frame(
    method = c("IDW", "TPS", "OK"), design = "kfold", scope = "pooled",
    support_subset = "all", finite_coverage = c(1, 1, 0.5),
    support_coverage = c(.8, .9, .4), rmse = c(1.0, 1.1, .7),
    mae = c(.9, .7, .6), stringsAsFactors = FALSE
  )
  pareto <- ps_compare_methods(metrics, metric = c("rmse", "mae"),
                               objective_weights = c(rmse = 2, mae = 1),
                               minimum_coverage = .9)
  expect_true("pareto" %in% names(pareto$ranking))
  expect_true("objective_score" %in% names(pareto$ranking))
  expect_false(pareto$ranking$adequate_coverage[pareto$ranking$method == "OK"])

  chosen <- ps_compare_methods(metrics, metric = "rmse", select = TRUE,
                               minimum_coverage = .9)
  expect_identical(chosen$selection, "IDW")
  expect_error(ps_compare_methods(metrics, metric = c("rmse", "mae"),
                                  objective_weights = c(rmse = -1, mae = 1)),
               class = "potentiomap_validation_error")
  expect_error(ps_compare_methods(metrics, metric = "rmse", select = TRUE,
                                  minimum_coverage = 1.1),
               class = "potentiomap_validation_error")

  multiple <- rbind(metrics, transform(metrics, design = "spatial_block"))
  expect_error(ps_compare_methods(multiple),
               class = "potentiomap_validation_error")
})

test_that("every validation plot type returns its plotted data", {
  p <- expansion_points(12)
  v <- ps_validate(p, c("IDW", "TPS"), "kfold", folds = 2,
                   prediction_mode = "direct", seed = 4)
  comparison <- ps_compare_methods(v)
  file <- tempfile(fileext = ".pdf")
  grDevices::pdf(file)
  on.exit({
    grDevices::dev.off()
    unlink(file)
  }, add = TRUE)

  for (type in c("observed_predicted", "residual_map",
                 "residual_distribution", "fold_map", "support")) {
    plotted <- ps_validation_plot(v, type, methods = "IDW", design = "kfold")
    expect_gt(nrow(plotted$data), 0)
  }
  expect_gt(nrow(ps_validation_plot(comparison, "metric")$data), 0)
  expect_gt(nrow(ps_validation_plot(comparison, "coverage")$data), 0)
  conditions <- ps_validation_plot(v, "method_conditions", legend = FALSE)
  expect_s3_class(conditions$data, "data.frame")
  expect_error(ps_validation_plot(comparison, "residual_map"),
               class = "potentiomap_validation_error")
  expect_error(ps_validation_plot(v, "metric", methods = "absent"),
               class = "potentiomap_validation_error")
  expect_error(ps_validation_plot(v, "observed_predicted",
                                  display_limits = c(1, 1)),
               class = "potentiomap_validation_error")
})

test_that("direct kriging validation retains covariance variance and rejects direct drift", {
  p <- expansion_points(18)
  kriging <- suppressWarnings(ps_validate(
    p, c("OK", "UK"), "kfold", folds = 2,
    prediction_mode = "direct", seed = 14
  ))
  expect_true(all(kriging$fit_manifest$status == "success"))
  expect_true(any(is.finite(kriging$predictions$prediction_variance)))
  expect_true(all(kriging$predictions$method %in% c("OK", "UK")))

  blocked_drift <- ps_validate(
    p, "UK", "kfold", folds = 2, prediction_mode = "direct",
    interpolation_control = list(trend = Z ~ drift,
                                 covariates = list(drift = expansion_raster()))
  )
  expect_true(all(blocked_drift$fit_manifest$status == "failed"))
  expect_true(all(blocked_drift$predictions$status == "failed_fit"))

  automatic_blocks <- ps_validate(
    p, "IDW", "spatial_block", folds = 3,
    prediction_mode = "direct", seed = 7
  )
  expect_gt(nrow(automatic_blocks$partition_manifest), 1)

  file <- tempfile(fileext = ".pdf")
  grDevices::pdf(file)
  plotted <- ps_validation_plot(blocked_drift, "method_conditions")
  grDevices::dev.off()
  unlink(file)
  expect_gt(nrow(plotted$data), 0)
})

test_that("validation and comparison reject incompatible CRS and incomplete tables", {
  p <- expansion_points(10)
  data("synthetic_validation_points")
  vp <- ps_make_points(synthetic_validation_points, "x", "y", "head",
                       "validation_id", "EPSG:26915")
  expect_error(ps_validate(p, "IDW", "independent", validation_points = vp),
               class = "potentiomap_crs_error")
  wrong_mask <- terra::convHull(p)
  terra::crs(wrong_mask) <- "EPSG:26915"
  expect_error(ps_validate(p, "IDW", "kfold", folds = 2,
                           prediction_mode = "direct", mask = wrong_mask),
               class = "potentiomap_crs_error")

  expect_error(ps_compare_methods(data.frame(method = "IDW")),
               class = "potentiomap_validation_error")
  v <- ps_validate(p, "IDW", "kfold", folds = 2,
                   prediction_mode = "direct")
  expect_error(ps_compare_methods(v, design = "absent"),
               class = "potentiomap_validation_error")
  expect_error(ps_compare_methods(v, support_subset = "supported",
                                  select = TRUE),
               class = "potentiomap_validation_error")
})
