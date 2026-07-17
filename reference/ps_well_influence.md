# Calculate conditional leave-one-well influence

Calculate conditional leave-one-well influence

## Usage

``` r
ps_well_influence(
  points,
  method = "TPS",
  template = NULL,
  mask = NULL,
  grid_res = NULL,
  contour_levels = NULL,
  difference_threshold = NULL,
  interpolation_control = list(),
  progress = NULL
)
```

## Arguments

- points:

  Groundwater-head points.

- method:

  Interpolation method.

- template, mask, grid_res:

  Fixed surface controls.

- contour_levels:

  Optional comparison contours.

- difference_threshold:

  Optional absolute-difference area threshold.

- interpolation_control:

  Named interpolation controls.

- progress:

  Optional callback.

## Value

A `potentiomap_well_influence` object. Influence is conditional on this
network and method and is not evidence that a well is erroneous.

## Examples

``` r
data("synthetic_wells")
p <- ps_make_points(synthetic_wells[1:7, ], "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
influence <- ps_well_influence(p, method = "IDW", grid_res = 350)
influence$influence[, c("well_id", "held_out_residual", "status")]
#>    well_id held_out_residual  status
#> x    MW-01      0.3731615509 success
#> x1   MW-02      0.8260783266 success
#> x2   MW-03     -2.8687849589 success
#> x3   MW-04      0.3232249216 success
#> x4   MW-05     -0.0034458989 success
#> x5   MW-06     -0.6882900343 success
#> x6   MW-07      0.0004870479 success
# High conditional influence is not an automatic data-error classification.
```
