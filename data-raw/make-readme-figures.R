if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("Install devtools before running this script.", call. = FALSE)
}

devtools::load_all(".")
suppressPackageStartupMessages(library(terra))

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

data("synthetic_wells")
data("synthetic_dem")
synthetic_dem <- terra::rast(synthetic_dem)

pts <- ps_potentiometric_points(
  synthetic_wells,
  x = "x",
  y = "y",
  depth_col = "depth_to_water",
  surface = synthetic_dem,
  name_col = "well_id",
  crs = "EPSG:26916"
)
aoi <- ps_sample_aoi()

panel_png <- function(file, expr, width = 2400, height = 650) {
  grDevices::png(file, width = width, height = height, res = 150)
  old <- par(no.readonly = TRUE)
  on.exit({
    par(old)
    grDevices::dev.off()
  }, add = TRUE)
  par(mfrow = c(1, 4), mar = c(1.8, 2, 3, 4), oma = c(0, 0, 0, 0))
  force(expr)
}

draw_arrows <- function(arrows_layer, col = "black", lwd = 1.3) {
  if (is.null(arrows_layer) || nrow(arrows_layer) < 1) {
    return(invisible(NULL))
  }
  for (i in seq_len(nrow(arrows_layer))) {
    xy <- terra::crds(arrows_layer[i], df = TRUE)
    if (nrow(xy) >= 2) {
      graphics::arrows(
        xy[1, 1], xy[1, 2],
        xy[nrow(xy), 1], xy[nrow(xy), 2],
        length = 0.08,
        angle = 25,
        col = col,
        lwd = lwd
      )
    }
  }
}

draw_surface <- function(surface, main, interval = 1, arrows = NULL) {
  terra::plot(surface, main = main, col = hcl.colors(32, "viridis"),
              axes = FALSE, plg = list(cex = 0.8))
  contours <- try(ps_contours(surface, interval = interval), silent = TRUE)
  if (!inherits(contours, "try-error") && nrow(contours) > 0) {
    terra::plot(contours, add = TRUE, col = "white", lwd = 2)
    terra::plot(contours, add = TRUE, col = "grey15", lwd = 0.8)
  }
  if (!is.null(arrows) && nrow(arrows) > 0) {
    draw_arrows(arrows, col = "black", lwd = 1.35)
  }
  terra::plot(pts, add = TRUE, pch = 21, bg = "white", col = "black", cex = 0.65)
}

method_surfaces <- suppressWarnings(ps_interpolate(
  pts,
  methods = c("TPS", "IDW", "OK", "UK"),
  grid_res = 60,
  mask = aoi,
  padding = 150
))

panel_png("man/figures/interpolation_methods.png", {
  for (method in names(method_surfaces)) {
    draw_surface(method_surfaces[[method]], paste(method, "interpolation"), interval = 1)
  }
})

resolution_values <- c(160, 100, 60, 30)
panel_png("man/figures/grid_resolution.png", {
  for (grid_res in resolution_values) {
    s <- ps_interpolate(pts, grid_res = grid_res, mask = aoi, padding = 150)
    draw_surface(s$TPS, paste("TPS grid resolution:", grid_res, "map units"),
                 interval = 1)
  }
})

base_surface <- ps_interpolate(pts, grid_res = 50, mask = aoi, padding = 150)$TPS
contour_intervals <- c(2, 1, 0.5, 0.25)
panel_png("man/figures/contour_intervals.png", {
  for (interval in contour_intervals) {
    draw_surface(base_surface, paste("Contour interval:", interval),
                 interval = interval)
  }
})

lambda_values <- list(
  "GCV-selected lambda" = NULL,
  "lambda = 1e-4" = 1e-4,
  "lambda = 1e-5" = 1e-5,
  "lambda = 1e-6" = 1e-6
)
panel_png("man/figures/tps_smoothing.png", {
  for (label in names(lambda_values)) {
    s <- suppressWarnings(ps_interpolate(
      pts,
      grid_res = 60,
      mask = aoi,
      padding = 150,
      tps_lambda = lambda_values[[label]]
    ))
    draw_surface(s$TPS, paste("TPS smoothing:", label), interval = 1)
  }
})

smoothing_values <- list(
  "No raster smoothing" = list(window_size = NULL, iterations = 0),
  "3 x 3 mean, 1 pass" = list(window_size = 3, iterations = 1),
  "5 x 5 mean, 1 pass" = list(window_size = 5, iterations = 1),
  "5 x 5 mean, 2 passes" = list(window_size = 5, iterations = 2)
)
panel_png("man/figures/raster_smoothing.png", {
  for (label in names(smoothing_values)) {
    spec <- smoothing_values[[label]]
    smoothed <- if (spec$iterations == 0) {
      base_surface
    } else {
      ps_smooth_surface(
        base_surface,
        window_size = spec$window_size,
        iterations = spec$iterations
      )
    }
    draw_surface(smoothed, label, interval = 1)
  }
})

arrow_density <- c(12, 8, 5, 3)
panel_png("man/figures/arrow_density.png", {
  for (res_factor in arrow_density) {
    flow <- ps_flow_arrows(base_surface, res_factor = res_factor, scale = 80)
    draw_surface(
      base_surface,
      paste("Arrow density: res_factor =", res_factor),
      interval = 1,
      arrows = flow$arrows
    )
  }
})

arrow_scales <- c(25, 50, 100, 150)
panel_png("man/figures/arrow_scale.png", {
  for (scale in arrow_scales) {
    flow <- ps_flow_arrows(base_surface, res_factor = 8, scale = scale)
    draw_surface(
      base_surface,
      paste("Arrow scale =", scale),
      interval = 1,
      arrows = flow$arrows
    )
  }
})
