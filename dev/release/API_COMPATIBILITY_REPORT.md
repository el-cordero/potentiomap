# API compatibility report

Release candidate: potentiomap 0.2.0
Baseline: potentiomap 0.1.0 at `1adc6dab36f8e842d526adc3aa89545c20e9a4a6`

## Preserved defaults

- `ps_make_points()` and `ps_potentiometric_points()` still return point
  `SpatVector` objects.
- `ps_interpolate()` still returns a named list of `SpatRaster` surfaces by
  default. Structured output is opt-in with `return = "result"`.
- `ps_contours()` still returns a line `SpatVector` by default. Its manifest is
  opt-in with `return = "result"`.
- `ps_flow_arrows()` still returns a list containing `raster`, `points`, and
  `arrows`; validation fields are additive.
- Existing names and pre-0.2.0 positional arguments remain in their original
  order. New arguments were appended.
- Named custom interpolation methods remain supported.
- TPS remains the software default for compatibility.

## Existing functions changed additively

- `ps_make_points()` adds metadata, unit conversion, metadata-mode, and invalid
  record controls.
- `ps_potentiometric_points()` adds metadata, unit, reference, sign, measuring
  point, and invalid-record controls.
- `ps_interpolate()` adds structured returns, duplicate-coordinate policy,
  geographic-distance control, UK coordinate scaling and diagnostics, and
  optional prediction support.
- `ps_contours()` adds the structured manifest return.
- `ps_flow_arrows()` adds endpoint policies, extraction/tolerance controls,
  deterministic shortening, validation records, and overwrite control. The new
  default `endpoint_action = "flag"` preserves original line geometry while
  reporting failed tips; `"none"` reproduces unvalidated 0.1.0 geometry.
- `ps_arrow_vertices()` adds explicit overwrite control.
- `ps_quicklook()` adds contour units, contour-label and overwrite controls.
- `ps_export_surfaces()` adds explicit levels, GeoPackage, support, diagnostic,
  contour-manifest and output-manifest products, plus overwrite control.
- `ps_smooth_surface()` retains its signature and now uses classed validation
  and export errors consistently.

## New exported functions

- `ps_contour_support()`
- `ps_diagnostics()`
- `ps_export_contour_support()`
- `ps_interpolate_grouped()`
- `ps_metadata()`
- `ps_prediction_support()`
- `ps_surfaces()`
- `ps_validate_arrows()`

New S3 behavior includes print/summary methods for structured interpolation
results, print/plot methods for contour-support results, and print support for
arrow-validation results.

## Deliberate scientific behavior changes

- Requested interpolation methods are never silently substituted.
- Duplicate coordinates default to a classed error and require an explicit
  aggregation policy.
- Distance-based interpolation and support calculations reject geographic
  degree coordinates by default.
- Quadratic-drift UK uses centered and scaled coordinates by default;
  `uk_coordinate_scaling = "none"` retains legacy comparison behavior.
- Important errors and warnings now have stable `potentiomap_*` classes.

These changes preserve valid 0.1.0 calls while refusing or clearly flagging
scientifically ambiguous inputs that were previously accepted silently.
