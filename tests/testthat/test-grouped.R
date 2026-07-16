test_that("two events and two units produce four isolated analyses", {
  data("synthetic_wells", package = "potentiomap")
  d <- transform(
    synthetic_wells,
    event = rep(c("spring", "autumn"), each = 16),
    unit = rep(c("upper", "lower"), times = 16)
  )
  result <- ps_interpolate_grouped(
    d, c("event", "unit"), value = "gw_elevation", name_col = "well_id",
    crs = "EPSG:26916", methods = "IDW", grid_res = 400
  )

  expect_s3_class(result, "potentiomap_grouped_result")
  expect_equal(nrow(result$group_keys), 4)
  expect_length(result$results, 4)
  expect_true(all(result$manifest$status == "success"))
  expect_true(all(result$manifest$input_count == 8))
  expect_true(all(result$manifest$retained_count == 8))
  expect_output(print(result), "groups: 4")
})

test_that("empty and failed groups remain in the grouped manifest", {
  data("synthetic_wells", package = "potentiomap")
  d <- synthetic_wells[1:12, ]
  d$event <- factor(rep(c("sampled", "sparse"), c(8, 4)),
                    levels = c("sampled", "sparse", "empty"))
  result <- ps_interpolate_grouped(
    d, "event", value = "gw_elevation", name_col = "well_id",
    crs = "EPSG:26916", methods = "IDW", grid_res = 400
  )
  expect_setequal(result$manifest$status, c("success", "failed", "empty"))
  expect_true(any(nzchar(result$manifest$errors[result$manifest$status == "failed"])))
})

test_that("group masks and progress callbacks are explicit", {
  data("synthetic_wells", package = "potentiomap")
  d <- synthetic_wells[1:12, ]
  d$event <- rep(c("a", "b"), each = 6)
  seen <- character()
  progress <- function(index, total, group_id, status) {
    seen <<- c(seen, paste(index, total, group_id, status, sep = ":"))
  }
  result <- ps_interpolate_grouped(
    d, "event", value = "gw_elevation", name_col = "well_id",
    crs = "EPSG:26916", methods = "IDW", grid_res = 400,
    progress = progress
  )
  expect_length(seen, 2)
  expect_true(all(result$manifest$status == "success"))
})
