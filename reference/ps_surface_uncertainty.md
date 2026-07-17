# Quantify model-conditional or resampling surface variability

Quantify model-conditional or resampling surface variability

## Usage

``` r
ps_surface_uncertainty(
  x = NULL,
  points = NULL,
  method = NULL,
  approach = c("kriging_variance", "conditional_simulation", "tps_standard_error",
    "resampling_sensitivity"),
  nsim = 100,
  probabilities = c(0.05, 0.5, 0.95),
  resampling_design = NULL,
  template = NULL,
  mask = NULL,
  keep_realizations = FALSE,
  output_directory = NULL,
  seed = 1,
  progress = NULL,
  exceedance_levels = NULL
)
```

## Arguments

- x:

  A structured interpolation result.

- points:

  Points used for resampling sensitivity when `x` is absent.

- method:

  Interpolation method for resampling.

- approach:

  Uncertainty or sensitivity approach.

- nsim:

  Number of simulations or resamples.

- probabilities:

  Pointwise quantile probabilities.

- resampling_design:

  `"case"`, `"jackknife"`, or a list with a `type` and spatial `group`
  vector.

- template, mask:

  Mapping geometry controls.

- keep_realizations:

  Retain realization rasters in memory.

- output_directory:

  Optional realization directory.

- seed:

  Deterministic seed.

- progress:

  Optional callback.

- exceedance_levels:

  Optional head levels for exceedance probability.

## Value

A `potentiomap_uncertainty` object. Resampling products are sensitivity
summaries, not formal confidence intervals.

## Examples

``` r
data("synthetic_wells")
p <- ps_make_points(synthetic_wells[1:14, ], "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
fit <- suppressWarnings(ps_interpolate(p, methods = "OK", grid_res = 250,
                                       return = "result"))
uncertainty <- ps_surface_uncertainty(fit, approach = "kriging_variance")
uncertainty$method_manifest
#>   method         approach
#> 1     OK kriging_variance
#>                                                                                                             assumptions
#> 1 Model-conditional kriging variance under the fitted trend and variogram; this is not total hydrogeologic uncertainty.
#>   simulation_count seed
#> 1                0    1
# Kriging variance is conditional on the retained covariance model.
```
