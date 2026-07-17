# Package index

## Prepare and check groundwater observations

- [`ps_make_points()`](https://el-cordero.github.io/potentiomap/reference/ps_make_points.md)
  : Make groundwater observation points
- [`ps_potentiometric_points()`](https://el-cordero.github.io/potentiomap/reference/ps_potentiometric_points.md)
  : Build potentiometric points from depth-to-water measurements
- [`ps_check_observations()`](https://el-cordero.github.io/potentiomap/reference/ps_check_observations.md)
  : Check groundwater observation records
- [`ps_metadata()`](https://el-cordero.github.io/potentiomap/reference/ps_metadata.md)
  : Inspect scientific metadata
- [`ps_sample_aoi()`](https://el-cordero.github.io/potentiomap/reference/ps_sample_aoi.md)
  : Make the sample area-of-interest polygon

## Select monitoring events and water-bearing units

- [`ps_select_event()`](https://el-cordero.github.io/potentiomap/reference/ps_select_event.md)
  : Select a groundwater monitoring event
- [`ps_screen_groups()`](https://el-cordero.github.io/potentiomap/reference/ps_screen_groups.md)
  : Assign or validate monitoring-well screen groups
- [`ps_interpolate_grouped()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate_grouped.md)
  : Interpolate grouped groundwater observations

## Interpolate potentiometric surfaces

- [`ps_interpolate()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate.md)
  : Interpolate potentiometric surfaces
- [`ps_interpolate_regions()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate_regions.md)
  : Interpolate explicit regions independently
- [`ps_split_domain()`](https://el-cordero.github.io/potentiomap/reference/ps_split_domain.md)
  : Validate and split an explicit hydrogeologic domain

## Inspect variograms, trends, and anisotropy

- [`ps_variogram()`](https://el-cordero.github.io/potentiomap/reference/ps_variogram.md)
  : Calculate an empirical groundwater-head variogram
- [`ps_variogram_compare()`](https://el-cordero.github.io/potentiomap/reference/ps_variogram_compare.md)
  : Compare fitted variogram models
- [`ps_anisotropy()`](https://el-cordero.github.io/potentiomap/reference/ps_anisotropy.md)
  : Explore directional anisotropy in hydraulic head

## Validate and tune interpolation methods

- [`ps_validate()`](https://el-cordero.github.io/potentiomap/reference/ps_validate.md)
  : Validate potentiometric-surface interpolation
- [`ps_compare_methods()`](https://el-cordero.github.io/potentiomap/reference/ps_compare_methods.md)
  : Compare validated interpolation methods
- [`ps_validation_plot()`](https://el-cordero.github.io/potentiomap/reference/ps_validation_plot.md)
  : Plot validation diagnostics with base graphics
- [`ps_tune_interpolation()`](https://el-cordero.github.io/potentiomap/reference/ps_tune_interpolation.md)
  : Tune interpolation parameters under recorded validation partitions

## Inspect support and uncertainty

- [`ps_prediction_support()`](https://el-cordero.github.io/potentiomap/reference/ps_prediction_support.md)
  : Describe prediction support and extrapolation
- [`ps_surface_ensemble()`](https://el-cordero.github.io/potentiomap/reference/ps_surface_ensemble.md)
  : Combine compatible potentiometric surfaces
- [`ps_method_disagreement()`](https://el-cordero.github.io/potentiomap/reference/ps_method_disagreement.md)
  : Map disagreement among interpolation methods
- [`ps_surface_uncertainty()`](https://el-cordero.github.io/potentiomap/reference/ps_surface_uncertainty.md)
  : Quantify model-conditional or resampling surface variability
- [`ps_contour_uncertainty()`](https://el-cordero.github.io/potentiomap/reference/ps_contour_uncertainty.md)
  : Construct pointwise contour-uncertainty bands

## Compare surfaces and monitoring events

- [`ps_compare_surfaces()`](https://el-cordero.github.io/potentiomap/reference/ps_compare_surfaces.md)
  : Compare two potentiometric surfaces
- [`ps_head_change()`](https://el-cordero.github.io/potentiomap/reference/ps_head_change.md)
  : Compare paired measurements and modeled head change between events
- [`ps_surface_sensitivity()`](https://el-cordero.github.io/potentiomap/reference/ps_surface_sensitivity.md)
  : Evaluate explicit interpolation sensitivity scenarios

## Calculate vertical gradients and depth surfaces

- [`ps_vertical_gradient()`](https://el-cordero.github.io/potentiomap/reference/ps_vertical_gradient.md)
  : Calculate a vertical hydraulic gradient
- [`ps_depth_to_water_surface()`](https://el-cordero.github.io/potentiomap/reference/ps_depth_to_water_surface.md)
  : Calculate depth to a water-table or potentiometric surface

## Evaluate monitoring networks

- [`ps_well_influence()`](https://el-cordero.github.io/potentiomap/reference/ps_well_influence.md)
  : Calculate conditional leave-one-well influence
- [`ps_network_thinning()`](https://el-cordero.github.io/potentiomap/reference/ps_network_thinning.md)
  : Evaluate reproducible monitoring-network thinning scenarios
- [`ps_candidate_network()`](https://el-cordero.github.io/potentiomap/reference/ps_candidate_network.md)
  : Rank explicit candidate monitoring locations with recorded
  constraints

## Create contours and hydraulic-gradient arrows

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

## Extract profiles and cross-sections

- [`ps_surface_profile()`](https://el-cordero.github.io/potentiomap/reference/ps_surface_profile.md)
  : Extract one or more surface profiles along explicit lines
- [`ps_cross_section()`](https://el-cordero.github.io/potentiomap/reference/ps_cross_section.md)
  : Build a plot-ready potentiometric cross-section

## Visualize, style, report, and export

- [`ps_quicklook()`](https://el-cordero.github.io/potentiomap/reference/ps_quicklook.md)
  : Draw a quicklook surface plot
- [`ps_smooth_surface()`](https://el-cordero.github.io/potentiomap/reference/ps_smooth_surface.md)
  : Smooth a potentiometric surface raster
- [`ps_export_surfaces()`](https://el-cordero.github.io/potentiomap/reference/ps_export_surfaces.md)
  : Export potentiometric-surface products
- [`ps_export_contour_support()`](https://el-cordero.github.io/potentiomap/reference/ps_export_contour_support.md)
  : Export classified contour-support products
- [`ps_export_style()`](https://el-cordero.github.io/potentiomap/reference/ps_export_style.md)
  : Export open GIS style XML
- [`ps_report()`](https://el-cordero.github.io/potentiomap/reference/ps_report.md)
  : Render a package-owned technical report

## Example data

- [`synthetic_wells`](https://el-cordero.github.io/potentiomap/reference/synthetic_wells.md)
  : Synthetic groundwater monitoring wells
- [`synthetic_dem`](https://el-cordero.github.io/potentiomap/reference/synthetic_dem.md)
  : Synthetic DEM raster
- [`synthetic_surface_points`](https://el-cordero.github.io/potentiomap/reference/synthetic_surface_points.md)
  : Synthetic surface elevation measurement points
- [`synthetic_events`](https://el-cordero.github.io/potentiomap/reference/synthetic_events.md)
  : Synthetic repeated groundwater-monitoring events
- [`synthetic_nested_wells`](https://el-cordero.github.io/potentiomap/reference/synthetic_nested_wells.md)
  : Synthetic nested monitoring wells
- [`synthetic_regions`](https://el-cordero.github.io/potentiomap/reference/synthetic_regions.md)
  : Two synthetic interpolation compartments
- [`synthetic_covariates`](https://el-cordero.github.io/potentiomap/reference/synthetic_covariates.md)
  : Synthetic surface shapes and hydrogeologic covariates
- [`synthetic_candidate_sites`](https://el-cordero.github.io/potentiomap/reference/synthetic_candidate_sites.md)
  : Synthetic candidate monitoring sites
- [`synthetic_transect`](https://el-cordero.github.io/potentiomap/reference/synthetic_transect.md)
  : Synthetic cross-section transect
- [`synthetic_anisotropic_points`](https://el-cordero.github.io/potentiomap/reference/synthetic_anisotropic_points.md)
  : Synthetic anisotropic head points
- [`synthetic_validation_points`](https://el-cordero.github.io/potentiomap/reference/synthetic_validation_points.md)
  : Synthetic independent validation points

## Result classes and accessors

- [`ps_diagnostics()`](https://el-cordero.github.io/potentiomap/reference/ps_diagnostics.md)
  : Extract interpolation diagnostics
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
- [`potentiomap-package`](https://el-cordero.github.io/potentiomap/reference/potentiomap-package.md)
  [`potentiomap`](https://el-cordero.github.io/potentiomap/reference/potentiomap-package.md)
  : Build potentiometric surfaces and hydraulic-gradient arrows
