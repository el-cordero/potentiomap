set.seed(42)

suppressPackageStartupMessages(library(terra))

crs_txt <- "EPSG:26916"
ext <- ext(499700, 503550, 4639900, 4643200)
synthetic_dem <- rast(ext, resolution = 50, crs = crs_txt)
xy <- xyFromCell(synthetic_dem, seq_len(ncell(synthetic_dem)))

surface <- 185.5 +
  0.0011 * (xy[, 1] - 500000) -
  0.00035 * (xy[, 2] - 4640000) +
  2.4 * sin((xy[, 1] - 499700) / 720) +
  1.8 * cos((xy[, 2] - 4639900) / 650)

values(synthetic_dem) <- surface
names(synthetic_dem) <- "surface_elevation"

n <- 32
well_xy <- cbind(
  runif(n, 500150, 503100),
  runif(n, 4640200, 4642850)
)
colnames(well_xy) <- c("x", "y")
well_surface <- extract(synthetic_dem, well_xy)[, 1]
flow_term <- 0.0022 * (well_xy[, 1] - 500000) +
  0.0011 * (well_xy[, 2] - 4640000)
mound <- 2.2 * exp(-(((well_xy[, 1] - 501850) / 850)^2 +
  ((well_xy[, 2] - 4641750) / 750)^2))
gw_elevation <- 173.8 - flow_term + mound + rnorm(n, 0, 0.12)
depth_to_water <- well_surface - gw_elevation

synthetic_wells <- data.frame(
  well_id = sprintf("MW-%02d", seq_len(n)),
  x = round(well_xy[, 1], 2),
  y = round(well_xy[, 2], 2),
  surface_elevation = round(well_surface, 2),
  depth_to_water = round(depth_to_water, 2),
  gw_elevation = round(gw_elevation, 2)
)

surf_xy <- cbind(
  runif(55, 499850, 503350),
  runif(55, 4640050, 4643050)
)
surf_z <- extract(synthetic_dem, surf_xy)[, 1] + rnorm(55, 0, 0.08)
synthetic_surface_points <- data.frame(
  point_id = sprintf("SP-%02d", seq_len(nrow(surf_xy))),
  x = round(surf_xy[, 1], 2),
  y = round(surf_xy[, 2], 2),
  surface_elevation = round(surf_z, 2)
)

synthetic_dem <- wrap(synthetic_dem, proxy = FALSE)

dir.create("data", showWarnings = FALSE)
save(synthetic_wells, file = "data/synthetic_wells.rda", compress = "xz")
save(synthetic_dem, file = "data/synthetic_dem.rda", compress = "xz")
save(synthetic_surface_points,
     file = "data/synthetic_surface_points.rda", compress = "xz")
