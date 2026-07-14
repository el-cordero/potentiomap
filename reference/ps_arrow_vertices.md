# Extract arrow base or tip points

Extract arrow base or tip points

## Usage

``` r
ps_arrow_vertices(arrows, which = c("last", "first"), out_file = NULL)
```

## Arguments

- arrows:

  A line `SpatVector` or path to a line vector file.

- which:

  `"first"` for arrow bases or `"last"` for arrow tips.

- out_file:

  Optional output vector path.

## Value

A point `SpatVector`.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
s <- ps_interpolate(pts, methods = "IDW", grid_res = 100)
#> [inverse distance weighted interpolation]
arrows <- ps_flow_arrows(s$IDW, res_factor = 4, scale = 60)
tips <- ps_arrow_vertices(arrows$arrows, which = "last")
tips
#> class       : SpatVector
#> geometry    : points
#> dimensions  : 49, 3  (geometries, attributes)
#> extent      : 500355.7, 502850.4, 4640185, 4642660  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 16N (EPSG:26916)
#> names       :     gwe      igrad  aspect
#> type        :   <num>      <num>   <num>
#> values      : 169.599 0.00199533 6.89488
#>                169.23 0.00196999 40.4709
#>               168.636 0.00183209 77.1184
#>               ...
```
