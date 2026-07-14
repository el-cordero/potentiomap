# Package index

## Prepare monitoring observations

Standardize measured heads or calculate groundwater elevation from depth
to water.

- [`ps_make_points()`](https://el-cordero.github.io/potentiomap/reference/ps_make_points.md)
  : Make groundwater observation points
- [`ps_potentiometric_points()`](https://el-cordero.github.io/potentiomap/reference/ps_potentiometric_points.md)
  : Build potentiometric points from depth-to-water measurements

## Build and refine surfaces

Interpolate and optionally smooth gridded potentiometric surfaces.

- [`ps_interpolate()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate.md)
  : Interpolate potentiometric surfaces
- [`ps_smooth_surface()`](https://el-cordero.github.io/potentiomap/reference/ps_smooth_surface.md)
  : Smooth a potentiometric surface raster

## Create contours and outputs

Create contour vectors, native quicklooks, and GIS-ready files.

- [`ps_contours()`](https://el-cordero.github.io/potentiomap/reference/ps_contours.md)
  : Create contours from a surface raster
- [`ps_quicklook()`](https://el-cordero.github.io/potentiomap/reference/ps_quicklook.md)
  : Draw a quicklook surface plot
- [`ps_export_surfaces()`](https://el-cordero.github.io/potentiomap/reference/ps_export_surfaces.md)
  : Export surfaces, contours, and quicklook PNGs

## Create and inspect hydraulic-gradient products

Derive gradient rasters and downgradient line and point products.

- [`ps_flow_arrows()`](https://el-cordero.github.io/potentiomap/reference/ps_flow_arrows.md)
  : Generate hydraulic-gradient flow arrows
- [`ps_arrow_vertices()`](https://el-cordero.github.io/potentiomap/reference/ps_arrow_vertices.md)
  : Extract arrow base or tip points

## Example data and geometry

Released synthetic observations, elevation data, and an example area of
interest.

- [`synthetic_wells`](https://el-cordero.github.io/potentiomap/reference/synthetic_wells.md)
  : Synthetic groundwater monitoring wells
- [`synthetic_dem`](https://el-cordero.github.io/potentiomap/reference/synthetic_dem.md)
  : Synthetic DEM raster
- [`synthetic_surface_points`](https://el-cordero.github.io/potentiomap/reference/synthetic_surface_points.md)
  : Synthetic surface elevation measurement points
- [`ps_sample_aoi()`](https://el-cordero.github.io/potentiomap/reference/ps_sample_aoi.md)
  : Make the sample area-of-interest polygon
