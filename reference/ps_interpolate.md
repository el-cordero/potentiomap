# Interpolate potentiometric surfaces

Creates one raster for each requested method. Thin-plate splines
(`"TPS"`) remain the software default for backward compatibility, but
method selection should reflect the hydrogeologic setting,
monitoring-network geometry, spatial trend, sample density, prediction
support, validation design, and intended map use. Other built-in methods
are inverse-distance weighting (`"IDW"`), ordinary kriging (`"OK"`), and
universal kriging (`"UK"`) with a quadratic drift. Named custom
functions are also supported.

## Usage

``` r
ps_interpolate(
  points,
  value = "Z",
  methods = "TPS",
  grid_res = NULL,
  template = NULL,
  mask = NULL,
  padding = NULL,
  idw_power = 2,
  idw_nmax = 15,
  tps_lambda = NULL,
  kr_auto_cutoff = TRUE,
  kr_cutoff = NA_real_,
  kr_width = NA_real_,
  custom_methods = NULL,
  x = "x",
  y = "y",
  name_col = NULL,
  crs = NULL,
  return = c("surfaces", "result"),
  duplicate_action = c("error", "mean", "median", "first"),
  allow_geographic = FALSE,
  uk_coordinate_scaling = c("center_scale", "none"),
  diagnostic_control = NULL,
  support = FALSE,
  support_max_distance = NULL
)
```

## Arguments

- points:

  A point `SpatVector`, `sf` object, or coordinate table.

- value:

  Data column name when `points` is not standardized. Defaults to `"Z"`.

- methods:

  Character vector containing `"TPS"`, `"IDW"`, `"OK"`, `"UK"`, or names
  in `custom_methods`.

- grid_res:

  Positive output cell size in projected map units.

- template:

  Optional one-layer template `SpatRaster`; overrides extent
  construction from `grid_res`, `padding`, and `mask`.

- mask:

  Optional polygon mask. A convex hull or supplied mask describes the
  computational domain, not an aquifer boundary.

- padding:

  Nonnegative padding around the template extent.

- idw_power, idw_nmax:

  Positive IDW power and optional positive maximum neighbor count.

- tps_lambda:

  Optional nonnegative TPS smoothing parameter. `NULL` uses the
  selection performed by
  [`fields::Tps()`](https://rdrr.io/pkg/fields/man/Tps.html).

- kr_auto_cutoff:

  Use an automatically derived variogram cutoff and lag width.

- kr_cutoff, kr_width:

  Positive manual variogram values when `kr_auto_cutoff = FALSE`.

- custom_methods:

  Optional named list of functions called as
  `fun(points, template, grid)`. Each must return a matching
  `SpatRaster` or one numeric value per template cell.

- x, y, name_col, crs:

  Used for a coordinate table.

- return:

  Either `"surfaces"` (the backward-compatible named raster list) or
  `"result"` for a
  [potentiomap_result](https://el-cordero.github.io/potentiomap/reference/potentiomap_result.md).

- duplicate_action:

  Handling for duplicate coordinates: `"error"`, `"mean"`, `"median"`,
  or `"first"`.

- allow_geographic:

  Allow distance calculations in longitude/latitude degrees with a
  classed warning. The default is `FALSE`.

- uk_coordinate_scaling:

  Either `"center_scale"` (the safer default) or `"none"` for a
  documented legacy comparison.

- diagnostic_control:

  Optional named list overriding heuristic UK warning thresholds.
  Supported names are `condition_number_warning`,
  `predicted_range_ratio_warning`, `overshoot_range_ratio_warning`,
  `warn_on_rank_deficiency`, and `warn_on_nonfinite_predictions`.

- support:

  Calculate
  [`ps_prediction_support()`](https://el-cordero.github.io/potentiomap/reference/ps_prediction_support.md)
  for the first returned surface.

- support_max_distance:

  Optional support distance threshold.

## Value

By default, a named list of
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
surfaces. With `return = "result"`, a documented `potentiomap_result`.

## Details

Requested methods are never silently replaced. Kriging conditions and
fit information, TPS selection information, prediction ranges, and
method messages are available in the opt-in structured result.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
result <- ps_interpolate(
  pts, methods = c("IDW", "TPS"), grid_res = 150,
  return = "result", support = TRUE
)
#> Warning: TPS GCV selected lambda 1.81248e-05 at a search boundary; inspect sensitivity and prediction support.
ps_surfaces(result)
#> $IDW
#> class       : SpatRaster
#> size        : 21, 22, 1  (nrow, ncol, nlyr)
#> resolution  : 150, 150  (x, y)
#> extent      : 500093.2, 503393.2, 4639910, 4643060  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 16N (EPSG:26916)
#> source(s)   : memory
#> name        :        IDW
#> min value   : 164.277299
#> max value   : 171.163169
#> 
#> $TPS
#> class       : SpatRaster
#> size        : 21, 22, 1  (nrow, ncol, nlyr)
#> resolution  : 150, 150  (x, y)
#> extent      : 500093.2, 503393.2, 4639910, 4643060  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / UTM zone 16N (EPSG:26916)
#> source(s)   : memory
#> name        :        TPS
#> min value   : 163.047396
#> max value   : 173.390637
#> 
ps_diagnostics(result, "TPS")
#> $formula
#> [1] "thin-plate spline"
#> 
#> $observation_count
#> [1] 32
#> 
#> $selection_mode
#> [1] "GCV"
#> 
#> $selected_lambda
#> [1] 1.812476e-05
#> 
#> $effective_degrees_of_freedom
#> [1] 30.40003
#> 
#> $gcv_score
#> [1] 0.02826268
#> 
#> $search_range
#> [1] 1.812476e-05 1.733447e+02
#> 
#> $selected_at_search_boundary
#> [1] TRUE
#> 
#> $warning_table_available
#> [1] TRUE
#> 
#> $warning_text
#> [1] "TPS GCV selected lambda 1.81248e-05 at a search boundary; inspect sensitivity and prediction support."
#> 
#> $message_text
#> [1] "Warning: | Grid searches over lambda (nugget and sill variances) with  minima at the endpoints: | (GCV) Generalized Cross-Validation | minimum at  right endpoint  lambda  =  1.812476e-05 (eff. df= 30.40003 )"
#> 
#> $return_status
#> [1] "success_with_warning"
#> 
#> $requested_method
#> [1] "TPS"
#> 
#> $returned_method
#> [1] "TPS"
#> 
#> $finite_prediction_count
#> [1] 462
#> 
#> $nonfinite_prediction_count
#> [1] 0
#> 
```
