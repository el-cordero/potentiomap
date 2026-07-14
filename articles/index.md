# Articles

### Start Here

- [Five-minute quick
  start](https://el-cordero.github.io/potentiomap/articles/quick-start.md):

  A copy-paste workflow from released synthetic groundwater observations
  to a surface, contours, quicklook, and hydraulic-gradient arrows.

### Prepare Monitoring Data

- [Preparing groundwater
  observations](https://el-cordero.github.io/potentiomap/articles/preparing-observations.md):

  Direct head measurements and every released depth-to-water pathway,
  with data-frame, sf, and terra inputs.

- [Input formats and coordinate
  systems](https://el-cordero.github.io/potentiomap/articles/input-formats-crs.md):

  Prepare data-frame, sf, and terra point inputs; distinguish CRS
  assignment from transformation; and diagnose common spatial mistakes.

### Build Surfaces

- [Comparing TPS, IDW, ordinary kriging, and universal
  kriging](https://el-cordero.github.io/potentiomap/articles/interpolation-methods.md):

  Four released interpolation methods on one projected grid, with common
  scales, contours, and difference rasters.

- [Interpolation parameters and common grid
  geometry](https://el-cordero.github.io/potentiomap/articles/interpolation-parameters.md):

  See how resolution, padding, masks, IDW controls, TPS smoothing,
  kriging lags, and templates affect the modeled product.

- [Custom interpolation
  functions](https://el-cordero.github.io/potentiomap/articles/custom-interpolation.md):

  Implement and validate the released custom-method signature without
  using package internals.

- [Contours and surface
  smoothing](https://el-cordero.github.io/potentiomap/articles/contours-smoothing.md):

  Regular and explicit contours plus mean, median, one-pass, and
  multi-pass focal smoothing with scientific cautions.

### Create Products

- [Hydraulic-gradient
  arrows](https://el-cordero.github.io/potentiomap/articles/flow-arrows.md):

  Inspect gradient rasters, arrow lines, bases and tips, cartographic
  controls, filtering, log options, and a programmatic downgradient
  check.

- [Exporting GIS-ready
  products](https://el-cordero.github.io/potentiomap/articles/exporting-products.md):

  Write, inventory, read back, and validate GeoTIFF, contour, quicklook,
  arrow, tip, and base products.

- [Repeated monitoring
  events](https://el-cordero.github.io/potentiomap/articles/repeated-events.md):

  Use ordinary R iteration around potentiomap for three synthetic
  monitoring rounds on one common grid.

### Applied Examples

- [Public USGS groundwater-monitoring
  example](https://el-cordero.github.io/potentiomap/articles/real-world-usgs.md):

  A reproducible TPS, contour, and inferred-gradient workflow for 36
  Stanley Shale wells near Hot Springs, Arkansas, using official USGS
  data.

- [Output
  gallery](https://el-cordero.github.io/potentiomap/articles/output-gallery.md):

  Actual outputs generated with potentiomap 0.1.0 from released
  synthetic data and the attributed USGS public-data example.

### Guidance

- [Interpretation, assumptions, and
  limitations](https://el-cordero.github.io/potentiomap/articles/interpretation-limitations.md):

  A hydrogeologic review checklist for observations, interpolation,
  smoothing, boundaries, and inferred hydraulic-gradient products.

- [Troubleshooting and common
  errors](https://el-cordero.github.io/potentiomap/articles/troubleshooting.md):

  Observed potentiomap 0.1.0 errors and practical checks for CRS,
  missing values, duplicates, kriging, grids, arrows, contours, and
  exports.

- [Citing
  potentiomap](https://el-cordero.github.io/potentiomap/articles/citation.md):

  CRAN availability, DOI, released version, license, citation, and
  BibTeX.
