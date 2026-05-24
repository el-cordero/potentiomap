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

panel_png <- function(file, expr, width = 1100, height = 1800) {
  grDevices::png(file, width = width, height = height, res = 150)
  old <- par(no.readonly = TRUE)
  on.exit({
    par(old)
    grDevices::dev.off()
  }, add = TRUE)
  par(mfrow = c(4, 1), mar = c(2.5, 3, 3.2, 5), oma = c(0, 0, 0, 0))
  force(expr)
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
    terra::plot(arrows, add = TRUE, col = "#d73027", lwd = 1.4)
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
