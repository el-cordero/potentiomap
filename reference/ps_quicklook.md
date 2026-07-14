# Draw a quicklook surface plot

Draw a quicklook surface plot

## Usage

``` r
ps_quicklook(
  surface,
  contours = NULL,
  points = NULL,
  file = NULL,
  title = "Potentiometric surface",
  label_points = TRUE,
  width = 1600,
  height = 1200,
  res = 180
)
```

## Arguments

- surface:

  A `SpatRaster`.

- contours:

  Optional contour `SpatVector`.

- points:

  Optional observation point `SpatVector`.

- file:

  Optional PNG output path. When `NULL`, plots to the active device.

- title:

  Plot title.

- label_points:

  Label points with `Name` and `Z`.

- width, height, res:

  PNG dimensions and resolution.

## Value

Invisibly returns `file`.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
s <- ps_interpolate(pts, methods = "IDW", grid_res = 100)
#> [inverse distance weighted interpolation]
ps_quicklook(s$IDW, points = pts, title = "Synthetic IDW")
```
