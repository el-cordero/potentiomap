# Combine compatible potentiometric surfaces

Calculates a cellwise ensemble and method-spread layers from compatible
head surfaces. Method spread is disagreement among supplied surfaces,
not statistical uncertainty, and an ensemble is not automatically more
accurate than a component method.

## Usage

``` r
ps_surface_ensemble(
  surfaces,
  statistic = c("mean", "median", "weighted_mean", "quantile"),
  weights = NULL,
  probabilities = c(0.1, 0.5, 0.9),
  support = c("intersection", "union"),
  minimum_methods = NULL,
  method_metadata = NULL
)
```

## Arguments

- surfaces:

  Named compatible one-layer head rasters or a `potentiomap_result`.

- statistic:

  Cellwise mean, median, named weighted mean, or quantiles.

- weights:

  Named nonnegative weights for `weighted_mean`. Attribute `origin` may
  record how they were derived.

- probabilities:

  Quantile probabilities.

- support:

  Use only the intersection or allow the union of finite cells.

- minimum_methods:

  Minimum finite component count. The default is all methods for
  intersection and one for union.

- method_metadata:

  Optional named metadata list supplementing raster metadata.

## Value

A `potentiomap_ensemble` with ensemble, count, extrema, SD, MAD and
method/support manifests.

## Examples

``` r
r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2,
                 crs = "EPSG:26920", vals = 1:4)
e <- ps_surface_ensemble(list(a = r, b = r + 2))
e$ensemble
#> class       : SpatRaster
#> size        : 2, 2, 1  (nrow, ncol, nlyr)
#> resolution  : 1, 1  (x, y)
#> extent      : 0, 2, 0, 2  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 20N (EPSG:26920)
#> source(s)   : memory
#> name        : mean
#> min value   :    2
#> max value   :    5
# The spread records method disagreement, not a confidence interval.
```
