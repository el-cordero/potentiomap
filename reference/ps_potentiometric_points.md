# Build potentiometric points from depth-to-water measurements

Calculates groundwater elevation as surface elevation minus depth to
water. Surface elevation can come from a DEM raster, a column in the
depth table, or separate surface-elevation points. Separate surface
points are matched by name when possible; otherwise their elevations are
interpolated to the depth points with inverse distance weighting.

## Usage

``` r
ps_potentiometric_points(
  data,
  x = "x",
  y = "y",
  depth_col,
  surface = NULL,
  surface_col = NULL,
  name_col = NULL,
  surface_name_col = name_col,
  crs = NULL,
  idw_power = 2
)
```

## Arguments

- data:

  Depth-to-water observations as a data frame, `sf`, or
  [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html).

- x, y:

  Coordinate column names for tabular depth data.

- depth_col:

  Depth-to-water column name. Positive values are assumed to be depth
  below land surface.

- surface:

  A DEM `SpatRaster`, separate surface-elevation observations, or `NULL`
  when `surface_col` is used.

- surface_col:

  Surface-elevation column in `data`, or in `surface` when `surface` is
  a point/table object.

- name_col:

  Optional name column in `data`.

- surface_name_col:

  Optional name column in separate surface observations.

- crs:

  CRS for tabular depth data.

- idw_power:

  Power used when interpolating separate surface points.

## Value

A point
[`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
with `surface_elevation`, `depth_to_water`, and `Z` groundwater
elevation fields.

## Examples

``` r
data("synthetic_wells")
data("synthetic_dem")
gw <- ps_potentiometric_points(
  synthetic_wells,
  x = "x", y = "y",
  depth_col = "depth_to_water",
  surface = synthetic_dem,
  name_col = "well_id",
  crs = "EPSG:26916"
)
head(terra::values(gw))
#>   well_id surface_elevation depth_to_water gw_elevation        Z  Name
#> 1   MW-01          185.1316          18.48       166.65 166.6516 MW-01
#> 2   MW-02          183.8884          18.39       165.50 165.4984 MW-02
#> 3   MW-03          190.4255          18.97       171.45 171.4555 MW-03
#> 4   MW-04          184.3528          18.66       165.70 165.6928 MW-04
#> 5   MW-05          189.0185          20.02       169.00 168.9985 MW-05
#> 6   MW-06          188.4036          18.87       169.53 169.5336 MW-06
```
