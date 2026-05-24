#' Generate hydraulic-gradient flow arrows
#'
#' Derives slope, aspect, hydraulic gradient, and downgradient arrows from a
#' potentiometric surface raster.
#'
#' @param surface A groundwater elevation `SpatRaster`.
#' @param res_factor Factor used to thin arrows by resampling to a coarser grid.
#' @param scale Arrow length multiplier.
#' @param min_gradient Gradients below this value are dropped.
#' @param log_gradient Store `log1p()` transformed gradient in the output raster.
#' @param log_arrow Use `log1p()` transformed gradient for arrow lengths.
#' @param out_dir Optional output directory. When supplied, files are written.
#' @param out_stub File prefix used when writing outputs.
#'
#' @return A list with `raster`, `points`, and `arrows`.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' s <- ps_interpolate(pts, methods = "IDW", grid_res = 100)
#' arrows <- ps_flow_arrows(s$IDW, res_factor = 4, scale = 60)
#' arrows$arrows
ps_flow_arrows <- function(surface, res_factor = 7, scale = 50,
                           min_gradient = 1e-5, log_gradient = FALSE,
                           log_arrow = FALSE, out_dir = NULL,
                           out_stub = "gw") {
  r <- if (inherits(surface, "SpatRaster")) surface else terra::rast(surface)
  gwe <- r[[1]]
  names(gwe) <- "gwe"
  slope_rad <- try(terra::terrain(gwe, v = "slope", unit = "radians"),
                   silent = TRUE)
  if (inherits(slope_rad, "try-error")) {
    slope_rad <- terra::terrain(gwe, v = "slope", unit = "degrees") * pi / 180
  }
  igrad <- tan(slope_rad)
  aspect <- terra::terrain(gwe, v = "aspect", unit = "degrees")
  igrad[igrad < min_gradient] <- NA

  igrad_out <- if (log_gradient) log1p(igrad) else igrad
  gradient_raster <- c(gwe, igrad_out, aspect)
  names(gradient_raster) <- c("gwe", "igrad", "aspect")

  coarse <- terra::rast(
    crs = terra::crs(r),
    ext = terra::ext(r),
    res = terra::res(r) * res_factor
  )
  gwe_c <- terra::resample(gwe, coarse, method = "bilinear")
  igrad_c <- terra::resample(igrad_out, coarse, method = "bilinear")
  aspect_c <- terra::resample(aspect, coarse, method = "near")
  sampled <- c(gwe_c, igrad_c, aspect_c)
  names(sampled) <- c("gwe", "igrad", "aspect")

  pts <- terra::as.points(sampled)
  vals <- terra::values(pts)
  keep <- is.finite(vals$igrad) & is.finite(vals$aspect)
  pts <- pts[keep]
  vals <- terra::values(pts)
  coords <- terra::crds(pts)

  theta <- vals$aspect * pi / 180
  ux <- sin(theta)
  uy <- cos(theta)
  lengths <- vals$igrad
  if (log_arrow) {
    lengths <- log1p(lengths)
  }
  arrow_len <- lengths * mean(terra::res(sampled)) * scale
  line_geoms <- lapply(seq_len(nrow(coords)), function(i) {
    rbind(
      c(coords[i, 1], coords[i, 2]),
      c(coords[i, 1] + ux[i] * arrow_len[i],
        coords[i, 2] + uy[i] * arrow_len[i])
    )
  })
  arrows <- terra::vect(line_geoms, type = "lines", crs = terra::crs(r))
  terra::values(arrows) <- vals

  if (!is.null(out_dir)) {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    terra::writeRaster(
      gradient_raster,
      file.path(out_dir, paste0(out_stub, "_hgrad.tif")),
      overwrite = TRUE
    )
    terra::writeVector(
      pts,
      file.path(out_dir, paste0(out_stub, "_hgrad_points.shp")),
      overwrite = TRUE
    )
    terra::writeVector(
      arrows,
      file.path(out_dir, paste0(out_stub, "_hgrad_arrows.shp")),
      overwrite = TRUE
    )
  }
  list(raster = gradient_raster, points = pts, arrows = arrows)
}

#' Extract arrow base or tip points
#'
#' @param arrows A line `SpatVector` or path to a line vector file.
#' @param which `"first"` for arrow bases or `"last"` for arrow tips.
#' @param out_file Optional output vector path.
#'
#' @return A point `SpatVector`.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' s <- ps_interpolate(pts, methods = "IDW", grid_res = 100)
#' arrows <- ps_flow_arrows(s$IDW, res_factor = 4, scale = 60)
#' tips <- ps_arrow_vertices(arrows$arrows, which = "last")
#' tips
ps_arrow_vertices <- function(arrows, which = c("last", "first"),
                              out_file = NULL) {
  which <- match.arg(which)
  arrows <- if (inherits(arrows, "SpatVector")) arrows else terra::vect(arrows)
  verts <- lapply(seq_len(nrow(arrows)), function(i) {
    xy <- terra::crds(arrows[i], df = TRUE)
    if (which == "last") {
      xy[nrow(xy), , drop = FALSE]
    } else {
      xy[1, , drop = FALSE]
    }
  })
  verts <- do.call(rbind, verts)
  pts <- terra::vect(verts, geom = c("x", "y"), crs = terra::crs(arrows))
  terra::values(pts) <- terra::values(arrows)
  if (!is.null(out_file)) {
    terra::writeVector(pts, out_file, overwrite = TRUE)
  }
  pts
}
