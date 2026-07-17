# Tune interpolation parameters under recorded validation partitions

Compares explicit candidate configurations using the same deterministic
inner partitions. With an outer design, tuning occurs only inside each
outer training partition and the selected configuration is evaluated on
its outer holdout. Without an outer design, reported performance is
tuning performance, not an unbiased estimate of final predictive
performance.

## Usage

``` r
ps_tune_interpolation(
  points,
  method,
  candidates,
  inner_design = "spatial_block",
  outer_design = NULL,
  inner_folds = 5,
  outer_folds = 5,
  repeats = 1,
  metric = "rmse",
  minimum_coverage = 0.9,
  template = NULL,
  mask = NULL,
  grid_res = NULL,
  refit = TRUE,
  seed = 1,
  progress = NULL,
  search = c("grid", "random"),
  maximum_runs = 1000
)
```

## Arguments

- points:

  Groundwater-head points.

- method:

  One of `"TPS"`, `"IDW"`, `"OK"`, or `"UK"`.

- candidates:

  Candidate table or named parameter list.

- inner_design, outer_design:

  Inner and optional outer validation designs.

- inner_folds, outer_folds, repeats:

  Fold and repeat counts.

- metric:

  Objective metric minimized during selection.

- minimum_coverage:

  Minimum finite-prediction coverage.

- template, mask, grid_res:

  Fixed mapping controls.

- refit:

  Refit the selected configuration to all observations.

- seed:

  Deterministic seed.

- progress:

  Optional callback.

- search:

  Exhaustive grid or reproducible row sampling.

- maximum_runs:

  Maximum candidate-by-fold run guard.

## Value

A `potentiomap_tuning` object.

## Examples

``` r
data("synthetic_wells")
p <- ps_make_points(synthetic_wells[1:12, ], "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
tuned <- ps_tune_interpolation(p, "IDW", list(idw_power = c(1.5, 2)),
                               inner_design = "kfold", inner_folds = 3,
                               refit = FALSE, seed = 4)
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
tuned$candidates[, c("candidate_id", "metric", "coverage", "selected")]
#>     candidate_id   metric coverage selected
#> 1 candidate_0001 1.336077        1    FALSE
#> 2 candidate_0002 1.222580        1     TRUE
# These are tuning scores, not unbiased final performance estimates.
```
