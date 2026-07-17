# Dependency audit for potentiomap 0.2.0 expansion

Checked 2026-07-17 against current package documentation and the installed
release environment.

| Dependency | Feature | Why existing/base R is insufficient | Placement | System requirements / CRAN / maintenance | Installation and fallback |
|---|---|---|---|---|---|
| `terra` | All raster/vector products | Existing core spatial representation and file-backed raster operations | Imports, unchanged | CRAN; compiled geospatial library maintained by rspatial | Already required; package cannot operate without it |
| `sf` | Geometry conversion, overlays, line projection, distances | Existing supported simple-feature operations and gstat bridge | Imports, unchanged | CRAN; GDAL/GEOS/PROJ-linked, actively maintained | Already required; no `sp` or `raster` fallback is added |
| `gstat` | IDW, kriging, variograms, anisotropy, prediction variance, conditional simulation | Base R has no supported implementation of these geostatistical APIs | Imports, unchanged | CRAN; actively maintained | Requested geostatistical methods fail clearly if unavailable during installation |
| `fields` | TPS fits and supported standard errors | Base R does not provide the existing thin-plate spline behavior | Imports, unchanged | CRAN; actively maintained | Existing TPS behavior is preserved; no silent method fallback |
| `xml2` | QML/SLD validation and safe XML construction | Base R XML writing does not provide the same compact namespace-aware construction and parse validation | Imports, new | CRAN; actively maintained; compiled against libxml2 but binary packages are widely available | Small incremental dependency; style export is always validated rather than becoming conditionally unavailable |
| `graphics`, `grDevices`, `stats` | Base plots, palettes, metrics/models | R-recommended/base facilities | Imports, unchanged | Shipped with R | No effect |
| `testthat` | Routine and extended tests | Test harness and classed condition/file assertions | Suggests, unchanged | CRAN; actively maintained | Tests skip only when Suggests are legitimately absent outside checks |
| `withr` | Scoped seeds/options and temporary state in tests | Reliable restoration of state | Suggests, unchanged | CRAN; actively maintained | Runtime code uses base restoration where possible |
| `knitr`, `rmarkdown` | Vignettes and `ps_report()` | Document rendering and package-owned templates | Suggests, unchanged | CRAN; Pandoc is needed for rendering; maintained | `ps_report()` raises `potentiomap_report_error` with installation/Pandoc guidance; core package remains usable |
| `pkgdown` | Local website | Website generator | `Config/Needs/website`, unchanged | CRAN; maintained | Development-only; not required by users |
| `covr` | Coverage measurement | Instrumented line coverage | `Config/Needs/coverage`, unchanged | CRAN; maintained | Development-only |

No machine-learning framework, database, optimization framework, R6-based
runtime design, workflow engine, Docker/Java/Python requirement, or compiled
package code is introduced. Stable IDs and hashes use package-local base-R
helpers; progress callbacks use ordinary functions; report escaping uses base R
plus the renderer. Optional parallel execution is not introduced in this
release, so all computation defaults to one core.

The checked local versions were terra 1.9.27, sf 1.1.0, gstat 2.1.5, fields
17.1, xml2 1.5.2, testthat 3.3.2, withr 3.0.2, knitr 1.51, rmarkdown 2.30,
and pkgdown 2.2.0. covr 3.6.5 and spelling 2.3.2 were installed only into
temporary release-audit libraries. The local site builder reported newer CRAN
versions for several spatial packages; compatibility with current releases is
delegated to the configured R-devel and fresh-dependency CI jobs.
