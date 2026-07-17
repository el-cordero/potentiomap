test_that("empirical variograms support residual formulas, boundaries, clouds, and robust estimates", {
  p <- expansion_points(16)
  pv <- terra::values(p)
  pv$elevation <- seq_len(nrow(p))
  terra::values(p) <- pv

  residual <- suppressWarnings(ps_variogram(
    p, Z ~ elevation, cutoff = 2500,
    boundaries = c(250, 500, 1000, 1750, 2500),
    directions = c(-45, 0, 225), direction_tolerance = 25,
    robust = TRUE
  ))
  cloud <- suppressWarnings(ps_variogram(
    p, cutoff = 1500, width = 250, cloud = TRUE
  ))
  expect_identical(residual$formula, Z ~ elevation)
  expect_equal(residual$directions, c(135, 0, 45))
  expect_true(residual$settings$robust)
  expect_true(cloud$settings$cloud)
  expect_gt(nrow(as.data.frame(cloud)), 0)

  expect_error(ps_variogram(p, formula = "Z ~ 1"),
               class = "potentiomap_variogram_error")
  expect_error(ps_variogram(p, Z ~ absent),
               class = "potentiomap_variogram_error")
  expect_error(ps_variogram(p, cutoff = 0),
               class = "potentiomap_variogram_error")
  expect_error(ps_variogram(p, boundaries = c(100, 50)),
               class = "potentiomap_variogram_error")
  expect_error(ps_variogram(p, directions = numeric()),
               class = "potentiomap_variogram_error")
  expect_error(ps_variogram(p, direction_tolerance = 91),
               class = "potentiomap_variogram_error")
})

test_that("variogram fitting retains supplied starts, anisotropy, validation, and selection", {
  p <- expansion_points(20)
  empirical <- suppressWarnings(ps_variogram(p, cutoff = 2500, width = 250))
  starts <- list(
    Sph = list(psill = 4, range = 1000, nugget = .5),
    Exp = list(psill = 4, range = 900, nugget = .5)
  )
  validation <- data.frame(model = c("Sph", "Exp"), rmse = c(1.2, 1.4))
  compared <- suppressWarnings(ps_variogram_compare(
    empirical, c("Sph", "Exp"), initial = starts,
    anisotropy = c(30, .7), validation = validation,
    select = TRUE, selection_metric = "validation_rmse"
  ))
  expect_equal(compared$ranking$validation_rmse, c(1.2, 1.4))
  expect_true(is.null(compared$selection) ||
                compared$selection %in% compared$ranking$candidate_id)
  expect_equal(compared$fits$variogram_0001$initial$ang1[2], 30)
  expect_equal(compared$fits$variogram_0001$initial$anis1[2], .7)

  sse <- suppressWarnings(ps_variogram_compare(
    empirical, "Sph", initial = gstat::vgm(4, "Sph", 1000, .5),
    select = TRUE, selection_metric = "weighted_sse"
  ))
  expect_equal(nrow(sse$ranking), 1)
  expect_error(ps_variogram_compare(data.frame(x = 1)),
               class = "potentiomap_variogram_error")
  expect_error(ps_variogram_compare(empirical, c("Sph", "Sph")),
               class = "potentiomap_variogram_error")
  expect_error(ps_variogram_compare(empirical, "Sph", initial = "bad"),
               class = "potentiomap_variogram_error")
  expect_error(ps_variogram_compare(
    empirical, "Sph", validation = data.frame(method = "Sph", value = 1),
    selection_metric = "validation_rmse"
  ), class = "potentiomap_variogram_error")
})

test_that("anisotropy weak evidence and activation rules stay explicit", {
  p <- expansion_points(12)
  weak <- suppressWarnings(ps_anisotropy(
    p, directions = c(0, 90), minimum_pairs = 10000,
    validation = TRUE
  ))
  expect_match(weak$validation, "requested")
  expect_equal(weak$summary$usable_directions, 0)
  expect_error(ps_anisotropy(p, validation = NA),
               class = "potentiomap_anisotropy_error")
  expect_error(potentiomap:::.ps_apply_anisotropy_model(
    gstat::vgm(1, "Sph", 10), list(angle = 0, ratio = .5)
  ), class = "potentiomap_anisotropy_error")
})

test_that("external drift supports aligned rasters, point-grid tables, and user covariance", {
  p <- expansion_points(16)
  base <- ps_interpolate(p, "Z", "IDW", grid_res = 400,
                         return = "result")
  template <- base$template
  coarse <- terra::aggregate(template, 2)
  xy <- terra::xyFromCell(coarse, seq_len(terra::ncell(coarse)))
  terra::values(coarse) <- scale(xy[, 1])[, 1]
  names(coarse) <- "drift"

  aligned <- suppressWarnings(ps_interpolate(
    p, methods = "UK", template = template, trend = Z ~ drift,
    covariates = list(drift = coarse), covariate_alignment = "bilinear",
    variogram_model = gstat::vgm(4, "Sph", 1500, .5),
    anisotropy = c(20, .8),
    kriging_control = list(nmax = 10, nmin = 0, maxdist = Inf),
    return = "result"
  ))
  expect_identical(aligned$fits$UK$variogram_model_origin,
                   "user_supplied_not_refitted")
  expect_true(any(aligned$fits$UK$covariate_manifest$alignment == "bilinear"))

  point_values <- terra::extract(terra::resample(coarse, template), p)[[2]]
  grid_values <- terra::values(terra::resample(coarse, template), mat = FALSE)
  tabular <- suppressWarnings(ps_interpolate(
    p, methods = "UK", template = template, trend = Z ~ drift,
    covariates = list(points = data.frame(drift = point_values),
                      grid = data.frame(drift = grid_values)),
    variogram_model = gstat::vgm(4, "Sph", 1500, .5),
    return = "result"
  ))
  expect_true(any(tabular$fits$UK$covariate_manifest$alignment ==
                    "supplied_point_grid"))

  expect_error(ps_interpolate(
    p, methods = "UK", template = template, trend = Z ~ absent,
    covariates = list(drift = terra::resample(coarse, template))
  ), class = "potentiomap_covariate_error")
  expect_error(ps_interpolate(
    p, methods = "UK", template = template,
    kriging_control = list(unknown = 1)
  ), class = "potentiomap_covariate_error")
  expect_error(ps_interpolate(
    p, methods = "UK", template = template,
    kriging_control = list(nmin = -1)
  ), class = "potentiomap_covariate_error")
  expect_error(ps_interpolate(
    p, methods = "UK", template = template,
    variogram_model = list(psill = 1)
  ), class = "potentiomap_variogram_error")
})
