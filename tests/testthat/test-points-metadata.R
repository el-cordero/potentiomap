test_that("direct observations retain metadata and convert international feet", {
  d <- data.frame(x = 1:5, y = c(1, 2, 4, 7, 11), head = 100:104)
  pts <- ps_make_points(
    d, value = "head", crs = "EPSG:3857", head_unit = "ft",
    output_unit = "m", vertical_datum = "example datum",
    surface_reference = "land_surface", metadata_mode = "strict"
  )

  expect_s4_class(pts, "SpatVector")
  expect_equal(terra::values(pts)$Z, (100:104) * 0.3048)
  expect_equal(ps_metadata(pts)$output_unit, "m")
  expect_equal(attr(pts, "dropped_records")$dropped_count, 0)
})

test_that("metadata modes preserve legacy behavior and classify omissions", {
  d <- data.frame(x = 1:5, y = 1:5, head = 10:14)
  expect_silent(ps_make_points(d, value = "head", crs = "EPSG:3857"))
  expect_warning(
    ps_make_points(d, value = "head", crs = "EPSG:3857",
                   head_unit = "m", output_unit = "m",
                   surface_reference = "land_surface",
                   metadata_mode = "warn"),
    class = "potentiomap_metadata_warning"
  )
  expect_error(
    ps_make_points(d, value = "head", crs = "EPSG:3857",
                   head_unit = "m", output_unit = "m",
                   surface_reference = "land_surface",
                   metadata_mode = "strict"),
    class = "potentiomap_metadata_error"
  )
})

test_that("invalid observations are reported or rejected", {
  d <- data.frame(x = c(1:5, NA), y = 1:6, head = c(10:13, NA, 15))
  pts <- NULL
  expect_warning(
    pts <- ps_make_points(d, value = "head", crs = "EPSG:3857"),
    class = "potentiomap_input_warning"
  )
  expect_equal(nrow(pts), 4)
  expect_equal(attr(pts, "dropped_records")$dropped_count, 2)
  expect_error(
    ps_make_points(d, value = "head", crs = "EPSG:3857",
                   invalid_action = "error"),
    class = "potentiomap_input_error"
  )
})

test_that("depth-to-water calculations honor sign, units, and offsets", {
  d <- data.frame(
    id = paste0("w", 1:6), x = 1:6, y = c(1, 2, 4, 7, 11, 16),
    land = rep(100, 6), depth = rep(10, 6), signed = rep(-10, 6)
  )
  down <- ps_potentiometric_points(
    d, depth_col = "depth", surface_col = "land", name_col = "id",
    crs = "EPSG:3857", depth_unit = "ft", surface_unit = "ft",
    output_unit = "m", vertical_datum = "example datum",
    surface_reference = "land_surface", depth_sign = "positive_down",
    metadata_mode = "strict"
  )
  signed <- ps_potentiometric_points(
    d, depth_col = "signed", surface_col = "land", name_col = "id",
    crs = "EPSG:3857", depth_unit = "ft", surface_unit = "ft",
    output_unit = "m", vertical_datum = "example datum",
    surface_reference = "measuring_point", depth_sign = "signed",
    measuring_point_offset = 2, metadata_mode = "strict"
  )
  expect_equal(terra::values(down)$Z, rep(90 * 0.3048, 6))
  expect_equal(terra::values(signed)$Z, rep(92 * 0.3048, 6))
})

test_that("contradictory depth metadata is rejected in strict mode", {
  d <- data.frame(x = 1:6, y = c(1, 2, 4, 7, 11, 16), land = 100, depth = -2)
  expect_error(
    ps_potentiometric_points(
      d, depth_col = "depth", surface_col = "land", crs = "EPSG:3857",
      depth_unit = "m", surface_unit = "m", output_unit = "m",
      vertical_datum = "example", surface_reference = "land_surface",
      depth_sign = "positive_down", metadata_mode = "strict"
    ),
    class = "potentiomap_metadata_error"
  )
})

test_that("sf and SpatVector observations preserve point behavior", {
  d <- data.frame(
    x = 1:6, y = c(1, 2, 4, 7, 11, 16),
    head = c(10:14, NA_real_), id = paste0("w", 1:6)
  )
  sf_points <- sf::st_as_sf(d[1:5, ], coords = c("x", "y"), crs = 3857)
  from_sf <- ps_make_points(sf_points, value = "head", name_col = "id")
  expect_s4_class(from_sf, "SpatVector")
  expect_equal(terra::values(from_sf)$Name, d$id[1:5])

  vector_points <- terra::vect(d, geom = c("x", "y"), crs = "EPSG:3857")
  from_vector <- NULL
  expect_warning(
    from_vector <- ps_make_points(vector_points, value = "head"),
    class = "potentiomap_input_warning"
  )
  expect_equal(nrow(from_vector), 5)
  expect_equal(terra::values(from_vector)$Name, paste0("P", 1:5))
  expect_error(
    ps_make_points(vector_points, value = "head", invalid_action = "error"),
    class = "potentiomap_input_error"
  )
})

test_that("point preparation rejects malformed public inputs", {
  d <- data.frame(x = 1:5, y = 1:5, head = 1:5)
  expect_error(ps_make_points(d, crs = "EPSG:3857"),
               class = "potentiomap_input_error")
  expect_error(ps_make_points(1:5, value = "head", crs = "EPSG:3857"),
               class = "potentiomap_input_error")
  expect_error(ps_make_points(d, value = "head"),
               class = "potentiomap_crs_error")
})

test_that("depth calculations accept raster and separate-point surfaces", {
  depths <- data.frame(
    id = paste0("d", 1:5), x = c(2, 5, 8, 12, 16),
    y = c(2, 5, 8, 12, 16), depth = rep(2, 5)
  )
  surface <- make_plane("west")
  from_raster <- ps_potentiometric_points(
    depths, depth_col = "depth", surface = surface, name_col = "id",
    crs = "EPSG:3857", depth_unit = "m", surface_unit = "m",
    output_unit = "m", vertical_datum = "example datum",
    surface_reference = "land_surface", depth_sign = "positive_down",
    metadata_mode = "strict"
  )
  expect_equal(nrow(from_raster), 5)
  expect_true(all(is.finite(terra::values(from_raster)$Z)))

  surface_points <- transform(
    depths,
    id = c("d1", "d2", "d3", "other1", "other2"),
    elevation = c(100, 101, 102, 103, 104)
  )
  from_points <- ps_potentiometric_points(
    depths, depth_col = "depth", surface = surface_points,
    surface_col = "elevation", name_col = "id", surface_name_col = "id",
    crs = "EPSG:3857", depth_unit = "m", surface_unit = "m",
    output_unit = "m", vertical_datum = "example datum",
    surface_reference = "land_surface", depth_sign = "positive_down",
    metadata_mode = "strict"
  )
  expect_equal(terra::values(from_points)$Z[1:3], c(98, 99, 100))
  expect_true(all(is.finite(terra::values(from_points)$Z)))
  expect_error(
    ps_potentiometric_points(depths, depth_col = "depth", crs = "EPSG:3857"),
    class = "potentiomap_input_error"
  )
})
