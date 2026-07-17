test_that("contour extraction validates finite surfaces and level inventories", {
  r <- make_plane("east")
  missing <- r
  terra::values(missing) <- NA_real_
  expect_error(ps_contours(missing), class = "potentiomap_input_error")
  expect_error(ps_contours(r, interval = 0), class = "potentiomap_input_error")
  expect_error(ps_contours(r, levels = numeric()),
               class = "potentiomap_input_error")
  expect_error(ps_contours(r, levels = c(1, Inf)),
               class = "potentiomap_input_error")
  expect_error(ps_contours(r, levels = c(-10, -10)),
               class = "potentiomap_input_error")

  constant <- r
  terra::values(constant) <- 7
  result <- ps_contours(constant, return = "result")
  expect_s3_class(result, "potentiomap_contour_result")
  expect_equal(result$surface_range, c(7, 7))
  expect_identical(capture.output(print(result))[1],
                   "<potentiomap_contour_result>")
})

test_that("quicklook validates device options and draws structured overlays", {
  r <- make_plane("east")
  contours <- ps_contours(r, interval = 4, return = "result")
  points <- make_test_points()
  out <- tempfile(fileext = ".png")
  expect_identical(
    ps_quicklook(r, contours = contours, points = points, file = out,
                 contour_units = "m", label_contours = TRUE,
                 label_points = TRUE, width = 600, height = 450, res = 100),
    out
  )
  expect_gt(file.info(out)$size, 0)
  expect_error(ps_quicklook(r, width = 0), class = "potentiomap_input_error")
  expect_error(ps_quicklook(r, label_points = NA),
               class = "potentiomap_input_error")
  expect_error(ps_quicklook(r, file = ""),
               class = "potentiomap_export_error")
})

test_that("surface exports support minimal products and validate sidecars", {
  r <- make_plane("east")
  surfaces <- list(Plane = r)
  out <- tempfile("potentiomap-minimal-export-")
  manifest <- ps_export_surfaces(
    surfaces, out, write_raster = FALSE, write_contours = FALSE,
    write_png = FALSE, write_contour_manifest = FALSE,
    write_manifest = TRUE
  )
  expect_equal(manifest$method, "Plane")
  expect_true(all(is.na(manifest[1, -1])))
  expect_true(file.exists(file.path(out, "gw_output_manifest.csv")))

  expect_error(
    ps_export_surfaces(surfaces, out, write_raster = FALSE,
                       write_contours = FALSE, write_png = FALSE,
                       write_contour_manifest = FALSE, overwrite = FALSE),
    class = "potentiomap_export_error"
  )
  expect_error(ps_export_surfaces(surfaces, tempfile(), write_support = TRUE,
                                  write_raster = FALSE, write_contours = FALSE,
                                  write_png = FALSE),
               class = "potentiomap_export_error")
  expect_error(ps_export_surfaces(surfaces, tempfile(),
                                  write_diagnostics = TRUE,
                                  diagnostics = 1,
                                  write_raster = FALSE, write_contours = FALSE,
                                  write_png = FALSE),
               class = "potentiomap_export_error")
  expect_error(ps_export_surfaces(surfaces, ""),
               class = "potentiomap_export_error")

  occupied <- tempfile("potentiomap-export-file-")
  writeLines("occupied", occupied)
  expect_error(ps_export_surfaces(surfaces, occupied),
               class = "potentiomap_export_error")
})

test_that("surface export failures are classed at the method boundary", {
  r <- make_plane("east")
  out <- tempfile("potentiomap-existing-vector-")
  dir.create(out)
  existing <- file.path(out, "gw_Plane_contours.gpkg")
  terra::writeVector(ps_contours(r, interval = 4), existing)
  expect_error(
    ps_export_surfaces(
      list(Plane = r), out, vector_format = "gpkg",
      write_raster = FALSE, write_png = FALSE,
      write_contour_manifest = FALSE, write_manifest = FALSE,
      overwrite = FALSE
    ),
    class = "potentiomap_export_error"
  )
})
