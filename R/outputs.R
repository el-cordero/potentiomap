#' Create contours from a surface raster
#'
#' @param surface A `terra::SpatRaster` potentiometric surface.
#' @param interval Contour interval in map elevation units.
#' @param levels Optional explicit contour levels. When supplied, `interval` is
#'   ignored.
#'
#' @return A line `terra::SpatVector` of contours.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' s <- ps_interpolate(pts, methods = "IDW", grid_res = 100)
#' ctr <- ps_contours(s$IDW, interval = 1)
#' ctr
ps_contours <- function(surface, interval = 1, levels = NULL) {
  vals <- terra::values(surface, mat = FALSE)
  vals <- vals[is.finite(vals)]
  if (length(vals) == 0) {
    stop("`surface` has no finite values.", call. = FALSE)
  }
  if (is.null(levels)) {
    rg <- range(vals)
    levels <- seq(
      floor(rg[1] / interval) * interval,
      ceiling(rg[2] / interval) * interval,
      by = interval
    )
    levels <- levels[levels > rg[1] & levels < rg[2]]
    if (length(levels) == 0) {
      levels <- mean(rg)
    }
  }
  terra::as.contour(surface, levels = levels)
}

#' Draw a quicklook surface plot
#'
#' @param surface A `SpatRaster`.
#' @param contours Optional contour `SpatVector`.
#' @param points Optional observation point `SpatVector`.
#' @param file Optional PNG output path. When `NULL`, plots to the active device.
#' @param title Plot title.
#' @param label_points Label points with `Name` and `Z`.
#' @param width,height,res PNG dimensions and resolution.
#'
#' @return Invisibly returns `file`.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' s <- ps_interpolate(pts, methods = "IDW", grid_res = 100)
#' ps_quicklook(s$IDW, points = pts, title = "Synthetic IDW")
ps_quicklook <- function(surface, contours = NULL, points = NULL, file = NULL,
                         title = "Potentiometric surface",
                         label_points = TRUE,
                         width = 1600, height = 1200, res = 180) {
  if (!is.null(file)) {
    dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
    grDevices::png(file, width = width, height = height, res = res)
    on.exit(grDevices::dev.off(), add = TRUE)
  }
  terra::plot(surface, main = title)
  if (!is.null(contours) && nrow(contours) > 0) {
    terra::plot(contours, add = TRUE, col = "white", lwd = 2)
    terra::plot(contours, add = TRUE, col = "blue", lwd = 1)
    .label_contours(contours)
  }
  if (!is.null(points)) {
    terra::plot(points, add = TRUE, pch = 21, bg = "white",
                col = "black", cex = 1)
    vals <- terra::values(points)
    if (label_points && all(c("Name", "Z") %in% names(vals))) {
      labels <- paste0(vals$Name, " (", round(vals$Z, 2), ")")
      xy <- terra::crds(points, df = TRUE)
      graphics::text(xy[, 1], xy[, 2], labels = labels, pos = 3,
                     cex = 0.7, col = "black")
    }
  }
  graphics::grid()
  invisible(file)
}

#' Export surfaces, contours, and quicklook PNGs
#'
#' @param surfaces A named list of `SpatRaster` objects, such as the result of
#'   `ps_interpolate()`.
#' @param out_dir Output directory.
#' @param out_stub File prefix.
#' @param contour_interval Contour interval.
#' @param points Optional observation points to draw on quicklook figures.
#' @param write_raster,write_contours,write_png Choose which outputs to write.
#'
#' @return A data frame listing written files.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' s <- ps_interpolate(pts, methods = "IDW", grid_res = 100)
#' out <- ps_export_surfaces(s, points = pts, out_dir = tempdir())
#' out
ps_export_surfaces <- function(surfaces, out_dir, out_stub = "gw",
                               contour_interval = 1, points = NULL,
                               write_raster = TRUE, write_contours = TRUE,
                               write_png = TRUE) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  rows <- list()
  for (nm in names(surfaces)) {
    surface <- surfaces[[nm]]
    contours <- ps_contours(surface, interval = contour_interval)
    tif <- file.path(out_dir, sprintf("%s_%s_surface.tif", out_stub, nm))
    shp <- file.path(out_dir, sprintf("%s_%s_contours.shp", out_stub, nm))
    png <- file.path(out_dir, sprintf("%s_%s_quicklook.png", out_stub, nm))
    if (write_raster) {
      terra::writeRaster(surface, tif, overwrite = TRUE)
    } else {
      tif <- NA_character_
    }
    if (write_contours) {
      terra::writeVector(contours, shp, overwrite = TRUE)
    } else {
      shp <- NA_character_
    }
    if (write_png) {
      ps_quicklook(
        surface, contours = contours, points = points, file = png,
        title = sprintf("Potentiometric surface - %s", nm)
      )
    } else {
      png <- NA_character_
    }
    rows[[nm]] <- data.frame(
      method = nm,
      raster = tif,
      contours = shp,
      quicklook = png,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

.label_contours <- function(contours) {
  lvl_name <- intersect(c("level", "levels", "value", "Level", "LEVEL"),
                        names(contours))[1]
  if (is.na(lvl_name)) {
    return(invisible(NULL))
  }
  vals <- terra::values(contours)
  for (level in unique(vals[[lvl_name]])) {
    segs <- contours[which(vals[[lvl_name]] == level), ]
    if (nrow(segs) < 1) {
      next
    }
    lab_pt <- try(terra::spatSample(segs, size = 1, method = "regular"),
                  silent = TRUE)
    if (inherits(lab_pt, "try-error")) {
      next
    }
    xy <- terra::crds(lab_pt, df = TRUE)
    if (nrow(xy) == 1) {
      graphics::text(xy[1, 1], xy[1, 2], labels = format(level, trim = TRUE),
                     cex = 0.7, col = "white", pos = 3, xpd = NA)
      graphics::text(xy[1, 1], xy[1, 2], labels = format(level, trim = TRUE),
                     cex = 0.65, col = "black", pos = 3, xpd = NA)
    }
  }
  invisible(NULL)
}
