# Describe prediction support and extrapolation

Classifies raster cells using the training-point convex hull, distance
to the nearest observation, an optional maximum distance, mask
membership, and finite prediction availability. The convex hull is a
training-network geometry, not an aquifer boundary. Predictions are
described, not removed.

## Usage

``` r
ps_prediction_support(
  points,
  surface = NULL,
  template = NULL,
  mask = NULL,
  max_distance = NULL,
  allow_geographic = FALSE
)
```

## Arguments

- points:

  Training observations as a point `SpatVector`, `sf` object, or object
  readable by
  [`terra::vect()`](https://rspatial.github.io/terra/reference/vect.html).

- surface:

  Optional one-layer prediction `SpatRaster`.

- template:

  Optional one-layer template when `surface` is not supplied.

- mask:

  Optional polygon mask used to classify cells.

- max_distance:

  Optional positive distance threshold in projected map units.

- allow_geographic:

  Allow longitude/latitude calculations with a classed warning. The
  default is `FALSE`.

## Value

A `potentiomap_support` list containing `rasters`, a reason-code
`lookup` table, a cell-level `records` table, `summary`, the
standardized training `points`, and `call`. Stable support classes are
`supported`, `outside_training_hull`, `beyond_maximum_distance`,
`outside_mask`, `prediction_unavailable`, and `multiple_limitations`.

## Details

Distance calculations require projected coordinates by default. An
explicit override reports that longitude/latitude degrees are not linear
ground units.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
surface <- ps_interpolate(pts, methods = "IDW", grid_res = 200)$IDW
support <- ps_prediction_support(pts, surface = surface,
                                 max_distance = 1000)
support$summary
#>             support_class cells    percent
#> 1               supported   173 59.8615917
#> 2   outside_training_hull   114 39.4463668
#> 3 beyond_maximum_distance     0  0.0000000
#> 4            outside_mask     0  0.0000000
#> 5  prediction_unavailable     0  0.0000000
#> 6    multiple_limitations     2  0.6920415
```
