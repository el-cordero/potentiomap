# potentiomap

`potentiomap` is an R package for building potentiometric surface products from
groundwater monitoring data. It standardizes common field inputs, interpolates
groundwater elevation surfaces with multiple methods, exports GIS-ready outputs,
and derives hydraulic-gradient flow arrows from the finished surface.

The package is designed for the practical groundwater workflow: start with a
well table, a DEM or land-surface elevation measurements, and depth-to-water or
groundwater elevation data; finish with rasters, contours, quicklook plots, and
flow-direction arrow layers that can be used in reports or GIS.

## Features

- Create standardized monitoring point layers from coordinate tables, `sf`
  objects, or `terra::SpatVector` point layers.
- Calculate groundwater elevations from depth-to-water measurements using:
  - a DEM raster,
  - a land-surface elevation column, or
  - separate land-surface elevation measurement points.
- Interpolate potentiometric surfaces using:
  - inverse distance weighting (`IDW`),
  - thin-plate spline (`TPS`),
  - ordinary kriging (`OK`), and
  - universal kriging with quadratic drift (`UK`).
- Export GeoTIFF surfaces, contour shapefiles, and quicklook PNG figures.
- Generate hydraulic-gradient rasters, sampled gradient points, flow-arrow line
  layers, and arrow-tip or arrow-base point layers.
- Includes synthetic but realistic example data so examples and tests do not
  depend on proprietary project data.

## Installation

Install from GitHub:

```r
install.packages("remotes")
remotes::install_github("el-cordero/potentiomap")
```

For local development from this repository:

```r
devtools::load_all(".")
devtools::test()
```

## Data Model

`potentiomap` standardizes groundwater observation points with two important
fields:

- `Z`: groundwater elevation, used for interpolation.
- `Name`: monitoring location label, used in quicklook plots.

Most functions accept either already-spatial inputs or ordinary coordinate
tables. For coordinate tables, provide `x`, `y`, and `crs`.

The bundled synthetic data include:

- `synthetic_wells`: well coordinates, land-surface elevation, depth to water,
  and groundwater elevation.
- `synthetic_dem`: a packed `terra` DEM raster. Use `terra::rast()` to unpack.
- `synthetic_surface_points`: separate synthetic land-surface elevation points.
- `ps_sample_aoi()`: an example area-of-interest polygon.

## Walkthrough 1: Direct Groundwater Elevation Measurements

Use this workflow when your table already contains groundwater elevation.

```r
library(potentiomap)
library(terra)

data("synthetic_wells")

gw_points <- ps_make_points(
  synthetic_wells,
  x = "x",
  y = "y",
  value = "gw_elevation",
  name_col = "well_id",
  crs = "EPSG:26916"
)

surfaces <- ps_interpolate(
  gw_points,
  methods = c("IDW", "TPS"),
  grid_res = 50,
  mask = ps_sample_aoi()
)

names(surfaces)
```

## Walkthrough 2: Depth to Water Plus a DEM

Use this workflow when field measurements are depths below land surface and a
DEM is available.

```r
library(potentiomap)
library(terra)

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

head(terra::values(gw_points))
```

## Walkthrough 3: Depth to Water Plus a Surface-Elevation Column

Use this workflow when each well record already includes land-surface elevation.

```r
gw_points <- ps_potentiometric_points(
  synthetic_wells,
  x = "x",
  y = "y",
  depth_col = "depth_to_water",
  surface_col = "surface_elevation",
  name_col = "well_id",
  crs = "EPSG:26916"
)
```

## Walkthrough 4: Depth to Water Plus Separate Surface Points

Use this workflow when land-surface elevations are stored separately from the
depth-to-water table. If names match, elevations are matched by name; otherwise
the surface points are interpolated to the groundwater measurement locations.

```r
data("synthetic_surface_points")

gw_points <- ps_potentiometric_points(
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
```

## Interpolate and Export Products

The main interpolation function returns a named list of rasters. Exporting writes
GIS and image products for each method.

```r
out_dir <- file.path(tempdir(), "potentiomap-products")

surfaces <- ps_interpolate(
  gw_points,
  methods = c("IDW", "TPS", "OK", "UK"),
  grid_res = 50,
  mask = ps_sample_aoi(),
  padding = 150,
  idw_power = 2,
  idw_nmax = 15
)

outputs <- ps_export_surfaces(
  surfaces,
  points = gw_points,
  out_dir = out_dir,
  out_stub = "synthetic",
  contour_interval = 1
)

outputs
```

Typical exported files include:

- `synthetic_IDW_surface.tif`
- `synthetic_IDW_contours.shp`
- `synthetic_IDW_quicklook.png`

The same pattern is used for `TPS`, `OK`, and `UK` when those methods are run.

## Generate Flow Arrows

`ps_flow_arrows()` derives slope and aspect from the potentiometric surface,
calculates hydraulic gradient, samples the grid to a readable arrow spacing, and
creates downgradient arrow line features.

```r
flow <- ps_flow_arrows(
  surfaces$TPS,
  res_factor = 8,
  scale = 80,
  out_dir = out_dir,
  out_stub = "synthetic_TPS"
)

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
```

Typical flow products include:

- `synthetic_TPS_hgrad.tif`
- `synthetic_TPS_hgrad_points.shp`
- `synthetic_TPS_hgrad_arrows.shp`
- `synthetic_TPS_arrow_tips.shp`
- `synthetic_TPS_arrow_bases.shp`

## Complete Local Example

Run the bundled example script from the package root:

```r
source("_scripts/example_run_all_functions.R")
```

That script exercises every public workflow with the bundled synthetic data and
writes rasters, contours, quicklook PNGs, hydraulic-gradient rasters, arrows,
arrow tips, and arrow bases to a temporary output directory.

## Local Build and QA Script

The repository includes a build/check helper:

```r
source("_scripts/build_check_local.R")
```

It runs:

- `roxygen2::roxygenise()`
- `devtools::test()`
- the full example script
- `R CMD build .`
- `R CMD check --no-manual potentiomap_0.1.0.tar.gz`

The script stops on the first failure and prints the output location for the
full example products.

## Notes on Interpolation

Different interpolation methods make different assumptions. `IDW` is simple and
stable for small monitoring networks. `TPS` often produces smooth surfaces and
is useful for reporting contours. `OK` and `UK` require fitting a variogram, so
they may emit convergence warnings on sparse or synthetic datasets. Those
warnings should be reviewed rather than automatically suppressed; they can tell
you whether the spatial structure in the data supports the kriging model.

## Repository Layout

```text
R/          Package functions
data/       Bundled synthetic example data
data-raw/   Script used to generate synthetic data
man/        Generated function documentation
tests/      Unit and integration tests
_scripts/   Full examples and local build/check scripts
```

The package repository intentionally does not include proprietary project data.
