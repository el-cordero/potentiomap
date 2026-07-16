# Make groundwater observation points

Converts a coordinate table, `sf` point object, or `terra` point vector
to a `SpatVector` with standard `Z` and `Name` fields. Optional unit and
vertical reference information is retained as package metadata; a
horizontal CRS is never interpreted as a vertical datum.

## Usage

``` r
ps_make_points(
  data,
  x = "x",
  y = "y",
  value,
  name_col = NULL,
  crs = NULL,
  metadata = NULL,
  head_unit = NULL,
  output_unit = NULL,
  vertical_datum = NULL,
  surface_reference = NULL,
  metadata_mode = c("legacy", "warn", "strict"),
  invalid_action = c("drop", "error")
)
```

## Arguments

- data:

  A data frame, `sf` object, or
  [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
  containing point observations.

- x, y:

  Coordinate column names for tabular data.

- value:

  Groundwater elevation column name.

- name_col:

  Optional well or station name column.

- crs:

  Coordinate reference system for tabular data, such as `"EPSG:26916"`.

- metadata:

  Optional named list containing scientific metadata.

- head_unit:

  Unit of `value`; accepted spellings represent metres or the
  international foot.

- output_unit:

  Desired unit of `Z`. When supplied with `head_unit`, values are
  converted using exactly 1 ft = 0.3048 m.

- vertical_datum:

  Documented vertical datum. It is recorded, not transformed.

- surface_reference:

  Measurement reference, such as `"land_surface"` or
  `"measuring_point"`.

- metadata_mode:

  One of `"legacy"`, `"warn"`, or `"strict"`. Legacy mode accepts
  numeric data without metadata; warning mode reports omissions; strict
  mode rejects them.

- invalid_action:

  Either `"drop"` to report and remove invalid records or `"error"` to
  stop.

## Value

A point
[`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
with standardized attributes and optional metadata available through
[`ps_metadata()`](https://el-cordero.github.io/potentiomap/reference/ps_metadata.md).
The `dropped_records` attribute summarizes invalid observations.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(
  synthetic_wells,
  x = "x", y = "y",
  value = "gw_elevation",
  name_col = "well_id",
  crs = "EPSG:26916",
  head_unit = "m", output_unit = "m",
  vertical_datum = "synthetic example datum",
  surface_reference = "land_surface"
)
pts
#> class       : SpatVector
#> geometry    : points
#> dimensions  : 32, 6  (geometries, attributes)
#> extent      : 500393.2, 503067.2, 4640210, 4642804  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 16N (EPSG:26916)
#> names       : well_id surface_elevation depth_to_water gw_elevation      Z  Name
#> type        :   <chr>             <num>          <num>        <num>  <num> <chr>
#> values      :   MW-01            185.13          18.48       166.65 166.65 MW-01
#>                 MW-02            183.89          18.39        165.5  165.5 MW-02
#>                 MW-03            190.43          18.97       171.45 171.45 MW-03
#>               ...
```
