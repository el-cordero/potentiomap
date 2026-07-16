#' Create contours and a contour-level inventory
#'
#' Extracts contour lines from a one-layer surface. The default remains a line
#' `SpatVector`. The opt-in result inventories every requested level, its
#' relation to the finite surface range, returned feature count, and any
#' omission. Open lines are not converted to polygons.
#'
#' @param surface One-layer potentiometric-surface `SpatRaster`.
#' @param interval Positive contour interval in surface units.
#' @param levels Optional finite explicit contour levels. `interval` is ignored
#'   when these are supplied.
#' @param return Either `"contours"` for the backward-compatible `SpatVector` or
#'   `"result"` for a structured inventory.
#'
#' @return A line `SpatVector`, or a `potentiomap_contour_result` containing
#'   `contours`, `manifest`, `surface_range`, `call`, `interval`, `levels`,
#'   `warnings`, and `package_version`.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' surface <- ps_interpolate(pts, methods = "IDW", grid_res = 150)$IDW
#' result <- ps_contours(surface, levels = c(165, 168, 171), return = "result")
#' result$manifest
ps_contours <- function(surface, interval = 1, levels = NULL,
                        return = c("contours", "result")) {
  call <- match.call()
  return <- match.arg(return)
  r <- .as_surface(surface)
  values <- terra::values(r, mat = FALSE)
  finite <- values[is.finite(values)]
  if (!length(finite)) {
    .ps_abort("`surface` has no finite values.", "potentiomap_input_error")
  }
  .validate_number(interval, "interval", lower = 0)
  explicit <- !is.null(levels)
  surface_range <- range(finite)
  if (explicit) {
    if (!is.numeric(levels) || !length(levels) || any(!is.finite(levels))) {
      .ps_abort("`levels` must contain one or more finite numbers.",
                "potentiomap_input_error")
    }
    if (anyDuplicated(levels)) {
      .ps_abort("`levels` must not contain duplicates.",
                "potentiomap_input_error")
    }
    requested <- as.numeric(levels)
  } else if (surface_range[1] == surface_range[2]) {
    requested <- numeric()
  } else {
    requested <- seq(
      floor(surface_range[1] / interval) * interval,
      ceiling(surface_range[2] / interval) * interval,
      by = interval
    )
    requested <- requested[requested > surface_range[1] &
                             requested < surface_range[2]]
  }
  within <- requested[requested >= surface_range[1] & requested <= surface_range[2]]
  contours <- if (length(within)) {
    tryCatch(
      terra::as.contour(r, levels = within),
      error = function(e) .ps_abort(
        paste0("Contour extraction failed: ", conditionMessage(e)),
        "potentiomap_input_error"
      )
    )
  } else .empty_lines(terra::crs(r))

  returned_levels <- numeric()
  feature_count <- integer()
  if (nrow(contours)) {
    attrs <- terra::values(contours)
    level_name <- intersect(c("level", "levels", "value", "elevation"),
                            names(attrs))[1]
    if (!is.na(level_name)) {
      returned_levels <- as.numeric(attrs[[level_name]])
      feature_count <- table(returned_levels)
    }
  }
  relation <- ifelse(requested < surface_range[1], "below_surface_range",
                     ifelse(requested > surface_range[2], "above_surface_range",
                            "within_surface_range"))
  counts <- vapply(requested, function(level) {
    if (!length(feature_count)) return(0L)
    index <- match(as.character(level), names(feature_count))
    if (is.na(index)) 0L else as.integer(feature_count[[index]])
  }, integer(1))
  manifest <- data.frame(
    requested_level = requested,
    surface_minimum = rep(surface_range[1], length(requested)),
    surface_maximum = rep(surface_range[2], length(requested)),
    level_relation = relation,
    returned_status = ifelse(counts > 0L, "returned", "omitted"),
    returned_feature_count = counts,
    omission_reason = ifelse(
      counts > 0L, "",
      ifelse(relation == "within_surface_range", "no_contour_geometry",
             relation)
    ),
    stringsAsFactors = FALSE
  )
  omitted <- explicit && any(manifest$returned_status == "omitted")
  warning_text <- character()
  if (omitted) {
    omitted_levels <- manifest$requested_level[manifest$returned_status == "omitted"]
    warning_text <- sprintf(
      "Explicit contour level(s) were not returned: %s.",
      paste(format(omitted_levels, trim = TRUE), collapse = ", ")
    )
    .ps_warn(warning_text, "potentiomap_contour_level_warning",
             data = list(manifest = manifest))
  }
  if (return == "contours") return(contours)
  out <- list(
    contours = contours, manifest = manifest, surface_range = surface_range,
    call = call, interval = if (explicit) NULL else interval,
    levels = if (explicit) requested else NULL,
    warnings = warning_text, package_version = .package_version_string()
  )
  class(out) <- "potentiomap_contour_result"
  out
}

#' @export
print.potentiomap_contour_result <- function(x, ...) {
  cat("<potentiomap_contour_result>\n")
  cat("  surface range:", paste(format(x$surface_range), collapse = " to "), "\n")
  cat("  contour features:", nrow(x$contours), "\n")
  print(x$manifest, row.names = FALSE)
  invisible(x)
}

#' Draw a quicklook surface plot
#'
#' @param surface One-layer `SpatRaster`.
#' @param contours Optional contour `SpatVector` or contour result.
#' @param points Optional observation points.
#' @param file Optional PNG path. No file is written when `NULL`.
#' @param title Plot title.
#' @param label_points Label points with `Name` and `Z` when available.
#' @param width,height,res Positive PNG dimensions and resolution.
#' @param contour_units Optional units appended to contour labels.
#' @param label_contours Draw contour labels.
#' @param overwrite Overwrite `file` when it exists.
#'
#' @return Invisibly returns `file`.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' surface <- ps_interpolate(pts, methods = "IDW", grid_res = 150)$IDW
#' ps_quicklook(surface, points = pts, title = "Synthetic IDW")
ps_quicklook <- function(surface, contours = NULL, points = NULL, file = NULL,
                         title = "Potentiometric surface",
                         label_points = TRUE,
                         width = 1600, height = 1200, res = 180,
                         contour_units = NULL, label_contours = TRUE,
                         overwrite = TRUE) {
  r <- .as_surface(surface)
  if (inherits(contours, "potentiomap_contour_result")) contours <- contours$contours
  for (item in c("width", "height", "res")) {
    .validate_number(get(item), item, lower = 0)
  }
  if (!is.logical(label_points) || length(label_points) != 1L || is.na(label_points) ||
      !is.logical(label_contours) || length(label_contours) != 1L || is.na(label_contours)) {
    .ps_abort("`label_points` and `label_contours` must be TRUE or FALSE.",
              "potentiomap_input_error")
  }
  opened <- FALSE
  if (!is.null(file)) {
    if (!is.character(file) || length(file) != 1L || !nzchar(file)) {
      .ps_abort("`file` must be one nonempty path or NULL.",
                "potentiomap_export_error")
    }
    if (!overwrite && file.exists(file)) {
      .ps_abort("Quicklook output exists and `overwrite = FALSE`.",
                "potentiomap_export_error")
    }
    dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
    tryCatch(grDevices::png(file, width = width, height = height, res = res,
                            bg = "white"),
             error = function(e) .ps_abort(
               paste0("Could not open quicklook device: ", conditionMessage(e)),
               "potentiomap_export_error"
             ))
    opened <- TRUE
    on.exit(if (opened) grDevices::dev.off(), add = TRUE)
  }
  terra::plot(r, main = title)
  if (!is.null(contours) && nrow(contours) > 0L) {
    terra::plot(contours, add = TRUE, col = "white", lwd = 2)
    terra::plot(contours, add = TRUE, col = "#145b70", lwd = 1)
    if (label_contours) .label_contours(contours, contour_units)
  }
  if (!is.null(points) && nrow(points) > 0L) {
    pts <- .as_points(points)
    terra::plot(pts, add = TRUE, pch = 21, bg = "white", col = "black", cex = 1)
    vals <- terra::values(pts)
    if (label_points && all(c("Name", "Z") %in% names(vals))) {
      labels <- paste0(vals$Name, " (", round(vals$Z, 2), ")")
      xy <- terra::crds(pts, df = TRUE)
      graphics::text(xy[, 1], xy[, 2], labels = labels, pos = 3,
                     cex = 0.7, col = "black")
    }
  }
  graphics::grid()
  invisible(file)
}

#' Export potentiometric-surface products
#'
#' Writes deterministic GeoTIFF, vector, contour-manifest, quicklook, support,
#' and diagnostic products only when an output directory is supplied. GeoPackage
#' is recommended because it preserves field names and supports multiple layers
#' better than shapefiles; the shapefile default is retained for compatibility.
#'
#' @param surfaces Named raster list or `potentiomap_result`.
#' @param out_dir Output directory.
#' @param out_stub Safe file prefix.
#' @param contour_interval Positive contour interval.
#' @param points Optional observation points for quicklooks.
#' @param write_raster,write_contours,write_png Choose outputs.
#' @param contour_levels Optional explicit levels.
#' @param vector_format Either `"shapefile"` or `"gpkg"`.
#' @param support Optional `potentiomap_support`; defaults to support stored in a
#'   structured interpolation result.
#' @param diagnostics Optional diagnostic list; defaults to structured-result
#'   diagnostics.
#' @param write_contour_manifest,write_support,write_diagnostics,write_manifest
#'   Choose sidecar products.
#' @param overwrite Overwrite existing outputs.
#'
#' @return A data frame describing written files.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' surfaces <- ps_interpolate(pts, methods = "IDW", grid_res = 200)
#' ps_export_surfaces(surfaces, tempdir(), points = pts)
ps_export_surfaces <- function(surfaces, out_dir, out_stub = "gw",
                               contour_interval = 1, points = NULL,
                               write_raster = TRUE, write_contours = TRUE,
                               write_png = TRUE, contour_levels = NULL,
                               vector_format = c("shapefile", "gpkg"),
                               support = NULL, diagnostics = NULL,
                               write_contour_manifest = TRUE,
                               write_support = FALSE,
                               write_diagnostics = FALSE,
                               write_manifest = TRUE, overwrite = TRUE) {
  vector_format <- match.arg(vector_format)
  .validate_number(contour_interval, "contour_interval", lower = 0)
  if (!is.character(out_dir) || length(out_dir) != 1L || !nzchar(out_dir)) {
    .ps_abort("`out_dir` must be one nonempty path.",
              "potentiomap_export_error")
  }
  if (inherits(surfaces, "potentiomap_result")) {
    result <- surfaces
    surfaces <- result$surfaces
    if (is.null(support)) support <- result$support
    if (is.null(diagnostics)) diagnostics <- result$diagnostics
  }
  surfaces <- ps_surfaces(surfaces)
  if (is.null(names(surfaces)) || any(!nzchar(names(surfaces))) ||
      anyDuplicated(names(surfaces))) {
    .ps_abort("`surfaces` must have unique nonempty names.",
              "potentiomap_export_error")
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(out_dir)) {
    .ps_abort(sprintf("Could not create output directory `%s`.", out_dir),
              "potentiomap_export_error")
  }
  stub <- .safe_name(out_stub)
  rows <- list()
  for (nm in names(surfaces)) {
    method <- .safe_name(nm)
    surface <- .as_surface(surfaces[[nm]])
    contour_result <- suppressWarnings(ps_contours(
      surface, interval = contour_interval, levels = contour_levels,
      return = "result"
    ))
    tif <- file.path(out_dir, sprintf("%s_%s_surface.tif", stub, method))
    vector_ext <- if (vector_format == "gpkg") "gpkg" else "shp"
    vector_file <- file.path(out_dir, sprintf("%s_%s_contours.%s",
                                              stub, method, vector_ext))
    png <- file.path(out_dir, sprintf("%s_%s_quicklook.png", stub, method))
    contour_csv <- file.path(out_dir, sprintf("%s_%s_contour_manifest.csv",
                                              stub, method))
    written <- character()
    tryCatch({
      if (write_raster) {
        terra::writeRaster(surface, tif, overwrite = overwrite)
        written <- c(written, tif)
      } else tif <- NA_character_
      if (write_contours) {
        if (!overwrite && file.exists(vector_file)) stop("vector output exists")
        terra::writeVector(contour_result$contours, vector_file,
                           overwrite = overwrite)
        written <- c(written, vector_file)
      } else vector_file <- NA_character_
      if (write_png) {
        ps_quicklook(surface, contour_result$contours, points, png,
                     sprintf("Potentiometric surface: %s", nm),
                     overwrite = overwrite)
        written <- c(written, png)
      } else png <- NA_character_
      if (write_contour_manifest) {
        if (!overwrite && file.exists(contour_csv)) stop("contour manifest exists")
        utils::write.csv(contour_result$manifest, contour_csv, row.names = FALSE,
                         na = "")
        written <- c(written, contour_csv)
      } else contour_csv <- NA_character_
    }, error = function(e) {
      .remove_export_files(written)
      .ps_abort(
        sprintf("Could not export method `%s`: %s", nm, conditionMessage(e)),
        "potentiomap_export_error"
      )
    })
    rows[[nm]] <- data.frame(
      method = nm, raster = tif, contours = vector_file, quicklook = png,
      contour_manifest = contour_csv, stringsAsFactors = FALSE
    )
  }
  manifest <- do.call(rbind, rows)
  rownames(manifest) <- NULL
  if (write_support) {
    if (!inherits(support, "potentiomap_support")) {
      .ps_abort("`write_support = TRUE` requires a potentiomap_support object.",
                "potentiomap_export_error")
    }
    support_file <- file.path(out_dir, paste0(stub, "_prediction_support.tif"))
    terra::writeRaster(support$rasters, support_file, overwrite = overwrite)
  }
  if (write_diagnostics) {
    if (is.null(diagnostics) || !is.list(diagnostics)) {
      .ps_abort("`write_diagnostics = TRUE` requires diagnostic data.",
                "potentiomap_export_error")
    }
    diagnostic_file <- file.path(out_dir, paste0(stub, "_diagnostics.csv"))
    utils::write.csv(.diagnostic_scalars(diagnostics), diagnostic_file,
                     row.names = FALSE, na = "")
  }
  if (write_manifest) {
    manifest_file <- file.path(out_dir, paste0(stub, "_output_manifest.csv"))
    if (!overwrite && file.exists(manifest_file)) {
      .ps_abort("Output manifest exists and `overwrite = FALSE`.",
                "potentiomap_export_error")
    }
    utils::write.csv(manifest, manifest_file, row.names = FALSE, na = "")
  }
  manifest
}

.diagnostic_scalars <- function(diagnostics) {
  rows <- list()
  for (method in names(diagnostics)) {
    values <- diagnostics[[method]]
    scalar <- values[vapply(values, function(x) length(x) == 1L &&
                              (is.atomic(x) || is.null(x)), logical(1))]
    rows[[method]] <- data.frame(
      method = method, field = names(scalar),
      value = vapply(scalar, as.character, character(1)),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

.remove_export_files <- function(files) {
  for (file in files) {
    if (grepl("\\.shp$", file, ignore.case = TRUE)) {
      stem <- sub("\\.shp$", "", file, ignore.case = TRUE)
      unlink(paste0(stem, c(".shp", ".shx", ".dbf", ".prj", ".cpg")))
    } else unlink(file)
  }
  invisible(NULL)
}

.label_contours <- function(contours, units = NULL) {
  level_name <- intersect(c("level", "levels", "value", "elevation"),
                          names(contours))[1]
  if (is.na(level_name) || !nrow(contours)) return(invisible(NULL))
  values <- terra::values(contours)
  for (level in unique(values[[level_name]])) {
    segments <- contours[which(values[[level_name]] == level)]
    point <- try(terra::spatSample(segments, size = 1, method = "regular"),
                 silent = TRUE)
    if (inherits(point, "try-error") || !nrow(point)) next
    xy <- terra::crds(point, df = TRUE)
    label <- paste(format(level, trim = TRUE), units %||% "")
    graphics::text(xy[1, 1], xy[1, 2], labels = label, cex = 0.72,
                   col = "white", pos = 3, xpd = NA)
    graphics::text(xy[1, 1], xy[1, 2], labels = label, cex = 0.65,
                   col = "black", pos = 3, xpd = NA)
  }
  invisible(NULL)
}
