# Make groundwater observation points

Convert a coordinate table, `sf` point object, or `terra` vector to a
`SpatVector` with standard `Z` and `Name` fields.

## Usage

``` r
ps_make_points(data, x = "x", y = "y", value, name_col = NULL, crs = NULL)
```

## Arguments

- data:

  A data frame, `sf` object, or
  [`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html).

- x, y:

  Coordinate column names for tabular data.

- value:

  Groundwater elevation column name.

- name_col:

  Optional well or station name column.

- crs:

  Coordinate reference system for tabular data, such as `"EPSG:26916"`.

## Value

A point
[`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
with standardized attributes.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(
  synthetic_wells,
  x = "x", y = "y",
  value = "gw_elevation",
  name_col = "well_id",
  crs = "EPSG:26916"
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
