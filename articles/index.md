# Articles

### Start here

- [Five-minute quick
  start](https://el-cordero.github.io/potentiomap/articles/quick-start.md):

  A copy-paste workflow from released synthetic groundwater observations
  to a surface, contours, quicklook, and hydraulic-gradient arrows.

### Prepare observations

- [Preparing groundwater
  observations](https://el-cordero.github.io/potentiomap/articles/preparing-observations.md):

  Direct head measurements and every released depth-to-water pathway,
  with data-frame, sf, and terra inputs.

- [Input formats and coordinate
  systems](https://el-cordero.github.io/potentiomap/articles/input-formats-crs.md):

  Prepare data-frame, sf, and terra point inputs; distinguish CRS
  assignment from transformation; and diagnose common spatial mistakes.

### Build surfaces

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

- [Comparing contour-support
  thresholds](https://el-cordero.github.io/potentiomap/articles/contour-support-thresholds.md):

  See how tighter, broader, and network-relative distance criteria
  divide the same modeled contours into supported, approximate, and
  unsupported sections.

### Create products

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

### Applied examples

- [Public USGS groundwater-monitoring
  example](https://el-cordero.github.io/potentiomap/articles/real-world-usgs.md):

  A reproducible TPS, contour, and inferred-gradient workflow for 36
  Stanley Shale wells near Hot Springs, Arkansas, using official USGS
  data.

- [Output
  gallery](https://el-cordero.github.io/potentiomap/articles/output-gallery.md):

  Actual potentiomap outputs from synthetic data and the attributed USGS
  public-data example.

### 0.2.0 guides

- [Getting started with
  potentiomap](https://el-cordero.github.io/potentiomap/articles/getting-started.md):
- [Interpolation diagnostics and prediction
  support](https://el-cordero.github.io/potentiomap/articles/diagnostics-and-support.md):
- [Contours and hydraulic-gradient
  arrows](https://el-cordero.github.io/potentiomap/articles/contours-and-arrows.md):
- [Units, vertical references, and grouped groundwater
  observations](https://el-cordero.github.io/potentiomap/articles/units-and-groups.md):
- [Preparing and checking groundwater
  observations](https://el-cordero.github.io/potentiomap/articles/observation-checks.md):
- [Validating and comparing interpolation
  methods](https://el-cordero.github.io/potentiomap/articles/validation-methods.md):
- [Variograms, anisotropy, and external
  drift](https://el-cordero.github.io/potentiomap/articles/variograms-trends.md):
- [Prediction support, surface uncertainty, and contour
  uncertainty](https://el-cordero.github.io/potentiomap/articles/uncertainty-support.md):
- [Temporal head change and vertical hydraulic
  gradients](https://el-cordero.github.io/potentiomap/articles/temporal-vertical.md):
- [Monitoring-network sensitivity and candidate
  locations](https://el-cordero.github.io/potentiomap/articles/monitoring-network.md):
- [Surface profiles, depth to water, and
  cross-sections](https://el-cordero.github.io/potentiomap/articles/profiles-depth.md):
- [Exporting GIS products and technical
  reports](https://el-cordero.github.io/potentiomap/articles/gis-reports.md):

### Expanded analysis articles

- [Observation QA, event selection, and screen
  grouping](https://el-cordero.github.io/potentiomap/articles/observation-qa-events-screens.md):
- [Leave-one-out, spatial-block, and independent
  validation](https://el-cordero.github.io/potentiomap/articles/validation-designs.md):
- [Nested tuning without information
  leakage](https://el-cordero.github.io/potentiomap/articles/nested-tuning.md):
- [Comparing TPS, IDW, OK, and
  UK](https://el-cordero.github.io/potentiomap/articles/comparing-methods.md):
- [Ensembles versus method
  disagreement](https://el-cordero.github.io/potentiomap/articles/ensembles-disagreement.md):
- [Conditional simulation and model-conditional
  uncertainty](https://el-cordero.github.io/potentiomap/articles/conditional-simulation.md):
- [Pointwise contour uncertainty versus approximate
  contours](https://el-cordero.github.io/potentiomap/articles/contour-uncertainty.md):
- [Comparing monitoring
  events](https://el-cordero.github.io/potentiomap/articles/monitoring-events.md):
- [Vertical-gradient sign
  conventions](https://el-cordero.github.io/potentiomap/articles/vertical-gradient-sign.md):
- [Well influence and network
  thinning](https://el-cordero.github.io/potentiomap/articles/well-influence-network-thinning.md):
- [Candidate monitoring locations and design
  constraints](https://el-cordero.github.io/potentiomap/articles/candidate-locations.md):
- [Grid, boundary, and parameter
  sensitivity](https://el-cordero.github.io/potentiomap/articles/surface-sensitivity.md):
- [Directional variograms and
  anisotropy](https://el-cordero.github.io/potentiomap/articles/directional-variograms.md):
- [Universal kriging with hydrogeologic
  covariates](https://el-cordero.github.io/potentiomap/articles/external-drift.md):
- [Interpolation within user-defined hydrogeologic
  regions](https://el-cordero.github.io/potentiomap/articles/regional-interpolation.md):
- [Depth to water and depth to a potentiometric
  surface](https://el-cordero.github.io/potentiomap/articles/depth-surfaces.md):
- [Profiles and
  cross-sections](https://el-cordero.github.io/potentiomap/articles/profiles-cross-sections.md):
- [QGIS and SLD style
  exports](https://el-cordero.github.io/potentiomap/articles/gis-styles.md):
- [Building a technical analysis
  report](https://el-cordero.github.io/potentiomap/articles/technical-reports.md):
- [Complete synthetic aquifer
  example](https://el-cordero.github.io/potentiomap/articles/complete-synthetic-aquifer.md):

### Scientific guidance

- [Interpretation, assumptions, and
  limitations](https://el-cordero.github.io/potentiomap/articles/interpretation-limitations.md):

  A hydrogeologic review checklist for observations, interpolation,
  smoothing, boundaries, and inferred hydraulic-gradient products.

- [Troubleshooting and common
  errors](https://el-cordero.github.io/potentiomap/articles/troubleshooting.md):

  Observed potentiomap errors and practical checks for CRS, missing
  values, duplicates, kriging, grids, arrows, contours, and exports.

- [Citing
  potentiomap](https://el-cordero.github.io/potentiomap/articles/citation.md):

  CRAN availability, DOI, package version, license, citation, and
  BibTeX.
