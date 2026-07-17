test_that("grouped interpolation preserves empty, failed, successful, masked, and exported groups", {
  p <- expansion_points(12)
  values <- terra::values(p)
  values$event <- factor(rep(c("spring", "autumn"), each = 6),
                         levels = c("spring", "autumn", "unused"))
  terra::values(p) <- values
  output <- tempfile("grouped-output-")
  on.exit(unlink(output, recursive = TRUE), add = TRUE)
  progress <- list()
  masks <- list(spring = terra::convHull(p), autumn = terra::convHull(p))
  names(masks) <- c("spring", "autumn")

  grouped <- ps_interpolate_grouped(
    p, "event", template_mode = "shared", mask_mode = "group",
    mask = masks, output_dir = output,
    methods = "IDW", grid_res = 500,
    progress = function(index, total, group_id, status) {
      progress[[length(progress) + 1L]] <<- status
    }
  )
  expect_true(all(c("success", "empty") %in% grouped$manifest$status))
  expect_true(any(grepl("unused", grouped$manifest$group_id)))
  expect_true(any(nzchar(grouped$manifest$output_paths[
    grouped$manifest$status == "success"
  ])))
  expect_true(all(file.exists(unlist(strsplit(
    grouped$manifest$output_paths[grouped$manifest$status == "success"],
    " \\| "
  )))))
  expect_true(all(c("success", "empty") %in% progress))

  too_small <- p[1:4]
  tv <- terra::values(too_small)
  tv$event <- "small"
  terra::values(too_small) <- tv
  failed_progress <- character()
  failed <- ps_interpolate_grouped(
    too_small, "event", methods = "IDW", grid_res = 500,
    progress = function(index, total, group_id, status) {
      failed_progress <<- c(failed_progress, status)
    }
  )
  expect_true(all(failed$manifest$status == "failed"))
  expect_true("failed" %in% failed_progress)
})

test_that("grouped IDs remain deterministic when safe names collide", {
  data("synthetic_wells")
  d <- synthetic_wells[1:12, ]
  d$group <- rep(c("a b", "a_b"), each = 6)
  result <- ps_interpolate_grouped(
    d, "group", value = "gw_elevation", name_col = "well_id",
    crs = "EPSG:26916", methods = "IDW", grid_res = 500,
    template_mode = "group"
  )
  expect_equal(anyDuplicated(result$group_keys$group_id), 0L)
  expect_true(all(grepl("a_b", result$group_keys$group_id)))

  expect_error(ps_interpolate_grouped(d, character(), value = "gw_elevation",
                                      crs = "EPSG:26916"),
               class = "potentiomap_input_error")
  expect_error(ps_interpolate_grouped(d, "absent", value = "gw_elevation",
                                      crs = "EPSG:26916"),
               class = "potentiomap_input_error")
  expect_error(ps_interpolate_grouped(d, "group", value = "gw_elevation",
                                      crs = "EPSG:26916", progress = TRUE),
               class = "potentiomap_input_error")
})

test_that("metadata units, modes, and depth references enforce scientific contracts", {
  expect_null(potentiomap:::.normalize_length_unit(NULL, "unit"))
  expect_error(potentiomap:::.normalize_length_unit(NULL, "unit", FALSE),
               class = "potentiomap_metadata_error")
  expect_error(potentiomap:::.normalize_length_unit("yards", "unit"),
               class = "potentiomap_metadata_error")
  expect_equal(potentiomap:::.convert_length(1, "ft", "m"), .3048)
  expect_equal(potentiomap:::.convert_length(.3048, "m", "ft"), 1)
  expect_equal(potentiomap:::.convert_length(2, "m", "m"), 2)

  warning_metadata <- suppressWarnings(
    potentiomap:::.prepare_direct_metadata(metadata_mode = "warn")
  )
  expect_null(warning_metadata$head_unit)
  expect_error(potentiomap:::.prepare_direct_metadata(metadata_mode = "strict"),
               class = "potentiomap_metadata_error")
  expect_error(potentiomap:::.prepare_direct_metadata(metadata = 1),
               class = "potentiomap_metadata_error")
  explicit <- potentiomap:::.prepare_direct_metadata(
    metadata = list(head_unit = "feet", output_unit = "m",
                    vertical_datum = "NAVD88",
                    surface_reference = "measuring point")
  )
  expect_identical(explicit$head_unit, "ft")
  expect_identical(explicit$output_unit, "m")

  expect_error(potentiomap:::.prepare_depth_metadata(metadata = 1),
               class = "potentiomap_metadata_error")
  expect_warning(
    offset <- potentiomap:::.prepare_depth_metadata(
      depth_unit = "ft", surface_unit = "m", output_unit = "m",
      vertical_datum = "NAVD88", surface_reference = "land_surface",
      depth_sign = "positive_down", measuring_point_offset = 1,
      metadata_mode = "warn"
    ),
    class = "potentiomap_metadata_warning"
  )
  expect_equal(offset$measuring_point_offset, 1)
  expect_error(potentiomap:::.prepare_depth_metadata(
    depth_unit = "m", surface_unit = "m", vertical_datum = "NAVD88",
    surface_reference = "land_surface", depth_sign = "positive_down",
    measuring_point_offset = 1, metadata_mode = "strict"
  ), class = "potentiomap_metadata_error")
})

test_that("condition conversion rejects invalid integers and spatial geometry", {
  expect_error(potentiomap:::.validate_integer(1.5, "count"),
               class = "potentiomap_input_error")
  multi <- c(expansion_raster(), expansion_raster())
  expect_error(potentiomap:::.as_surface(multi),
               class = "potentiomap_input_error")
  polygon <- terra::as.polygons(expansion_raster())
  expect_error(potentiomap:::.as_points(polygon),
               class = "potentiomap_input_error")
  no_crs <- expansion_raster()
  terra::crs(no_crs) <- ""
  expect_error(potentiomap:::.require_crs(no_crs),
               class = "potentiomap_crs_error")
})
