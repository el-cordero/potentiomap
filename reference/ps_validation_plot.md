# Plot validation diagnostics with base graphics

Plot validation diagnostics with base graphics

## Usage

``` r
ps_validation_plot(
  x,
  type = c("metric", "observed_predicted", "residual_map", "residual_distribution",
    "fold_map", "support", "coverage", "method_conditions"),
  methods = NULL,
  design = NULL,
  support_subset = "all",
  display_limits = NULL,
  legend = TRUE,
  ...
)
```

## Arguments

- x:

  A validation or method-comparison result.

- type:

  Diagnostic plot type.

- methods, design:

  Optional subsets.

- support_subset:

  Support subset.

- display_limits:

  Optional explicit axis/value limits. Values remain in returned plot
  data and requested clipping is disclosed.

- legend:

  Draw a legend.

- ...:

  Base graphics arguments.

## Value

Plot data invisibly.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation", "well_id", "EPSG:26916")
val <- ps_validate(pts, "IDW", "kfold", folds = 3, prediction_mode = "direct")
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
ps_validation_plot(val, "observed_predicted")
```
