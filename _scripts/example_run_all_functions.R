# Complete potentiomap example using bundled synthetic data.
# Run from the package root after installing/loading the package.

suppressPackageStartupMessages({
  if (file.exists("DESCRIPTION") &&
      any(grepl("^Package: potentiomap$", readLines("DESCRIPTION")))) {
    devtools::load_all(".")
  } else {
    library(potentiomap)
  }
  library(terra)
})

data("synthetic_wells")
data("synthetic_dem")
data("synthetic_surface_points")
synthetic_dem <- terra::rast(synthetic_dem)

out_dir <- file.path(tempdir(), "potentiomap_example_outputs")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# 1. Direct groundwater elevation measurements to standardized points.
gw_points_direct <- ps_make_points(
  synthetic_wells,
  x = "x",
  y = "y",
  value = "gw_elevation",
  name_col = "well_id",
  crs = "EPSG:26916"
)

# 2. Depth-to-water plus DEM raster to groundwater elevation points.
gw_points_from_dem <- ps_potentiometric_points(
  synthetic_wells,
  x = "x",
  y = "y",
  depth_col = "depth_to_water",
  surface = synthetic_dem,
  name_col = "well_id",
  crs = "EPSG:26916"
)

# 3. Depth-to-water plus a surface-elevation column.
gw_points_from_column <- ps_potentiometric_points(
  synthetic_wells,
  x = "x",
  y = "y",
  depth_col = "depth_to_water",
  surface_col = "surface_elevation",
  name_col = "well_id",
  crs = "EPSG:26916"
)

# 4. Depth-to-water plus separate surface elevation point measurements.
gw_points_from_surface_points <- ps_potentiometric_points(
  synthetic_wells,
  x = "x",
  y = "y",
  depth_col = "depth_to_water",
  surface = synthetic_surface_points,
  surface_col = "surface_elevation",
  name_col = "well_id",
  surface_name_col = "point_id",
  crs = "EPSG:26916"
)

# 5. Build an AOI and interpolate multiple potentiometric surfaces.
aoi <- ps_sample_aoi()
surfaces <- ps_interpolate(
  gw_points_from_dem,
  methods = c("IDW", "TPS", "OK", "UK"),
  grid_res = 50,
  mask = aoi,
  padding = 150,
  idw_power = 2,
  idw_nmax = 15,
  tps_lambda = NULL
)

# 6. Create contours directly from one surface.
tps_contours <- ps_contours(surfaces$TPS, interval = 1)
writeVector(
  tps_contours,
  file.path(out_dir, "synthetic_TPS_contours_only.shp"),
  overwrite = TRUE
)

# 7. Export rasters, contours, and quicklook PNGs for all surfaces.
output_index <- ps_export_surfaces(
  surfaces,
  points = gw_points_from_dem,
  out_dir = out_dir,
  out_stub = "synthetic",
  contour_interval = 1
)
print(output_index)

# 8. Make one quicklook manually.
ps_quicklook(
  surfaces$IDW,
  contours = ps_contours(surfaces$IDW, interval = 1),
  points = gw_points_direct,
  file = file.path(out_dir, "manual_IDW_quicklook.png"),
  title = "Synthetic IDW quicklook"
)

# 9. Generate hydraulic-gradient raster, points, and flow arrows.
flow <- ps_flow_arrows(
  surfaces$TPS,
  res_factor = 8,
  scale = 80,
  out_dir = out_dir,
  out_stub = "synthetic_TPS"
)

# 10. Extract arrow tips and bases.
tips <- ps_arrow_vertices(
  flow$arrows,
  which = "last",
  out_file = file.path(out_dir, "synthetic_TPS_arrow_tips.shp")
)
bases <- ps_arrow_vertices(
  flow$arrows,
  which = "first",
  out_file = file.path(out_dir, "synthetic_TPS_arrow_bases.shp")
)

print(gw_points_from_column)
print(gw_points_from_surface_points)
print(tips)
print(bases)
cat("Example outputs written to:", out_dir, "\n")
