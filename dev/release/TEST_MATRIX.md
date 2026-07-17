# Test matrix for potentiomap 0.2.0 expansion

The matrix is the implementation checklist. `ordinary`, `invalid`, `edge`,
`class/fields`, `metadata`, `conditions`, `determinism`, `integration`, and
`example` apply to every new export. File functions also require
`write/overwrite/cleanup/serialization`; repeated analyses require stable IDs,
seeds, failed-run retention, and manifests. Existing exports retain regression
tests for positional calls, default return types, condition classes, requested
methods, contour support, and arrow endpoint behavior.

| Function/group | Material numerical or metamorphic tests | Special edge/platform coverage |
|---|---|---|
| `ps_validate` | No holdout in training; folds independent of head; hand ME/MAE/RMSE; failed/nonfinite records retained; deterministic/duplicate partition hashes; independent label | Empty/one-row folds, insufficient method sample, direct unavailable, raster outside domain, weights |
| `ps_compare_methods`, `ps_validation_plot` | Coverage gate; design separation; tie tolerance; Pareto/objective selection; plot data retain extremes | Empty/failed subsets, explicit clipping disclosure, no ggplot2 |
| `ps_tune_interpolation` | Inner/outer separation; selected row supplied; failures visible; exact refit; seed/order determinism | Maximum runs, no eligible candidate, random candidate subset |
| `ps_surface_ensemble` | Identity; exact equal mean; convex bounds; invalid weights | Geometry/unit/datum/type mismatch; intersection/union NA support |
| `ps_method_disagreement` | Zero identical; known constant offset; direction [0,180]; flat undefined | Fewer than minimum methods and partial support |
| `ps_surface_uncertainty` | Nonnegative variance/SE; ordered quantiles; bounded probabilities; seed; zero collapse; counts; sensitivity label | Missing fit, simulation conditioning tolerance, output cleanup/file-backed raster |
| `ps_contour_uncertainty` | Deterministic narrow band; wider synthetic uncertainty; out-of-range inventory; bounded probability; no simultaneous wording | Insufficient realizations and unaccepted Gaussian assumption |
| `ps_compare_surfaces` | Identity; antisymmetry; symmetric common support; swapped one-sided masks | Explicit alignment methods and metadata mismatch |
| `ps_head_change` | Exact paired changes/membership/sign; no volume field | Duplicate IDs, timing/unit/datum/reference/unit/screen mismatch |
| `ps_vertical_gradient` | Known upward/downward/zero; reversed/zero separation; no flux | Overlap/ambiguous interval; raster/numeric modes; alignment |
| `ps_well_influence` | One run/well; removed ID absent; failed refit retained; common support | Threshold/contour optional paths and progress callback |
| `ps_network_thinning` | Exact counts; disjoint sets; duplicate hashes; seeded maximin; descriptive label | User subset validation, one/zero holdout, failed reduced fit |
| `ps_candidate_network` | Constraints; exclusion; sequential score update; nonnegative variance reduction tolerance; exact cost ratios | No feasible candidates, invalid CRS/cost/model/target |
| `ps_surface_sensitivity` | Reference self-zero; every scenario row; failures; maximum guard; deterministic ordering | Scenario masks/templates and invalid controls |
| `ps_variogram`, `ps_variogram_compare` | Pair counts; invalid width/boundaries; direction convention; warnings/models retained; no explicit-model replacement | Cloud/robust/residual formulas; singular and negative parameters |
| `ps_anisotropy` | Rotated field broad direction; 0/180 equivalence; ratio [0,1]; weak warning | Sparse direction bins and optional validation |
| Extended `ps_interpolate` | Supplied trend/covariates; missing coverage; constant/duplicate/rank detection; geometry error; no coordinate fallback; supplied model identity | Existing positional/default regression; near/bilinear explicit alignment; neighborhood controls |
| `ps_split_domain`, `ps_interpolate_regions` | No cross-region observations; distinct constants; overlaps/gaps/boundary policy; no cross-boundary smoothing | Invalid geometry not silently repaired; overlap priority; underpopulated failure |
| `ps_depth_to_water_surface` | Exact land-head; negatives retained; datum required; confined label | Alignment and only-one support masks |
| `ps_surface_profile` | Monotone chainage; exact count/spacing; unsupported NA; multiple line IDs | Projected/geodesic gate and invalid step/n |
| `ps_cross_section` | Correct chainage/perpendicular offset; offset exclusion; screen reference; exaggeration | Missing land/wells/support/uncertainty combinations and plot method |
| `ps_export_style` | QML/SLD parse; field names; support patterns; overwrite; no absolute paths | Raster/vector layer types, palettes/breaks, temp cleanup |
| `ps_report` | Minimal HTML; DOCX when Pandoc; dependency errors; no network; escaped text | Relevant-section selection, overwrite, failed render cleanup |
| `ps_check_observations` | Fixture for every issue code; no outlier deletion; removals inventoried | Zero/one row, nonfinite, tolerance duplicates, spatial/tabular CRS |
| `ps_select_event` | Timezone; deterministic ties; one/well; exact span; no averaging | Empty window, parse failures, maximum span warn/error |
| `ps_screen_groups` | Existing labels preserved; overlap exact; ambiguity retained; bins not aquifers | Reversed/zero screens, rule gaps/overlap, invalid breaks/labels |

Long randomized cases live under `dev/stress-tests/` and are excluded from
ordinary CRAN checks. They cover multiple fixed seeds, clustered/elongated
networks, moderately large and file-backed rasters, missing support, many
candidates, simulations, thinning, report/style cleanup, and intentionally
failed writes. Platform-only external services (Win-builder and hosted Linux,
Windows, macOS matrices) cannot be exercised by a local test and are reported
separately rather than marked covered.

Coverage targets are at least 95% overall and 98% for new R files. Any genuinely
unreachable platform branch will be named with its reason in the final coverage
report; skips are not used merely to hide core behavior from CRAN.
