# Validate hydraulic-gradient arrow endpoints

Samples modeled head at each line base and tip and checks finite raster
support along the line. A downhill pass requires a finite line and a tip
no higher than the base within `tolerance`. Geometry is not reversed or
bent.

## Usage

``` r
ps_validate_arrows(
  surface,
  arrows,
  tolerance = 1e-06,
  extraction = c("bilinear", "simple")
)
```

## Arguments

- surface:

  One-layer modeled-head `SpatRaster`.

- arrows:

  Line `SpatVector` or readable vector path.

- tolerance:

  Nonnegative head tolerance.

- extraction:

  Either `"bilinear"` or `"simple"` endpoint extraction.

## Value

A `potentiomap_arrow_validation` list with validated `arrows`, an
arrow-level `records` data frame, and a concise `summary`.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
surface <- ps_interpolate(pts, methods = "IDW", grid_res = 150)$IDW
legacy <- ps_flow_arrows(surface, endpoint_action = "none")
checked <- ps_validate_arrows(surface, legacy$arrows)
checked$summary
#>   endpoint_action arrows_generated arrows_retained finite_support downhill_pass
#> 1        validate                9               9              9             9
#>   failed shortened dropped
#> 1      0         0       0
```
