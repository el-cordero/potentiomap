test_that("QML and SLD exports cover continuous and vector layer semantics", {
  r <- expansion_raster()
  directory <- tempfile("styles-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  types <- c("head_raster", "depth_raster", "support", "contours",
             "contour_support", "arrows", "wells")
  manifests <- list()
  for (format in c("qml", "sld")) {
    for (type in types) {
      file <- file.path(directory, paste(type, format, sep = "."))
      object <- if (type %in% c("head_raster", "depth_raster", "support")) r else NULL
      manifests[[paste(format, type)]] <- ps_export_style(
        object, file, format, type,
        field = if (type == "contour_support") "support_class" else "level",
        units = "m", palette = c("#0b3c5d", "#f4d35e", "#d1495b")
      )
      expect_true(xml2::xml_length(xml2::read_xml(file)) > 0)
    }
  }
  expect_true(all(vapply(manifests, function(x) x$manifest$validated, logical(1))))
  expect_equal(nrow(as.data.frame(manifests[[1]])), 1)

  custom <- file.path(directory, "custom.qml")
  palette_function <- function(n) grDevices::gray.colors(n)
  styled <- ps_export_style(r, custom, "qml", "head_raster",
                            breaks = c(1, 2, 4), palette = palette_function)
  expect_equal(styled$manifest$break_count, 3)
  expect_error(ps_export_style(r, custom, "qml", "head_raster"),
               class = "potentiomap_export_error")
  overwritten <- ps_export_style(r, custom, "qml", "head_raster",
                                 overwrite = TRUE)
  expect_true(overwritten$manifest$validated)
  expect_error(ps_export_style(r, file.path(directory, "wrong.sld"),
                               "qml", "head_raster"),
               class = "potentiomap_export_error")
  expect_error(ps_export_style(r, file.path(directory, "palette.qml"),
                               "qml", "head_raster", palette = 1),
               class = "potentiomap_export_error")
})

test_that("technical reports render HTML and Word with escaped titles", {
  skip_if_not(rmarkdown::pandoc_available())
  p <- expansion_points(10)
  checked <- ps_check_observations(p, value = "Z", id = "Name")
  directory <- tempfile("reports-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)

  html <- ps_report(
    checked, file.path(directory, "analysis.html"), "html",
    title = "Heads <review> & QA", sections = c("summary", "conditions"),
    include_session = FALSE, include_conditions = TRUE
  )
  docx <- ps_report(
    checked, file.path(directory, "analysis.docx"), "docx",
    title = "Head report", include_session = FALSE,
    include_conditions = FALSE
  )
  expect_s3_class(html, "potentiomap_report_manifest")
  expect_true(file.exists(html$file))
  html_text <- paste(readLines(html$file, warn = FALSE), collapse = "\n")
  expect_match(html_text, "Analysis summary")
  expect_false(grepl("Metadata and units", html_text, fixed = TRUE))
  expect_identical(html$sections, "summary;conditions")
  expect_true(file.exists(docx$file))
  expect_gt(file.info(docx$file)$size, 0)
  expect_error(ps_report(checked, file.path(directory, "wrong.txt"), "html"),
               class = "potentiomap_report_error")
  expect_error(ps_report(checked, html$file, "html"),
               class = "potentiomap_report_error")
  expect_error(ps_report(checked, file.path(directory, "bad.html"), "html",
                         sections = "not-a-section"),
               class = "potentiomap_report_error")
})
