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

  A concise end-to-end introduction to observations, interpolation,
  contours, diagnostics, and support.

- [Interpolation diagnostics and prediction
  support](https://el-cordero.github.io/potentiomap/articles/diagnostics-and-support.md):

  Review retained interpolation diagnostics and classify where a mapped
  prediction has limited spatial support.

- [Contours and hydraulic-gradient
  arrows](https://el-cordero.github.io/potentiomap/articles/contours-and-arrows.md):

  Create contours and checked downgradient display symbols while keeping
  support and interpretation limits explicit.

- [Units, vertical references, and grouped groundwater
  observations](https://el-cordero.github.io/potentiomap/articles/units-and-groups.md):

  Keep units, vertical datums, screened intervals, and water-bearing
  groups explicit before interpolation.

- [Preparing and checking groundwater
  observations](https://el-cordero.github.io/potentiomap/articles/observation-checks.md):

  Prepare measured heads or depth-to-water records and inspect
  observation-level QA findings before mapping.

- [Validating and comparing interpolation
  methods](https://el-cordero.github.io/potentiomap/articles/validation-methods.md):

  Define prediction tasks, compare validation designs, and select
  methods without overstating map-wide accuracy.

- [Variograms, anisotropy, and external
  drift](https://el-cordero.github.io/potentiomap/articles/variograms-trends.md):

  Inspect spatial dependence, directional structure, trend assumptions,
  and covariate-supported kriging models.

- [Prediction support, surface uncertainty, and contour
  uncertainty](https://el-cordero.github.io/potentiomap/articles/uncertainty-support.md):

  Distinguish geometric support, model-conditional uncertainty, method
  spread, and pointwise contour bands.

- [Temporal head change and vertical hydraulic
  gradients](https://el-cordero.github.io/potentiomap/articles/temporal-vertical.md):

  Compare monitoring events and calculate explicitly signed vertical
  gradients from compatible paired intervals.

- [Monitoring-network sensitivity and candidate
  locations](https://el-cordero.github.io/potentiomap/articles/monitoring-network.md):

  Assess leave-one-well influence, thinning consequences, and
  constrained candidate-location rankings.

- [Surface profiles, depth to water, and
  cross-sections](https://el-cordero.github.io/potentiomap/articles/profiles-depth.md):

  Derive depth surfaces and extract transect profiles and plot-ready
  cross-sections from modeled heads.

- [Exporting GIS products and technical
  reports](https://el-cordero.github.io/potentiomap/articles/gis-reports.md):

  Export auditable rasters, vectors, open GIS styles, manifests, and
  concise technical reports.

### Expanded analysis articles

- [Observation QA, event selection, and screen
  grouping](https://el-cordero.github.io/potentiomap/articles/observation-qa-events-screens.md):

  Check records, select coherent monitoring events, and separate
  screened intervals before surface modeling.

- [Leave-one-out, spatial-block, and independent
  validation](https://el-cordero.github.io/potentiomap/articles/validation-designs.md):

  Match validation design to the intended prediction task and interpret
  the resulting errors within that scope.

- [Nested tuning without information
  leakage](https://el-cordero.github.io/potentiomap/articles/nested-tuning.md):

  Tune interpolation settings inside training folds so held-out
  predictions remain an honest comparison.

- [Comparing TPS, IDW, OK, and
  UK](https://el-cordero.github.io/potentiomap/articles/comparing-methods.md):

  Compare deterministic and geostatistical surfaces, diagnostics,
  assumptions, and validation results.

- [Ensembles versus method
  disagreement](https://el-cordero.github.io/potentiomap/articles/ensembles-disagreement.md):

  Separate an ensemble prediction from a descriptive map of spread among
  interpolation methods.

- [Conditional simulation and model-conditional
  uncertainty](https://el-cordero.github.io/potentiomap/articles/conditional-simulation.md):

  Summarize conditional simulations while keeping model assumptions and
  uncertainty scope visible.

- [Pointwise contour uncertainty versus approximate
  contours](https://el-cordero.github.io/potentiomap/articles/contour-uncertainty.md):

  Compare pointwise contour-position bands with support-classified
  approximate contour segments.

- [Comparing monitoring
  events](https://el-cordero.github.io/potentiomap/articles/monitoring-events.md):

  Select comparable monitoring rounds and map modeled head differences
  without interpreting them as storage change.

- [Vertical-gradient sign
  conventions](https://el-cordero.github.io/potentiomap/articles/vertical-gradient-sign.md):

  Calculate paired vertical gradients with an explicit numerator,
  denominator, and sign interpretation.

- [Well influence and network
  thinning](https://el-cordero.github.io/potentiomap/articles/well-influence-network-thinning.md):

  Quantify leave-one-well surface change and evaluate proposed
  monitoring-network reductions.

- [Candidate monitoring locations and design
  constraints](https://el-cordero.github.io/potentiomap/articles/candidate-locations.md):

  Rank feasible candidate wells using explicit objectives, exclusions,
  costs, and user priorities.

- [Grid, boundary, and parameter
  sensitivity](https://el-cordero.github.io/potentiomap/articles/surface-sensitivity.md):

  Compare surfaces across grid resolution, domain, and interpolation
  settings without treating spread as uncertainty.

- [Directional variograms and
  anisotropy](https://el-cordero.github.io/potentiomap/articles/directional-variograms.md):

  Inspect directional semivariance and evaluate whether anisotropy is
  supported by the observation network.

- [Universal kriging with hydrogeologic
  covariates](https://el-cordero.github.io/potentiomap/articles/external-drift.md):

  Use aligned covariates as an explicit external drift and review the
  resulting trend assumptions.

- [Interpolation within user-defined hydrogeologic
  regions](https://el-cordero.github.io/potentiomap/articles/regional-interpolation.md):

  Fit separate surfaces inside defensible hydrogeologic regions and
  retain region-level diagnostics.

- [Depth to water and depth to a potentiometric
  surface](https://el-cordero.github.io/potentiomap/articles/depth-surfaces.md):

  Subtract modeled head from a compatible land-surface raster and review
  datum and unit requirements.

- [Profiles and
  cross-sections](https://el-cordero.github.io/potentiomap/articles/profiles-cross-sections.md):

  Sample a modeled surface along a transect and assemble plot-ready
  hydrogeologic section data.

- [QGIS and SLD style
  exports](https://el-cordero.github.io/potentiomap/articles/gis-styles.md):

  Create portable open GIS style files for exported potentiometric
  rasters and contour products.

- [Building a technical analysis
  report](https://el-cordero.github.io/potentiomap/articles/technical-reports.md):

  Record methods, conditions, QA, support, and exported artifacts in a
  reproducible technical report.

- [Complete synthetic aquifer
  example](https://el-cordero.github.io/potentiomap/articles/complete-synthetic-aquifer.md):

  A complete fixed-seed 0.2.0 workflow from observation QA through
  validation, uncertainty, network review, profiles, and export.

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
