# Make the sample area-of-interest polygon

Make the sample area-of-interest polygon

## Usage

``` r
ps_sample_aoi()
```

## Value

A
[`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html)
polygon in EPSG:26916.

## Examples

``` r
aoi <- ps_sample_aoi()
aoi
#> class       : SpatVector
#> geometry    : polygons
#> dimensions  : 1, 0  (geometries, attributes)
#> extent      : 499850, 503400, 4640100, 4643000  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 16N (EPSG:26916)
```
