# Methods due diligence for potentiomap 0.2.0 expansion

Research was checked on 2026-07-17. Citations and the design decision each
source supports are inventoried in `REFERENCE_AUDIT.csv`. This document records
the decisions made before implementation; it paraphrases the sources and does
not reproduce their text.

## Governing scientific position

potentiomap maps and compares observed hydraulic head. It does not solve the
groundwater-flow equation, estimate a water budget, track particles, calculate
travel time, or simulate contaminant transport. The package treats head as an
elevation relative to an explicitly recorded vertical reference. Horizontal
hydraulic-gradient symbols are based on

\[
  \nabla h=(\partial h/\partial x,\partial h/\partial y),\qquad
  \theta=\operatorname{atan2}(-\partial h/\partial x,-\partial h/\partial y),
\]

and therefore point down the modeled head surface. They are not paths,
velocities, Darcy fluxes, or particle tracks. Vertical gradients use explicit
upper and lower observation elevations. No vertical flux is calculated.

An empirical prediction score is conditional on its resampling design. It is
not automatically an unbiased estimate of map error over an area. Model spread
is method disagreement, distance and hull membership are prediction-support
descriptors, kriging variance is conditional on a trend/covariance model, and
simulation summaries are conditional on the stated stochastic model. A
pointwise contour band is not a simultaneous contour-confidence region.

## Common spatial, unit, and computational decisions

- Distance, area, direction, and gradient operations require a known projected
  CRS unless a function explicitly offers a geodesic option. Longitude and
  latitude degrees are never used silently as planar distance.
- Raster geometry is compared before cellwise operations. Mismatch defaults to
  an error. Resampling/reprojection is performed only through an explicit
  `align` or covariate-alignment choice and the source/target geometry is
  recorded. Bilinear interpolation is restricted to continuous surfaces and
  nearest-neighbor interpolation to masks/classes.
- Head, elevation, and depth values must have compatible length units and named
  vertical references. A horizontal CRS never supplies a vertical datum.
  Original and converted units are retained in metadata.
- Finite-support differences are reported. Nonfinite values are never changed
  to zero. Negative depth-to-surface values are preserved for review.
- Result objects are concise S3 lists with stable tables, settings, metadata,
  conditions, package/schema versions, seeds where applicable, and the call.
  Failed planned analyses remain in manifests.
- Repeated analyses use deterministic derived seeds. Progress callbacks receive
  index, total, stable run ID, and status. Execution defaults to one core.
- Expected dominant costs are interpolation fits plus raster prediction.
  Dense TPS and kriging fits are approximately cubic in observation count in
  their unoptimized dense algebra, IDW prediction is approximately observation
  count times prediction count, raster summaries are linear in cells and
  methods/realizations, and pairwise variograms are quadratic in observations.

## A. Validation and method comparison

### `ps_validate()`

- **Question:** How well does a requested interpolation method predict records
  withheld according to a stated prediction task?
- **Equations:** residual is `predicted - observed`; ME is the mean residual;
  MAE is mean absolute residual; RMSE is the square root of mean squared
  residual; MedAE and MaxAE retain their usual definitions. Optional
  standardized kriging residuals divide by model-conditional prediction SE.
- **Assumptions and inputs:** point IDs and heads are distinct; partitions use
  coordinates, user assignments, or independent data but never held-out heads;
  every fold has training and validation records and method-specific minimum
  training size. Sampling weights are accepted only for an explicitly
  independent probability sample.
- **Selected implementation:** deterministic LOOCV, k-fold, spatial blocks,
  leave-cluster-out, user folds, and independent validation; fixed and hashed
  partitions; direct point prediction or the full raster/extraction sequence;
  explicit training/validation IDs; finite and support subsets; failed fits and
  nonfinite predictions retained.
- **Alternatives considered:** treating random CV as generic accuracy, dropping
  failures, or silently switching prediction modes were rejected because they
  change the estimand or conceal failure.
- **Allowed claim:** performance for the stated partition and prediction task.
  **Forbidden claim:** universal method quality, design-unbiased map accuracy,
  or independence created merely by LOOCV.
- **References/tests:** Roberts et al. (2017), Wadoux et al. (2021), gstat
  documentation. Tests exclude every holdout from training, reproduce seeds and
  hashes, hand-check metrics, preserve failures, and label independent results.

### `ps_compare_methods()` and `ps_validation_plot()`

- **Question:** How do adequately covered methods compare under one explicitly
  chosen validation design and support subset, and how can the result be
  inspected without hiding failures or extremes?
- **Selected implementation:** rank within design/group/subset; enforce minimum
  finite coverage; report conditions and effective partitions; use an explicit
  numeric tie tolerance; require explicit objective weights for an aggregate;
  otherwise report criterion-specific/Pareto status. Base-R plots return their
  plot data invisibly and encode support with symbol as well as color.
- **Limitations/nonclaims:** ranking is objective-specific, not a universal best
  method. Display limits are optional and clipping is disclosed.
- **Tests:** coverage exclusions, ties, multi-design rejection, selection gate,
  empty/failed subsets, and retained extreme plot data.

## B. Parameter tuning

### `ps_tune_interpolation()`

- **Question:** Which supplied configuration performs best for the stated inner
  resampling objective, and how does that choice transfer to outer holdouts?
- **Selected implementation:** a supplied candidate table or reproducible sample
  from it; fixed inner partitions per comparison; optional nested outer design;
  no outer record enters tuning; failed candidates remain unscored but visible;
  selection is restricted to minimum coverage; a maximum-runs guard precedes
  execution; optional all-data refit uses the exact selected row.
- **Alternatives:** opaque Bayesian optimization and assigning arbitrary large
  scores to failures were rejected. Without an outer design the result is
  described as tuning performance, not final unbiased performance.
- **References/tests:** Schratz et al. (2019), Roberts et al. (2017). Tests check
  inner/outer separation, candidate membership, failure retention, order/seed
  determinism, and exact refit controls.

## C. Ensembles and disagreement

### `ps_surface_ensemble()`

- **Question:** What cellwise summary follows from compatible component head
  surfaces?
- **Equation:** equal or convex weighted mean is
  \(\bar h(s)=\sum_m w_m h_m(s)/\sum_m w_m\); median and quantiles are
  corresponding cellwise order statistics.
- **Selected implementation:** exact geometry/unit/datum/surface-type checks;
  intersection or explicit union support; named finite nonnegative weights with
  recorded origin; ensemble, count, min, max, SD, and MAD products.
- **Nonclaim/tests:** an ensemble is not automatically more accurate. Convex
  means are tested to remain within component extrema; identical/equal-weight
  identities, invalid weights, and metadata mismatch are tested.

### `ps_method_disagreement()`

- **Question:** Where and how strongly do modeled heads and down-gradient
  directions differ across methods?
- **Equations:** head range, SD, MAD, and mean absolute pairwise difference;
  direction difference is `min(abs(a-b), 360-abs(a-b))` on directed bearings,
  bounded by 180 degrees. Groundwater direction is not treated as an axial
  orientation.
- **Selected implementation:** head rasters, pair table, gradient-direction
  differences, median/max directional disagreement, and flat-gradient mask.
- **Nonclaim/tests:** this is method disagreement, not statistical uncertainty;
  identical, constant-offset, bounded-angle, and flat-surface cases are tested.

## D. Surface and contour uncertainty

### `ps_surface_uncertainty()`

- **Question:** What model-conditional or resampling-based variability is
  available for a fitted surface?
- **Selected approaches:** (1) retained OK/UK variogram and trend yield kriging
  variance and SE; (2) gstat `nsim` yields conditional Gaussian realizations
  with recorded seed/model/path behavior; (3) fields `predictSE` is used only
  with a retained compatible TPS fit; (4) documented case, jackknife, or spatial
  group refits yield *resampling sensitivity*.
- **Units:** variance is squared head units; SE, SD, and quantile bounds are head
  units; exceedance products are probabilities. Realization and support counts
  are dimensionless.
- **Assumptions/limitations:** kriging and simulations condition on trend,
  covariance, geometry, neighborhood, and nugget/error treatment; TPS SE depends
  on the fitted smoothing model; resampling intervals are not formal confidence
  intervals. Failed realizations are retained. Streaming cell summaries are
  preferred when realizations are not retained.
- **References/tests:** Pebesma (2004), gstat `krige`/`predict`, fields/Wahba.
  Tests check nonnegative variance/SE, ordered quantiles, bounded probabilities,
  deterministic seeds, zero-variability collapse, counts, labels, and cleanup.

### `ps_contour_uncertainty()`

- **Question:** At each requested head level, where do realizations or a
  pointwise Gaussian calculation place possible level crossings?
- **Selected implementation:** central contour, exceedance probability,
  empirical crossing frequency when realizations exist, pointwise crossing
  band, area, counts, and level manifest. A Gaussian-only calculation requires
  explicit acceptance and uses marginal mean/SE without claiming joint spatial
  coverage.
- **Alternatives:** implementing a nominal simultaneous region without the joint
  procedure of French or Bolin/Lindgren was rejected.
- **Nonclaim/tests:** output is a pointwise contour-uncertainty band, never a
  simultaneous confidence region. Deterministic width, increasing-uncertainty
  behavior, out-of-range levels, and probability bounds are tested.

## E. Surface comparison, events, and vertical gradients

### `ps_compare_surfaces()`

- **Question/equations:** signed difference is `b-a` by default; absolute
  difference, mean difference, mean absolute difference, and RMSE are evaluated
  only on common finite support. Gradient magnitude and directed bearing
  differences are optional; contour displacement is level-specific.
- **Selected implementation:** alignment defaults to error; explicit alignment
  records geometries/method; common, only-A, and only-B masks and areas are
  returned. No percentage head statistic is calculated.
- **Tests:** identity, antisymmetry, common-support symmetry, reversed one-sided
  masks, units/datum, and explicit alignment.

### `ps_head_change()`

- **Question:** What measured paired-well change and separately modeled surface
  change occurred from event A to B?
- **Equation:** `event B - event A` for both paired heads and common-support
  surfaces.
- **Assumptions:** event timing, units, datum, measuring reference, aquifer/unit,
  and screen-selection rules are compatible; pair IDs are unique or inventoried.
- **Selected implementation:** membership audit, exact paired changes, two
  separately fitted surfaces, common-support comparison, gradient change, and
  visible limitations.
- **Nonclaim/tests:** neither product is a storage, depletion, recharge, budget,
  or volumetric estimate. Pair accounting, exact changes, sign, and absence of
  volume fields are tested. USGS SIM 3509 and Circular 1217 guide terminology.

### `ps_vertical_gradient()`

- **Question/equations:** with upper elevation above lower elevation,
  \(dz=z_u-z_l>0\), \(dh/dz=(h_u-h_l)/dz\), and upward-driving gradient is
  \((h_l-h_u)/dz\). The requested sign convention selects that value or its
  negative.
- **Inputs/assumptions:** paired absolute elevations or exactly aligned rasters,
  common head units/datum/event, nonoverlapping representative intervals, and
  an explicit screen-midpoint assumption when used.
- **Selected implementation:** retain inputs, head difference, separation,
  `dh_dz`, signed gradient, upward/downward/near-zero/indeterminate class,
  support masks, and sign metadata.
- **Nonclaim/tests:** it indicates potential direction, not vertical flux.
  Known upward/downward/zero cases, reversed/zero separation, interval ambiguity,
  and absence of a flux field are tested.

## F. Monitoring-network analysis

### `ps_well_influence()`

- **Question:** Conditional on fixed method and grid, how much does deleting one
  well change the fit?
- **Selected implementation:** full reference fit; exactly one deletion per ID;
  held-out prediction/residual plus common-support surface, contour, gradient,
  and finite-support changes; failures retained.
- **Nonclaim/tests:** influence can arise from geometry, local gradient, unique
  information, or an anomalous value and does not classify a well as erroneous.
  Tests check one run per well, deletion, failure retention, and common support.

### `ps_network_thinning()`

- **Question:** How do reproducible smaller networks predict held-out wells and
  differ descriptively from the full-network surface?
- **Selected implementation:** exact counts; random, maximin/farthest-point, or
  user subsets; stable subset hashes; planned and unique counts; validation and
  descriptive surface metrics kept separate.
- **Nonclaim/tests:** full-surface difference is not truth error. Tests cover
  counts, disjoint retained/held-out sets, duplicate hashes, deterministic
  coverage selection, and failure retention.

### `ps_candidate_network()`

- **Question:** Which *supplied feasible candidates* most improve a stated
  coverage, support-gap, model-conditional kriging-variance, or user-score
  objective under spacing/area/cost constraints?
- **Selected implementation:** sequential greedy scoring with updates;
  constraint failures retained; gains, costs, and gain/cost kept separate;
  kriging objective requires a valid model/trend and target geometry.
- **Nonclaim/tests:** rankings are not guaranteed globally optimal or drillable.
  Tests enforce exclusions/spacing, sequential updates, nonnegative model-
  conditional variance reductions within tolerance, and exact cost arithmetic.

## G. Grid, boundary, and parameter sensitivity

### `ps_surface_sensitivity()`

- **Question:** How much do explicit modeling/grid scenarios change a surface
  relative to an identified reference?
- **Selected implementation:** stable scenario IDs; explicit data frame/grid;
  maximum-runs guard; fixed seeds; failed rows retained; common-support head,
  contour, direction, area, and runtime summaries; no automatic preference.
- **Nonclaim/tests:** sensitivity is not statistical uncertainty. Tests cover
  zero self-comparison, every manifest row, failures, guard, and ordering.

## H. Variograms, anisotropy, and external drift

### `ps_variogram()`

- **Question/equation:** empirical semivariance summarizes half the mean squared
  pair difference within lag/direction classes, optionally after a stated trend.
- **Selected implementation:** gstat ordinary/residual, robust Cressie, cloud,
  irregular boundaries, explicit clockwise-from-North directions, pair counts,
  coordinate/distance units, and no automatic model fitting.
- **Limitations/tests:** sparse directional bins are flagged. Pair counts,
  widths/boundaries, direction convention, and formula retention are tested.

### `ps_variogram_compare()`

- **Question:** How do explicitly initialized covariance candidates fit the
  empirical variogram and, optionally, predict under one validation design?
- **Selected implementation:** separate `fit.variogram` calls; retain initial and
  fitted nugget/sill/range/kappa/anisotropy, singular state, warnings, and
  weighted SSE; selection criterion must be explicit.
- **Nonclaim/tests:** smallest SSE does not prove predictive superiority. Tests
  preserve failed candidates and reject negative parameters or implicit
  selection.

### `ps_anisotropy()`

- **Question:** Do directional variograms show exploratory geometric
  anisotropy?
- **Selected implementation:** directional empirical variograms, supported range
  fits, major-continuity direction modulo 180, minor/major ratio in [0,1], pair
  thresholds and weak/conflicting-evidence warning; interpolation uses it only
  when supplied explicitly.
- **Tests:** a fixed-seed elongated field, 0/180 equivalence, ratio bounds, and
  weak-evidence warnings.

### Extended `ps_interpolate()` trend and covariates

- **Question:** Can universal kriging represent a scientifically defensible
  trend using exhaustive prediction-domain covariates?
- **Selected implementation:** add arguments only at the end; preserve existing
  coordinate-quadratic UK when `trend=NULL`; accept formula and named raster or
  table covariates; default geometry mismatch error; explicit continuous/class
  alignment; standardization metadata; missing coverage, constants,
  duplication, collinearity, rank, and condition-number checks; use an explicit
  variogram unchanged except for validity checks; apply explicitly supplied
  anisotropy/neighborhood controls.
- **Alternatives:** a separate “external drift” method or fallback to coordinate
  UK was rejected because gstat implements it as universal kriging and fallback
  would change the requested model.
- **Nonclaim/tests:** covariates are predictors, not causal proof. Synthetic
  valley/land-elevation prediction, missing coverage, rank deficiency, geometry
  mismatch, and no-fallback behavior are tested. Desbarats et al., Rivest et al.,
  Rocha et al., Pebesma, and gstat guide the design.

## I. User-defined regions

### `ps_split_domain()` and `ps_interpolate_regions()`

- **Question:** How are an explicit domain and user-supplied hydrogeologic
  regions partitioned, and what surfaces result when each region uses only its
  own observations?
- **Selected implementation:** validate rather than silently repair polygons;
  inventory overlaps/gaps/boundaries/ambiguous points; obey explicit priority,
  duplication, or error policy; fit each region with its own mask and records;
  retain underpopulated failures; mosaic only with explicit overlap priority;
  preserve region ID.
- **Nonclaim/tests:** regions are not inferred from wells and are not numerical
  no-flow/specified-head boundaries. Tests prove no cross-region data influence,
  preserve distinct constants, detect topology cases, and prevent smoothing
  across the boundary.

## J. Depth, profiles, and cross-sections

### `ps_depth_to_water_surface()`

- **Equation:** depth is `land-surface elevation - head elevation` after explicit
  alignment and compatible vertical metadata.
- **Selected implementation:** depth, negative/near-zero/common/only-one masks,
  summary and alignment manifest; preserve negative depth.
- **Terminology/nonclaim:** water-table input yields depth to water; confined
  input yields depth to the potentiometric surface. Negative values are review
  flags compatible with artesian/discharge behavior, local fit, measurement or
  DEM uncertainty, or incompatible references; they are not clipped.
- **Tests:** exact subtraction, negative retention, datum enforcement, and label.

### `ps_surface_profile()`

- **Question:** What are surface/support values at documented spacing along one
  or more lines?
- **Selected implementation:** explicit `step` or `n`; monotone chainage, line
  ID, coordinates, spacing, and NA preservation; projected distance by default
  and explicit geodesic option for longitude/latitude.
- **Tests:** monotonicity, count/spacing, unsupported NA, and multiple IDs.

### `ps_cross_section()`

- **Question:** How can plan-view surfaces, nearby wells, and screens be shown
  along one transect?
- **Selected implementation:** sample profiles; project wells to chainage and
  retain perpendicular offset; require absolute screen elevations or an
  explicit conversion; enforce maximum offset; retain omitted-well audit,
  support/uncertainty, plot-ready tables, and vertical exaggeration.
- **Nonclaim/tests:** no hydrostratigraphy is invented and the graphic is not a
  three-dimensional groundwater-flow model. Chainage/offset, exclusions,
  screens, and exaggeration are tested.

## K. GIS styles and technical reports

### `ps_export_style()`

- **Question:** Can map products be accompanied by portable, inspectable styles?
- **Selected implementation:** well-formed QGIS QML or OGC SLD XML; raster
  ramps, labels, solid/dashed/dotted support lines, arrow lines, and points;
  units where supported; pattern plus color; overwrite guard; manifest; no
  absolute paths. XML parsing is validated with `xml2`.
- **Limitations/tests:** optional renderer properties may differ across GIS
  versions. Every format parses; fields/support patterns/overwrite/no-path rules
  are tested.

### `ps_report()`

- **Question:** Can a result be summarized reproducibly without implying
  certification or replacing hydrogeologic review?
- **Selected implementation:** package-owned offline R Markdown template;
  relevant sections only; escaped user text; conditions/limitations/session as
  selected; HTML or DOCX through Suggested `rmarkdown` and `knitr`; no PDF or
  internet requirement; output-only writes and overwrite guard.
- **Tests:** minimal HTML, conditional DOCX when Pandoc is present, clear missing
  dependency errors, escaped content, and no remote assets.

## L. Observation QA, event selection, and screen groups

### `ps_check_observations()`

- **Question:** Which deterministic metadata/geometry/measurement conflicts and
  statistical review flags are present before analysis?
- **Selected implementation:** stable issue IDs/codes/severity/field/message and
  review advice; original/retained/removal tables; every requested issue code;
  deterministic cleaning only under explicit action. Extreme values are review
  flags and are never automatically deleted.
- **Tests:** one fixture per issue code, no outlier deletion, and complete
  deterministic-removal inventory.

### `ps_select_event()`

- **Question:** Which single measurement per well best represents an explicitly
  centered monitoring window?
- **Selected implementation:** preserve time zone; symmetric window; deterministic
  nearest/earliest/latest/quality rule; explicit tie and exclusion records;
  actual event span; optional warn/error maximum span; no averaging.
- **Nonclaim/tests:** falling inside a window does not make measurements
  synoptic. Time zones, ties, one-per-well, span, and no averaging are tested.

### `ps_screen_groups()`

- **Question:** How should explicit unit labels, user-defined interval rules, or
  descriptive depth bins be retained or assigned?
- **Equation:** interval overlap fraction is intersection length divided by the
  positive screen length.
- **Selected implementation:** preserve existing labels; rules require the
  overlap criterion and retain ties/unclassified records; bins are explicitly
  named descriptive screen-depth/elevation bins.
- **Nonclaim/tests:** screen midpoint or interval alone does not establish
  aquifer identity. Existing labels, overlap math, ambiguity, and bin wording
  are tested.

## Implementation alternatives deliberately excluded

The release will not add online USGS downloads, a Shiny app, cloud automation,
MODFLOW construction, numerical groundwater-flow simulation, particle tracking,
transport, pumping-test analysis, or water-budget calculation. It will not add a
machine-learning, database, workflow-orchestration, Java, Python, or compiled-code
dependency. Base R plus the existing spatial stack is adequate; `xml2` is the
only planned new runtime dependency and report packages remain Suggested.
