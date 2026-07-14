# Generate hydraulic-gradient flow arrows

Derives slope, aspect, hydraulic gradient, and downgradient arrows from
a potentiometric surface raster.

## Usage

``` r
ps_flow_arrows(
  surface,
  res_factor = 7,
  scale = 50,
  min_gradient = 1e-05,
  log_gradient = FALSE,
  log_arrow = FALSE,
  out_dir = NULL,
  out_stub = "gw"
)
```

## Arguments

- surface:

  A groundwater elevation `SpatRaster`.

- res_factor:

  Factor used to thin arrows by resampling to a coarser grid.

- scale:

  Arrow length multiplier.

- min_gradient:

  Gradients below this value are dropped.

- log_gradient:

  Store [`log1p()`](https://rdrr.io/r/base/Log.html) transformed
  gradient in the output raster.

- log_arrow:

  Use [`log1p()`](https://rdrr.io/r/base/Log.html) transformed gradient
  for arrow lengths.

- out_dir:

  Optional output directory. When supplied, files are written.

- out_stub:

  File prefix used when writing outputs.

## Value

A list with `raster`, `points`, and `arrows`.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
s <- ps_interpolate(pts, methods = "IDW", grid_res = 100)
#> [inverse distance weighted interpolation]
arrows <- ps_flow_arrows(s$IDW, res_factor = 4, scale = 60)
arrows$arrows
#> class       : SpatVector
#> geometry    : lines
#> dimensions  : 49, 3  (geometries, attributes)
#> extent      : 500355.7, 502850.4, 4640185, 4642660  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 16N (EPSG:26916)
#> names       :     gwe      igrad  aspect
#> type        :   <num>      <num>   <num>
#> values      : 169.599 0.00199533 6.89488
#>                169.23 0.00196999 40.4709
#>               168.636 0.00183209 77.1184
#>               ...
```
