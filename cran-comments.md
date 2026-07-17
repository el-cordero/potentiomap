# CRAN comments

## Resubmission

This resubmission addresses the invalid file URIs reported by CRAN. The
relative links to `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md` in `README.md`
have been replaced with valid absolute URLs to the corresponding files in the
public GitHub repository. The linked policy files are intentionally excluded
from the CRAN source tarball, so no package-local file URI remains.

## Release

This is an update from potentiomap 0.1.0 to 0.2.0. The package name,
maintainer email, and minimum R version are unchanged.

## Local test environment

- macOS Tahoe 26.2, arm64
- R 4.5.3 (2026-03-11)

## Actual local results for the candidate

Candidate SHA-256:
`d9320ee01d56c8556910eabbaca804294964cfc75b436b4517686c4a3d65f90a`

- Exact-candidate `R CMD check --as-cran --no-manual`: 0 errors, 0 warnings,
  0 notes (Status: OK), with only the local system-clock probe disabled.
- A separate manual-enabled run passed the PDF manual and reported two local
  host NOTEs: the host could not verify its current time, and the Apple-supplied
  HTML Tidy is too old, so optional HTML-manual validation was skipped.
  Installation, code, data, examples, 897 test expectations, vignettes and
  their rebuild, incoming URL feasibility, and detritus checks passed.
- Overall line coverage is 96.57%; every new executable R file is at least
  98.08%.
- All 18 discovered external URLs, including the corrected contribution-policy
  links, and the spelling audit passed.
- CRAN lists no direct or recursive reverse dependencies.

The release adds observation/event/screen checks, multiple validation designs,
nested tuning, variograms/anisotropy/external drift, ensembles and disagreement,
model-conditional uncertainty, temporal/vertical/surface comparisons,
monitoring-network analyses, regional interpolation, depth/profile/section
products, GIS styles, and offline technical reports. Existing default returns
and positional calls remain available.

GitHub Actions is configured for Linux with R-release and R-devel, Windows with
R-release, and macOS with R-release. Coverage upload uses Codecov OIDC, and the
pkgdown workflow deploys to GitHub Pages. Separate Win-builder and external
macOS services were not run. This corrected source archive is ready for CRAN
resubmission; no resubmission has yet been made.
