# Generate hydraulic-gradient arrows

Derives the local negative modeled-head gradient from a potentiometric
surface. Arrow direction comes from raster aspect; arrow length is a
display convention based on gradient, raster resolution, and `scale`.
Arrows are map symbols, not groundwater velocities, travel times,
particle paths, or traced groundwater paths.

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
  out_stub = "gw",
  endpoint_action = c("flag", "shorten", "drop", "none"),
  endpoint_tolerance = 1e-06,
  endpoint_extraction = c("bilinear", "simple"),
  max_shortening = 12L,
  overwrite = TRUE
)
```

## Arguments

- surface:

  A one-layer groundwater-elevation `SpatRaster`.

- res_factor:

  Positive integer used to thin arrows on a coarser grid.

- scale:

  Positive cartographic length multiplier.

- min_gradient:

  Nonnegative gradient threshold.

- log_gradient:

  Store [`log1p()`](https://rdrr.io/r/base/Log.html) gradient in the
  returned raster.

- log_arrow:

  Use [`log1p()`](https://rdrr.io/r/base/Log.html) gradient for arrow
  display length.

- out_dir:

  Optional output directory. No files are written when `NULL`.

- out_stub:

  Safe file prefix.

- endpoint_action:

  One of `"flag"`, `"shorten"`, `"drop"`, or `"none"`. `"flag"`
  preserves geometry and warns; `"shorten"` retains direction while
  reducing failed lines; `"drop"` removes failures; `"none"` reproduces
  the version 0.1.0 unvalidated geometry.

- endpoint_tolerance:

  Nonnegative head tolerance.

- endpoint_extraction:

  Either `"bilinear"` or `"simple"` raster extraction.

- max_shortening:

  Positive maximum number of length halvings.

- overwrite:

  Overwrite gradient files when `out_dir` is supplied.

## Value

A list containing at least `raster`, `points`, and `arrows`, plus
`tips`, `bases`, `validation`, and `validation_summary`.

## Details

Endpoint checking compares each straight line with the supplied raster.
It can flag, shorten, or drop lines whose tip is nonfinite or higher
than the base. Shortening retains the original direction and repeatedly
halves length; arrows are never reversed or bent. A passing check does
not establish that the interpolated surface is physically correct.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
surface <- ps_interpolate(pts, methods = "IDW", grid_res = 150)$IDW
flow <- ps_flow_arrows(surface, res_factor = 6, scale = 30,
                       endpoint_action = "shorten")
#> Warning: 1 hydraulic-gradient arrow endpoint(s) failed validation under `endpoint_action = "shorten"`.
flow$validation_summary
#>   endpoint_action arrows_generated arrows_retained finite_support downhill_pass
#> 1         shorten                9               9              9             8
#>   failed shortened dropped
#> 1      1         1       0
```
