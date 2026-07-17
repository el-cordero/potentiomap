# Changelog

## potentiomap 0.2.0

### Observation preparation and quality checks

- Added
  [`ps_check_observations()`](https://el-cordero.github.io/potentiomap/reference/ps_check_observations.md),
  [`ps_select_event()`](https://el-cordero.github.io/potentiomap/reference/ps_select_event.md),
  and
  [`ps_screen_groups()`](https://el-cordero.github.io/potentiomap/reference/ps_screen_groups.md)
  with record-level issue, exclusion, ambiguity, and grouping manifests.

### Validation and tuning

- Added deterministic leave-one-out, random-fold, spatial-block,
  leave-cluster-out, user-fold, and independent validation through
  [`ps_validate()`](https://el-cordero.github.io/potentiomap/reference/ps_validate.md).
- Added design-specific method comparison, diagnostic plotting,
  exhaustive or reproducibly sampled candidate tuning, and optional
  nested validation.

### Variograms, anisotropy, and trends

- Added empirical and directional variograms, independent
  candidate-model fitting, exploratory anisotropy, explicit variogram
  models, neighborhoods, anisotropy, trends, and raster or table
  covariates for kriging.

### Support and uncertainty

- Added compatible-surface ensembles and method-disagreement products.
- Added retained kriging variance, conditional Gaussian simulation,
  supported TPS standard error, resampling sensitivity, and pointwise
  contour bands with explicit terminology and assumptions.
- Prediction-support products retain training-hull,
  observation-distance, mask, and finite-prediction information, and
  modeled contours can be split by user-defined support criteria without
  calling those classes confidence.

### Surface and event comparisons

- Added aligned surface comparisons, paired-event head change, and
  numeric or raster vertical hydraulic gradients with explicit sign
  conventions.
- Structured interpolation and contour results inventory diagnostics,
  conditions, requested methods or levels, and nonfinite outputs.

### Monitoring-network analysis

- Added conditional leave-one-well influence, reproducible network
  thinning, constrained sequential candidate ranking, and explicit
  parameter/grid sensitivity scenarios.

### Profiles, cross-sections, and depth products

- Added water-table or potentiometric depth surfaces, sampled surface
  profiles, and plot-ready cross-sections with well offsets and screen
  elevations.

### GIS and reporting

- Added validated open QML/SLD style export and offline HTML/DOCX
  technical reports from a package-owned template.
- Hydraulic-gradient arrows retain endpoint support checks and the
  explicit `endpoint_action = "none"` legacy geometry option.

### Documentation

- Added small deterministic fixtures, expanded function examples,
  integrated vignettes, website articles, scientific due diligence, and
  release audits.
- Rebuilt the hydrogeologist-facing README, package help, reference
  index, and Bootstrap 5 website configuration, with guidance for
  on-disk rasters and larger prediction grids.

### Compatibility

- Existing public functions remain exported, and
  [`ps_interpolate()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate.md)
  continues to return a named list of `SpatRaster` objects by default.
- Structured interpolation results now also retain exact template and
  method-fit objects needed by validation and model-conditional
  uncertainty.
- [`ps_contours()`](https://el-cordero.github.io/potentiomap/reference/ps_contours.md)
  still returns a `SpatVector` by default; structured interpolation and
  contour results remain opt-in.
- Existing public names and valid positional calls remain available,
  requested interpolation methods are not silently replaced, and
  universal kriging keeps the documented
  `uk_coordinate_scaling = "none"` compatibility option.
