# API design for potentiomap 0.2.0 expansion

Design completed before implementation on 2026-07-17. Existing exported
arguments are not reordered. The current default returns of `ps_interpolate()`,
`ps_contours()`, and `ps_flow_arrows()` remain unchanged.

## Shared contracts

Substantive results are ordinary S3 lists. Every result contains `summary`,
`settings`, `metadata`, `conditions`, `warnings`, `errors`, `package_version`,
`schema_version = "0.2.0-1"`, and `call` where applicable, plus the products
listed below. Repeated analyses add `run_id`, `fold_id` or `replicate_id`,
`method`, `status`, warning/error counts, seed, input/retained/prediction counts,
and stable record IDs. `print()` is concise; `as.data.frame()` returns the one
natural record table; `summary()` is added when it is more useful than the
stored summary table.

All errors inherit from `potentiomap_error`; warnings inherit from
`potentiomap_warning`. New stable feature classes are the classes named in the
release specification, with `potentiomap_input_error`,
`potentiomap_metadata_error`, and `potentiomap_crs_error` retained for shared
input failures. Upstream text is preserved in condition records with function,
method, group, fold, run, candidate, and region fields when known.

Unless a geodesic option is explicit, spatial inputs require a known projected
CRS. Raster cellwise operations require identical geometry by default. Units
and vertical references come from `potentiomap_metadata` attributes or explicit
event metadata; no vertical datum is inferred from a CRS. Deterministic IDs use
canonicalized values and stable internal hashing. Estimated complexities below
use `n` observations, `p` prediction cells, `m` methods, `f` folds, `c`
candidates, `r` realizations/runs, and `q` candidates/sites.

Compact examples on every help page use the package's small synthetic data and
small rasters. File examples use `tempdir()`. Every example states the relevant
scientific limitation.

## Validation

```r
ps_validate(
  points,
  methods = c("TPS", "IDW", "OK", "UK"),
  design = c("loocv", "kfold", "spatial_block", "leave_cluster_out",
             "user_folds", "independent"),
  validation_points = NULL, fold_id = NULL, cluster = NULL, folds = 5,
  repeats = 1, block_size = NULL, template = NULL, mask = NULL,
  grid_res = NULL, domain_policy = c("fixed", "training"),
  prediction_mode = c("raster", "direct"),
  metrics = c("me", "mae", "rmse", "medae", "maxae"),
  support = TRUE, sampling_weight = NULL,
  interpolation_control = list(), seed = 1, progress = NULL
)
```

Inputs are standardized point objects or point data accepted by
`ps_interpolate`; independent validation is a compatible point object.
`fold_id`/`cluster` are vectors or columns. Output class:
`potentiomap_validation`; fields: `predictions`, `metrics`, `fold_manifest`,
`partition_manifest`, `fit_manifest`, `support_summary`, and shared fields.
Residuals and head metrics use head units; distance support uses CRS units.
Partitions and derived seeds are deterministic. Complexity is approximately
`f * m` fits plus prediction. Expected failures include invalid/duplicate IDs,
fold leakage, insufficient training size, unavailable direct prediction,
geographic planar distance, invalid weights, and missing grid geometry.

```r
ps_compare_methods(
  validation, metric = "rmse", design = NULL,
  support_subset = c("all", "finite", "supported"),
  minimum_coverage = 0.9, tie_tolerance = NULL,
  objective_weights = NULL, select = FALSE
)
ps_validation_plot(
  x,
  type = c("metric", "observed_predicted", "residual_map",
           "residual_distribution", "fold_map", "support", "coverage",
           "method_conditions"),
  methods = NULL, design = NULL, support_subset = "all",
  display_limits = NULL, legend = TRUE, ...
)
```

Comparison accepts `potentiomap_validation` (a compatible table must contain
the documented prediction columns). Output `potentiomap_method_comparison`
contains `ranking`, `pareto`, `selection`, and shared fields. The plot function
accepts validation/comparison, draws with base graphics, and invisibly returns a
plot-data list. Complexity is linear in prediction records for comparison and
plot preparation. Failures include implicit pooling of designs, inadequate
coverage, missing single selection objective, empty subsets, and invalid limits.

## Tuning

```r
ps_tune_interpolation(
  points, method, candidates, inner_design = "spatial_block",
  outer_design = NULL, inner_folds = 5, outer_folds = 5, repeats = 1,
  metric = "rmse", minimum_coverage = 0.9, template = NULL, mask = NULL,
  grid_res = NULL, refit = TRUE, seed = 1, progress = NULL,
  search = c("grid", "random"), maximum_runs = 1000
)
```

`candidates` is a data frame/list convertible to one row per explicit
configuration; supported names are those listed in the release specification.
The two final arguments are justified additions: the required reproducible
random selection and maximum-runs guard otherwise have no public control.
Output `potentiomap_tuning`: `candidates`, `fold_results`, `outer_results`,
`selection`, `final_result`, and shared fields. Deterministic for fixed inputs
and seed. Complexity is `c * inner_folds`, nested inside outer folds when used.
Failures include unknown candidate fields, excessive runs, no candidate meeting
coverage, leakage-prone fold definitions, and unavailable refit.

## Ensembles and disagreement

```r
ps_surface_ensemble(
  surfaces,
  statistic = c("mean", "median", "weighted_mean", "quantile"),
  weights = NULL, probabilities = c(0.1, 0.5, 0.9),
  support = c("intersection", "union"), minimum_methods = NULL,
  method_metadata = NULL
)
ps_method_disagreement(
  surfaces,
  head_measures = c("range", "sd", "mad", "mean_pairwise_absolute"),
  gradient = TRUE, min_gradient = 1e-5,
  support = c("intersection", "union"), minimum_methods = 2
)
```

`surfaces` is a named list or `potentiomap_result`; metadata must identify
compatible head surfaces. Classes are `potentiomap_ensemble` with `ensemble`,
`count`, `minimum`, `maximum`, `standard_deviation`, `mad`, `method_manifest`,
`support_manifest`; and `potentiomap_disagreement` with `rasters`,
`pairwise_summary`, `direction_summary`, `flat_mask`, `method_pair_manifest`.
Head outputs use head units; SD/MAD/range are method spread. Angles are degrees
on [0,180]. Complexity is `O(mp)` plus `O(m^2 p)` for pairwise disagreement.
Failures include unnamed surfaces/weights, incompatible geometry/CRS/unit/datum,
invalid convex weights, inadequate finite methods, and invalid probabilities.

## Surface and contour uncertainty

```r
ps_surface_uncertainty(
  x = NULL, points = NULL, method = NULL,
  approach = c("kriging_variance", "conditional_simulation",
               "tps_standard_error", "resampling_sensitivity"),
  nsim = 100, probabilities = c(0.05, 0.5, 0.95),
  resampling_design = NULL, template = NULL, mask = NULL,
  keep_realizations = FALSE, output_directory = NULL, seed = 1,
  progress = NULL, exceedance_levels = NULL
)
```

The final optional `exceedance_levels` argument implements the required
user-supplied exceedance products. Inputs are a structured fitted result or
points plus method/configuration. Output `potentiomap_uncertainty`: `central`,
`standard_deviation`, `variance`, `standard_error`, `quantiles`, `lower`,
`upper`, `exceedance`, `finite_count`, `support_count`, `realizations`,
`method_manifest`, `realization_manifest`, `output_manifest`, and shared fields.
Variance uses squared head units; other surfaces use head units; probabilities
are dimensionless. Simulation/resampling is deterministic for a fixed seed.
Complexity is `O(rp)` storage/streaming plus fits. Failures include absent fitted
model, unsupported method/approach, invalid counts/probabilities, nonwritable
directory, partial output cleanup, or requested simulation without a valid
stochastic model.

```r
ps_contour_uncertainty(
  uncertainty, levels, probability = 0.9,
  method = c("empirical_crossing", "gaussian_pointwise"),
  keep_realized_contours = FALSE, minimum_realizations = 20,
  accept_gaussian = FALSE
)
```

`accept_gaussian` is an explicit gate required by the specification. Output
`potentiomap_contour_uncertainty`: `central_contours`,
`exceedance_probability`, `crossing_frequency`, `bands`,
`realized_contours`, `level_manifest`, and shared fields. Band area uses squared
CRS units. Complexity is `O(rp + r * levels)`; failure modes include invalid
levels/probability, insufficient realizations, absent SE/realizations, geographic
area without explicit support, and unaccepted Gaussian assumptions.

## Surface/event comparison and vertical gradients

```r
ps_compare_surfaces(
  surface_a, surface_b, direction = c("b_minus_a", "a_minus_b"),
  align = c("error", "to_a", "to_b", "template"), template = NULL,
  resampling = c("bilinear", "near"), contour_levels = NULL,
  compare_gradient = TRUE, min_gradient = 1e-5
)
```

Inputs are one-layer continuous head rasters with metadata. Output
`potentiomap_surface_comparison`: `signed_difference`, `absolute_difference`,
`common_support`, `only_a`, `only_b`, `gradient_magnitude_difference`,
`gradient_direction_difference`, `contour_displacement`, `support_summary`,
`alignment_manifest`, and shared fields. Head differences use head units;
direction uses degrees and area uses squared CRS units. Complexity `O(p)` plus
contours. Failures: unit/datum/type mismatch, implicit alignment, invalid
template/resampling, or geographic gradients.

```r
ps_head_change(
  event_a, event_b, pair_by, event_a_time = NULL, event_b_time = NULL,
  method = "TPS", template = NULL, mask = NULL, grid_res = NULL,
  interpolation_control = list(), compare_gradient = TRUE
)
ps_vertical_gradient(
  upper_head, lower_head, upper_elevation, lower_elevation,
  positive = c("upward", "downward"), tolerance = 0,
  align = c("error", "to_upper", "to_lower", "template"),
  template = NULL, event_metadata = NULL
)
```

Head-change inputs are compatible point events; output
`potentiomap_head_change`: `membership`, `paired_changes`, `surface_a`,
`surface_b`, `surface_comparison`, and shared fields. Vertical-gradient inputs
are four matching rasters or compatible numeric paired records; output
`potentiomap_vertical_gradient`: `upper_head`, `lower_head`, `head_difference`,
`vertical_separation`, `dh_dz`, `gradient`, `direction_class`, `overlap`,
`finite_support`, `sign_convention`, and shared fields. Gradients are
dimensionless when numerator/denominator length units match. Complexity is two
fits plus `O(p)` and `O(p)`, respectively. Failures cover duplicate pair IDs,
event/metadata incompatibility, zero/reversed separation, overlapping screens,
unidentified depth references, or implicit alignment.

## Monitoring networks and sensitivity

```r
ps_well_influence(
  points, method = "TPS", template = NULL, mask = NULL, grid_res = NULL,
  contour_levels = NULL, difference_threshold = NULL,
  interpolation_control = list(), progress = NULL
)
ps_network_thinning(
  points, retain = c(0.75, 0.5, 0.25),
  design = c("random", "spatial_coverage", "user"), method = "TPS",
  repeats = 10, subsets = NULL, template = NULL, mask = NULL,
  grid_res = NULL, seed = 1, progress = NULL
)
ps_candidate_network(
  existing_points, candidates,
  objective = c("spatial_coverage", "support_gap",
                "kriging_variance_reduction", "user_score"),
  n_select = 1, target = NULL, variogram_model = NULL, trend = NULL,
  minimum_existing_distance = 0, minimum_candidate_distance = 0,
  allowed_area = NULL, exclusion_area = NULL, cost = NULL,
  user_score = NULL, sequential = TRUE
)
ps_surface_sensitivity(
  points, method, scenarios, reference = NULL, template = NULL, mask = NULL,
  maximum_runs = 100, contour_levels = NULL, compare_gradient = TRUE,
  seed = 1, progress = NULL
)
```

Network inputs are standardized points with stable IDs; candidates are explicit
point locations. Classes/primary fields: `potentiomap_well_influence`
(`reference`, `wells`, `run_manifest`); `potentiomap_network_thinning`
(`run_manifest`, `retained_manifest`, `heldout_predictions`,
`validation_metrics`, `surface_metrics`, `subset_summary`, `support_summary`);
`potentiomap_candidate_network` (`candidate_scores`, `selected_sequence`,
`constraint_failures`, `before_after`, `target_summary`);
`potentiomap_sensitivity` (`scenarios`, `results`, `comparisons`,
`run_manifest`). Distances/areas and head differences retain explicit units.
Fixed seeds/subset hashes/scenario IDs are deterministic. Complexity is `n`
leave-one-out fits, requested thinning fits, up to `q * n_select` scoring plus
kriging solves, and one fit per scenario. Failures include too few points,
duplicate/missing IDs, invalid retain counts/subsets, no feasible candidate,
missing model/target, invalid costs/spacing, or excessive scenarios.

## Variograms, anisotropy, and extended interpolation

```r
ps_variogram(
  points, formula = Z ~ 1, cutoff = NULL, width = NULL,
  boundaries = NULL, directions = 0, direction_tolerance = NULL,
  robust = FALSE, cloud = FALSE
)
ps_variogram_compare(
  variogram, models = c("Sph", "Exp", "Gau", "Mat"), initial = NULL,
  fit_method = 7, anisotropy = NULL, validation = NULL, select = FALSE,
  selection_metric = c("validation_rmse", "weighted_sse")
)
ps_anisotropy(
  points, formula = Z ~ 1, directions = seq(0, 135, by = 45),
  tolerance = 22.5, cutoff = NULL, width = NULL, model = "Sph",
  minimum_pairs = 20, validation = FALSE
)
```

Classes/fields: `potentiomap_variogram` (`empirical`, `formula`, `directions`,
`point_summary`); `potentiomap_variogram_comparison` (`fits`, `ranking`,
`selection`); `potentiomap_anisotropy` (`empirical`, `directional_fits`,
`major_direction`, `range_ratio`, `validation`). Distance units are CRS units;
semivariance uses squared head units; direction is degrees clockwise from North.
Complexity is `O(n^2)` pairs plus candidate fits. Failures include invalid
formula/cutoff/width/boundaries/directions, insufficient pairs, negative model
parameters, singular/nonconvergent fits (retained), or selection without a
criterion.

The existing `ps_interpolate()` signature is extended only at the end:

```r
ps_interpolate(...existing arguments...,
  trend = NULL, covariates = NULL,
  covariate_alignment = c("error", "bilinear", "near"),
  standardize_covariates = TRUE, variogram_model = NULL,
  anisotropy = NULL, kriging_control = list()
)
```

`trend` is a formula; named covariates are compatible rasters or columns.
Explicit model/anisotropy objects are validated and not refitted/replaced.
Structured result fields gain retained fit objects and a covariate manifest with
units, source geometry, centers/scales, missing counts, formula, rank, and
condition number. Existing UK behavior remains when `trend=NULL`. Failures
include missing prediction-domain coverage, constant/duplicate/collinear
covariates, rank deficiency, invalid model/anisotropy/neighborhood, or implicit
geometry alignment. Complexity adds extraction and a trend matrix solve.

## Regions

```r
ps_split_domain(
  domain, regions, region_id, points = NULL,
  overlap_action = c("error", "priority"),
  gap_action = c("report", "error"),
  boundary_action = c("error", "assign_by_priority", "duplicate")
)
ps_interpolate_regions(
  points, regions, region_id, methods = "TPS", template = NULL,
  grid_res = NULL, interpolation_control = list(), mosaic = TRUE,
  overlap_priority = NULL, progress = NULL
)
```

Inputs are polygon domains/regions with unique IDs and optional points. Classes:
`potentiomap_domain_split` (`regions`, `point_assignments`, `overlap_polygons`,
`gap_polygons`, `ambiguous_points`); `potentiomap_regional_result`
(`region_results`, `mosaic`, `region_manifest`, `method_manifest`). CRS and
metadata are preserved; no vertical operation occurs. Complexity is geometry
overlay plus one fit per region/method. Failures include invalid/empty geometry,
duplicate IDs, unapproved overlaps/gaps/boundaries, missing priority, insufficient
regional observations, and incompatible template.

## Depth, profiles, and cross-sections

```r
ps_depth_to_water_surface(
  head_surface, land_surface,
  surface_type = c("water_table", "potentiometric"),
  align = c("error", "to_head", "to_land", "template"),
  template = NULL, resampling = "bilinear", tolerance = 0
)
ps_surface_profile(
  lines, surfaces, step = NULL, n = NULL, support = NULL,
  distance_method = c("projected", "geodesic")
)
ps_cross_section(
  transect, head_surface, land_surface = NULL, wells = NULL,
  screen_top = NULL, screen_bottom = NULL, well_id = NULL,
  maximum_well_offset = NULL, support = NULL, uncertainty = NULL,
  step = NULL, vertical_exaggeration = 1
)
```

Classes/fields: `potentiomap_depth_surface` (`depth`, `negative_mask`,
`near_zero_mask`, `common_support`, `only_head`, `only_land`,
`alignment_manifest`); `potentiomap_profile` (`records`, `line_summary`);
`potentiomap_cross_section` (`head_profile`, `land_profile`, `depth_profile`,
`wells`, `omitted_wells`, `plot_data`). `as.data.frame(profile)` returns
records; cross-section has print/plot and a plot-data accessor through its
fields. Depth/head/elevation use compatible length units; chainage/offset use
CRS or geodesic length units. Complexity is `O(p)` raster algebra and line
sampling/nearest projection. Failures include vertical mismatch, implicit
alignment, both/neither step and n, longitude/latitude with projected distance,
invalid screens, or invalid vertical exaggeration.

## GIS style and reports

```r
ps_export_style(
  x, file, format = c("qml", "sld"),
  layer_type = c("head_raster", "depth_raster", "contours",
                 "contour_support", "arrows", "wells", "support"),
  field = NULL, units = NULL, palette = NULL, breaks = NULL,
  overwrite = FALSE
)
ps_report(
  x, output_file, format = c("html", "docx"), title = NULL,
  sections = "auto", include_session = TRUE, include_conditions = TRUE,
  overwrite = FALSE
)
```

Style output is a `potentiomap_style_manifest` data frame/list with path,
format, layer, field, units, breaks, XML validity, and version. Report output is
a `potentiomap_report_manifest` containing path, format, sections, dependencies,
and render status. Deterministic apart from session information. Complexity is
linear in style classes or report records. Failures include unsupported object,
missing field/dependency/Pandoc, unsafe/occupied output, malformed XML, invalid
breaks/palette, or render failure; partial outputs are removed.

## Observation QA, event selection, and screens

```r
ps_check_observations(
  data, x = NULL, y = NULL, value = NULL, id = NULL, datetime = NULL,
  unit = NULL, vertical_datum = NULL, depth = NULL,
  surface_elevation = NULL, screen_top = NULL, screen_bottom = NULL,
  unit_group = NULL, duplicate_tolerance = 0,
  action = c("report", "return_clean")
)
ps_select_event(
  data, id, datetime, center, window,
  rule = c("nearest", "earliest", "latest", "best_quality"),
  quality = NULL, timezone = "UTC", maximum_span = NULL,
  maximum_span_action = c("warn", "error")
)
ps_screen_groups(
  data, mode = c("existing", "rules", "depth_bins"), unit_col = NULL,
  screen_top, screen_bottom, rules = NULL, breaks = NULL, labels = NULL,
  overlap_required = 0.5, ambiguous_action = c("report", "error")
)
```

The final event-selection argument is required to implement the specified
explicit maximum-span policy. Classes/fields: `potentiomap_observation_check`
(`issues`, `data`, `retained`, `removed`, `summary`);
`potentiomap_event_selection` (`selected`, `excluded`, `ties`, `summary`);
`potentiomap_screen_groups` (`assigned`, `overlap`, `ambiguous`,
`unclassified`, `rules`, `summary`). Datetimes retain timezone; depths/elevations
retain input units and references. Operations are deterministic. Complexity is
linear except coordinate duplicate comparisons, which may be quadratic for a
positive tolerance. Failures include absent columns/classes, invalid tolerance,
unparseable dates/window, missing quality field, duplicate unresolved ties,
reversed/zero screens, invalid rules/breaks, or ambiguity under `"error"`.

## Compatibility conclusion

All new functions are additive. The only changed public signature is
`ps_interpolate()`, whose new arguments are appended. No existing argument is
reordered; valid positional calls retain meaning. Structured interpolation
results gain fields but retain all old fields. Ordinary raster lists, contour
vectors, arrow components, and `endpoint_action="none"` behavior remain
available. Requested methods and explicit variogram/trend configurations are
never silently replaced.
