# Final package release report

## Identification

- Package: potentiomap
- Original version: 0.1.0
- Final candidate version: 0.2.0
- Original commit: `1adc6dab36f8e842d526adc3aa89545c20e9a4a6`
- Final package-source commit:
  `1b94cdc3cfa11d303805a21d9674a7c7175d0ed5`
- Release branch: `release/0.2.0`

## Public API

Added exports:

- `ps_contour_support()`
- `ps_diagnostics()`
- `ps_export_contour_support()`
- `ps_interpolate_grouped()`
- `ps_metadata()`
- `ps_prediction_support()`
- `ps_surfaces()`
- `ps_validate_arrows()`

Changed additively:

- `ps_make_points()`
- `ps_potentiometric_points()`
- `ps_interpolate()`
- `ps_contours()`
- `ps_flow_arrows()`
- `ps_arrow_vertices()`
- `ps_quicklook()`
- `ps_export_surfaces()`
- `ps_smooth_surface()` validation behavior

Backward-compatible defaults are documented in
`API_COMPATIBILITY_REPORT.md`. Most importantly, raster-list interpolation and
line-vector contour defaults remain unchanged, and requested methods are not
silently replaced.

## Feature status

- FR-001 arrow endpoints: complete and tested.
- FR-002 UK conditioning/diagnostics: complete and tested.
- FR-003 kriging diagnostics: complete and tested.
- FR-004 TPS GCV diagnostics: complete and tested.
- FR-005 prediction support: complete and tested.
- FR-006 grouped observations: complete and tested.
- FR-007 units/vertical references: complete and tested.
- FR-008 contour inventory: complete and tested.
- FR-009 resource behavior: documentation, benchmark harness, and three local
  synthetic benchmark sizes complete.
- FR-010 contour support: complete and tested, including section splitting,
  relative and absolute thresholds, hull/neighbor/uncertainty rules, plotting,
  summaries, and export.

## Documentation and repository maturity

- README generated from README.Rmd; competing `README 2.md` removed.
- NEWS, package-level help, full function help, condition/result pages, four
  vignettes, CFF citation, pkgdown, CI, issue forms, and community files added.
- Local pkgdown 0.2.0 site built and visually inspected on desktop/mobile.
  Navigation, reference index, search, headings, code overflow, and image alt
  text passed inspection.
- Live website status: HTTP 200, but it still documents 0.1.0. Manual 0.2.0
  deployment remains required.
- Issue tracker status: visible, but ordinary public issue creation is
  restricted. Manual settings remain required.

## Verification

- Test expectations: 273 passed, 0 failed/warned/skipped.
- Test blocks: 59 across 11 files.
- Coverage: 85.66474%.
- Standard `R CMD check`: Status OK, 0 errors, 0 warnings, 0 notes.
- `R CMD check --as-cran`: 0 errors, 0 warnings, 2 local-host notes (external
  clock verification unavailable; Apple HTML Tidy too old for optional HTML
  validation). No package-content note remains.
- URL check: all 5 URLs correct.
- Spelling: no errors.
- Reverse dependencies: none listed on CRAN.
- Current public CRAN 0.1.0 checks: all 12 displayed flavors OK.
- Cross-platform 0.2.0 candidate checks: CI configured but not run remotely;
  Win-builder and external macOS checks remain manual.

## Package artifact

- Exact tarball:
  `/Users/ec/Documents/Data/PotentiometricSurfPackage/potentiomap/potentiomap_0.2.0.tar.gz`
- SHA-256:
  `ca119ee73f57322cc494b9605561fb32e608209e8e501e74910ff6437a88692b`
- Compressed size: 1,576,813 bytes.
- Installed size: 1,980 KiB on the local release host.
- Tar entries: 88.

The tarball contains no manuscript or paper material, development directory,
website build, GitHub metadata, benchmark output, local checks, nested tarball,
or duplicate README.

## Scope confirmation

No manuscript or manuscript-analysis file was modified. No manuscript analysis
was run. The package name and maintainer email were retained. No remote branch,
pull request, tag, release, website deployment, repository-setting change, or
CRAN submission occurred.

## Release readiness

The local package implementation is stable, documented, tested, and transparent
about scientific limitations. It is a release candidate, not yet the final CRAN
submission artifact. Before submission, an authorized maintainer must complete
the live 0.2.0 website deployment, enable public issue creation, run the remote
cross-platform/Win-builder/macOS checks, then rebuild and recheck the exact
merged tarball as specified in `MANUAL_RELEASE_ACTIONS.md`.
