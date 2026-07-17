# Small deterministic fixtures for potentiomap 0.2.0 examples and tests.
set.seed(20260717)

base_ids <- sprintf("EW-%02d", 1:20)
base_x <- 500000 + runif(20, 0, 3000)
base_y <- 4640000 + runif(20, 0, 2500)
base_head <- 172 - 0.0012 * (base_x - 500000) - 0.0006 * (base_y - 4640000) +
  1.2 * exp(-((base_x - 501400)^2 + (base_y - 4641200)^2) / 8e5)
synthetic_events <- rbind(
  data.frame(well_id = base_ids[1:18], x = base_x[1:18], y = base_y[1:18],
             datetime = as.POSIXct("2025-03-15 12:00:00", tz = "UTC") + seq(-7200, 7200, length.out = 18),
             event = "spring", head = round(base_head[1:18], 3), quality = rep(c("A", "B"), 9),
             unit = "m", vertical_datum = "NAVD88", water_bearing_unit = "sand_A"),
  data.frame(well_id = base_ids[3:20], x = base_x[3:20], y = base_y[3:20],
             datetime = as.POSIXct("2025-09-15 12:00:00", tz = "UTC") + seq(-5400, 5400, length.out = 18),
             event = "autumn", head = round(base_head[3:20] - 0.65 + 0.15 * sin(seq_len(18)), 3),
             quality = rep(c("A", "B"), 9), unit = "m", vertical_datum = "NAVD88",
             water_bearing_unit = "sand_A")
)

synthetic_nested_wells <- data.frame(
  nest_id = rep(sprintf("N-%02d", 1:8), each = 2),
  interval = rep(c("upper", "lower"), 8),
  x = rep(500300 + seq(0, 2100, length.out = 8), each = 2),
  y = rep(4640300 + seq(0, 1400, length.out = 8), each = 2),
  head = as.vector(rbind(165 + seq(0, 2.1, length.out = 8),
                         165 + seq(0, 2.1, length.out = 8) + c(0.5, -0.4, 0, 0.3, -0.2, 0.7, -0.5, 0))),
  representative_elevation = rep(c(142, 122), 8),
  screen_top = rep(c(147, 127), 8), screen_bottom = rep(c(137, 117), 8),
  unit = "m", vertical_datum = "NAVD88"
)

synthetic_regions <- data.frame(
  region_id = c("western_compartment", "eastern_compartment"),
  xmin = c(500000, 501500), xmax = c(501500, 503000),
  ymin = c(4640000, 4640000), ymax = c(4642500, 4642500),
  wkt = c("POLYGON ((500000 4640000, 501500 4640000, 501500 4642500, 500000 4642500, 500000 4640000))",
          "POLYGON ((501500 4640000, 503000 4640000, 503000 4642500, 501500 4642500, 501500 4640000))"),
  crs = "EPSG:26916"
)

grid <- expand.grid(x = seq(500000, 503000, length.out = 16),
                    y = seq(4640000, 4642500, length.out = 14))
grid$land_surface <- 190 - 0.0007 * (grid$x - 500000) + 0.001 * (grid$y - 4640000)
grid$valley_distance <- abs(grid$y - (4640800 + 0.35 * (grid$x - 500000)))
grid$planar_head <- 171 - 0.001 * (grid$x - 500000) - 0.0004 * (grid$y - 4640000)
grid$bowl_head <- 163 + ((grid$x - 501500)^2 + (grid$y - 4641250)^2) / 2e6
grid$saddle_head <- 168 + ((grid$x - 501500)^2 - (grid$y - 4641250)^2) / 3e6
grid$valley_head <- 0.75 * grid$land_surface - 0.0012 * grid$valley_distance + 27
grid$crs <- "EPSG:26916"
synthetic_covariates <- grid

synthetic_candidate_sites <- data.frame(
  candidate_id = sprintf("C-%02d", 1:12),
  x = seq(500100, 502900, length.out = 12),
  y = 4640300 + c(0, 250, 700, 1100, 1700, 2100, 350, 850, 1450, 1950, 550, 1250),
  excluded = c(TRUE, rep(FALSE, 10), TRUE),
  cost = seq(8, 19), user_score = c(1, 4, 3, 6, 8, 5, 9, 7, 10, 4, 6, 2),
  crs = "EPSG:26916"
)

synthetic_transect <- data.frame(
  transect_id = "T-01",
  wkt = "LINESTRING (500000 4640400, 501400 4641300, 503000 4642100)",
  crs = "EPSG:26916"
)

n_anis <- 45
ax <- runif(n_anis, 0, 3000); ay <- runif(n_anis, 0, 2500)
theta <- 35 * pi / 180
major <- ax * sin(theta) + ay * cos(theta)
minor <- ax * cos(theta) - ay * sin(theta)
synthetic_anisotropic_points <- data.frame(
  point_id = sprintf("A-%02d", seq_len(n_anis)),
  x = 500000 + ax, y = 4640000 + ay,
  head = 168 + sin(major / 700) + 0.25 * sin(minor / 120),
  crs = "EPSG:26916", generating_major_direction_degrees_clockwise_from_north = 35
)

synthetic_validation_points <- data.frame(
  validation_id = sprintf("V-%02d", 1:14),
  x = 500150 + runif(14, 0, 2700), y = 4640150 + runif(14, 0, 2200)
)
synthetic_validation_points$head <- 171 - 0.001 * (synthetic_validation_points$x - 500000) -
  0.0004 * (synthetic_validation_points$y - 4640000) + rnorm(14, 0, 0.08)
synthetic_validation_points$crs <- "EPSG:26916"

unlink("data/synthetic_expansion.rda")
fixtures <- c("synthetic_events", "synthetic_nested_wells", "synthetic_regions",
              "synthetic_covariates", "synthetic_candidate_sites", "synthetic_transect",
              "synthetic_anisotropic_points", "synthetic_validation_points")
for (fixture in fixtures) {
  save(list = fixture, file = file.path("data", paste0(fixture, ".rda")),
       compress = "xz", version = 2)
}
