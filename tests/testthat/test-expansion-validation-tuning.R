test_that("validation partitions are deterministic, leak-free, and numerically exact", {
  p <- expansion_points(14)
  v <- ps_validate(p, "IDW", design = "kfold", folds = 3,
                   prediction_mode = "direct", seed = 19)
  expect_s3_class(v, "potentiomap_validation")
  expect_true(all(c("predictions", "metrics", "fold_manifest", "fit_manifest") %in% names(v)))
  expect_false(any(vapply(seq_len(nrow(v$predictions)), function(i) {
    v$predictions$record_id[i] %in% strsplit(v$predictions$training_ids[i], "\\|")[[1]]
  }, logical(1))))
  pooled <- subset(v$metrics, scope == "pooled" & support_subset == "all")
  error <- v$predictions$predicted - v$predictions$observed
  expect_equal(pooled$me, mean(error), tolerance = 1e-10)
  expect_equal(pooled$mae, mean(abs(error)), tolerance = 1e-10)
  expect_equal(pooled$rmse, sqrt(mean(error^2)), tolerance = 1e-10)
  v2 <- ps_validate(p, "IDW", design = "kfold", folds = 3,
                    prediction_mode = "direct", seed = 19)
  expect_identical(v$partition_manifest$partition_hash,
                   v2$partition_manifest$partition_hash)
  changed <- p; terra::values(changed)$Z <- rev(terra::values(changed)$Z)
  v3 <- ps_validate(changed, "IDW", design = "kfold", folds = 3,
                    prediction_mode = "direct", seed = 19)
  expect_identical(v$partition_manifest$partition_hash,
                   v3$partition_manifest$partition_hash)
})

test_that("validation records duplicate partitions and independent terminology", {
  p <- expansion_points(12)
  folds <- rep(1:3, length.out = nrow(p))
  duplicate <- ps_validate(p, "IDW", "user_folds", fold_id = folds,
                           repeats = 2, prediction_mode = "direct")
  expect_true(any(duplicate$partition_manifest$duplicate_partition))
  data("synthetic_validation_points")
  vp <- ps_make_points(synthetic_validation_points, "x", "y", "head",
                       "validation_id", "EPSG:26916")
  independent <- ps_validate(p, "IDW", "independent",
                             validation_points = vp,
                             prediction_mode = "direct")
  expect_identical(independent$settings$design, "independent")
  expect_match(independent$warnings, "Independent validation")
  expect_error(ps_validate(p[1], "IDW", "kfold", prediction_mode = "direct"),
               class = "potentiomap_validation_error")
})

test_that("method comparison and plots retain stated objective and support", {
  p <- expansion_points(14)
  v <- ps_validate(p, c("IDW", "TPS"), "kfold", folds = 3,
                   prediction_mode = "direct", seed = 3)
  comparison <- ps_compare_methods(v, metric = "rmse", select = TRUE)
  expect_s3_class(comparison, "potentiomap_method_comparison")
  expect_true(comparison$selection %in% c("IDW", "TPS"))
  expect_true(all(c("rank", "adequate_coverage", "tie_status") %in% names(comparison$ranking)))
  file <- tempfile(fileext = ".pdf"); grDevices::pdf(file); on.exit({grDevices::dev.off(); unlink(file)}, add = TRUE)
  plotted <- ps_validation_plot(v, "observed_predicted")
  expect_equal(nrow(plotted$data), nrow(v$predictions))
  expect_warning(ps_validation_plot(v, "residual_distribution", display_limits = c(-1, 1)),
                 class = "potentiomap_validation_warning")
  expect_error(ps_compare_methods(v, metric = "unknown"), class = "potentiomap_validation_error")
})

test_that("tuning preserves candidates, partitions, selection, and guard", {
  p <- expansion_points(14)
  candidate_table <- data.frame(idw_power = c(1.2, 2, -1))
  tuned <- ps_tune_interpolation(p, "IDW", candidate_table,
                                 inner_design = "kfold", inner_folds = 3,
                                 refit = TRUE, seed = 11)
  expect_s3_class(tuned, "potentiomap_tuning")
  expect_equal(nrow(tuned$candidates), 3)
  expect_true(any(tuned$candidates$status == "failed"))
  expect_true(tuned$selection$candidate_id %in% tuned$candidates$candidate_id)
  expect_s3_class(tuned$final_result, "potentiomap_result")
  expect_equal(tuned$final_result$method_parameters$IDW$idw_power,
               tuned$selection$idw_power)
  again <- ps_tune_interpolation(p, "IDW", candidate_table[1:2, , drop = FALSE],
                                 inner_design = "kfold", inner_folds = 3,
                                 refit = FALSE, seed = 11)
  reordered <- ps_tune_interpolation(p, "IDW", candidate_table[2:1, , drop = FALSE],
                                     inner_design = "kfold", inner_folds = 3,
                                     refit = FALSE, seed = 11)
  expect_equal(again$selection$idw_power, reordered$selection$idw_power)
  expect_error(ps_tune_interpolation(p, "IDW", candidate_table,
                                     inner_folds = 5, maximum_runs = 2),
               class = "potentiomap_tuning_error")
})
