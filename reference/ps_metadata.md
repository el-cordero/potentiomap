# Inspect scientific metadata

Returns the length-unit, vertical-reference, measurement-reference, and
depth-sign information attached by
[`ps_make_points()`](https://el-cordero.github.io/potentiomap/reference/ps_make_points.md)
or
[`ps_potentiometric_points()`](https://el-cordero.github.io/potentiomap/reference/ps_potentiometric_points.md).
Structured interpolation results also retain this information in their
input summary.

## Usage

``` r
ps_metadata(x)
```

## Arguments

- x:

  A potentiomap point object or structured result.

## Value

A named list, or `NULL` when no metadata are attached.

## Details

R-level attributes are not guaranteed to survive export to every GIS
vector format. Use an output manifest or sidecar table when these
details must accompany exported files. Matching units do not establish
that two vertical datums are compatible, and potentiomap does not
transform vertical datums.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(
  synthetic_wells, "x", "y", "gw_elevation", "well_id", "EPSG:26916",
  head_unit = "m", output_unit = "m", vertical_datum = "synthetic datum"
)
ps_metadata(pts)
#> $head_unit
#> [1] "m"
#> 
#> $output_unit
#> [1] "m"
#> 
#> $vertical_datum
#> [1] "synthetic datum"
#> 
#> $surface_reference
#> NULL
#> 
#> $metadata_mode
#> [1] "legacy"
#> 
```
