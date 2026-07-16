# Test and coverage report

Date: 2026-07-16
Package-source commit: `1b94cdc3cfa11d303805a21d9674a7c7175d0ed5`

## Test suite

- Test files: 11, plus one shared synthetic helper.
- `test_that()` blocks: 59.
- Expectations: 273 passed.
- Failures: 0.
- Warnings: 0.
- Skips: 0.

The suite uses fixed, small synthetic points, rasters, contours, and temporary
directories. It uses no internet, manuscript data, manuscript raster, or
uploaded map fixture.

## Coverage

Measured with covr 3.6.5 using test coverage only:

- Total line coverage: **85.66474%**.
- `R/smooth.R`: 100.00%.
- `R/result.R`: 97.73%.
- `R/support.R`: 95.65%.
- `R/conditions.R`: 92.77%.
- `R/flow.R`: 89.53%.
- `R/points.R`: 88.27%.
- `R/interpolate.R`: 87.42%.
- `R/outputs.R`: 87.07%.
- `R/grouped.R`: 83.89%.
- `R/metadata.R`: 82.24%.
- `R/contour-support.R`: 77.44%.
- `R/data.R`: 100.00%.

The target of at least 85% was met by adding meaningful tests for sf and
SpatVector observations, nonfinite inputs, raster- and point-derived land
surfaces, weighted and file-based smoothing, and structured-result accessors.
No tests were added solely to execute unreachable internal lines.

Expression-level detail is stored in
`dev/release/checks/coverage-detail.csv`.
