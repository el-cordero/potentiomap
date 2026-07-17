# QGIS and SLD style exports

[`ps_export_style()`](https://el-cordero.github.io/potentiomap/reference/ps_export_style.md)
writes text-based QGIS QML or OGC SLD and parses the XML before
returning. Continuous rasters, points, arrows, contour labels, and
solid, dashed, or dotted support classes are represented without relying
only on color. Existing files are protected by default. Optional
properties can render differently among GIS versions, so inspect the
style in the target software.

``` r

ps_export_style(surface, "head.qml", "qml", "head_raster", units="m")
ps_export_style(contours, "support.sld", "sld", "contour_support",
                field="support_class")
```
