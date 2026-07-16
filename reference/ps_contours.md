# Create contours and a contour-level inventory

Extracts contour lines from a one-layer surface. The default remains a
line `SpatVector`. The opt-in result inventories every requested level,
its relation to the finite surface range, returned feature count, and
any omission. Open lines are not converted to polygons.

## Usage

``` r
ps_contours(
  surface,
  interval = 1,
  levels = NULL,
  return = c("contours", "result")
)
```

## Arguments

- surface:

  One-layer potentiometric-surface `SpatRaster`.

- interval:

  Positive contour interval in surface units.

- levels:

  Optional finite explicit contour levels. `interval` is ignored when
  these are supplied.

- return:

  Either `"contours"` for the backward-compatible `SpatVector` or
  `"result"` for a structured inventory.

## Value

A line `SpatVector`, or a `potentiomap_contour_result` containing
`contours`, `manifest`, `surface_range`, `call`, `interval`, `levels`,
`warnings`, and `package_version`.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
surface <- ps_interpolate(pts, methods = "IDW", grid_res = 150)$IDW
result <- ps_contours(surface, levels = c(165, 168, 171), return = "result")
result$manifest
#>   requested_level surface_minimum surface_maximum       level_relation
#> 1             165        164.2773        171.1632 within_surface_range
#> 2             168        164.2773        171.1632 within_surface_range
#> 3             171        164.2773        171.1632 within_surface_range
#>   returned_status returned_feature_count omission_reason
#> 1        returned                      1                
#> 2        returned                      1                
#> 3        returned                      1                
```
