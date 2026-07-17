# CRAN comments

## Release

This is an update from potentiomap 0.1.0 to 0.2.0. The package name,
maintainer email, and minimum R version are unchanged.

## Local test environment

- macOS Tahoe 26.2, arm64
- R 4.5.3 (2026-03-11)

## Actual local results for the candidate

Candidate SHA-256:
`9c89c6bffe7018ae786f71cb7f4270862b6f9b6daded8c17b54c14124853ae59`

- `R CMD check`: 0 errors, 0 warnings, 0 notes (Status: OK).
- isolated `R CMD check --as-cran`: 0 errors, 0 warnings, 1 local host NOTE.
  The Apple-supplied HTML Tidy is too old, so optional HTML-manual validation
  was skipped. Installation, code, data, examples, 897 test expectations,
  vignettes and their rebuild, PDF manual, incoming URL feasibility, and
  detritus checks passed.
- Overall line coverage is 96.57%; every new executable R file is at least
  98.08%.
- All 13 discovered external URLs and the spelling audit passed.
- CRAN lists no direct or recursive reverse dependencies.

The release adds observation/event/screen checks, multiple validation designs,
nested tuning, variograms/anisotropy/external drift, ensembles and disagreement,
model-conditional uncertainty, temporal/vertical/surface comparisons,
monitoring-network analyses, regional interpolation, depth/profile/section
products, GIS styles, and offline technical reports. Existing default returns
and positional calls remain available.

Linux, Windows, R-devel, Win-builder, current-HTML-Tidy, and external macOS
checks must be completed on the committed candidate before this file is used
for submission. No submission has been made.
