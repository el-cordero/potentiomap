# Compare fitted variogram models

Fits each requested gstat variogram candidate independently and
preserves initial values, fitted parameters, singular status, weighted
fitting error, warnings, and errors. Smallest variogram SSE is not proof
of best predictive performance.

## Usage

``` r
ps_variogram_compare(
  variogram,
  models = c("Sph", "Exp", "Gau", "Mat"),
  initial = NULL,
  fit_method = 7,
  anisotropy = NULL,
  validation = NULL,
  select = FALSE,
  selection_metric = c("validation_rmse", "weighted_sse")
)
```

## Arguments

- variogram:

  A `potentiomap_variogram` or gstat empirical variogram.

- models:

  Candidate model abbreviations.

- initial:

  Optional model or named model-specific initial values.

- fit_method:

  gstat fit method.

- anisotropy:

  Optional explicit anisotropy result or `c(angle, ratio)`.

- validation:

  Optional compatible validation result/table.

- select:

  Select a model using an explicitly supplied criterion.

- selection_metric:

  Validation RMSE or weighted variogram SSE.

## Value

A `potentiomap_variogram_comparison` with every fit and ranking.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
cmp <- ps_variogram_compare(ps_variogram(pts), c("Sph", "Exp"))
#> Warning: 2 lag-direction bin(s) contain fewer than five pairs.
cmp$ranking
#>     candidate_id model status singular weighted_sse nugget partial_sill range
#> 1 variogram_0001   Sph failed       NA           NA     NA           NA    NA
#> 2 variogram_0002   Exp failed       NA           NA     NA           NA    NA
#>   kappa warning_count error_count validation_rmse rank
#> 1    NA             0           1              NA   NA
#> 2    NA             0           1              NA   NA
# Weighted SSE alone is not a predictive-performance guarantee.
```
