# Export surfaces, contours, and quicklook PNGs

Export surfaces, contours, and quicklook PNGs

## Usage

``` r
ps_export_surfaces(
  surfaces,
  out_dir,
  out_stub = "gw",
  contour_interval = 1,
  points = NULL,
  write_raster = TRUE,
  write_contours = TRUE,
  write_png = TRUE
)
```

## Arguments

- surfaces:

  A named list of `SpatRaster` objects, such as the result of
  [`ps_interpolate()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate.md).

- out_dir:

  Output directory.

- out_stub:

  File prefix.

- contour_interval:

  Contour interval.

- points:

  Optional observation points to draw on quicklook figures.

- write_raster, write_contours, write_png:

  Choose which outputs to write.

## Value

A data frame listing written files.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
s <- ps_interpolate(pts, methods = "IDW", grid_res = 100)
#> [inverse distance weighted interpolation]
out <- ps_export_surfaces(s, points = pts, out_dir = tempdir())
out[] <- lapply(out, basename)
out
#>     method             raster            contours            quicklook
#> IDW    IDW gw_IDW_surface.tif gw_IDW_contours.shp gw_IDW_quicklook.png
```
