# Smooth a potentiometric surface raster

Applies a focal moving-window smoother to a potentiometric surface
raster. This can be useful when an interpolated surface is technically
valid but too locally rough for contour development or
hydraulic-gradient visualization.

## Usage

``` r
ps_smooth_surface(
  surface,
  window_size = 3,
  method = c("mean", "median"),
  weights = NULL,
  iterations = 1,
  na.rm = TRUE,
  preserve_na = TRUE,
  filename = "",
  overwrite = FALSE
)
```

## Arguments

- surface:

  A
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  potentiometric surface.

- window_size:

  Odd integer window size used when `weights` is `NULL`.

- method:

  Smoothing statistic. Supported values are `"mean"` and `"median"`.

- weights:

  Optional odd-dimension numeric matrix of focal weights. `NA` values in
  the matrix are ignored by
  [`terra::focal()`](https://rspatial.github.io/terra/reference/focal.html).

- iterations:

  Number of smoothing passes.

- na.rm:

  Ignore missing values inside the focal window.

- preserve_na:

  Preserve the original `NA` footprint after smoothing.

- filename:

  Optional output raster filename.

- overwrite:

  Overwrite `filename` when it exists.

## Value

A smoothed
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html).

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
s <- ps_interpolate(pts, grid_res = 100)
#> Warning: 
#> Grid searches over lambda (nugget and sill variances) with  minima at the endpoints: 
#>   (GCV) Generalized Cross-Validation 
#>    minimum at  right endpoint  lambda  =  1.812476e-05 (eff. df= 30.40003 )
smoothed <- ps_smooth_surface(s$TPS, window_size = 5)
smoothed
#> class       : SpatRaster
#> size        : 30, 31, 1  (nrow, ncol, nlyr)
#> resolution  : 100, 100  (x, y)
#> extent      : 500193.2, 503293.2, 4640010, 4643010  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 16N (EPSG:26916)
#> source(s)   : memory
#> name        :        TPS
#> min value   : 163.675095
#> max value   : 172.806939
```
