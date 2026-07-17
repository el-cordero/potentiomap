# Integration test report

Date: 2026-07-17

`dev/integration-tests/complete-synthetic.R` completed successfully with fixed
seed 20260717. It exercised observation QA, event selection, screen grouping,
TPS/IDW/OK interpolation, validation, comparison, tuning, variograms,
anisotropy, external drift, support, ensembles, disagreement, uncertainty,
contour uncertainty/support, arrows, head change, vertical gradient, influence,
thinning, candidate sites, sensitivity, regional interpolation, depth,
profiles, cross-sections, QML, and HTML reporting.

`dev/stress-tests/run-stress.R` also completed successfully with master seed
20260717 and six recorded derived seeds. It covered repeated spatial
validation, clustered and elongated networks, a 75 m ordinary-kriging grid,
20 conditional simulations, 10 thinning runs, 15 tuning candidates,
file-backed rasters, missing support, repeated exports/reports, overwrite
protection, and a deliberately failed destination. Temporary outputs were
removed on exit.

Both suites use only public synthetic fixtures. No manuscript analysis, data,
or files were read or executed.
