# Export potentiometric-surface products

Writes deterministic GeoTIFF, vector, contour-manifest, quicklook,
support, and diagnostic products only when an output directory is
supplied. GeoPackage is recommended because it preserves field names and
supports multiple layers better than shapefiles; the shapefile default
is retained for compatibility.

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
  write_png = TRUE,
  contour_levels = NULL,
  vector_format = c("shapefile", "gpkg"),
  support = NULL,
  diagnostics = NULL,
  write_contour_manifest = TRUE,
  write_support = FALSE,
  write_diagnostics = FALSE,
  write_manifest = TRUE,
  overwrite = TRUE
)
```

## Arguments

- surfaces:

  Named raster list or `potentiomap_result`.

- out_dir:

  Output directory.

- out_stub:

  Safe file prefix.

- contour_interval:

  Positive contour interval.

- points:

  Optional observation points for quicklooks.

- write_raster, write_contours, write_png:

  Choose outputs.

- contour_levels:

  Optional explicit levels.

- vector_format:

  Either `"shapefile"` or `"gpkg"`.

- support:

  Optional `potentiomap_support`; defaults to support stored in a
  structured interpolation result.

- diagnostics:

  Optional diagnostic list; defaults to structured-result diagnostics.

- write_contour_manifest, write_support, write_diagnostics,
  write_manifest:

  Choose sidecar products.

- overwrite:

  Overwrite existing outputs.

## Value

A data frame describing written files.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
surfaces <- ps_interpolate(pts, methods = "IDW", grid_res = 200)
ps_export_surfaces(surfaces, tempdir(), points = pts)
#>   method                             raster                            contours
#> 1    IDW /tmp/RtmpgjRmr9/gw_IDW_surface.tif /tmp/RtmpgjRmr9/gw_IDW_contours.shp
#>                              quicklook
#> 1 /tmp/RtmpgjRmr9/gw_IDW_quicklook.png
#>                              contour_manifest
#> 1 /tmp/RtmpgjRmr9/gw_IDW_contour_manifest.csv
```
