# Cross-platform report

Date: 2026-07-17

## Executed locally

- macOS Tahoe 26.2, arm64, R 4.5.3: routine tests, all examples, vignettes,
  integration, stress, ordinary `R CMD check`, and `R CMD check --as-cran` were
  run locally.
- No package code assumes forked processes or more than one core. File paths,
  temporary outputs, XML, raster writing, and deterministic seeds have
  cross-platform unit coverage.

## Configured but not executed for this unpushed working tree

The GitHub Actions matrix contains Linux R-release, Linux R-devel, Windows
R-release, and macOS R-release jobs. A scheduled/manual extended workflow runs
the integration and stress suites. Because no push or external service action
was authorized, those jobs, Win-builder, and another external macOS service
have not run on this exact candidate.

Therefore local macOS evidence is complete, but cross-platform acceptance item
55 remains an external release gate. No cross-platform pass is claimed from
configuration alone.
