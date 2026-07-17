# Evaluate explicit interpolation sensitivity scenarios

Evaluate explicit interpolation sensitivity scenarios

## Usage

``` r
ps_surface_sensitivity(
  points,
  method,
  scenarios,
  reference = NULL,
  template = NULL,
  mask = NULL,
  maximum_runs = 100,
  contour_levels = NULL,
  compare_gradient = TRUE,
  seed = 1,
  progress = NULL
)
```

## Arguments

- points:

  Groundwater-head points.

- method:

  Interpolation method.

- scenarios:

  Explicit data frame or named parameter grid.

- reference:

  Scenario ID or row used as reference.

- template, mask:

  Default mapping controls.

- maximum_runs:

  Maximum scenario guard.

- contour_levels:

  Optional contour levels.

- compare_gradient:

  Compare gradient direction.

- seed:

  Deterministic seed.

- progress:

  Optional callback.

## Value

A `potentiomap_sensitivity` object. No preferred scenario is selected.

## Examples

``` r
data("synthetic_wells")
p <- ps_make_points(synthetic_wells[1:12, ], "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
scenarios <- data.frame(idw_power = c(1.5, 2), grid_res = c(300, 300))
sensitivity <- ps_surface_sensitivity(p, "IDW", scenarios, reference = 1)
sensitivity$comparisons[, c("scenario_id", "mean_absolute_difference")]
#>     scenario_id mean_absolute_difference
#> 1 scenario_0001                0.0000000
#> 2 scenario_0002                0.2422791
# Sensitivity comparison does not select a universally preferred setting.
```
