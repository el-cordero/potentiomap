# Validate potentiometric-surface interpolation

Evaluates requested methods under an explicit leave-one-out, k-fold,
spatial block, cluster, user-fold, or independent validation prediction
task. Held-out heads never construct folds and held-out records never
enter their training fit. Cross-validation performance is not
automatically area-wide map accuracy.

## Usage

``` r
ps_validate(
  points,
  methods = c("TPS", "IDW", "OK", "UK"),
  design = c("loocv", "kfold", "spatial_block", "leave_cluster_out", "user_folds",
    "independent"),
  validation_points = NULL,
  fold_id = NULL,
  cluster = NULL,
  folds = 5,
  repeats = 1,
  block_size = NULL,
  template = NULL,
  mask = NULL,
  grid_res = NULL,
  domain_policy = c("fixed", "training"),
  prediction_mode = c("raster", "direct"),
  metrics = c("me", "mae", "rmse", "medae", "maxae"),
  support = TRUE,
  sampling_weight = NULL,
  interpolation_control = list(),
  seed = 1,
  progress = NULL
)
```

## Arguments

- points:

  Training groundwater-head points with stable IDs.

- methods:

  Interpolation methods.

- design:

  Validation design.

- validation_points:

  Independent compatible validation points.

- fold_id, cluster:

  Assignment vector or column.

- folds, repeats:

  Positive counts.

- block_size:

  Spatial-block size in projected units.

- template, mask, grid_res:

  Fixed mapping geometry controls.

- domain_policy:

  Fixed or fold-training-derived raster domain.

- prediction_mode:

  Full raster/extraction sequence or supported direct prediction.

- metrics:

  Error metrics; residual is predicted minus observed.

- support:

  Calculate held-out hull/distance/mask support.

- sampling_weight:

  Optional weights for explicitly independent probability validation
  records only.

- interpolation_control:

  Named arguments passed to interpolation.

- seed:

  Deterministic master seed.

- progress:

  Optional callback `(index, total, run_id, status)`.

## Value

A `potentiomap_validation` with predictions, metrics, fold/partition/
fit manifests, support summary, settings and captured conditions.

## References

Roberts et al. (2017),
[doi:10.1111/ecog.02881](https://doi.org/10.1111/ecog.02881) ; Wadoux et
al. (2021),
[doi:10.1016/j.ecolmodel.2021.109692](https://doi.org/10.1016/j.ecolmodel.2021.109692)
.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
val <- ps_validate(pts, methods = "IDW", design = "kfold", folds = 3,
                   prediction_mode = "direct", seed = 7)
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
#> [inverse distance weighted interpolation]
val$metrics
#>   method design  scope           fold_id support_subset scheduled_count
#> 1    IDW  kfold pooled              <NA>            all              32
#> 2    IDW  kfold pooled              <NA>         finite              32
#> 3    IDW  kfold pooled              <NA>      supported              32
#> 4    IDW  kfold   fold repeat_001_fold_1            all              11
#> 5    IDW  kfold   fold repeat_001_fold_2            all              11
#> 6    IDW  kfold   fold repeat_001_fold_3            all              10
#>   evaluated_count finite_count supported_count          me       mae      rmse
#> 1              32           32              23 -0.06425555 0.6013091 0.7784370
#> 2              32           32              23 -0.06425555 0.6013091 0.7784370
#> 3              23           32              23 -0.16332788 0.5491970 0.6510427
#> 4              11           11               9  0.06739166 0.7079855 0.8400653
#> 5              11           11               8 -0.10342376 0.4702794 0.5772881
#> 6              10           10               6 -0.16598244 0.6280976 0.8923099
#>       medae    maxae finite_fraction finite_coverage support_coverage
#> 1 0.5467966 2.006500               1               1        0.7187500
#> 2 0.5467966 2.006500               1               1        0.7187500
#> 3 0.5683705 1.530031               1               1        0.7187500
#> 4 0.5804934 1.952406               1               1        0.8181818
#> 5 0.5683705 0.994181               1               1        0.7272727
#> 6 0.3450660 2.006500               1               1        0.6000000
# These scores describe the stated folds, not design-unbiased map accuracy.
```
