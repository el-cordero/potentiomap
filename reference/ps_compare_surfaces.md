# Compare two potentiometric surfaces

Compares compatible surfaces on their common finite support. Alignment
is an explicit operation and defaults to an error. The signed default is
surface B minus surface A; percentage head change is not calculated.

## Usage

``` r
ps_compare_surfaces(
  surface_a,
  surface_b,
  direction = c("b_minus_a", "a_minus_b"),
  align = c("error", "to_a", "to_b", "template"),
  template = NULL,
  resampling = c("bilinear", "near"),
  contour_levels = NULL,
  compare_gradient = TRUE,
  min_gradient = 1e-05
)
```

## Arguments

- surface_a, surface_b:

  One-layer continuous head rasters.

- direction:

  Signed-difference order.

- align:

  Alignment action; mismatch errors by default.

- template:

  Explicit target for `align = "template"`.

- resampling:

  Continuous bilinear or explicit nearest-neighbor alignment.

- contour_levels:

  Optional head contour levels.

- compare_gradient:

  Compare modeled gradient magnitude and direction.

- min_gradient:

  Threshold below which direction is undefined.

## Value

A `potentiomap_surface_comparison` with difference/support/gradient
rasters, contour displacement, summaries, and an alignment manifest.

## Examples

``` r
a <- terra::rast(nrows = 3, ncols = 3, xmin = 0, xmax = 3, ymin = 0, ymax = 3,
                 crs = "EPSG:26920", vals = 1:9)
cmp <- ps_compare_surfaces(a, a + 1)
cmp$summary
#>   direction common_cells only_a_cells only_b_cells common_area only_a_area
#> 1 b_minus_a            9            0            0           9           0
#>   only_b_area mean_difference mean_absolute_difference rmse minimum_difference
#> 1           0               1                        1    1                  1
#>   maximum_difference
#> 1                  1
# A modeled difference is not a storage or water-budget estimate.
```
