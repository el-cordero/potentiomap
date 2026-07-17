# Exporting GIS products and technical reports

``` r

library(potentiomap)
r <- terra::rast(nrows = 3, ncols = 3, xmin = 0, xmax = 300,
                 ymin = 0, ymax = 300, crs = "EPSG:26920", vals = 1:9)
```

``` r

style_file <- tempfile(fileext = ".sld")
style <- ps_export_style(r, style_file, "sld", "head_raster", units = "m")
style$manifest
```

    ##                                   file format  layer_type field units
    ## 1 /tmp/RtmpMadTB9/file8dd613a56b8e.sld    sld head_raster  <NA>     m
    ##   break_count              xml_root validated
    ## 1           7 StyledLayerDescriptor      TRUE

[`ps_report()`](https://el-cordero.github.io/potentiomap/reference/ps_report.md)
renders an offline HTML or DOCX file from a package-owned template.
Reports include direct limitations and never claim professional
certification or regulatory approval. Open style properties can render
differently across GIS versions, so inspect the result in the target
GIS.
