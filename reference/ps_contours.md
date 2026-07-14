# Create contours from a surface raster

Create contours from a surface raster

## Usage

``` r
ps_contours(surface, interval = 1, levels = NULL)
```

## Arguments

- surface:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  potentiometric surface.

- interval:

  Contour interval in map elevation units.

- levels:

  Optional explicit contour levels. When supplied, `interval` is
  ignored.

## Value

A line
[`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
of contours.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
s <- ps_interpolate(pts, methods = "IDW", grid_res = 100)
#> [inverse distance weighted interpolation]
ctr <- ps_contours(s$IDW, interval = 1)
ctr
#> class       : SpatVector
#> geometry    : lines
#> dimensions  : 7, 1  (geometries, attributes)
#> extent      : 500243.2, 503243.2, 4640060, 4642960  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 16N (EPSG:26916)
#> names       : level
#> type        : <num>
#> values      :   165
#>                 166
#>                 167
#>               ...
```
