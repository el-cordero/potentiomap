test_that("cardinal plane gradients preserve actual downgradient direction", {
  for (direction in c("east", "west", "north", "south")) {
    flow <- ps_flow_arrows(
      make_plane(direction), res_factor = 5, scale = 1,
      endpoint_action = "none"
    )
    base <- terra::crds(flow$bases)
    tip <- terra::crds(flow$tips)
    delta <- colMeans(tip - base)
    if (direction == "east") expect_gt(delta[1], 0)
    if (direction == "west") expect_lt(delta[1], 0)
    if (direction == "north") expect_gt(delta[2], 0)
    if (direction == "south") expect_lt(delta[2], 0)
  }
})

test_that("arrow validation records passing, uphill, and unsupported tips", {
  r <- make_plane("east")
  lines <- terra::vect(list(
    rbind(c(2, 10), c(8, 10)),
    rbind(c(8, 8), c(2, 8)),
    rbind(c(16, 6), c(25, 6))
  ), type = "lines", crs = terra::crs(r))
  checked <- ps_validate_arrows(r, lines, extraction = "bilinear")
  expect_s3_class(checked, "potentiomap_arrow_validation")
  expect_named(checked$records, c(
    "arrow_id", "base_x", "base_y", "tip_x", "tip_y", "base_head",
    "tip_head", "head_drop", "finite_base", "finite_tip", "finite_support",
    "downhill_pass", "tolerance", "original_length", "final_length",
    "shortening_steps", "validation_status", "validation_reason"
  ))
  expect_identical(checked$records$downhill_pass, c(TRUE, FALSE, FALSE))
  expect_match(checked$records$validation_reason[2], "tip_higher")
  expect_match(checked$records$validation_reason[3], "nonfinite_tip")
})

test_that("endpoint policies flag, shorten, drop, or preserve geometry", {
  r <- make_curved_surface()
  flagged <- NULL
  expect_warning(
    flagged <- ps_flow_arrows(r, res_factor = 4, scale = 0.25,
                              endpoint_action = "flag"),
    class = "potentiomap_arrow_endpoint_warning"
  )
  shortened <- suppressWarnings(ps_flow_arrows(
    r, res_factor = 4, scale = 0.25, endpoint_action = "shorten"
  ))
  dropped <- NULL
  expect_warning(
    dropped <- ps_flow_arrows(r, res_factor = 4, scale = 0.5,
                              endpoint_action = "drop"),
    class = "potentiomap_arrow_endpoint_warning"
  )
  legacy <- ps_flow_arrows(r, res_factor = 4, scale = 0.25,
                           endpoint_action = "none")

  expect_true(any(!flagged$validation$downhill_pass))
  expect_true(any(shortened$validation$shortening_steps > 0))
  expect_true(all(shortened$validation$final_length <=
                    shortened$validation$original_length))
  expect_lt(nrow(dropped$arrows), dropped$validation_summary$arrows_generated[[1]])
  expect_true(all(legacy$validation$validation_status == "not_checked"))
})

test_that("flat surfaces produce zero arrows and empty vertex helpers", {
  r <- make_plane("east")
  terra::values(r) <- 1
  flow <- ps_flow_arrows(r, min_gradient = 1e-5)
  expect_equal(nrow(flow$arrows), 0)
  expect_equal(nrow(flow$tips), 0)
  expect_equal(nrow(flow$bases), 0)
  checked <- ps_validate_arrows(r, flow$arrows)
  expect_equal(nrow(checked$records), 0)
})

test_that("arrow vertices preserve attributes and overwrite controls", {
  line <- terra::vect(list(rbind(c(0, 0), c(1, 2))), type = "lines",
                      crs = "EPSG:3857")
  terra::values(line) <- data.frame(id = 7)
  file <- file.path(tempdir(), "potentiomap-arrow-tip.gpkg")
  unlink(file)
  tip <- ps_arrow_vertices(line, "last", file)
  expect_equal(terra::crds(tip), matrix(c(1, 2), nrow = 1,
                                       dimnames = list(NULL, c("x", "y"))))
  expect_equal(terra::values(tip)$id, 7)
  expect_error(ps_arrow_vertices(line, "last", file, overwrite = FALSE),
               class = "potentiomap_export_error")
})
