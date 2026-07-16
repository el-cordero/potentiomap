# Package index

## Prepare groundwater observations

Standardize measured heads or calculate head from depth to water.

- [`ps_make_points()`](https://el-cordero.github.io/potentiomap/reference/ps_make_points.md)
  : Make groundwater observation points
- [`ps_potentiometric_points()`](https://el-cordero.github.io/potentiomap/reference/ps_potentiometric_points.md)
  : Build potentiometric points from depth-to-water measurements
- [`ps_metadata()`](https://el-cordero.github.io/potentiomap/reference/ps_metadata.md)
  : Inspect scientific metadata
- [`ps_sample_aoi()`](https://el-cordero.github.io/potentiomap/reference/ps_sample_aoi.md)
  : Make the sample area-of-interest polygon
- [`synthetic_wells`](https://el-cordero.github.io/potentiomap/reference/synthetic_wells.md)
  : Synthetic groundwater monitoring wells
- [`synthetic_dem`](https://el-cordero.github.io/potentiomap/reference/synthetic_dem.md)
  : Synthetic DEM raster
- [`synthetic_surface_points`](https://el-cordero.github.io/potentiomap/reference/synthetic_surface_points.md)
  : Synthetic surface elevation measurement points

## Interpolate potentiometric surfaces

Fit single or explicitly grouped mapped surfaces.

- [`ps_interpolate()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate.md)
  : Interpolate potentiometric surfaces
- [`ps_interpolate_grouped()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate_grouped.md)
  : Interpolate grouped groundwater observations

## Inspect diagnostics and prediction support

Review retained fit information, conditions, and training support.

- [`ps_diagnostics()`](https://el-cordero.github.io/potentiomap/reference/ps_diagnostics.md)
  : Extract interpolation diagnostics
- [`ps_prediction_support()`](https://el-cordero.github.io/potentiomap/reference/ps_prediction_support.md)
  : Describe prediction support and extrapolation
- [`ps_surfaces()`](https://el-cordero.github.io/potentiomap/reference/ps_surfaces.md)
  : Extract interpolated surfaces
- [`potentiomap_result`](https://el-cordero.github.io/potentiomap/reference/potentiomap_result.md)
  : Structured potentiometric-surface result
- [`potentiomap_conditions`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_warning`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_error`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_input_error`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_metadata_error`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_crs_error`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_arrow_endpoint_warning`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_uk_instability_warning`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_kriging_convergence_warning`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_tps_gcv_boundary_warning`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_contour_level_warning`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_contour_support_warning`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_contour_support_error`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_contour_threshold_error`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_contour_uncertainty_error`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_support_warning`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  [`potentiomap_export_error`](https://el-cordero.github.io/potentiomap/reference/potentiomap_conditions.md)
  : potentiomap condition classes

## Create contours and hydraulic-gradient arrows

Inventory contour levels and create checked negative-gradient symbols.

- [`ps_contours()`](https://el-cordero.github.io/potentiomap/reference/ps_contours.md)
  : Create contours and a contour-level inventory
- [`ps_contour_support()`](https://el-cordero.github.io/potentiomap/reference/ps_contour_support.md)
  : Classify modeled contour sections by local prediction support
- [`plot(`*`<potentiomap_contour_support>`*`)`](https://el-cordero.github.io/potentiomap/reference/plot.potentiomap_contour_support.md)
  : Plot classified contour support
- [`ps_flow_arrows()`](https://el-cordero.github.io/potentiomap/reference/ps_flow_arrows.md)
  : Generate hydraulic-gradient arrows
- [`ps_validate_arrows()`](https://el-cordero.github.io/potentiomap/reference/ps_validate_arrows.md)
  : Validate hydraulic-gradient arrow endpoints
- [`ps_arrow_vertices()`](https://el-cordero.github.io/potentiomap/reference/ps_arrow_vertices.md)
  : Extract arrow base or tip points

## Visualize and export

Create quicklooks, smooth rasters, and save GIS products.

- [`ps_quicklook()`](https://el-cordero.github.io/potentiomap/reference/ps_quicklook.md)
  : Draw a quicklook surface plot
- [`ps_export_surfaces()`](https://el-cordero.github.io/potentiomap/reference/ps_export_surfaces.md)
  : Export potentiometric-surface products
- [`ps_export_contour_support()`](https://el-cordero.github.io/potentiomap/reference/ps_export_contour_support.md)
  : Export classified contour-support products
- [`ps_smooth_surface()`](https://el-cordero.github.io/potentiomap/reference/ps_smooth_surface.md)
  : Smooth a potentiometric surface raster

## Package overview

- [`potentiomap-package`](https://el-cordero.github.io/potentiomap/reference/potentiomap-package.md)
  [`potentiomap`](https://el-cordero.github.io/potentiomap/reference/potentiomap-package.md)
  : Build potentiometric surfaces and hydraulic-gradient arrows
