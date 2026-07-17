# Calculate depth to a water-table or potentiometric surface

Calculates land-surface elevation minus modeled head after explicit
geometry, unit, and vertical-datum checks. Negative values are
preserved. For a confined surface the product is depth to the
potentiometric surface, not necessarily depth to the water table.

## Usage

``` r
ps_depth_to_water_surface(
  head_surface,
  land_surface,
  surface_type = c("water_table", "potentiometric"),
  align = c("error", "to_head", "to_land", "template"),
  template = NULL,
  resampling = "bilinear",
  tolerance = 0
)
```

## Arguments

- head_surface, land_surface:

  One-layer continuous elevation rasters.

- surface_type:

  Water table or potentiometric surface terminology.

- align, template, resampling:

  Explicit alignment controls.

- tolerance:

  Nonnegative absolute depth classified as near zero.

## Value

A `potentiomap_depth_surface` with depth and review/support masks.

## Examples

``` r
h <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2,
                 crs = "EPSG:26920", vals = c(9, 11, 8, 10))
land <- h * 0 + 10
z <- ps_depth_to_water_surface(h, land, "potentiometric")
terra::values(z$depth)
#>      depth_to_potentiometric_surface
#> [1,]                               1
#> [2,]                              -1
#> [3,]                               2
#> [4,]                               0
# Negative values are retained for hydrogeologic and datum review.
```
