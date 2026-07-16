# potentiomap 0.2.0 baseline audit

Audit date: 2026-07-16

## Scope protection

- Package repository: `/Users/ec/Documents/Data/PotentiometricSurfPackage/potentiomap`
- Original branch: `main`
- Original commit: `1adc6dab36f8e842d526adc3aa89545c20e9a4a6`
- Release branch: `release/0.2.0`
- Original status: one pre-existing untracked file, `LICENSE`
- Manuscript repository and manuscript-analysis files are outside the package
  repository. They are read-only and will not be edited or executed.
- The three manuscript-based MRE scripts under
  `potentiomap_hj_manuscript/future_release/mre/` were inspected as evidence
  only. They were not run or copied into the package.
- `paper/` exists in the package repository and is excluded by `.Rbuildignore`.

## Release version decision

- Local package version: `0.1.0`
- Current CRAN version checked on 2026-07-16: `0.1.0`
- Remote Git tags: none
- Direct CRAN reverse dependencies: none
- Selected release version: `0.2.0`

## Public API at baseline

The original `NAMESPACE` exports ten functions:

- `ps_make_points(data, x = "x", y = "y", value, name_col = NULL, crs = NULL)`
- `ps_potentiometric_points(data, x = "x", y = "y", depth_col, surface = NULL, surface_col = NULL, name_col = NULL, surface_name_col = name_col, crs = NULL, idw_power = 2)`
- `ps_interpolate(points, value = "Z", methods = "TPS", grid_res = NULL, template = NULL, mask = NULL, padding = NULL, idw_power = 2, idw_nmax = 15, tps_lambda = NULL, kr_auto_cutoff = TRUE, kr_cutoff = NA_real_, kr_width = NA_real_, custom_methods = NULL, x = "x", y = "y", name_col = NULL, crs = NULL)`
- `ps_contours(surface, interval = 1, levels = NULL)`
- `ps_flow_arrows(surface, res_factor = 7, scale = 50, min_gradient = 1e-5, log_gradient = FALSE, log_arrow = FALSE, out_dir = NULL, out_stub = "gw")`
- `ps_arrow_vertices(arrows, which = c("last", "first"), out_file = NULL)`
- `ps_quicklook(surface, contours = NULL, points = NULL, file = NULL, title = "Potentiometric surface", label_points = TRUE, width = 1600, height = 1200, res = 180)`
- `ps_export_surfaces(surfaces, out_dir, out_stub = "gw", contour_interval = 1, points = NULL, write_raster = TRUE, write_contours = TRUE, write_png = TRUE)`
- `ps_sample_aoi()`
- `ps_smooth_surface(surface, window_size = 3, method = c("mean", "median"), weights = NULL, iterations = 1, na.rm = TRUE, preserve_na = TRUE, filename = "", overwrite = FALSE)`

## Repository contents at baseline

- Tests: `tests/testthat/test-potentiomap.R` only
- Vignettes: none
- GitHub Actions: none
- Pkgdown configuration: none
- README sources: `README.md` and a nonidentical `README 2.md`; no
  `README.Rmd`
- Release notes: no `NEWS.md`
- Issue templates and repository community files: absent
- Existing built tarball: `potentiomap_0.1.0.tar.gz`
- Existing local check directory: `potentiomap.Rcheck/`

## DESCRIPTION at baseline

- Package: `potentiomap`
- Title: `Build Potentiometric Surfaces and Flow Arrows`
- Version: `0.1.0`
- License: `GPL-3`
- Depends: `R (>= 4.1)`
- Imports: `fields`, `grDevices`, `graphics`, `gstat`, `sf`, `stats`, `terra`
- Suggests: `testthat (>= 3.0.0)`
- URL and BugReports fields: absent
- Maintainer: `Elvin Cordero <elvin.cordero@seamountgeo.com>`

## Check status at baseline

A fresh local check of the existing `potentiomap_0.1.0.tar.gz` was run with R
4.5.3 on macOS 26.2 using `R CMD check --no-manual`. Result: **OK**.
Repository access was unavailable inside that first sandboxed check, so its
dependency-index lookups warned; package installation, examples, code checks,
documentation checks, and tests all completed successfully. A separate live
CRAN query confirmed version 0.1.0, no direct reverse dependencies, and an all-OK
public CRAN check matrix across the listed Linux, Windows, and macOS flavors.

## Baseline scientific findings

- Arrow orientation follows raster aspect, but scaled line tips can leave
  finite support or finish above their bases.
- Universal kriging constructs raw quadratic terms from large projected
  coordinates and returns no conditioning or prediction-range diagnostics.
- Kriging and TPS conditions are not retained in a method-attributed result.
- Explicit contour levels omitted by `terra::as.contour()` are not inventoried.
- Invalid coordinate and head records can be silently dropped by point
  preparation.
- Interpolation has no structured result, prediction-support product, grouped
  interface, or explicit vertical-reference metadata.

## Compatibility decisions

- Preserve the existing default return classes and existing function names.
- Add new arguments at the end of signatures whenever practical.
- Do not silently substitute interpolation methods, reverse arrows, or change a
  requested UK trend.
- Retain legacy unvalidated arrow geometry through `endpoint_action = "none"`;
  use additive validation output for the new release.
- Keep TPS as the software default for compatibility while documenting that
  suitability depends on the hydrogeologic setting, monitoring geometry,
  prediction support, validation design, and intended map use.
