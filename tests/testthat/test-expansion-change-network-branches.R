test_that("head change validates event order, pairing, metadata, and gradient choice", {
  p <- expansion_points(10)
  b <- p
  terra::values(b)$Z <- terra::values(b)$Z + 1
  attr(p, "potentiomap_metadata") <- list(head_unit = "m",
                                           vertical_datum = "NAVD88")
  attr(b, "potentiomap_metadata") <- list(head_unit = "m",
                                           vertical_datum = "NAVD88")
  changed <- ps_head_change(
    p, b, "well_id", event_a_time = "2026-01-01",
    event_b_time = "2026-02-01", method = "IDW", grid_res = 500,
    compare_gradient = FALSE
  )
  expect_null(changed$gradient_direction_change)
  expect_equal(changed$summary$mean_paired_change, 1)
  expect_equal(nrow(as.data.frame(changed)), nrow(p))

  expect_error(ps_head_change(
    p, b, "well_id", event_a_time = "2026-02-01",
    event_b_time = "2026-01-01", method = "IDW", grid_res = 500
  ), class = "potentiomap_head_change_error")
  duplicate <- rbind(b, b[1])
  expect_error(ps_head_change(p, duplicate, "well_id", method = "IDW",
                              grid_res = 500),
               class = "potentiomap_input_error")
  incompatible <- b
  attr(incompatible, "potentiomap_metadata") <- list(head_unit = "ft",
                                                       vertical_datum = "NAVD88")
  expect_error(ps_head_change(p, incompatible, "well_id", method = "IDW",
                              grid_res = 500),
               class = "potentiomap_metadata_error")
})

test_that("well influence covers successful and failed leave-one-out fits", {
  p <- expansion_points(7)
  progress <- list()
  successful <- suppressWarnings(ps_well_influence(
    p, "IDW", grid_res = 500, contour_levels = c(168, 170),
    difference_threshold = .5,
    progress = function(index, total, run_id, status) {
      progress[[length(progress) + 1L]] <<- status
    }
  ))
  expect_equal(nrow(successful$influence), 7)
  expect_true(all(is.finite(successful$influence$affected_area_m2)))
  expect_gt(length(progress), 0)

  five <- expansion_points(5)
  failed <- suppressWarnings(ps_well_influence(five, "IDW", grid_res = 600))
  expect_true(all(failed$influence$status == "failed"))
  expect_true(all(is.na(failed$influence$held_out_prediction)))
  expect_gt(nrow(failed$conditions), 0)
})

test_that("network thinning covers random, spatial maximin, user, and failed subsets", {
  p <- expansion_points(10)
  random <- ps_network_thinning(p, retain = .7, design = "random",
                                method = "IDW", repeats = 2,
                                grid_res = 500, seed = 17)
  spatial_a <- ps_network_thinning(p, retain = 6, design = "spatial_coverage",
                                   method = "IDW", repeats = 2,
                                   grid_res = 500, seed = 17)
  spatial_b <- ps_network_thinning(p, retain = 6, design = "spatial_coverage",
                                   method = "IDW", repeats = 2,
                                   grid_res = 500, seed = 17)
  expect_equal(nrow(random$run_manifest), 2)
  expect_identical(spatial_a$retained_well_manifest$retained_ids,
                   spatial_b$retained_well_manifest$retained_ids)
  expect_equal(nrow(as.data.frame(random)), 2)

  ids <- terra::values(p)$Name
  failed <- ps_network_thinning(
    p, design = "user", subsets = list(ids[1:2]),
    method = "IDW", grid_res = 500
  )
  expect_identical(failed$run_manifest$status, "failed")
  expect_equal(failed$run_manifest$prediction_coverage, 0)
  expect_error(ps_network_thinning(p, design = "user", subsets = list()),
               class = "potentiomap_network_error")
  expect_error(ps_network_thinning(p, retain = 1, design = "random"),
               class = "potentiomap_network_error")
  expect_error(ps_network_thinning(p, design = "user",
                                   subsets = list(c(ids[1], ids[1]))),
               class = "potentiomap_network_error")
})

test_that("candidate objectives retain constraints and conditional variance assumptions", {
  p <- expansion_points(12)
  xy <- terra::crds(p)[1:5, ] + cbind(seq(200, 1000, by = 200), 500)
  candidates <- terra::vect(
    data.frame(x = xy[, 1], y = xy[, 2], Z = mean(terra::values(p)$Z),
               Name = paste0("C", 1:5)),
    geom = c("x", "y"), crs = terra::crs(p)
  )
  target <- terra::vect(
    data.frame(x = xy[, 1] + 300, y = xy[, 2] + 300),
    geom = c("x", "y"), crs = terra::crs(p)
  )
  support <- ps_candidate_network(
    p, candidates, "support_gap", n_select = 2, target = target,
    minimum_candidate_distance = 100
  )
  user <- ps_candidate_network(
    p, candidates, "user_score", n_select = 2,
    user_score = c(1, 5, 3, 2, 4), sequential = FALSE
  )
  variance <- ps_candidate_network(
    p, candidates, "kriging_variance_reduction", n_select = 1,
    target = target, variogram_model = gstat::vgm(4, "Sph", 1500, .5),
    trend = Z ~ 1
  )
  expect_equal(nrow(support$selected_sequence), 2)
  expect_identical(user$selected_sequence$candidate_id, c("C2", "C5"))
  expect_true(is.finite(variance$target_summary$variance_before))
  expect_match(variance$warnings, "conditional")

  expect_error(ps_candidate_network(p, candidates, n_select = 6),
               class = "potentiomap_candidate_network_error")
  expect_error(ps_candidate_network(p, candidates, "support_gap"),
               class = "potentiomap_candidate_network_error")
  expect_error(ps_candidate_network(p, candidates, "user_score",
                                    user_score = c(1, 2)),
               class = "potentiomap_candidate_network_error")
  expect_error(ps_candidate_network(p, candidates, cost = c(1, 2)),
               class = "potentiomap_candidate_network_error")
  expect_error(ps_candidate_network(p, candidates,
                                    "kriging_variance_reduction"),
               class = "potentiomap_candidate_network_error")
})

test_that("surface sensitivity handles grids, references, alignment, progress, and failures", {
  p <- expansion_points(12)
  progress <- list()
  result <- ps_surface_sensitivity(
    p, "IDW",
    list(idw_power = c(1.5, 2), grid_res = c(350, 500)),
    reference = "scenario_0001", contour_levels = c(168, 170),
    progress = function(index, total, run_id, status) {
      progress[[length(progress) + 1L]] <<- status
    }
  )
  expect_equal(nrow(result$scenarios), 4)
  expect_equal(result$settings$reference_id, "scenario_0001")
  expect_gt(length(progress), 0)
  expect_true(all(result$run_manifest$status == "success"))

  failed_nonreference <- ps_surface_sensitivity(
    p, "IDW",
    data.frame(scenario_id = c("reference", "bad"),
               idw_power = c(2, -1), grid_res = 400),
    reference = "reference"
  )
  expect_true(is.na(failed_nonreference$comparisons$rmse_difference[
    failed_nonreference$comparisons$scenario_id == "bad"
  ]))
  expect_error(ps_surface_sensitivity(
    p, "IDW", data.frame(scenario_id = "bad", idw_power = -1,
                          grid_res = 400), reference = "bad"
  ), class = "potentiomap_sensitivity_error")
  expect_error(ps_surface_sensitivity(
    p, "IDW", data.frame(scenario_id = c("x", "x"),
                          idw_power = c(1, 2), grid_res = 400)
  ), class = "potentiomap_sensitivity_error")
  expect_error(ps_surface_sensitivity(p, "IDW", list()),
               class = "potentiomap_sensitivity_error")
})
