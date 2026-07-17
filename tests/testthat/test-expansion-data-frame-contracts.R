test_that("analysis result classes expose their documented primary tables", {
  table <- data.frame(id = "row_1", value = 1)
  make_result <- function(class, field) {
    out <- list()
    out[[field]] <- table
    class(out) <- c(class, "potentiomap_analysis")
    out
  }

  contracts <- list(
    potentiomap_observation_check = "issues",
    potentiomap_event_selection = "selected",
    potentiomap_screen_groups = "assigned",
    potentiomap_surface_comparison = "summary",
    potentiomap_disagreement = "pairwise_summary",
    potentiomap_depth_surface = "summary",
    potentiomap_variogram = "empirical",
    potentiomap_variogram_comparison = "ranking",
    potentiomap_anisotropy = "summary",
    potentiomap_validation = "predictions",
    potentiomap_method_comparison = "ranking",
    potentiomap_tuning = "candidates",
    potentiomap_uncertainty = "realization_manifest",
    potentiomap_contour_uncertainty = "level_manifest",
    potentiomap_head_change = "paired_measured_change",
    potentiomap_well_influence = "influence",
    potentiomap_network_thinning = "run_manifest",
    potentiomap_candidate_network = "candidate_scores",
    potentiomap_sensitivity = "comparisons",
    potentiomap_domain_split = "point_assignments",
    potentiomap_regional_result = "region_method_manifest",
    potentiomap_profile = "profile",
    potentiomap_cross_section = "profile"
  )
  for (class_name in names(contracts)) {
    expect_identical(as.data.frame(make_result(class_name, contracts[[class_name]])),
                     table, info = class_name)
  }
})

test_that("observation checking accepts sf and event/screen errors are explicit", {
  d <- data.frame(id = c("A", "B"), head = c(10, 11),
                  x = c(-66.1, -66), y = c(18.1, 18.2))
  sf_points <- sf::st_as_sf(d, coords = c("x", "y"), crs = 4326)
  checked <- ps_check_observations(sf_points, value = "head", id = "id")
  expect_true(any(checked$issues$issue_code ==
                    "geographic_crs_for_planar_analysis"))

  event <- data.frame(well = "A", time = "2026-01-01 00:00")
  expect_error(ps_select_event(event, "missing", "time",
                               "2026-01-01", 3600),
               class = "potentiomap_event_selection_error")
  event$time <- "not-a-time"
  expect_error(ps_select_event(event, "well", "time",
                               "2026-01-01", 3600),
               class = "potentiomap_event_selection_error")

  screens <- data.frame(top = 10, bottom = 5)
  expect_error(ps_screen_groups(screens, "existing", unit_col = "unit",
                                screen_top = "absent", screen_bottom = "bottom"),
               class = "potentiomap_screen_group_error")
  expect_error(ps_screen_groups(screens, "rules", screen_top = "top",
                                screen_bottom = "bottom", rules = data.frame()),
               class = "potentiomap_screen_group_error")
  expect_error(ps_screen_groups(screens, "rules", screen_top = "top",
                                screen_bottom = "bottom",
                                rules = data.frame(unit = c("a", "a"),
                                                   top = c(10, 9),
                                                   bottom = c(5, 4))),
               class = "potentiomap_screen_group_error")
  expect_error(ps_screen_groups(screens, "depth_bins", screen_top = "top",
                                screen_bottom = "bottom", breaks = c(0, 20),
                                labels = character()),
               class = "potentiomap_screen_group_error")
})

test_that("style breaks can be inferred from a general analysis result", {
  r <- make_plane("east")
  analysis <- structure(list(mapped_surface = r),
                        class = c("potentiomap_analysis", "list"))
  out <- tempfile(fileext = ".qml")
  exported <- ps_export_style(analysis, out, format = "qml",
                              layer_type = "head_raster")
  expect_true(exported$manifest$validated)
  expect_true(file.exists(out))
})

test_that("geodesic profile interpolation handles repeated segment vertices", {
  point <- c(-66.1, 18.2)
  interpolated <- potentiomap:::.ps_slerp_lonlat(point, point, 0.5)
  expect_equal(interpolated, point, tolerance = 1e-12)
})
