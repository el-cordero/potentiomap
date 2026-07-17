# Compare validated interpolation methods

Ranks adequately covered methods within an explicit validation design
and support subset. It does not declare a universally best method and
does not aggregate multiple objectives unless the user supplies weights.

## Usage

``` r
ps_compare_methods(
  validation,
  metric = "rmse",
  design = NULL,
  support_subset = c("all", "finite", "supported"),
  minimum_coverage = 0.9,
  tie_tolerance = NULL,
  objective_weights = NULL,
  select = FALSE
)
```

## Arguments

- validation:

  A `potentiomap_validation` or documented compatible metric table.

- metric:

  One or more metric columns.

- design:

  One validation design; required when multiple designs exist.

- support_subset:

  All scheduled, finite, or supported predictions.

- minimum_coverage:

  Minimum finite coverage.

- tie_tolerance:

  Nonnegative absolute metric tolerance; default is a scale-aware
  square-root machine tolerance.

- objective_weights:

  Explicit named nonnegative weights for multiple criteria.

- select:

  Select one method only after all selection gates pass.

## Value

A `potentiomap_method_comparison` with ranking, Pareto status and
optional selection.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation", "well_id", "EPSG:26916")
val <- ps_validate(pts, "IDW", "kfold", folds = 3, prediction_mode = "direct")
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
ps_compare_methods(val)$ranking
#>   method design  scope fold_id support_subset scheduled_count evaluated_count
#> 1    IDW  kfold pooled    <NA>            all              32              32
#>   finite_count supported_count         me       mae      rmse     medae   maxae
#> 1           32              18 0.06036557 0.7422033 0.9634087 0.6072782 2.74671
#>   finite_fraction finite_coverage support_coverage adequate_coverage rank
#> 1               1               1           0.5625              TRUE    1
#>   tie_status
#> 1  tied_best
# Ranking is specific to this design and objective.
```
