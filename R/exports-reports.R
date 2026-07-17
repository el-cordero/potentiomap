.ps_style_values <- function(x, breaks) {
  if (!is.null(breaks)) return(sort(unique(as.numeric(breaks))))
  raster <- if (inherits(x, "SpatRaster")) x else if (inherits(x, "potentiomap_result")) x$surfaces[[1]] else if (inherits(x, "potentiomap_analysis")) {
    candidates <- Filter(function(z) inherits(z, "SpatRaster"), x)
    candidates[[1]] %||% NULL
  } else NULL
  if (is.null(raster)) return(seq(0, 1, length.out = 7))
  values <- terra::values(raster[[1]], mat = FALSE); values <- values[is.finite(values)]
  if (!length(values)) .ps_abort("The styled raster has no finite values.", "potentiomap_export_error")
  unique(as.numeric(stats::quantile(values, seq(0, 1, length.out = 7), names = FALSE)))
}

.ps_style_palette <- function(palette, n) {
  if (is.null(palette)) return(grDevices::hcl.colors(n, "BluYl"))
  if (is.function(palette)) return(palette(n))
  if (!is.character(palette) || !length(palette)) .ps_abort("`palette` must be colors or a color function.", "potentiomap_export_error")
  grDevices::colorRampPalette(palette)(n)
}

.ps_qml_document <- function(layer_type, field, units, breaks, colors) {
  root <- xml2::xml_new_root("qgis", version = "3.34", styleCategories = "Symbology|Labeling")
  if (layer_type %in% c("head_raster", "depth_raster", "support")) {
    pipe <- xml2::xml_add_child(root, "pipe")
    renderer <- xml2::xml_add_child(pipe, "rasterrenderer", type = "singlebandpseudocolor", band = "1", opacity = "1")
    shader <- xml2::xml_add_child(renderer, "rastershader")
    ramp <- xml2::xml_add_child(shader, "colorrampshader", colorRampType = "INTERPOLATED",
                                classificationMode = "Continuous", labelPrecision = "4")
    for (i in seq_along(breaks)) xml2::xml_add_child(ramp, "item", value = format(breaks[i], scientific = FALSE),
                                                      color = colors[i], label = paste(format(breaks[i], trim = TRUE), units %||% ""), alpha = "255")
  } else {
    renderer <- xml2::xml_add_child(root, "renderer-v2", type = if (layer_type == "contour_support") "categorizedSymbol" else "singleSymbol",
                                    attr = field %||% "support_class")
    symbols <- xml2::xml_add_child(renderer, "symbols")
    classes <- if (layer_type == "contour_support") c("supported", "approximate", "unsupported") else "default"
    for (i in seq_along(classes)) {
      symbol <- xml2::xml_add_child(symbols, "symbol", name = as.character(i - 1L), type = if (layer_type == "wells") "marker" else "line")
      layer <- xml2::xml_add_child(symbol, "layer", class = if (layer_type == "wells") "SimpleMarker" else "SimpleLine", enabled = "1")
      xml2::xml_add_child(layer, "Option", name = "color", value = colors[min(i, length(colors))])
      if (layer_type != "wells") xml2::xml_add_child(layer, "Option", name = "line_style", value = c("solid", "dash", "dot")[min(i, 3)])
    }
    if (layer_type == "contours") {
      labeling <- xml2::xml_add_child(root, "labeling", type = "simple")
      settings <- xml2::xml_add_child(labeling, "settings")
      xml2::xml_add_child(settings, "text-style", fieldName = field %||% "level",
                          previewBkgrdColor = "255,255,255,255")
    }
  }
  root
}

.ps_sld_document <- function(layer_type, field, units, breaks, colors) {
  root <- xml2::xml_new_root("StyledLayerDescriptor", version = "1.0.0",
                            xmlns = "http://www.opengis.net/sld",
                            `xmlns:ogc` = "http://www.opengis.net/ogc")
  named <- xml2::xml_add_child(root, "NamedLayer"); xml2::xml_add_child(named, "Name", "potentiomap")
  style <- xml2::xml_add_child(named, "UserStyle"); xml2::xml_add_child(style, "Title", paste("potentiomap", layer_type, units %||% ""))
  fts <- xml2::xml_add_child(style, "FeatureTypeStyle")
  if (layer_type %in% c("head_raster", "depth_raster", "support")) {
    rule <- xml2::xml_add_child(fts, "Rule"); symbolizer <- xml2::xml_add_child(rule, "RasterSymbolizer"); cmap <- xml2::xml_add_child(symbolizer, "ColorMap")
    for (i in seq_along(breaks)) xml2::xml_add_child(cmap, "ColorMapEntry", color = colors[i], quantity = format(breaks[i], scientific = FALSE), label = paste(format(breaks[i], trim = TRUE), units %||% ""), opacity = "1")
  } else {
    classes <- if (layer_type == "contour_support") c("supported", "approximate", "unsupported") else "default"
    for (i in seq_along(classes)) {
      rule <- xml2::xml_add_child(fts, "Rule"); xml2::xml_add_child(rule, "Name", classes[i])
      if (layer_type == "contour_support") {
        filter <- xml2::xml_add_child(rule, "ogc:Filter"); equal <- xml2::xml_add_child(filter, "ogc:PropertyIsEqualTo")
        xml2::xml_add_child(equal, "ogc:PropertyName", field %||% "support_class"); xml2::xml_add_child(equal, "ogc:Literal", classes[i])
      }
      if (layer_type == "wells") {
        ps <- xml2::xml_add_child(rule, "PointSymbolizer"); graphic <- xml2::xml_add_child(ps, "Graphic"); mark <- xml2::xml_add_child(graphic, "Mark")
        xml2::xml_add_child(mark, "WellKnownName", "circle"); fill <- xml2::xml_add_child(mark, "Fill"); xml2::xml_add_child(fill, "CssParameter", colors[min(i, length(colors))], name = "fill")
      } else {
        ls <- xml2::xml_add_child(rule, "LineSymbolizer"); stroke <- xml2::xml_add_child(ls, "Stroke")
        xml2::xml_add_child(stroke, "CssParameter", colors[min(i, length(colors))], name = "stroke")
        xml2::xml_add_child(stroke, "CssParameter", "1.2", name = "stroke-width")
        if (i > 1L) xml2::xml_add_child(stroke, "CssParameter", if (i == 2L) "6 3" else "1 3", name = "stroke-dasharray")
      }
      if (layer_type == "contours") {
        text <- xml2::xml_add_child(rule, "TextSymbolizer"); label <- xml2::xml_add_child(text, "Label")
        xml2::xml_add_child(label, "ogc:PropertyName", field %||% "level")
      }
    }
  }
  root
}

#' Export open GIS style XML
#'
#' @param x Object whose values inform default raster breaks.
#' @param file Output QML or SLD file.
#' @param format QGIS QML or standards-based SLD.
#' @param layer_type Styled layer type.
#' @param field Attribute used for labels or support categories.
#' @param units Optional label units.
#' @param palette Colors or color function.
#' @param breaks Optional explicit continuous breaks.
#' @param overwrite Permit replacement of an existing file.
#' @return A `potentiomap_style_export` manifest. Optional properties can render
#'   differently among GIS versions.
#' @examples
#' r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2,
#'                  ymin = 0, ymax = 2, crs = "EPSG:26920", vals = 1:4)
#' file <- tempfile(fileext = ".qml")
#' style <- ps_export_style(r, file, "qml", "head_raster", units = "m")
#' style$manifest
#' # GIS versions can render optional style properties differently.
#' @export
ps_export_style <- function(x, file, format = c("qml", "sld"),
                            layer_type = c("head_raster", "depth_raster", "contours",
                                           "contour_support", "arrows", "wells", "support"),
                            field = NULL, units = NULL, palette = NULL,
                            breaks = NULL, overwrite = FALSE) {
  call <- match.call(); format <- match.arg(format); layer_type <- match.arg(layer_type)
  .ps_scalar_logical(overwrite, "overwrite"); .ps_safe_file(file, overwrite)
  if (!requireNamespace("xml2", quietly = TRUE)) .ps_abort("Style export requires the optional `xml2` package to validate and write XML.", "potentiomap_dependency_error")
  if (tolower(tools::file_ext(file)) != format) .ps_abort(sprintf("Output extension must be `.%s`.", format), "potentiomap_export_error")
  continuous <- layer_type %in% c("head_raster", "depth_raster", "support")
  values <- if (continuous) .ps_style_values(x, breaks) else c(0, 0.5, 1)
  colors <- .ps_style_palette(palette, length(values))
  doc <- if (format == "qml") .ps_qml_document(layer_type, field, units, values, colors) else .ps_sld_document(layer_type, field, units, values, colors)
  xml2::write_xml(doc, file, options = "format")
  parsed <- tryCatch(xml2::read_xml(file), error = function(e) e)
  if (inherits(parsed, "error")) {
    unlink(file); .ps_abort("Generated style did not pass XML parsing.", "potentiomap_export_error")
  }
  manifest <- data.frame(file = normalizePath(file), format = format,
                         layer_type = layer_type, field = field %||% NA_character_,
                         units = units %||% NA_character_, break_count = length(values),
                         xml_root = xml2::xml_name(xml2::xml_root(parsed)),
                         validated = TRUE, stringsAsFactors = FALSE)
  .ps_new_result(list(manifest = manifest), "potentiomap_style_export", call,
                 settings = list(format = format, layer_type = layer_type,
                                 field = field, units = units, palette = palette,
                                 breaks = values, overwrite = overwrite),
                 warnings = "Optional style properties can render differently among GIS versions.",
                 summary = manifest)
}

.ps_escape_report_text <- function(x) {
  x <- as.character(x %||% "Potentiomap technical report")
  x <- gsub("&", "&amp;", x, fixed = TRUE); x <- gsub("<", "&lt;", x, fixed = TRUE); x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("([#*_`\\[\\]])", "\\\\\\1", x, perl = TRUE)
}

#' Render a package-owned technical report
#'
#' @param x A potentiomap analysis or interpolation result.
#' @param output_file Selected `.html` or `.docx` output.
#' @param format HTML or Word.
#' @param title Optional safely escaped title.
#' @param sections `"auto"` or a character vector selecting from `"summary"`,
#'   `"metadata"`, `"settings"`, `"validation"`, `"uncertainty"`,
#'   `"change_network"`, `"conditions"`, `"limitations"`, and `"session"`.
#' @param include_session Include session information.
#' @param include_conditions Include captured conditions.
#' @param overwrite Permit replacement of an existing output.
#' @return An invisible report manifest.
#' @examples
#' data("synthetic_wells")
#' p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' checked <- ps_check_observations(p, value = "Z", id = "Name")
#' if (rmarkdown::pandoc_available()) {
#'   file <- tempfile(fileext = ".html")
#'   ps_report(checked, file, "html", include_session = FALSE)
#' }
#' # Generated reports are not professional certification.
#' @export
ps_report <- function(x, output_file, format = c("html", "docx"),
                      title = NULL, sections = "auto", include_session = TRUE,
                      include_conditions = TRUE, overwrite = FALSE) {
  call <- match.call(); format <- match.arg(format)
  .ps_scalar_logical(include_session, "include_session"); .ps_scalar_logical(include_conditions, "include_conditions"); .ps_scalar_logical(overwrite, "overwrite")
  allowed_sections <- c(
    "summary", "metadata", "settings", "validation", "uncertainty",
    "change_network", "conditions", "limitations", "session"
  )
  automatic_sections <- is.character(sections) && length(sections) == 1L &&
    identical(sections, "auto")
  if (!automatic_sections &&
      (!is.character(sections) || !length(sections) || anyNA(sections) ||
       any(!nzchar(sections)) || anyDuplicated(sections) ||
       any(!sections %in% allowed_sections))) {
    .ps_abort(
      paste0("`sections` must be \"auto\" or unique names from: ",
             paste(allowed_sections, collapse = ", "), "."),
      "potentiomap_report_error"
    )
  }
  .ps_safe_file(output_file, overwrite, "potentiomap_report_error")
  if (!requireNamespace("rmarkdown", quietly = TRUE) || !requireNamespace("knitr", quietly = TRUE)) .ps_abort("Technical reports require the suggested `rmarkdown` and `knitr` packages.", "potentiomap_dependency_error")
  expected <- if (format == "html") "html" else "docx"
  if (tolower(tools::file_ext(output_file)) != expected) .ps_abort(sprintf("Output extension must be `.%s`.", expected), "potentiomap_report_error")
  template <- system.file("rmarkdown", "templates", "potentiomap_report", "skeleton", "skeleton.Rmd", package = "potentiomap")
  if (!nzchar(template)) template <- file.path("inst", "rmarkdown", "templates", "potentiomap_report", "skeleton", "skeleton.Rmd")
  if (!file.exists(template)) .ps_abort("The package-owned report template was not found.", "potentiomap_report_error")
  params <- list(object = x, report_title = .ps_escape_report_text(title),
                 sections = sections, include_session = include_session,
                 include_conditions = include_conditions)
  intermediate <- tempfile("potentiomap-report-"); dir.create(intermediate); on.exit(unlink(intermediate, recursive = TRUE), add = TRUE)
  rendered <- rmarkdown::render(template,
                                output_format = if (format == "html") "html_document" else "word_document",
                                output_file = basename(output_file),
                                output_dir = dirname(output_file),
                                intermediates_dir = intermediate,
                                params = params, envir = new.env(parent = globalenv()),
                                quiet = TRUE, clean = TRUE)
  manifest <- data.frame(file = normalizePath(rendered), format = format,
                         title = title %||% "Potentiomap technical report",
                         sections = paste(sections, collapse = ";"),
                         include_session = include_session,
                         include_conditions = include_conditions,
                         package_version = .package_version_string(), stringsAsFactors = FALSE)
  structure(manifest, class = c("potentiomap_report_manifest", "data.frame"), call = call)
}

#' @export
as.data.frame.potentiomap_style_export <- function(x, ...) x$manifest
