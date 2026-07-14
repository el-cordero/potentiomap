# Complete potentiomap 0.1.0 example
# Install once with: install.packages("potentiomap")

library(potentiomap)
library(terra)

data("synthetic_wells", package = "potentiomap")

points <- ps_make_points(
  synthetic_wells,
  x = "x", y = "y",
  value = "gw_elevation",
  name_col = "well_id",
  crs = "EPSG:26916"
)

aoi <- ps_sample_aoi()
surfaces <- ps_interpolate(
  points,
  methods = c("TPS", "IDW"),
  grid_res = 100,
  mask = aoi,
  padding = 0
)

contours <- ps_contours(surfaces$TPS, interval = 1)

output_dir <- file.path(tempdir(), "potentiomap-complete-example")
files <- ps_export_surfaces(
  surfaces,
  out_dir = output_dir,
  out_stub = "synthetic",
  contour_interval = 1,
  points = points
)

flow <- ps_flow_arrows(
  surfaces$TPS,
  res_factor = 4,
  scale = 150,
  min_gradient = 1e-5,
  out_dir = output_dir,
  out_stub = "synthetic_TPS"
)

tips <- ps_arrow_vertices(
  flow$arrows,
  which = "last",
  out_file = file.path(output_dir, "synthetic_TPS_arrow_tips.gpkg")
)
bases <- ps_arrow_vertices(
  flow$arrows,
  which = "first",
  out_file = file.path(output_dir, "synthetic_TPS_arrow_bases.gpkg")
)

ps_quicklook(
  surfaces$TPS,
  contours = contours,
  points = points,
  title = "Synthetic TPS potentiometric surface"
)

print(files)
print(list(
  package_version = as.character(packageVersion("potentiomap")),
  crs = crs(surfaces$TPS, proj = TRUE),
  raster_dimensions = dim(surfaces$TPS),
  arrows = nrow(flow$arrows),
  tips = nrow(tips),
  bases = nrow(bases),
  output_directory = output_dir
))
