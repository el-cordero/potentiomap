# Extract interpolation diagnostics

Extract interpolation diagnostics

## Usage

``` r
ps_diagnostics(x, method = NULL)
```

## Arguments

- x:

  A `potentiomap_result`.

- method:

  Optional method name. When omitted, all method diagnostics are
  returned.

## Value

A named diagnostic list, or one method-specific list.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
result <- ps_interpolate(pts, methods = "IDW", grid_res = 150,
                         return = "result")
ps_diagnostics(result, "IDW")
#> $formula
#> [1] "Z ~ 1"
#> 
#> $observation_count
#> [1] 32
#> 
#> $idw_power
#> [1] 2
#> 
#> $idw_nmax
#> [1] 15
#> 
#> $return_status
#> [1] "success"
#> 
#> $requested_method
#> [1] "IDW"
#> 
#> $returned_method
#> [1] "IDW"
#> 
#> $finite_prediction_count
#> [1] 462
#> 
#> $nonfinite_prediction_count
#> [1] 0
#> 
```
