# Construct pointwise contour-uncertainty bands

Construct pointwise contour-uncertainty bands

## Usage

``` r
ps_contour_uncertainty(
  uncertainty,
  levels,
  probability = 0.9,
  method = c("empirical_crossing", "gaussian_pointwise"),
  keep_realized_contours = FALSE,
  minimum_realizations = 20,
  accept_gaussian = FALSE
)
```

## Arguments

- uncertainty:

  A `potentiomap_uncertainty` object.

- levels:

  Contour head levels.

- probability:

  Central pointwise probability.

- method:

  Empirical realization crossing or Gaussian pointwise method.

- keep_realized_contours:

  Retain contours for each realization.

- minimum_realizations:

  Minimum successful empirical realizations.

- accept_gaussian:

  Explicitly accept the Gaussian pointwise assumption.

## Value

A `potentiomap_contour_uncertainty` object. Bands are pointwise, not
simultaneous confidence regions.

## Examples

``` r
data("synthetic_wells")
p <- ps_make_points(synthetic_wells[1:14, ], "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
fit <- suppressWarnings(ps_interpolate(p, methods = "OK", grid_res = 300,
                                       return = "result"))
u <- ps_surface_uncertainty(fit, approach = "kriging_variance")
cu <- ps_contour_uncertainty(u, levels = 168, method = "gaussian_pointwise",
                             accept_gaussian = TRUE)
cu$level_manifest
#>   level probability             method pointwise_band_area_m2
#> 1   168         0.9 gaussian_pointwise                8100000
#>   finite_realizations gaussian_assumption
#> 1                   0                TRUE
# This is a pointwise band, not a simultaneous confidence region.
```
