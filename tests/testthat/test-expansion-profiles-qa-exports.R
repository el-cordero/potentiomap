test_that("observation QA inventories deterministic issues without deleting outliers", {
  d <- data.frame(id = c("A", "A", NA), x = c(1, 1, Inf), y = c(2, 2, 3),
                  head = c(10, 30, NA), unit = c("m", "m", NA),
                  datum = c("D", "D", NA), depth = c(2, -1, 1),
                  land = c(12, 12, 10), top = c(9, 8, NA), bottom = c(8, 9, NA),
                  time = c(NA, NA, NA), group = c("A", "B", NA))
  attr(d, "crs") <- "EPSG:26920"
  checked <- ps_check_observations(d, "x", "y", "head", "id", "time",
                                   "unit", "datum", "depth", "land",
                                   "top", "bottom", "group")
  expected <- c("missing_identifier", "nonfinite_coordinate", "missing_head",
                "missing_unit", "missing_vertical_datum", "duplicate_coordinate",
                "conflicting_head", "invalid_depth_sign", "reversed_screen_interval",
                "missing_screen_information", "missing_event_time",
                "ambiguous_unit_group")
  expect_true(all(expected %in% checked$issues$issue_code))
  expect_equal(nrow(checked$retained), nrow(d))
  expect_s3_class(checked, "potentiomap_observation_check")
})

test_that("event selection is deterministic, zoned, and never averages", {
  d <- data.frame(well = c("A", "A", "B"),
                  time = c("2026-01-01 00:00", "2026-01-01 02:00", "2026-01-01 01:00"),
                  head = c(10, 12, 11))
  selected <- ps_select_event(d, "well", "time", "2026-01-01 01:00", 7200,
                              timezone = "America/Puerto_Rico")
  expect_equal(nrow(selected$selected), 2)
  expect_equal(selected$summary$tie_count, 2)
  expect_equal(selected$selected$head[selected$selected$well == "A"], 10)
  expect_identical(attr(selected$selected$time, "tzone"), "America/Puerto_Rico")
  expect_warning(ps_select_event(d, "well", "time", "2026-01-01 01:00", 7200,
                                 maximum_span = 1),
                 class = "potentiomap_event_selection_warning")
})

test_that("screen groups preserve labels and descriptive terminology", {
  d <- data.frame(well = c("A", "B"), unit = c("sand", "gravel"),
                  top = c(10, 5), bottom = c(8, 1))
  existing <- ps_screen_groups(d, "existing", unit_col = "unit",
                               screen_top = "top", screen_bottom = "bottom")
  expect_identical(existing$assigned$screen_group, d$unit)
  bins <- ps_screen_groups(d, "depth_bins", screen_top = "top",
                           screen_bottom = "bottom", breaks = c(0, 6, 12))
  expect_true(all(grepl("descriptive_screen_bin", bins$rules$label)))
  rules <- data.frame(unit = c("one", "two"), top = c(12, 11), bottom = c(6, 7))
  expect_warning(amb <- ps_screen_groups(d, "rules", screen_top = "top",
                                         screen_bottom = "bottom", rules = rules,
                                         overlap_required = 0.25),
                 class = "potentiomap_screen_group_warning")
  expect_gt(nrow(amb$ambiguous), 0)
})

test_that("profiles and cross-sections retain chainage, NA support, and offsets", {
  p <- expansion_points(16); fit <- ps_interpolate(p, methods = "IDW", grid_res = 300, return = "result")
  extent <- terra::ext(fit$surfaces$IDW); y <- mean(c(extent[3], extent[4]))
  line <- terra::vect(data.frame(wkt = sprintf("LINESTRING (%f %f, %f %f)", extent[1], y, extent[2], y)), geom = "wkt", crs = terra::crs(p))
  profile <- ps_surface_profile(line, list(head = fit$surfaces$IDW), n = 11)
  expect_equal(nrow(profile$profile), 11)
  expect_true(all(diff(profile$profile$chainage) >= 0))
  expect_equal(length(unique(profile$profile$line_id)), 1)
  section <- ps_cross_section(line, fit$surfaces$IDW, wells = p,
                              maximum_well_offset = 200,
                              step = 300, vertical_exaggeration = 4)
  expect_equal(section$settings$vertical_exaggeration, 4)
  expect_true(all(section$wells$perpendicular_offset <= 200))
  expect_equal(nrow(section$wells) + nrow(section$omitted_wells), nrow(p))
  expect_match(section$warnings, "not a three-dimensional")
  expect_error(ps_surface_profile(line, list(head = fit$surfaces$IDW), step = 10, n = 5),
               class = "potentiomap_profile_error")
})

test_that("geodesic profiles use explicit metre chainage on longitude-latitude data", {
  surface <- terra::rast(nrows = 20, ncols = 20,
                         xmin = -66.2, xmax = -65.8,
                         ymin = 18.0, ymax = 18.4,
                         crs = "EPSG:4326", vals = seq_len(400))
  line <- terra::vect(
    data.frame(wkt = "LINESTRING (-66.15 18.05, -66.0 18.2, -65.85 18.35)"),
    geom = "wkt", crs = "EPSG:4326"
  )

  profile <- ps_surface_profile(
    line, list(head = surface), n = 9, distance_method = "geodesic"
  )

  expect_equal(nrow(profile$profile), 9)
  expect_equal(profile$profile$chainage[1], 0)
  expect_true(all(diff(profile$profile$chainage) > 0))
  expect_gt(max(profile$profile$chainage), 30000)
  expect_lt(max(profile$profile$chainage), 60000)
  expect_error(
    ps_surface_profile(line, list(head = surface), n = 9,
                       distance_method = "projected"),
    class = "potentiomap_profile_error"
  )
})

test_that("style files parse, distinguish support, and protect overwrite", {
  r <- expansion_raster(); qml <- tempfile(fileext = ".qml"); sld <- tempfile(fileext = ".sld")
  on.exit(unlink(c(qml, sld)), add = TRUE)
  q <- ps_export_style(r, qml, "qml", "head_raster", units = "m")
  s <- ps_export_style(NULL, sld, "sld", "contour_support", field = "support")
  expect_true(q$manifest$validated && s$manifest$validated)
  expect_silent(xml2::read_xml(qml)); expect_silent(xml2::read_xml(sld))
  text <- paste(readLines(sld, warn = FALSE), collapse = " ")
  expect_match(text, "stroke-dasharray")
  expect_match(text, "support")
  expect_false(grepl(normalizePath(tempdir()), text, fixed = TRUE))
  expect_error(ps_export_style(r, qml, "qml", "head_raster"),
               class = "potentiomap_export_error")
})

test_that("minimal reports render with escaped title and overwrite protection", {
  skip_if_not(rmarkdown::pandoc_available())
  checked <- ps_check_observations(expansion_points(8), value = "Z", id = "Name")
  html <- tempfile(fileext = ".html"); on.exit(unlink(html), add = TRUE)
  manifest <- ps_report(checked, html, "html", title = "QA <unsafe>",
                        include_session = FALSE)
  expect_s3_class(manifest, "potentiomap_report_manifest")
  expect_true(file.exists(html)); expect_gt(file.info(html)$size, 0)
  output <- paste(readLines(html, warn = FALSE), collapse = "\n")
  expect_false(grepl("QA <unsafe>", output, fixed = TRUE))
  expect_error(ps_report(checked, html, "html"), class = "potentiomap_report_error")
})
