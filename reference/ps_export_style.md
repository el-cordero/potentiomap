# Export open GIS style XML

Export open GIS style XML

## Usage

``` r
ps_export_style(
  x,
  file,
  format = c("qml", "sld"),
  layer_type = c("head_raster", "depth_raster", "contours", "contour_support", "arrows",
    "wells", "support"),
  field = NULL,
  units = NULL,
  palette = NULL,
  breaks = NULL,
  overwrite = FALSE
)
```

## Arguments

- x:

  Object whose values inform default raster breaks.

- file:

  Output QML or SLD file.

- format:

  QGIS QML or standards-based SLD.

- layer_type:

  Styled layer type.

- field:

  Attribute used for labels or support categories.

- units:

  Optional label units.

- palette:

  Colors or color function.

- breaks:

  Optional explicit continuous breaks.

- overwrite:

  Permit replacement of an existing file.

## Value

A `potentiomap_style_export` manifest. Optional properties can render
differently among GIS versions.

## Examples

``` r
r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2,
                 ymin = 0, ymax = 2, crs = "EPSG:26920", vals = 1:4)
file <- tempfile(fileext = ".qml")
style <- ps_export_style(r, file, "qml", "head_raster", units = "m")
style$manifest
#>                                   file format  layer_type field units
#> 1 /tmp/Rtmpad3ChN/file1dce37372491.qml    qml head_raster  <NA>     m
#>   break_count xml_root validated
#> 1           7     qgis      TRUE
# GIS versions can render optional style properties differently.
```
