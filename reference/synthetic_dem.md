# Synthetic DEM raster

A small artificial DEM matching `synthetic_wells`, stored as a packed
`terra` raster. Use `terra::rast(synthetic_dem)` to unpack it.

## Usage

``` r
synthetic_dem
```

## Format

A `terra::PackedSpatRaster` with one layer named `surface_elevation`.

## Examples

``` r
data("synthetic_dem")
dem <- terra::rast(synthetic_dem)
dem
#> class       : SpatRaster
#> size        : 66, 77, 1  (nrow, ncol, nlyr)
#> resolution  : 50, 50  (x, y)
#> extent      : 499700, 503550, 4639900, 4643200  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 16N (EPSG:26916)
#> source(s)   : memory
#> name        : surface_elevation
#> min value   :        182.786709
#> max value   :        190.770888
```
