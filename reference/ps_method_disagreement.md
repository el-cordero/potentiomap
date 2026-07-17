# Map disagreement among interpolation methods

Computes head and down-gradient-direction differences among compatible
surfaces. Directed bearings use circular differences from 0 to 180
degrees; they are not treated as axial orientations.

## Usage

``` r
ps_method_disagreement(
  surfaces,
  head_measures = c("range", "sd", "mad", "mean_pairwise_absolute"),
  gradient = TRUE,
  min_gradient = 1e-05,
  support = c("intersection", "union"),
  minimum_methods = 2
)
```

## Arguments

- surfaces:

  Named compatible one-layer head rasters or a `potentiomap_result`.

- head_measures:

  Requested head-disagreement measures.

- gradient:

  Include gradient-direction disagreement.

- min_gradient:

  Gradients below this magnitude are undefined.

- support:

  Use only the intersection or allow the union of finite cells.

- minimum_methods:

  Minimum finite component count. The default is all methods for
  intersection and one for union.

## Value

A `potentiomap_disagreement` with disagreement rasters, pairwise and
direction summaries, a flat mask, and method-pair manifest.

## Examples

``` r
r <- terra::rast(nrows = 3, ncols = 3, xmin = 0, xmax = 3, ymin = 0, ymax = 3,
                 crs = "EPSG:26920", vals = 1:9)
d <- ps_method_disagreement(list(a = r, b = r + 1))
d$pairwise_summary
#>     pair_id method_a method_b finite_cells mean_absolute_head_difference
#> 1 pair_0001        a        b            9                             1
#>   maximum_absolute_head_difference
#> 1                                1
# Head offsets are method differences, not statistical uncertainty.
```
