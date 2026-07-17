test_that("observation QA reports deterministic errors separately from review flags", {
  d <- data.frame(
    id = c("A", "A", "B", "C", "D", "E"),
    x = c(0, 10, 10, NA, 30, 40),
    y = c(0, 0, 0, 20, 30, 40),
    head = c(100, 101, 105, 103, Inf, 1000),
    time = c("2026-01-01 00:00", "2026-01-01 00:00",
             "2026-01-02 12:00", "2026-01-03 12:00",
             "2026-01-04 12:00", "2026-01-05 12:00"),
    unit = c("m", "m", "m", "m", "m", NA),
    datum = c("NAVD88", "NAVD88", "NAVD88", "NAVD88", NA, "NAVD88"),
    depth = c(10, -2, 5, 5, 5, 5),
    land = c(110, 110, 120, 108, 110, 110),
    top = c(104, 99, 110, NA, 120, 101),
    bottom = c(90, 105, 100, 80, 100, 99),
    group = c("shallow", "shallow", NA, "deep", "deep", "deep"),
    stringsAsFactors = FALSE
  )
  attr(d, "crs") <- "EPSG:26916"

  checked <- ps_check_observations(
    d, "x", "y", "head", "id", datetime = "time", unit = "unit",
    vertical_datum = "datum", depth = "depth",
    surface_elevation = "land", screen_top = "top",
    screen_bottom = "bottom", unit_group = "group",
    duplicate_tolerance = 0, action = "return_clean"
  )
  codes <- unique(checked$issues$issue_code)
  expect_true(all(c(
    "missing_coordinate", "nonfinite_head", "missing_unit",
    "missing_vertical_datum", "duplicate_well_datetime",
    "non_synoptic_span", "duplicate_coordinate",
    "same_id_different_coordinate", "conflicting_head",
    "invalid_depth_sign", "inconsistent_surface_minus_depth",
    "reversed_screen_interval", "head_outside_screen",
    "missing_screen_information", "ambiguous_unit_group"
  ) %in% codes))
  expect_gt(nrow(checked$removed), 0)
  expect_true("removal_reason" %in% names(checked$removed))
  expect_equal(nrow(as.data.frame(checked)), nrow(checked$issues))

  no_crs <- d
  attr(no_crs, "crs") <- NULL
  missing_crs <- ps_check_observations(no_crs, "x", "y", "head", "id")
  expect_true("missing_crs" %in% missing_crs$issues$issue_code)
  expect_error(ps_check_observations(list(a = 1)),
               class = "potentiomap_validation_error")
})

test_that("event-selection rules, ties, windows, and span gates are explicit", {
  d <- data.frame(
    well = c("A", "A", "A", "B", "B", "C"),
    time = c("2026-01-01 00:00", "2026-01-01 02:00",
             "2026-01-01 08:00", "2026-01-01 00:30",
             "2026-01-01 03:00", "2026-01-02 00:00"),
    quality = c(2, 1, 0, 1, 2, 1), value = seq_len(6),
    stringsAsFactors = FALSE
  )
  center <- "2026-01-01 01:00"
  nearest <- ps_select_event(d, "well", "time", center,
                             as.difftime(4, units = "hours"), "nearest")
  earliest <- ps_select_event(d, "well", "time", center, 4 * 3600,
                              "earliest")
  latest <- ps_select_event(d, "well", "time", center, 4 * 3600,
                            "latest")
  best <- ps_select_event(d, "well", "time", center, 4 * 3600,
                          "best_quality", quality = "quality")
  expect_equal(nrow(nearest$selected), 2)
  expect_gt(nrow(nearest$ties), 0)
  expect_lt(earliest$selected$value[earliest$selected$well == "A"],
            latest$selected$value[latest$selected$well == "A"])
  expect_equal(best$selected$value[best$selected$well == "A"], 2)
  expect_true("outside_window" %in% nearest$excluded$exclusion_reason)
  expect_warning(ps_select_event(
    d, "well", "time", center, 4 * 3600,
    maximum_span = 60, maximum_span_action = "warn"
  ), class = "potentiomap_event_selection_warning")
  expect_error(ps_select_event(
    d, "well", "time", center, 4 * 3600,
    maximum_span = 60, maximum_span_action = "error"
  ), class = "potentiomap_event_selection_error")
  expect_error(ps_select_event(d, "well", "time", center, 100,
                               "best_quality"),
               class = "potentiomap_event_selection_error")
})

test_that("screen grouping covers existing labels, descriptive bins, and ambiguity", {
  d <- data.frame(
    well = LETTERS[1:5], top = c(20, 15, 10, 5, NA),
    bottom = c(15, 10, 5, 0, 1),
    unit = c("u1", "u1", "u2", NA, "u3"),
    stringsAsFactors = FALSE
  )
  existing <- suppressWarnings(ps_screen_groups(
    d, "existing", unit_col = "unit", screen_top = "top",
    screen_bottom = "bottom"
  ))
  bins <- suppressWarnings(ps_screen_groups(
    d, "depth_bins", screen_top = "top", screen_bottom = "bottom",
    breaks = c(0, 8, 14, 20), labels = c("low", "middle", "high")
  ))
  expect_equal(nrow(existing$assigned), nrow(d))
  expect_true(all(na.omit(bins$assigned$screen_group) %in%
                    c("low", "middle", "high")))
  expect_match(bins$rules$mode[1], "descriptive")

  rules <- data.frame(unit = c("one", "two"), top = c(22, 18),
                      bottom = c(8, 4))
  suppressWarnings(expect_error(ps_screen_groups(
    d, "rules", screen_top = "top", screen_bottom = "bottom",
    rules = rules, overlap_required = .2, ambiguous_action = "error"
  ), class = "potentiomap_screen_group_error"))
  suppressWarnings(expect_error(ps_screen_groups(
    d, "depth_bins", screen_top = "top", screen_bottom = "bottom",
    breaks = c(0, 10, 5)
  ), class = "potentiomap_screen_group_error"))
  suppressWarnings(expect_error(ps_screen_groups(
    d, "existing", screen_top = "top", screen_bottom = "bottom"
  ), class = "potentiomap_screen_group_error"))
})
