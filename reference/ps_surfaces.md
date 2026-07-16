# Extract interpolated surfaces

Extract interpolated surfaces

## Usage

``` r
ps_surfaces(x)
```

## Arguments

- x:

  A `potentiomap_result` or named list of `SpatRaster` surfaces.

## Value

A named list of
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
objects.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
result <- ps_interpolate(pts, methods = "IDW", grid_res = 150,
                         return = "result")
ps_surfaces(result)
#> $IDW
#> class       : SpatRaster
#> size        : 21, 22, 1  (nrow, ncol, nlyr)
#> resolution  : 150, 150  (x, y)
#> extent      : 500093.2, 503393.2, 4639910, 4643060  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 16N (EPSG:26916)
#> source(s)   : memory
#> name        :        IDW
#> min value   : 164.277299
#> max value   : 171.163169
#> 
```
