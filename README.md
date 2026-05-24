# potentiomap

`potentiomap` turns groundwater measurements into potentiometric surfaces,
contours, quicklook figures, and hydraulic-gradient flow arrows.

The package accepts either direct groundwater elevation measurements or
depth-to-water measurements paired with a DEM raster, a surface-elevation
column, or separate surface-elevation points.

## Basic workflow

```r
library(potentiomap)

data("synthetic_wells")
data("synthetic_dem")
synthetic_dem <- terra::rast(synthetic_dem)

gw_points <- ps_potentiometric_points(
  synthetic_wells,
  x = "x",
  y = "y",
  depth_col = "depth_to_water",
  surface = synthetic_dem,
  name_col = "well_id",
  crs = "EPSG:26916"
)

surfaces <- ps_interpolate(
  gw_points,
  methods = c("IDW", "TPS"),
  grid_res = 50,
  mask = ps_sample_aoi()
)

outputs <- ps_export_surfaces(
  surfaces,
  points = gw_points,
  out_dir = tempfile("potentiomap-example-"),
  out_stub = "synthetic",
  contour_interval = 1
)

arrows <- ps_flow_arrows(surfaces$TPS, res_factor = 8, scale = 80)
```

See `_scripts/example_run_all_functions.R` for a complete runnable example.
