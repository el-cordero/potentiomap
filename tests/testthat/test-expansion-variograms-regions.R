test_that("variograms retain pair counts and candidate failures", {
  p <- expansion_points(20)
  v <- suppressWarnings(ps_variogram(p, cutoff = 1600, width = 200, directions = c(0, 90)))
  expect_s3_class(v, "potentiomap_variogram")
  expect_true(all(c("np", "dist", "gamma") %in% names(v$empirical)))
  expect_true(all(v$empirical$np >= 0))
  expect_match(v$settings$angle_convention, "clockwise")
  expect_error(ps_variogram(p, width = -1), class = "potentiomap_variogram_error")
  compared <- suppressWarnings(ps_variogram_compare(ps_variogram(p), c("Sph", "Exp")))
  expect_equal(nrow(compared$ranking), 2)
  expect_true(all(c("weighted_sse", "singular", "warning_count") %in% names(compared$ranking)))
  expect_error(ps_variogram_compare(v, select = TRUE), class = "potentiomap_variogram_error")
})

test_that("anisotropy reports modulo-180 direction and bounded ratio", {
  data("synthetic_anisotropic_points")
  p <- ps_make_points(synthetic_anisotropic_points, "x", "y", "head",
                      "point_id", "EPSG:26916")
  a <- suppressWarnings(ps_anisotropy(p, directions = c(0, 35, 90, 125),
                                     tolerance = 20, minimum_pairs = 5))
  expect_s3_class(a, "potentiomap_anisotropy")
  expect_true(is.na(a$range_ratio) || a$range_ratio > 0 && a$range_ratio <= 1)
  expect_true(is.na(a$major_direction) || a$major_direction >= 0 && a$major_direction < 180)
  expect_error(potentiomap:::.ps_apply_anisotropy_model(gstat::vgm(1, "Sph", 10), c(0, 1.2)),
               class = "potentiomap_anisotropy_error")
})

test_that("external drift uses explicit covariates and rejects bad coverage", {
  p <- expansion_points(16)
  template <- ps_interpolate(p, methods = "IDW", grid_res = 350,
                             return = "result")$template
  covariate <- template; xy <- terra::xyFromCell(covariate, seq_len(terra::ncell(covariate)))
  terra::values(covariate) <- (xy[, 1] - mean(xy[, 1])) / 1000; names(covariate) <- "land"
  z <- terra::extract(covariate, p)[[2]]; terra::values(p)$Z <- 160 + 2 * z
  fit <- suppressWarnings(ps_interpolate(p, methods = "UK", template = template,
                                        trend = Z ~ land,
                                        covariates = list(land = covariate),
                                        return = "result"))
  expect_equal(fit$diagnostics$UK$model_matrix_rank, 2)
  expect_equal(fit$diagnostics$UK$missing_prediction_covariates, 0)
  expect_identical(fit$fits$UK$formula, Z ~ land)
  constant <- covariate * 0 + 1; names(constant) <- "land"
  expect_error(ps_interpolate(p, methods = "UK", template = template,
                              trend = Z ~ land, covariates = list(land = constant)),
               class = "potentiomap_covariate_error")
  shifted <- terra::aggregate(covariate, 2)
  expect_error(ps_interpolate(p, methods = "UK", template = template,
                              trend = Z ~ land, covariates = list(land = shifted)),
               class = "potentiomap_covariate_error")
})

test_that("region splitting detects gaps, overlap, and boundary policy", {
  data("synthetic_regions")
  regions <- terra::vect(synthetic_regions, geom = "wkt", crs = "EPSG:26916")
  domain <- terra::as.polygons(terra::ext(500000, 503000, 4640000, 4642500), crs = "EPSG:26916")
  boundary <- terra::vect(data.frame(x = 501500, y = 4641000, Z = 1, Name = "B"),
                          geom = c("x", "y"), crs = "EPSG:26916")
  split <- ps_split_domain(domain, regions, "region_id", boundary,
                           boundary_action = "duplicate")
  expect_equal(nrow(split$point_assignments), 2)
  expect_equal(nrow(split$ambiguous_points), 1)
  gapped <- regions[1]
  expect_error(ps_split_domain(domain, gapped, "region_id", gap_action = "error"),
               class = "potentiomap_region_gap_error")
  overlap_data <- synthetic_regions
  overlap_data$wkt[2] <- "POLYGON ((501400 4640000, 503000 4640000, 503000 4642500, 501400 4642500, 501400 4640000))"
  overlap <- terra::vect(overlap_data, geom = "wkt", crs = "EPSG:26916")
  expect_error(ps_split_domain(domain, overlap, "region_id"),
               class = "potentiomap_region_overlap_error")
})

test_that("regional interpolation never shares observations across regions", {
  p <- expansion_points(20); data("synthetic_regions")
  regions <- terra::vect(synthetic_regions, geom = "wkt", crs = "EPSG:26916")
  result <- ps_interpolate_regions(p, regions, "region_id", "IDW", grid_res = 350)
  expect_s3_class(result, "potentiomap_regional_result")
  expect_equal(nrow(result$region_method_manifest), 2)
  ids <- strsplit(result$region_method_manifest$observation_ids, "\\|")
  expect_length(intersect(ids[[1]], ids[[2]]), 0)
  expect_true(all(result$region_method_manifest$status %in% c("success", "underpopulated")))
  expect_match(result$warnings, "without cross-boundary smoothing")
})
