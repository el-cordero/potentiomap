test_that("contour default and structured returns are compatible", {
  r <- make_plane("east")
  default <- ps_contours(r, interval = 4)
  result <- ps_contours(r, levels = c(-18, -10, -2), return = "result")

  expect_s4_class(default, "SpatVector")
  expect_s3_class(result, "potentiomap_contour_result")
  expect_equal(result$manifest$requested_level, c(-18, -10, -2))
  expect_true(all(result$manifest$level_relation == "within_surface_range"))
  expect_true(all(result$manifest$returned_status == "returned"))
  expect_output(print(result), "surface range")
})

test_that("omitted explicit levels have a classed warning and reason", {
  r <- make_plane("east")
  result <- expect_warning(
    ps_contours(r, levels = c(-100, -10, 100), return = "result"),
    class = "potentiomap_contour_level_warning"
  )
  expect_equal(result$manifest$level_relation,
               c("below_surface_range", "within_surface_range", "above_surface_range"))
  expect_equal(result$manifest$returned_status, c("omitted", "returned", "omitted"))
  expect_true(all(nzchar(result$manifest$omission_reason[c(1, 3)])))
})

test_that("constant surfaces return deterministic empty automatic contours", {
  r <- make_plane("east")
  terra::values(r) <- 5
  expect_silent(result <- ps_contours(r, interval = 1, return = "result"))
  expect_equal(nrow(result$contours), 0)
  expect_equal(nrow(result$manifest), 0)
})
