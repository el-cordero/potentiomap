test_that("variogram controls reject invalid models and covariate layouts", {
  p <- expansion_points(12)
  template <- suppressWarnings(ps_interpolate(
    p, methods = "IDW", grid_res = 500
  )$IDW)
  empirical <- suppressWarnings(ps_variogram(p, cutoff = 5000,
                                              width = 500))

  bad_initial <- gstat::vgm(psill = 1, model = "Sph", range = 1000,
                            nugget = 0)
  bad_initial$psill[1] <- -1
  expect_error(ps_variogram_compare(empirical, models = "Sph",
                                    initial = bad_initial),
               class = "potentiomap_variogram_error")

  bad_model <- gstat::vgm(psill = 1, model = "Sph", range = 1000,
                          nugget = 0)
  bad_model$range[2] <- -1
  expect_error(ps_interpolate(p, methods = "OK", template = template,
                              variogram_model = bad_model),
               class = "potentiomap_variogram_error")

  covariates <- c(template, template)
  names(covariates) <- c("land", "rain")
  cell_xy <- terra::xyFromCell(template, seq_len(terra::ncell(template)))
  terra::values(covariates[[1]]) <- cell_xy[, 1]
  terra::values(covariates[[2]]) <- cell_xy[, 2]
  fit <- suppressWarnings(ps_interpolate(
    p, methods = "UK", template = template, covariates = covariates,
    trend = Z ~ land + rain
  ))
  expect_s4_class(fit$UK, "SpatRaster")

  duplicate_covariates <- list(a = template, a = template + 1)
  expect_error(ps_interpolate(p, methods = "UK", template = template,
                              covariates = duplicate_covariates,
                              trend = Z ~ a),
               class = "potentiomap_covariate_error")
  bad_tables <- list(points = data.frame(cov = 1),
                     grid = data.frame(cov = seq_len(terra::ncell(template))))
  expect_error(ps_interpolate(p, methods = "UK", template = template,
                              covariates = bad_tables, trend = Z ~ cov),
               class = "potentiomap_covariate_error")
  expect_error(ps_interpolate(p, methods = "UK", template = template,
                              covariates = 1, trend = Z ~ cov),
               class = "potentiomap_covariate_error")
  expect_error(ps_interpolate(p, methods = "UK", template = template,
                              trend = head ~ X),
               class = "potentiomap_covariate_error")
})

test_that("anisotropy results and tuning controls are reusable inputs", {
  p <- expansion_points(12)
  empirical <- suppressWarnings(ps_variogram(p, cutoff = 5000,
                                              width = 500))
  anisotropy <- structure(
    list(major_direction = 30, range_ratio = 0.6),
    class = c("potentiomap_anisotropy", "potentiomap_analysis")
  )
  compared <- suppressWarnings(ps_variogram_compare(
    empirical, models = "Sph", anisotropy = anisotropy
  ))
  expect_s3_class(compared, "potentiomap_variogram_comparison")

  trend <- potentiomap:::.ps_candidate_control(
    data.frame(trend = "Z ~ X + Y", candidate_id = "candidate_0001"), "UK"
  )
  expect_s3_class(trend$trend, "formula")
  variogram <- potentiomap:::.ps_candidate_control(
    data.frame(model = "Sph", partial_sill = 2, range = 1000,
               nugget = 0.1, kappa = 0.5, anisotropy_angle = 25,
               anisotropy_ratio = 0.7, candidate_id = "candidate_0001"),
    "OK"
  )
  expect_s3_class(variogram$variogram_model, "variogramModel")
  expect_error(potentiomap:::.ps_uncertainty_layers(list(), c(0.1, 0.9)),
               class = "potentiomap_uncertainty_error")
})
