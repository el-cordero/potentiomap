# Baseline before the 0.2.0 expansion

Checked 2026-07-17 in America/Puerto_Rico before implementation changes.

## Repository and version safety

- Package repository: `/Users/ec/Documents/Data/PotentiometricSurfPackage/potentiomap`
- Branch at the start of the task: `main`
- Original commit: `358185faa657b8c2ef4154c5314ecfede306fe9e`
- Initial working tree: `main` matched `origin/main`; the pre-existing untracked
  file `LICENSE` was present and was not changed.
- DESCRIPTION version: `0.2.0`
- The historical `release/0.2.0` branch had already been merged and deleted.
  After the baseline and version gate were recorded, a new local
  `release/0.2.0` branch was created from the original commit so this expansion
  does not modify `main`.
- The official CRAN package page reported version `0.1.0` (published
  2026-05-29).
- `git ls-remote --tags origin` returned no tags.
- `gh release list --repo el-cordero/potentiomap` returned no releases.
- Remote heads were only `main` and `gh-pages`; no release branch remained.
- The repository contains a local `potentiomap_0.2.0.tar.gz`, but the existing
  release reports identify it as a local release candidate, not a submitted or
  distributed final release. `MANUAL_RELEASE_ACTIONS.md` states that no CRAN
  submission, tag, GitHub release, or remote deployment occurred.
- Conclusion: no 0.2.0 version conflict was found.

## Public API before expansion

The generated `NAMESPACE` exported 18 functions. Signatures loaded from the
untouched package source were:

```r
ps_arrow_vertices(arrows, which = c("last", "first"), out_file = NULL,
  overwrite = TRUE)
ps_contour_support(contours, points = NULL, surface = NULL, support = NULL,
  uncertainty = NULL, supported_distance = NULL,
  approximate_distance = NULL,
  distance_reference = c("map_units", "median_nearest_neighbor"),
  require_inside_hull = TRUE, neighbor_radius = NULL,
  minimum_neighbors = NULL, supported_uncertainty = NULL,
  approximate_uncertainty = NULL,
  combine = c("worst", "distance", "uncertainty"),
  keep_unsupported = TRUE, minimum_segment_length = 0,
  return = c("result", "segments"), uncertainty_type = NULL,
  uncertainty_units = NULL)
ps_contours(surface, interval = 1, levels = NULL,
  return = c("contours", "result"))
ps_diagnostics(x, method = NULL)
ps_export_contour_support(x, out_dir, out_stub = "gw",
  vector_format = c("gpkg", "shapefile"), write_summary = TRUE,
  write_thresholds = TRUE, overwrite = TRUE)
ps_export_surfaces(surfaces, out_dir, out_stub = "gw",
  contour_interval = 1, points = NULL, write_raster = TRUE,
  write_contours = TRUE, write_png = TRUE, contour_levels = NULL,
  vector_format = c("shapefile", "gpkg"), support = NULL,
  diagnostics = NULL, write_contour_manifest = TRUE,
  write_support = FALSE, write_diagnostics = FALSE,
  write_manifest = TRUE, overwrite = TRUE)
ps_flow_arrows(surface, res_factor = 7, scale = 50,
  min_gradient = 1e-5, log_gradient = FALSE, log_arrow = FALSE,
  out_dir = NULL, out_stub = "gw",
  endpoint_action = c("flag", "shorten", "drop", "none"),
  endpoint_tolerance = 1e-6,
  endpoint_extraction = c("bilinear", "simple"),
  max_shortening = 12L, overwrite = TRUE)
ps_interpolate(points, value = "Z", methods = "TPS", grid_res = NULL,
  template = NULL, mask = NULL, padding = NULL, idw_power = 2,
  idw_nmax = 15, tps_lambda = NULL, kr_auto_cutoff = TRUE,
  kr_cutoff = NA_real_, kr_width = NA_real_, custom_methods = NULL,
  x = "x", y = "y", name_col = NULL, crs = NULL,
  return = c("surfaces", "result"),
  duplicate_action = c("error", "mean", "median", "first"),
  allow_geographic = FALSE,
  uk_coordinate_scaling = c("center_scale", "none"),
  diagnostic_control = NULL, support = FALSE,
  support_max_distance = NULL)
ps_interpolate_grouped(data, group_cols, value = "Z", x = "x", y = "y",
  name_col = NULL, crs = NULL,
  template_mode = c("shared", "group"), mask = NULL,
  mask_mode = c("shared", "group"), output_dir = NULL,
  progress = NULL, ...)
ps_make_points(data, x = "x", y = "y", value, name_col = NULL,
  crs = NULL, metadata = NULL, head_unit = NULL, output_unit = NULL,
  vertical_datum = NULL, surface_reference = NULL,
  metadata_mode = c("legacy", "warn", "strict"),
  invalid_action = c("drop", "error"))
ps_metadata(x)
ps_potentiometric_points(data, x = "x", y = "y", depth_col,
  surface = NULL, surface_col = NULL, name_col = NULL,
  surface_name_col = name_col, crs = NULL, idw_power = 2,
  metadata = NULL, depth_unit = NULL, surface_unit = NULL,
  output_unit = NULL, vertical_datum = NULL, surface_reference = NULL,
  depth_sign = NULL, measuring_point_offset = NULL,
  metadata_mode = c("legacy", "warn", "strict"),
  invalid_action = c("drop", "error"))
ps_prediction_support(points, surface = NULL, template = NULL, mask = NULL,
  max_distance = NULL, allow_geographic = FALSE)
ps_quicklook(surface, contours = NULL, points = NULL, file = NULL,
  title = "Potentiometric surface", label_points = TRUE,
  width = 1600, height = 1200, res = 180, contour_units = NULL,
  label_contours = TRUE, overwrite = TRUE)
ps_sample_aoi()
ps_smooth_surface(surface, window_size = 3,
  method = c("mean", "median"), weights = NULL, iterations = 1,
  na.rm = TRUE, preserve_na = TRUE, filename = "", overwrite = FALSE)
ps_surfaces(x)
ps_validate_arrows(surface, arrows, tolerance = 1e-6,
  extraction = c("bilinear", "simple"))
```

Existing public S3 methods were `plot.potentiomap_contour_support`, print
methods for arrow validation, contour results/support, grouped results,
interpolation results and prediction support, plus `summary.potentiomap_result`
and `print.summary.potentiomap_result`.

## Tests, vignettes, articles, CI, and website configuration

Routine tests:

- `tests/testthat/test-potentiomap.R`
- `tests/testthat/test-contour-manifest.R`
- `tests/testthat/test-arrow-endpoints.R`
- `tests/testthat/test-interpolation-results.R`
- `tests/testthat/test-grouped.R`
- `tests/testthat/test-support.R`
- `tests/testthat/test-conditions-and-compatibility.R`
- `tests/testthat/test-contour-support.R`
- `tests/testthat/test-fit-diagnostics.R`
- `tests/testthat/test-outputs-and-smoothing.R`
- `tests/testthat/test-points-metadata.R`
- `tests/testthat/helper-synthetic.R`
- `tests/testthat.R`

CRAN vignettes:

- `vignettes/getting-started.Rmd`
- `vignettes/units-and-groups.Rmd`
- `vignettes/diagnostics-and-support.Rmd`
- `vignettes/contours-and-arrows.Rmd`

Website-only articles under `vignettes/articles/`:

- `citation.Rmd`
- `contour-support-thresholds.Rmd`
- `contours-smoothing.Rmd`
- `custom-interpolation.Rmd`
- `exporting-products.Rmd`
- `flow-arrows.Rmd`
- `input-formats-crs.Rmd`
- `interpolation-methods.Rmd`
- `interpolation-parameters.Rmd`
- `interpretation-limitations.Rmd`
- `output-gallery.Rmd`
- `preparing-observations.Rmd`
- `quick-start.Rmd`
- `real-world-usgs.Rmd`
- `repeated-events.Rmd`
- `troubleshooting.Rmd`

GitHub Actions:

- `.github/workflows/R-CMD-check.yaml`
- `.github/workflows/test-coverage.yaml`
- `.github/workflows/pkgdown.yaml`

Website configuration was in `_pkgdown.yml`; a generated `docs/pkgdown.yml`
also existed. No top-level `articles/` directory existed.

## Untouched baseline execution

- `testthat::test_local(".", reporter = "summary")`: PASS, exit status 0.
  All 12 test contexts completed; the existing release report records 273
  passing expectations for this suite.
- A direct source-directory `R CMD check --no-manual --no-build-vignettes`
  was attempted first and rejected before package checking because this R
  invocation did not synthesize `Author` and `Maintainer` from `Authors@R`.
  This is not the authoritative package check.
- An intentionally vignette-free temporary build checked with two expected
  vignette warnings; this diagnostic build is not the baseline release result.
- Authoritative baseline: a full `R CMD build` followed by
  `R CMD check potentiomap_0.2.0.tar.gz` on the built temporary tarball.
  Result: `Status: OK` with 0 errors, 0 warnings, and 0 notes. Examples, tests,
  vignettes, rebuilt vignette outputs, and the PDF manual all passed.
- R: 4.5.3 (2026-03-11), aarch64-apple-darwin20, macOS Tahoe 26.2.
- The check printed repository-index access warnings while testing dependency
  availability because network access was unavailable inside the sandbox, but
  dependency checking itself returned `OK` and these were not package check
  warnings.

All baseline build and check artifacts were written under `/private/tmp`, not
to the repository. No manuscript analysis or manuscript file was read or run as
part of the baseline.
