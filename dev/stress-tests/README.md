# Extended stress tests

`run-stress.R` uses fixed master seed `20260717` and records derived seeds for
moderately larger grids, clustered networks, repeated tuning, simulation,
thinning, file-backed rasters, GIS styles, and reports. It is deliberately
excluded from ordinary package checks and is run by the manually triggered or
scheduled extended GitHub Action.

No manuscript, confidential, or downloaded data are used. Temporary outputs
are removed on exit.
