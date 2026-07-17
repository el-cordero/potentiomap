# API compatibility report

Date: 2026-07-17

Baseline commit: `358185faa657b8c2ef4154c5314ecfede306fe9e`

Candidate: potentiomap 0.2.0 working tree on `release/0.2.0`

## Preserved API

All 18 baseline exports remain available: `ps_arrow_vertices()`,
`ps_contour_support()`, `ps_contours()`, `ps_diagnostics()`,
`ps_export_contour_support()`, `ps_export_surfaces()`, `ps_flow_arrows()`,
`ps_interpolate()`, `ps_interpolate_grouped()`, `ps_make_points()`,
`ps_metadata()`, `ps_potentiometric_points()`, `ps_prediction_support()`,
`ps_quicklook()`, `ps_sample_aoi()`, `ps_smooth_surface()`, `ps_surfaces()`, and
`ps_validate_arrows()`.

The candidate exports 46 functions. The 28 new exports are:

- `ps_anisotropy()`, `ps_variogram()`, and `ps_variogram_compare()`;
- `ps_validate()`, `ps_compare_methods()`, `ps_validation_plot()`, and
  `ps_tune_interpolation()`;
- `ps_surface_ensemble()`, `ps_method_disagreement()`,
  `ps_surface_uncertainty()`, and `ps_contour_uncertainty()`;
- `ps_compare_surfaces()`, `ps_head_change()`, `ps_vertical_gradient()`, and
  `ps_depth_to_water_surface()`;
- `ps_well_influence()`, `ps_network_thinning()`, `ps_candidate_network()`, and
  `ps_surface_sensitivity()`;
- `ps_split_domain()`, `ps_interpolate_regions()`, `ps_surface_profile()`, and
  `ps_cross_section()`;
- `ps_check_observations()`, `ps_select_event()`, `ps_screen_groups()`,
  `ps_export_style()`, and `ps_report()`.

## Return and signature compatibility

- `ps_interpolate()` still returns a named list of `SpatRaster` objects by
  default; `return = "result"` remains opt-in.
- `ps_contours()` still returns a `SpatVector` by default.
- `ps_flow_arrows()` retains its documented components, and
  `endpoint_action = "none"` retains legacy unvalidated geometry.
- Existing positional arguments retain their order. Extended kriging arguments
  (`trend`, `covariates`, alignment, standardization, explicit variogram,
  anisotropy, and neighborhood controls) were appended to `ps_interpolate()`.
- Requested interpolation methods are never silently substituted.
- Existing S3 classes and condition parents remain registered; new result
  classes add concise print and natural `as.data.frame()` methods.

Scientifically necessary refusals—unknown/geographic planar distances,
incompatible units or vertical datums, implicit raster alignment, duplicate
coordinates without a stated policy, and invalid stochastic models—use stable
classed conditions rather than silent correction. Regression tests cover the
baseline defaults, positional calls, result accessors, contours, support, and
arrow behavior.
