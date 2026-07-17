test_that("domain splitting records priority, boundary, and unassigned decisions", {
  data("synthetic_regions")
  regions <- terra::vect(synthetic_regions, geom = "wkt", crs = "EPSG:26916")
  domain <- terra::as.polygons(
    terra::ext(500000, 503000, 4640000, 4642500), crs = "EPSG:26916"
  )
  points <- terra::vect(
    data.frame(x = c(500500, 501500, 504000),
               y = c(4641000, 4641000, 4641000),
               Z = 1:3, Name = c("inside", "boundary", "outside")),
    geom = c("x", "y"), crs = "EPSG:26916"
  )
  priority <- ps_split_domain(
    domain, regions, "region_id", points,
    boundary_action = "assign_by_priority"
  )
  expect_equal(nrow(priority$ambiguous_points), 1)
  expect_equal(nrow(priority$unassigned_points), 1)
  expect_true("assign_by_priority" %in% priority$point_assignments$assignment)

  empty <- ps_split_domain(domain, regions, "region_id")
  expect_equal(nrow(empty$point_assignments), 0)
  expect_error(ps_split_domain(domain, regions, "absent"),
               class = "potentiomap_region_error")
  duplicate <- regions
  terra::values(duplicate)$region_id <- "same"
  expect_error(ps_split_domain(domain, duplicate, "region_id"),
               class = "potentiomap_region_error")
  expect_error(ps_split_domain(domain, regions, "region_id", points,
                               boundary_action = "error"),
               class = "potentiomap_region_boundary_error")
})

test_that("regional interpolation handles mosaics, underpopulation, and progress", {
  p <- expansion_points(20)
  data("synthetic_regions")
  regions <- terra::vect(synthetic_regions, geom = "wkt", crs = "EPSG:26916")
  events <- list()
  result <- suppressWarnings(ps_interpolate_regions(
    p, regions, "region_id", methods = c("IDW", "TPS"),
    grid_res = 500, mosaic = FALSE,
    progress = function(index, total, run_id, status) {
      events[[length(events) + 1L]] <<- list(index = index, total = total,
                                             run_id = run_id, status = status)
    }
  ))
  expect_length(result$mosaic, 0)
  expect_null(result$region_index)
  expect_equal(nrow(result$region_method_manifest), 4)
  expect_gt(length(events), 0)

  sparse <- suppressWarnings(ps_interpolate_regions(
    p[1:5], regions, "region_id", "IDW", grid_res = 600
  ))
  expect_true(any(sparse$region_method_manifest$status == "underpopulated"))
  expect_gt(nrow(sparse$conditions), 0)
  expect_error(ps_interpolate_regions(p, regions, "region_id", "IDW"),
               class = "potentiomap_region_error")
})

test_that("overlapping regional interpolation requires a complete priority", {
  p <- expansion_points(20)
  overlap_data <- data.frame(
    region_id = c("west", "east"),
    wkt = c(
      "POLYGON ((500000 4640000, 501800 4640000, 501800 4642500, 500000 4642500, 500000 4640000))",
      "POLYGON ((501200 4640000, 503000 4640000, 503000 4642500, 501200 4642500, 501200 4640000))"
    )
  )
  regions <- terra::vect(overlap_data, geom = "wkt", crs = "EPSG:26916")
  expect_error(ps_interpolate_regions(p, regions, "region_id", "IDW",
                                      grid_res = 500),
               class = "potentiomap_region_overlap_error")
  prioritized <- suppressWarnings(ps_interpolate_regions(
    p, regions, "region_id", "IDW", grid_res = 500,
    overlap_priority = c("east", "west")
  ))
  expect_s4_class(prioritized$region_index, "SpatRaster")
  expect_true("IDW" %in% names(prioritized$mosaic))
})

test_that("profiles accept raster stacks and expose support without inventing values", {
  r <- terra::rast(nrows = 20, ncols = 20, xmin = 0, xmax = 2000,
                   ymin = 0, ymax = 2000, crs = "EPSG:26920")
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  terra::values(r) <- 100 - xy[, 1] / 1000
  second <- r + 2
  stack <- c(r, second)
  names(stack) <- c("head", "alternate")
  support <- r
  terra::values(support) <- as.integer(xy[, 1] < 1500)
  names(support) <- "supported"
  lines <- terra::vect(
    data.frame(line_id = c("one", "two"),
               wkt = c("LINESTRING (100 500, 1900 500)",
                       "LINESTRING (100 1500, 1900 1500)")),
    geom = "wkt", crs = "EPSG:26920"
  )
  profile <- ps_surface_profile(lines, stack, step = 300,
                                support = support)
  expect_equal(length(unique(profile$profile$line_id)), 2)
  expect_true(all(c("head", "alternate", "support_supported") %in%
                    names(profile$profile)))
  expect_true(all(diff(profile$profile$chainage[profile$profile$line_id == "one"]) > 0))
  expect_equal(nrow(as.data.frame(profile)), nrow(profile$profile))

  wrong <- lines
  terra::crs(wrong) <- "EPSG:26919"
  expect_error(ps_surface_profile(wrong, list(head = r), n = 5),
               class = "potentiomap_crs_error")
  expect_error(ps_surface_profile(lines, list(head = r), step = 100, n = 5),
               class = "potentiomap_profile_error")
})

test_that("cross-sections retain screened wells, depth, uncertainty, and plot data", {
  p <- expansion_points(12)
  fit <- ps_interpolate(p, "Z", "IDW", grid_res = 400,
                        return = "result")
  head <- fit$surfaces$IDW
  land <- head * 0 + 175
  uncertainty <- head * 0 + 1.5
  support <- head * 0 + 1
  e <- terra::ext(head)
  y <- mean(c(e[3], e[4]))
  line <- terra::vect(
    data.frame(wkt = sprintf("LINESTRING (%f %f, %f %f)", e[1], y, e[2], y)),
    geom = "wkt", crs = terra::crs(p)
  )
  pv <- terra::values(p)
  pv$screen_top <- pv$Z - 2
  pv$screen_bottom <- pv$Z - 12
  terra::values(p) <- pv
  attr(p, "screen_vertical_reference") <- "absolute_elevation"
  section <- ps_cross_section(
    line, head, land_surface = land, wells = p,
    screen_top = "screen_top", screen_bottom = "screen_bottom",
    well_id = "Name", maximum_well_offset = 1000,
    support = support, uncertainty = uncertainty,
    step = 400, vertical_exaggeration = 3
  )
  expect_true("depth" %in% names(section$profile))
  expect_true(all(c("support_support", "support_uncertainty") %in%
                    names(section$profile)))
  expect_true(all(section$wells$screen_top >= section$wells$screen_bottom))

  file <- tempfile(fileext = ".pdf")
  grDevices::pdf(file)
  plotted <- plot(section)
  grDevices::dev.off()
  unlink(file)
  expect_named(plotted, c("profile", "wells"))

  no_reference <- p
  attr(no_reference, "screen_vertical_reference") <- NULL
  expect_error(ps_cross_section(
    line, head, wells = no_reference,
    screen_top = "screen_top", screen_bottom = "screen_bottom"
  ), class = "potentiomap_cross_section_error")
  reversed <- p
  rv <- terra::values(reversed)
  rv$screen_top[1] <- rv$screen_bottom[1] - 1
  terra::values(reversed) <- rv
  attr(reversed, "screen_vertical_reference") <- "absolute_elevation"
  expect_error(ps_cross_section(
    line, head, wells = reversed,
    screen_top = "screen_top", screen_bottom = "screen_bottom"
  ), class = "potentiomap_cross_section_error")
})

test_that("regional and profile geometry errors are classed without implicit repair", {
  data("synthetic_regions")
  regions <- terra::vect(synthetic_regions, geom = "wkt", crs = "EPSG:26916")
  domain <- terra::as.polygons(
    terra::ext(500000, 503000, 4640000, 4642500), crs = "EPSG:26916"
  )
  wrong_regions <- regions
  terra::crs(wrong_regions) <- "EPSG:26915"
  expect_error(ps_split_domain(domain, wrong_regions, "region_id"),
               class = "potentiomap_crs_error")
  points_not_polygons <- expansion_points(5)
  expect_error(ps_split_domain(points_not_polygons, regions, "region_id"),
               class = "potentiomap_region_error")

  invalid_sf <- sf::st_sf(
    region_id = "bowtie",
    geometry = sf::st_sfc(sf::st_polygon(list(matrix(
      c(0, 0, 2, 2, 0, 2, 2, 0, 0, 0), ncol = 2, byrow = TRUE
    ))), crs = 26916)
  )
  expect_error(ps_split_domain(domain, invalid_sf, "region_id"),
               class = "potentiomap_region_error")

  p <- expansion_points(10)
  expect_error(ps_interpolate_regions(p, wrong_regions, "region_id", "IDW",
                                      grid_res = 500),
               class = "potentiomap_crs_error")
  duplicate <- regions
  terra::values(duplicate)$region_id <- "duplicate"
  expect_error(ps_interpolate_regions(p, duplicate, "region_id", "IDW",
                                      grid_res = 500),
               class = "potentiomap_region_error")

  r <- expansion_raster()
  e <- terra::ext(r)
  line <- terra::vect(
    data.frame(wkt = sprintf("LINESTRING (%f %f, %f %f)",
                             e[1], e[3], e[2], e[4])),
    geom = "wkt", crs = terra::crs(r)
  )
  projected_geodesic <- ps_surface_profile(
    line, list(head = r), n = 5, distance_method = "geodesic"
  )
  expect_equal(nrow(projected_geodesic$profile), 5)
  expect_true(all(diff(projected_geodesic$profile$chainage) > 0))
  expect_error(ps_surface_profile(line, list(head = r), n = 5, support = 1),
               class = "potentiomap_profile_error")
  wrong_support <- r
  terra::crs(wrong_support) <- "EPSG:26919"
  expect_error(ps_surface_profile(line, list(head = r), n = 5,
                                  support = list(flag = wrong_support)),
               class = "potentiomap_crs_error")

  wells <- terra::as.points(r)
  terra::values(wells) <- data.frame(screen_top = rep(10, nrow(wells)),
                                     screen_bottom = rep(5, nrow(wells)))
  expect_error(ps_cross_section(line, r, wells = wells, screen_top = "screen_top"),
               class = "potentiomap_cross_section_error")
  wrong_wells <- wells
  terra::crs(wrong_wells) <- "EPSG:26919"
  expect_error(ps_cross_section(line, r, wells = wrong_wells),
               class = "potentiomap_crs_error")
})
