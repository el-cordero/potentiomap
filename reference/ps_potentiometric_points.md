# Build potentiometric points from depth-to-water measurements

Calculates groundwater elevation from land-surface elevation and a
documented depth convention. Surface elevation can come from a DEM, a
column in the depth table, or separate surface-elevation points.
Separate points are matched by name where possible and otherwise
interpolated by IDW.

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
  idw_power = 2,
  metadata = NULL,
  depth_unit = NULL,
  surface_unit = NULL,
  output_unit = NULL,
  vertical_datum = NULL,
  surface_reference = NULL,
  depth_sign = NULL,
  measuring_point_offset = NULL,
  metadata_mode = c("legacy", "warn", "strict"),
  invalid_action = c("drop", "error")
)
```

## Arguments

- data:

  Depth-to-water observations as a data frame, `sf`, or
  [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html).

- x, y:

  Coordinate column names for tabular depth data.

- depth_col:

  Depth-to-water column name.

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

  Positive IDW power for unmatched surface points.

- metadata:

  Optional named list of scientific metadata.

- depth_unit, surface_unit, output_unit:

  Supported length units.

- vertical_datum:

  Documented vertical datum; it is recorded, not transformed.

- surface_reference:

  Either `"land_surface"` or `"measuring_point"`.

- depth_sign:

  Either `"positive_down"` or `"signed"`.

- measuring_point_offset:

  Height of the measuring point above land surface, expressed in
  `surface_unit`. It is not inferred.

- metadata_mode:

  One of `"legacy"`, `"warn"`, or `"strict"`.

- invalid_action:

  Either `"drop"` or `"error"`.

## Value

A point
[`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
with `surface_elevation`, `depth_to_water`, and `Z` in `output_unit`,
plus metadata available through
[`ps_metadata()`](https://el-cordero.github.io/potentiomap/reference/ps_metadata.md).

## Details

With `depth_sign = "positive_down"`, groundwater elevation equals
reference elevation minus depth. With `depth_sign = "signed"`, a
negative value denotes water below the reference and is added to the
reference elevation. A measuring-point offset is added to land-surface
elevation only when `surface_reference = "measuring_point"`. potentiomap
converts supported units but does not transform vertical datums or guess
measuring-point offsets.

## Examples

``` r
data("synthetic_wells")
gw <- ps_potentiometric_points(
  synthetic_wells, "x", "y", "depth_to_water",
  surface_col = "surface_elevation", name_col = "well_id",
  crs = "EPSG:26916", depth_unit = "m", surface_unit = "m",
  output_unit = "m", vertical_datum = "synthetic example datum",
  surface_reference = "land_surface", depth_sign = "positive_down"
)
head(terra::values(gw))
#>   well_id surface_elevation depth_to_water gw_elevation      Z  Name
#> 1   MW-01            185.13          18.48       166.65 166.65 MW-01
#> 2   MW-02            183.89          18.39       165.50 165.50 MW-02
#> 3   MW-03            190.43          18.97       171.45 171.46 MW-03
#> 4   MW-04            184.35          18.66       165.70 165.69 MW-04
#> 5   MW-05            189.02          20.02       169.00 169.00 MW-05
#> 6   MW-06            188.40          18.87       169.53 169.53 MW-06
```
