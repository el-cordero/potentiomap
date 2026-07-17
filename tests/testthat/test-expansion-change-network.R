test_that("head change separates paired measurements and modeled differences", {
  p <- expansion_points(12); b <- p
  terra::values(b)$Z <- terra::values(b)$Z - 0.75
  b <- b[-c(1, 2)]; extra <- p[1]; terra::values(extra)$well_id <- "NEW"; terra::values(extra)$Name <- "NEW"; b <- rbind(b, extra)
  change <- ps_head_change(p, b, "well_id", method = "IDW", grid_res = 350)
  expect_s3_class(change, "potentiomap_head_change")
  expect_equal(change$summary$paired_wells, 10)
  expect_equal(change$summary$event_a_only, 2)
  expect_equal(change$summary$event_b_only, 1)
  expect_equal(change$paired_measured_change$measured_change_b_minus_a, rep(-0.75, 10))
  expect_identical(change$settings$sign, "event B minus event A")
  expect_false(any(grepl("storage|volume", names(change), ignore.case = TRUE)))
})

test_that("leave-one-well influence retains every run and never labels errors", {
  p <- expansion_points(7)
  influence <- ps_well_influence(p, "IDW", grid_res = 400)
  expect_equal(nrow(influence$influence), nrow(p))
  expect_setequal(influence$influence$well_id, terra::values(p)$Name)
  expect_true(all(influence$influence$status %in% c("success", "failed")))
  expect_false(any(grepl("data_error|erroneous", names(influence$influence))))
  expect_match(influence$warnings, "not an automatic removal")
})

test_that("network thinning reports exact and duplicate retained sets", {
  p <- expansion_points(10); ids <- terra::values(p)$Name
  user_sets <- list(ids[1:7], ids[1:7], ids[4:10])
  thin <- ps_network_thinning(p, design = "user", subsets = user_sets,
                              method = "IDW", grid_res = 400, seed = 4)
  expect_equal(thin$run_manifest$retained_count, rep(7, 3))
  expect_true(any(thin$run_manifest$duplicate_retained_set))
  expect_equal(thin$summary$unique_retained_sets, 2)
  for (i in seq_len(nrow(thin$retained_well_manifest))) {
    retained <- strsplit(thin$retained_well_manifest$retained_ids[i], "\\|")[[1]]
    held <- strsplit(thin$retained_well_manifest$held_out_ids[i], "\\|")[[1]]
    expect_length(intersect(retained, held), 0)
  }
  expect_match(thin$warnings, "descriptive")
})

test_that("candidate selection enforces exclusions, spacing, and cost arithmetic", {
  p <- expansion_points(12)
  xy <- terra::crds(p)[1:6, ] + cbind(c(10, 200, 400, 600, 800, 1000), 300)
  candidates <- terra::vect(data.frame(x = xy[, 1], y = xy[, 2], Name = paste0("C", 1:6)),
                            geom = c("x", "y"), crs = terra::crs(p))
  exclusion <- terra::buffer(candidates[1], 50)
  cost <- 1:6
  result <- ps_candidate_network(p, candidates, "spatial_coverage", n_select = 2,
                                 exclusion_area = exclusion,
                                 minimum_existing_distance = 50,
                                 minimum_candidate_distance = 50, cost = cost)
  expect_false("C1" %in% result$selected_sequence$candidate_id)
  expect_equal(result$selected_sequence$gain_per_unit_cost,
               result$selected_sequence$information_gain /
                 cost[match(result$selected_sequence$candidate_id, paste0("C", 1:6))])
  expect_match(result$warnings, "not globally optimal")
  expect_error(ps_candidate_network(p, candidates, "user_score", n_select = 1),
               class = "potentiomap_candidate_network_error")
})

test_that("sensitivity preserves failed scenarios and exact reference identity", {
  p <- expansion_points(12)
  scenarios <- data.frame(idw_power = c(2, 1.5, -1), grid_res = 350)
  result <- ps_surface_sensitivity(p, "IDW", scenarios, reference = 1)
  expect_equal(nrow(result$run_manifest), 3)
  reference <- subset(result$comparisons, scenario_id == result$settings$reference_id)
  expect_equal(reference$mean_absolute_difference, 0)
  expect_true(any(result$run_manifest$status == "failed"))
  expect_error(ps_surface_sensitivity(p, "IDW", scenarios, maximum_runs = 2),
               class = "potentiomap_sensitivity_error")
})
