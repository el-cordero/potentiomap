# Exporting GIS-ready products

The package exports standard spatial files. The example writes to an R
session temporary directory, then prints only portable file names so
local paths never become part of a project record.

## Export surfaces, contours, and quicklooks

``` r

output_dir <- file.path(tempdir(), "potentiomap-gis-example")
inventory <- ps_export_surfaces(
  surfaces,
  out_dir = output_dir,
  out_stub = "synthetic",
  contour_interval = 1,
  points = points
)

portable_inventory <- transform(
  inventory,
  raster = basename(raster),
  contours = basename(contours),
  quicklook = basename(quicklook)
)
portable_inventory
#>     method                    raster                   contours
#> TPS    TPS synthetic_TPS_surface.tif synthetic_TPS_contours.shp
#> IDW    IDW synthetic_IDW_surface.tif synthetic_IDW_contours.shp
#>                       quicklook
#> TPS synthetic_TPS_quicklook.png
#> IDW synthetic_IDW_quicklook.png
```

The contour vector is an ESRI Shapefile in release 0.1.0, so preserve
its sidecar files when transferring it. The downloadable example bundle
includes all components.

## Read the products back

``` r

surface_back <- rast(inventory$raster[1])
contours_back <- vect(inventory$contours[1])

data.frame(
  check = c("raster CRS", "contour CRS", "raster dimensions", "contour attributes", "contour features"),
  result = c(
    crs(surface_back, proj = TRUE),
    crs(contours_back, proj = TRUE),
    paste(dim(surface_back), collapse = " × "),
    paste(names(contours_back), collapse = ", "),
    nrow(contours_back)
  )
)
#>                check                                            result
#> 1         raster CRS +proj=utm +zone=16 +datum=NAD83 +units=m +no_defs
#> 2        contour CRS +proj=utm +zone=16 +datum=NAD83 +units=m +no_defs
#> 3  raster dimensions                                       29 × 36 × 1
#> 4 contour attributes                                             level
#> 5   contour features                                                10
```

``` r

plot(surface_back, col = hcl.colors(64, "RdYlBu", rev = TRUE),
     main = "Read-back TPS GeoTIFF and contour vector")
plot(contours_back, add = TRUE, col = "#17252d", lwd = 1)
plot(points, add = TRUE, pch = 21, bg = "white", cex = .65)
```

![GeoTIFF TPS surface read back from disk, shaded blue at lower
synthetic heads and red at higher heads, with the exported contour
shapefile
overlaid.](exporting-products_files/figure-html/read-back-map-1.png)

## Export hydraulic-gradient products

``` r

flow <- ps_flow_arrows(
  surfaces$TPS,
  res_factor = 5,
  scale = 180,
  min_gradient = 1e-5,
  out_dir = output_dir,
  out_stub = "synthetic_TPS"
)
tips_file <- file.path(output_dir, "synthetic_TPS_arrow_tips.gpkg")
bases_file <- file.path(output_dir, "synthetic_TPS_arrow_bases.gpkg")
tips <- ps_arrow_vertices(flow$arrows, "last", tips_file)
bases <- ps_arrow_vertices(flow$arrows, "first", bases_file)

data.frame(
  product = c("gradient GeoTIFF", "sample points", "arrow lines", "arrow tips", "arrow bases"),
  file = c("synthetic_TPS_hgrad.tif", "synthetic_TPS_hgrad_points.shp",
           "synthetic_TPS_hgrad_arrows.shp", basename(tips_file), basename(bases_file)),
  features_or_layers = c(nlyr(flow$raster), nrow(flow$points), nrow(flow$arrows), nrow(tips), nrow(bases))
)
#>            product                           file features_or_layers
#> 1 gradient GeoTIFF        synthetic_TPS_hgrad.tif                  3
#> 2    sample points synthetic_TPS_hgrad_points.shp                 33
#> 3      arrow lines synthetic_TPS_hgrad_arrows.shp                 33
#> 4       arrow tips  synthetic_TPS_arrow_tips.gpkg                 33
#> 5      arrow bases synthetic_TPS_arrow_bases.gpkg                 33
```

## Validate geometry and attributes

``` r

gradient_back <- rast(file.path(output_dir, "synthetic_TPS_hgrad.tif"))
arrow_back <- vect(file.path(output_dir, "synthetic_TPS_hgrad_arrows.shp"))
data.frame(
  check = c("gradient layers", "gradient CRS matches surface", "arrow CRS matches surface",
            "arrow attributes", "tip count equals arrow count"),
  pass = c(
    identical(names(gradient_back), c("gwe", "igrad", "aspect")),
    same.crs(gradient_back, surfaces$TPS),
    same.crs(arrow_back, surfaces$TPS),
    all(c("gwe", "igrad", "aspect") %in% names(arrow_back)),
    nrow(tips) == nrow(arrow_back)
  )
)
#>                          check pass
#> 1              gradient layers TRUE
#> 2 gradient CRS matches surface TRUE
#> 3    arrow CRS matches surface TRUE
#> 4             arrow attributes TRUE
#> 5 tip count equals arrow count TRUE
```

Download the complete [example GIS-output
bundle](https://el-cordero.github.io/potentiomap/downloads/potentiomap_example_outputs.zip).
It includes GeoTIFF surfaces, complete contour shapefiles, native
quicklook PNGs, hydraulic-gradient files, arrow vectors, tip and base
GeoPackages, a README with units and CRS, and the exact [R
script](https://el-cordero.github.io/potentiomap/downloads/potentiomap_complete_example.R)
used to generate them.

Exported files preserve the modeled products, not their validity. Keep
the monitoring data, aquifer selection, vertical datum, interpolation
parameters, mask, software version, and review record with every
deliverable.
