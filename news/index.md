# Changelog

## potentiomap 0.2.0

### Scientific behavior

- Hydraulic-gradient arrows can be flagged, shortened, dropped, or left
  with legacy unvalidated geometry after checking finite line support
  and modeled head at the base and tip. Shortening preserves the
  original direction.
- Universal kriging now centers and scales coordinates before
  constructing the quadratic drift by default. The legacy unscaled
  coordinates remain available through `uk_coordinate_scaling = "none"`.
- Universal-kriging results report trend rank, conditioning, prediction
  range, overshoot, and nonfinite predictions. Heuristic review
  thresholds produce classed warnings.
- Requested interpolation methods are not silently replaced.
- Prediction-support products describe the training convex hull,
  distance to observations, mask membership, and finite predictions
  without automatically removing extrapolated cells.
- Modeled contours can be divided into supported, approximate, and
  unsupported sections using user-defined distance, hull,
  local-neighbor, and optional identified uncertainty criteria.
- Groundwater-head units, depth units, vertical datum, measurement
  reference, depth sign, and measuring-point offset can be supplied and
  checked.

### Diagnostics

- Ordinary- and universal-kriging conditions are retained by method with
  empirical and fitted variogram information.
- Thin-plate-spline results retain supported GCV selection information
  and warn when the selected lambda is at a search boundary.
- `ps_interpolate(..., return = "result")` returns surfaces,
  diagnostics, parameters, input summaries, grid information,
  conditions, and optional prediction support.
- Structured contour results inventory requested, returned, and omitted
  levels.

### New functions

- [`ps_validate_arrows()`](https://el-cordero.github.io/potentiomap/reference/ps_validate_arrows.md)
  checks existing arrow geometry.
- [`ps_prediction_support()`](https://el-cordero.github.io/potentiomap/reference/ps_prediction_support.md)
  classifies prediction support.
- [`ps_contour_support()`](https://el-cordero.github.io/potentiomap/reference/ps_contour_support.md)
  splits contour lines at local support-class boundaries, and
  [`ps_export_contour_support()`](https://el-cordero.github.io/potentiomap/reference/ps_export_contour_support.md)
  writes the classified segments and summary.
- [`ps_interpolate_grouped()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate_grouped.md)
  separates analyses by explicit grouping keys.
- [`ps_metadata()`](https://el-cordero.github.io/potentiomap/reference/ps_metadata.md),
  [`ps_diagnostics()`](https://el-cordero.github.io/potentiomap/reference/ps_diagnostics.md),
  and
  [`ps_surfaces()`](https://el-cordero.github.io/potentiomap/reference/ps_surfaces.md)
  access retained metadata and structured results.

### Documentation

- Rewrote the generated README for groundwater practitioners.
- Added package-level help and four concise vignettes.
- Added a Bootstrap 5 pkgdown configuration, public support information,
  and issue-reporting templates.
- Added guidance for on-disk rasters, temporary files, and large
  prediction grids.

### Compatibility

- [`ps_interpolate()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate.md)
  still returns a named list of `SpatRaster` objects by default.
- [`ps_contours()`](https://el-cordero.github.io/potentiomap/reference/ps_contours.md)
  still returns a `SpatVector` by default.
- Existing public function names and valid positional arguments remain.
- Structured interpolation and contour results are opt-in.
- Requested interpolation methods are not silently replaced.
- Legacy unvalidated arrow geometry is available with
  `endpoint_action = "none"`; the new default is `"flag"`.
