test_that("structured-result utilities preserve summaries, conditions, and print behavior", {
  empty <- potentiomap:::.ps_new_result(list(value = 1),
                                        "potentiomap_test_result")
  expect_s3_class(empty, "potentiomap_analysis")
  expect_equal(nrow(empty$summary), 0)
  listed <- potentiomap:::.ps_new_result(
    list(value = 1), "potentiomap_test_result",
    summary = list(a = 1),
    conditions = potentiomap:::.ps_condition_rows(
      list(simpleWarning("review")), "test"
    )
  )
  output <- capture.output(print(listed))
  expect_true(any(grepl("conditions: 1", output, fixed = TRUE)))
  expect_true(any(grepl("a", output, fixed = TRUE)))
})

test_that("progress, scalar, stable-ID, and condition helpers validate contracts", {
  values <- list()
  expect_null(potentiomap:::.ps_progress(NULL, 1, 1, "x", "started"))
  potentiomap:::.ps_progress(function(...) values[[1]] <<- list(...),
                             1, 2, "run", "success")
  expect_equal(values[[1]][[1]], 1)
  expect_error(potentiomap:::.ps_progress(TRUE, 1, 1, "x", "started"),
               class = "potentiomap_input_error")
  expect_error(potentiomap:::.ps_scalar_logical(NA, "flag"),
               class = "potentiomap_input_error")
  expect_null(potentiomap:::.ps_scalar_character(NULL, "name", TRUE))
  expect_error(potentiomap:::.ps_scalar_character("", "name"),
               class = "potentiomap_input_error")
  expect_length(potentiomap:::.ps_stable_ids("id", 0), 0)
  expect_equal(nrow(potentiomap:::.ps_condition_rows()), 0)
})

test_that("standard-point conversion retains IDs across sf and attributed tables", {
  table <- data.frame(x = 1:5, y = 6:10, head = 11:15,
                      id = paste0("W", 1:5))
  attr(table, "crs") <- "EPSG:26920"
  points <- potentiomap:::.ps_standard_points(table, value = "head", id = "id")
  expect_equal(terra::values(points)$Z, 11:15)
  expect_equal(terra::values(points)$Name, paste0("W", 1:5))

  sf_points <- sf::st_as_sf(table, coords = c("x", "y"), crs = 26920)
  standardized_sf <- potentiomap:::.ps_standard_points(sf_points,
                                                        value = "head", id = "id")
  expect_equal(terra::values(standardized_sf)$Name, paste0("W", 1:5))
  expect_error(potentiomap:::.ps_standard_points(data.frame(a = 1)),
               class = "potentiomap_input_error")
  no_crs <- data.frame(x = 1, y = 2, Z = 3)
  expect_error(potentiomap:::.ps_standard_points(no_crs),
               class = "potentiomap_crs_error")
  expect_error(potentiomap:::.ps_standard_points(points, value = "absent"),
               class = "potentiomap_input_error")
})

test_that("surface input and metadata helpers reject incompatible scientific references", {
  r <- expansion_raster()
  single <- potentiomap:::.ps_surfaces_input(r)
  expect_named(single, "surface")
  expect_error(potentiomap:::.ps_surfaces_input(list()),
               class = "potentiomap_input_error")
  expect_error(potentiomap:::.ps_surfaces_input(list(r, r)),
               class = "potentiomap_input_error")

  analysis <- potentiomap:::.ps_new_result(
    list(), "potentiomap_test", metadata = list(unit = "m")
  )
  expect_identical(potentiomap:::.ps_get_metadata(analysis)$unit, "m")
  supplied <- potentiomap:::.ps_surface_metadata(
    analysis, supplied = list(vertical_datum = "NAVD88")
  )
  expect_identical(supplied$vertical_datum, "NAVD88")

  b <- r
  terra::crs(b) <- "EPSG:26919"
  expect_error(potentiomap:::.ps_assert_surface_compatible(r, b),
               class = "potentiomap_crs_error")
  for (field in c("vertical_datum", "surface_type")) {
    a <- r
    b <- r
    attr(a, "potentiomap_metadata") <- setNames(list("one"), field)
    attr(b, "potentiomap_metadata") <- setNames(list("two"), field)
    expect_error(potentiomap:::.ps_assert_surface_compatible(a, b),
                 class = "potentiomap_metadata_error")
  }
})

test_that("alignment, cell area, metrics, safe files, and captured conditions are deterministic", {
  a <- expansion_raster()
  b <- terra::rast(nrows = 6, ncols = 6, xmin = 0, xmax = 300,
                   ymin = 0, ymax = 300, crs = "EPSG:26920", vals = 1:36)
  to_b <- potentiomap:::.ps_align_pair(a, b, "to_b", method = "near")
  expect_equal(terra::ncell(to_b$a), terra::ncell(b))
  expect_identical(to_b$manifest$target, "to_b")

  geographic <- terra::rast(nrows = 2, ncols = 2, xmin = -66, xmax = -65.8,
                            ymin = 18, ymax = 18.2, crs = "EPSG:4326",
                            vals = 1:4)
  area <- potentiomap:::.ps_cell_area_values(geographic)
  expect_true(all(is.finite(area) & area > 0))

  unavailable <- potentiomap:::.ps_metric_values(
    c(1, 2), c(NA, NA), metrics = c("rmse", "mae")
  )
  expect_true(all(is.na(unavailable[c("rmse", "mae")])))

  nested <- file.path(tempfile("safe-parent-"), "child", "out.txt")
  on.exit(unlink(dirname(dirname(nested)), recursive = TRUE), add = TRUE)
  expect_identical(potentiomap:::.ps_safe_file(nested), nested)
  captured <- potentiomap:::.ps_capture_run({
    warning("warning text")
    message("message text")
    stop("error text")
  })
  expect_length(captured$warnings, 1)
  expect_length(captured$messages, 1)
  expect_s3_class(captured$error, "error")
})
