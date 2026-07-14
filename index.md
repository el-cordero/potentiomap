# Reproducible potentiometric surfaces and hydraulic-gradient products in R

Turn groundwater-monitoring points into interpolated surfaces, contours,
quicklook maps, and GIS-ready hydraulic-gradient products using a
transparent, scriptable workflow.

[Install from CRAN](https://CRAN.R-project.org/package=potentiomap) [Get
Started](https://el-cordero.github.io/potentiomap/articles/quick-start.md)
[Function
Reference](https://el-cordero.github.io/potentiomap/reference/index.md)
[View on GitHub](https://github.com/el-cordero/potentiomap)

## Install the released package

``` r

install.packages("potentiomap")
library(potentiomap)
```

The website documents **potentiomap 0.1.0**, the CRAN release published
on 2026-05-29. The [GitHub
repository](https://github.com/el-cordero/potentiomap) may contain
development work; use CRAN for the documented release.

## Five-minute workflow

This complete example uses the released synthetic monitoring network.
Its coordinates use NAD83 / UTM zone 16N (EPSG:26916). Head values are
synthetic elevation units and do not imply a field vertical datum.

``` r

library(potentiomap)

data("synthetic_wells", package = "potentiomap")

points <- ps_make_points(
  synthetic_wells,
  x = "x", y = "y",
  value = "gw_elevation",
  name_col = "well_id",
  crs = "EPSG:26916"
)

aoi <- ps_sample_aoi()
surfaces <- ps_interpolate(
  points,
  methods = "TPS",
  grid_res = 100,
  mask = aoi,
  padding = 0
)

contours <- ps_contours(surfaces$TPS, interval = 1)
ps_quicklook(
  surfaces$TPS,
  contours = contours,
  points = points,
  title = "Synthetic TPS potentiometric surface"
)

flow <- ps_flow_arrows(
  surfaces$TPS,
  res_factor = 4,
  scale = 150,
  min_gradient = 1e-5
)
tips <- ps_arrow_vertices(flow$arrows, which = "last")
bases <- ps_arrow_vertices(flow$arrows, which = "first")
```

![A synthetic TPS potentiometric surface shaded from cool low modeled
heads to warm high modeled heads, with one-unit contours and monitoring
wells.](homepage-workflow.png)

A synthetic TPS potentiometric surface shaded from cool low modeled
heads to warm high modeled heads, with one-unit contours and monitoring
wells.

[Run the executable quick
start](https://el-cordero.github.io/potentiomap/articles/quick-start.md)
for printed object summaries, a native
[`ps_quicklook()`](https://el-cordero.github.io/potentiomap/reference/ps_quicklook.md)
figure, and a hydraulic-gradient arrow map.

## Core workflow

- ### 

  1.  Prepare observations

  Standardize direct head measurements or calculate groundwater
  elevations from positive depth-to-water values and documented
  land-surface elevations.

- ### 

  2.  Interpolate surfaces

  Use TPS, IDW, ordinary kriging, universal kriging, or a documented
  custom function on an explicit projected grid.

- ### 

  3.  Create products

  Derive contours and quicklooks, then export reproducible raster and
  vector products for GIS workflows.

- ### 

  4.  Inspect gradients

  Calculate gradient rasters, cartographically scaled downgradient
  lines, and their base or tip vertices.

## Actual package outputs

The [output
gallery](https://el-cordero.github.io/potentiomap/articles/output-gallery.md)
contains more than 15 generated examples: monitoring points, four
interpolation methods, contours, smoothing comparisons, gradient
rasters, arrow layouts, exported quicklooks, repeated events, and a
public USGS example.

- [Compare TPS, IDW, ordinary kriging, and universal
  kriging](https://el-cordero.github.io/potentiomap/articles/interpolation-methods.md)
- [Inspect hydraulic-gradient arrows and the direction
  check](https://el-cordero.github.io/potentiomap/articles/flow-arrows.md)
- [Export and read back GIS-ready
  products](https://el-cordero.github.io/potentiomap/articles/exporting-products.md)
- [Work through the USGS Hot Springs
  example](https://el-cordero.github.io/potentiomap/articles/real-world-usgs.md)

## Why a scripted workflow?

`potentiomap` provides a scriptable complement to desktop GIS and
contouring workflows by preserving data preparation, interpolation
choices, spatial parameters, contour settings, and output generation in
executable R code. Scripts make input fields, coordinate systems, grid
resolution, method parameters, masks, contour intervals, arrow settings,
and output paths easier to review and repeat across monitoring events
and projects.

Although designed for potentiometric-surface mapping, the interpolation
framework may also be useful for other continuous scalar variables
observed at discrete points, provided the user applies appropriate
domain-specific assumptions and interpretation.

**Interpret with hydrogeologic context.** Interpolated surfaces depend
on monitoring-network geometry, data quality, aquifer selection,
screened intervals, boundaries, and method assumptions.
Hydraulic-gradient arrows point toward decreasing modeled head. They do
not represent groundwater velocity, travel time, particle paths, or
contaminant transport. The package is not a process-based
groundwater-flow model.

## Downloads

- [Complete end-to-end R
  script](https://el-cordero.github.io/potentiomap/downloads/potentiomap_complete_example.R)
- [Released synthetic well
  table](https://el-cordero.github.io/potentiomap/downloads/synthetic_wells.csv)
- [Example GIS-output
  bundle](https://el-cordero.github.io/potentiomap/downloads/potentiomap_example_outputs.zip)
- [Site build session
  information](https://el-cordero.github.io/potentiomap/downloads/potentiomap_site_session_info.txt)

## Citation and availability

`potentiomap` 0.1.0 is available from
[CRAN](https://CRAN.R-project.org/package=potentiomap) under GPL-3. Its
canonical CRAN DOI is
[10.32614/CRAN.package.potentiomap](https://doi.org/10.32614/CRAN.package.potentiomap).
See the [citation
page](https://el-cordero.github.io/potentiomap/articles/citation.md) for
the complete citation and BibTeX entry. Package authorship shown on this
site follows the released package metadata.
