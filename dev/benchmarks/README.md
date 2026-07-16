# Development benchmarks

These benchmarks exercise interpolation and hydraulic-gradient-arrow creation
on synthetic projected data at several raster sizes. They are maintainer tools,
not routine package tests, and are excluded from the CRAN source package.

Run from the package root with:

```sh
Rscript dev/benchmarks/resource-behavior.R
```

The script writes a timestamped CSV under `dev/benchmarks/results/`. Each row
records the operating system, R and package versions, relevant dependency
versions, interpolation method, target cell count, actual raster dimensions,
elapsed time, output file sizes, and the `terra` temporary directory. Timings
describe only the recorded environment and should not be generalized to other
systems.

The benchmark deliberately does not report R allocation measurements as peak
RAM. Operating-system-level peak-memory measurement requires a separate,
platform-specific tool and should be documented with the resulting report.

Before larger runs, direct `terra` temporary files to storage with adequate
space, for example:

```r
old <- terra::terraOptions()
on.exit(terra::terraOptions(tempdir = old$tempdir), add = TRUE)
terra::terraOptions(tempdir = "/path/to/large/temporary/storage")
```

Use a project-specific temporary directory and remove it after confirming that
no needed on-disk rasters still refer to those files. Interrupted R sessions can
leave temporary rasters behind.
