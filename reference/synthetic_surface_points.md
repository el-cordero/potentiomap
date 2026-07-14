# Synthetic surface elevation measurement points

Artificial land-surface elevation points for demonstrating workflows
that do not start with a DEM raster.

## Usage

``` r
synthetic_surface_points
```

## Format

A data frame with coordinate, surface-elevation, and name columns.

## Examples

``` r
data("synthetic_surface_points")
head(synthetic_surface_points)
#>   point_id        x       y surface_elevation
#> 1    SP-01 500667.3 4640828            188.57
#> 2    SP-02 502385.7 4642277            184.33
#> 3    SP-03 503012.7 4642292            183.96
#> 4    SP-04 501962.2 4642804            186.27
#> 5    SP-05 502060.3 4642430            185.15
#> 6    SP-06 503130.8 4640450            187.64
```
