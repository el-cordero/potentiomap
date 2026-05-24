---
title: "potentiomap: An R package for reproducible potentiometric surface mapping"
tags:
  - R
  - groundwater
  - hydrogeology
  - geospatial
  - interpolation
  - potentiometric surface
authors:
  - name: Elvin Cordero
    affiliation: 1
affiliations:
  - name: Seamount Geo
    index: 1
date: 24 May 2026
bibliography: paper.bib
---

# Summary

`potentiomap` is an R package for preparing groundwater observations,
interpolating potentiometric surfaces, exporting map products, and deriving
hydraulic-gradient flow arrows. The package supports common hydrogeologic input
forms: direct groundwater elevation measurements, depth-to-water measurements
paired with a DEM, depth-to-water measurements paired with land-surface
elevation columns, and depth-to-water measurements paired with separate
surface-elevation points. Outputs include `terra` rasters, contour vector
layers, quicklook graphics, hydraulic-gradient rasters, sampled gradient points,
flow-arrow line layers, and arrow-tip or arrow-base point layers.

The package is intended for applied hydrogeologists, environmental scientists,
and geospatial analysts who need reproducible potentiometric mapping workflows
without repeatedly rebuilding project-specific scripts. It provides a smooth
thin-plate spline surface as the default interpolation product while retaining
support for inverse distance weighting, ordinary kriging, universal kriging, and
user-supplied interpolation functions.

# Statement of Need

Potentiometric surface maps are a standard product in groundwater monitoring,
remediation, water-resource assessment, and compliance reporting. In practice,
these products are often produced through a mixture of spreadsheet handling,
desktop GIS operations, and project-specific scripts. That workflow can make it
difficult to document assumptions, compare interpolation methods, rerun maps as
new measurements arrive, or reproduce hydraulic-gradient arrows consistently.

`potentiomap` addresses this need by putting the complete workflow in a small R
package built on established spatial tools. Raster operations and vector
exports use `terra` [@hijmans_terra_2025], thin-plate splines use `fields`
[@nychka_fields_2021], and geostatistical interpolation uses `gstat`
[@pebesma_gstat_2004]. The package standardizes groundwater elevation
observations into a simple point layer with `Z` and `Name` fields, then carries
that structure through interpolation, contour development, visual review, and
hydraulic-gradient products.

# Functionality

The main functions are organized around the mapping workflow:

- `ps_make_points()` standardizes direct groundwater elevation measurements.
- `ps_potentiometric_points()` calculates groundwater elevation from
  depth-to-water measurements and land-surface elevation information.
- `ps_interpolate()` creates one or more surface rasters. The default method is
  thin-plate spline interpolation (`TPS`); `IDW`, `OK`, `UK`, and custom
  interpolation functions are also supported.
- `ps_smooth_surface()` applies optional focal smoothing to an interpolated
  raster before contour or arrow development.
- `ps_contours()` and `ps_export_surfaces()` create contour and GIS deliverables.
- `ps_flow_arrows()` derives hydraulic gradients and downgradient arrow lines.
- `ps_arrow_vertices()` extracts arrow-tip or arrow-base point layers.

The following example uses the bundled synthetic monitoring data:

```r
library(potentiomap)
library(terra)

data("synthetic_wells")
data("synthetic_dem")
synthetic_dem <- terra::rast(synthetic_dem)

gw_points <- ps_potentiometric_points(
  synthetic_wells,
  x = "x",
  y = "y",
  depth_col = "depth_to_water",
  surface = synthetic_dem,
  name_col = "well_id",
  crs = "EPSG:26916"
)

surfaces <- ps_interpolate(
  gw_points,
  methods = c("TPS", "IDW", "OK", "UK"),
  grid_res = 50,
  mask = ps_sample_aoi()
)

smoothed_tps <- ps_smooth_surface(surfaces$TPS, window_size = 5)
flow <- ps_flow_arrows(smoothed_tps, res_factor = 8, scale = 80)
tips <- ps_arrow_vertices(flow$arrows, which = "last")
```

![Examples of interpolation methods available in `potentiomap`.](../man/figures/interpolation_methods.png)

![Examples of arrow-density controls available in `potentiomap`.](../man/figures/arrow_density.png)

# Availability and Quality Control

`potentiomap` includes synthetic example data so documentation, tests, and
examples can be run without project-specific datasets. The test suite exercises
direct water-level input, depth-to-water conversion, all built-in interpolation
methods, custom interpolation functions, raster smoothing, contour generation,
surface export, quicklook PNG creation, hydraulic-gradient raster export, arrow
line export, and arrow-tip/base extraction. The repository also includes
developer scripts outside the R package source tree for local example generation
and CRAN-style checking.

# Acknowledgements

This package builds on the R geospatial ecosystem, especially `terra`, `fields`,
and `gstat`.

# References
