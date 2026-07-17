# Build potentiometric surfaces and hydraulic-gradient arrows

potentiomap prepares groundwater-head observations, interpolates mapped
potentiometric surfaces, reports model diagnostics and prediction
support, creates contour inventories, and derives local
hydraulic-gradient arrow symbols. It is intended for hydrogeologists,
environmental scientists, and GIS users reviewing groundwater-level
data.

## Details

Main functions:

- [`ps_make_points()`](https://el-cordero.github.io/potentiomap/reference/ps_make_points.md)
  and
  [`ps_potentiometric_points()`](https://el-cordero.github.io/potentiomap/reference/ps_potentiometric_points.md)
  prepare observations.

- [`ps_interpolate()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate.md)
  and
  [`ps_interpolate_grouped()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate_grouped.md)
  create surfaces.

- [`ps_diagnostics()`](https://el-cordero.github.io/potentiomap/reference/ps_diagnostics.md)
  and
  [`ps_prediction_support()`](https://el-cordero.github.io/potentiomap/reference/ps_prediction_support.md)
  describe model behavior and where predictions have limited
  observational support.

- [`ps_contours()`](https://el-cordero.github.io/potentiomap/reference/ps_contours.md)
  inventories requested contour levels, and
  [`ps_contour_support()`](https://el-cordero.github.io/potentiomap/reference/ps_contour_support.md)
  divides those lines by user-defined local support.

- [`ps_flow_arrows()`](https://el-cordero.github.io/potentiomap/reference/ps_flow_arrows.md)
  and
  [`ps_validate_arrows()`](https://el-cordero.github.io/potentiomap/reference/ps_validate_arrows.md)
  create and check local negative-gradient symbols.

- [`ps_quicklook()`](https://el-cordero.github.io/potentiomap/reference/ps_quicklook.md),
  [`ps_export_surfaces()`](https://el-cordero.github.io/potentiomap/reference/ps_export_surfaces.md),
  and
  [`ps_export_contour_support()`](https://el-cordero.github.io/potentiomap/reference/ps_export_contour_support.md)
  review and save products.

- [`ps_check_observations()`](https://el-cordero.github.io/potentiomap/reference/ps_check_observations.md),
  [`ps_select_event()`](https://el-cordero.github.io/potentiomap/reference/ps_select_event.md),
  and
  [`ps_screen_groups()`](https://el-cordero.github.io/potentiomap/reference/ps_screen_groups.md)
  document observation, timing, and screen-selection decisions.

- [`ps_validate()`](https://el-cordero.github.io/potentiomap/reference/ps_validate.md),
  [`ps_compare_methods()`](https://el-cordero.github.io/potentiomap/reference/ps_compare_methods.md),
  and
  [`ps_tune_interpolation()`](https://el-cordero.github.io/potentiomap/reference/ps_tune_interpolation.md)
  evaluate explicit prediction tasks without calling them map truth.

- [`ps_surface_uncertainty()`](https://el-cordero.github.io/potentiomap/reference/ps_surface_uncertainty.md)
  and
  [`ps_contour_uncertainty()`](https://el-cordero.github.io/potentiomap/reference/ps_contour_uncertainty.md)
  retain model-conditional or resampling assumptions.

- [`ps_head_change()`](https://el-cordero.github.io/potentiomap/reference/ps_head_change.md),
  [`ps_vertical_gradient()`](https://el-cordero.github.io/potentiomap/reference/ps_vertical_gradient.md),
  [`ps_well_influence()`](https://el-cordero.github.io/potentiomap/reference/ps_well_influence.md),
  and
  [`ps_network_thinning()`](https://el-cordero.github.io/potentiomap/reference/ps_network_thinning.md)
  support event and monitoring-network review.

- [`ps_surface_profile()`](https://el-cordero.github.io/potentiomap/reference/ps_surface_profile.md),
  [`ps_cross_section()`](https://el-cordero.github.io/potentiomap/reference/ps_cross_section.md),
  [`ps_export_style()`](https://el-cordero.github.io/potentiomap/reference/ps_export_style.md),
  and
  [`ps_report()`](https://el-cordero.github.io/potentiomap/reference/ps_report.md)
  create review and exchange products.

Hydraulic-gradient arrows are map symbols derived from the local
gradient of a modeled surface. Their lengths are display conventions.
They are not traced groundwater paths, groundwater velocities, or travel
times. A finite surface or a passing arrow-tip check does not establish
hydrogeologic validity; users should evaluate measurements, method
assumptions, spatial trend, prediction support, and intended map use.

Project links:

- Documentation: <https://el-cordero.github.io/potentiomap/>

- Source: <https://github.com/el-cordero/potentiomap>

- Issues: <https://github.com/el-cordero/potentiomap/issues>

- CRAN: <https://CRAN.R-project.org/package=potentiomap>

Use `citation("potentiomap")` for citation guidance.

## See also

Useful links:

- <https://el-cordero.github.io/potentiomap/>

- <https://github.com/el-cordero/potentiomap>

- Report bugs at <https://github.com/el-cordero/potentiomap/issues>

## Author

**Maintainer**: Elvin Cordero <elvin.cordero@seamountgeo.com>
([ORCID](https://orcid.org/0009-0003-8025-283X))
