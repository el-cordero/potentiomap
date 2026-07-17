# Test and coverage report

Date: 2026-07-17

## Routine suite

- `test_that()` blocks: **145**
- expectations: **897 passed**
- failures, warnings, errors, and skips: **0**
- documented example files run in clean sessions, including `\donttest`: **61**

Tests use fixed package synthetic data and temporary output locations. They do
not use internet access, manuscript material, confidential locations, or
study-scale fixtures.

## Line coverage

Measured with covr 3.6.5 from the complete test suite:

- overall line coverage: **96.57%** (target: at least 95%)
- expression coverage: 94.82% (reported for context; the acceptance target is
  line coverage)

New executable R files all meet the 98% line target:

| New R file | Line coverage |
|---|---:|
| `observations-expansion.R` | 100.00% |
| `variograms-expansion.R` | 99.55% |
| `change-network-sensitivity.R` | 99.07% |
| `exports-reports.R` | 98.91% |
| `validation-expansion.R` | 98.39% |
| `surface-analysis.R` | 98.32% |
| `expansion-utils.R` | 98.28% |
| `regions-profiles.R` | 98.10% |
| `tuning-uncertainty.R` | 98.08% |

`data-expansion.R` contains data documentation and no executable expressions
for covr to instrument. Existing lower-coverage modules are retained code:
`interpolate.R` 87.71%, `flow.R` 92.27%, `points.R` 93.65%, `support.R`
94.29%, `grouped.R` 95.10%, `metadata.R` 96.00%, `outputs.R` 97.21%, and
`contour-support.R` 97.53%. No platform branch was skipped to inflate results.
