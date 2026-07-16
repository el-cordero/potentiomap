# Interpolate grouped groundwater observations

Runs separate analyses for explicit event, aquifer, water-bearing-unit,
season, or other grouping columns. Training records are never combined
across groups. A shared template controls only output geometry; it does
not share observations or fit information.

## Usage

``` r
ps_interpolate_grouped(
  data,
  group_cols,
  value = "Z",
  x = "x",
  y = "y",
  name_col = NULL,
  crs = NULL,
  template_mode = c("shared", "group"),
  mask = NULL,
  mask_mode = c("shared", "group"),
  output_dir = NULL,
  progress = NULL,
  ...
)
```

## Arguments

- data:

  Observation data accepted by
  [`ps_make_points()`](https://el-cordero.github.io/potentiomap/reference/ps_make_points.md).

- group_cols:

  One or more explicit grouping columns.

- value, x, y, name_col, crs:

  Point-preparation arguments.

- template_mode:

  `"shared"` for one output grid or `"group"` for a grid derived
  independently within each group.

- mask:

  Optional shared mask, or a named list when `mask_mode = "group"`.

- mask_mode:

  `"shared"` or `"group"`.

- output_dir:

  Optional directory for group exports. No files are written when
  `NULL`.

- progress:

  Optional function called as
  `progress(index, total, group_id, status)`.

- ...:

  Arguments passed to
  [`ps_interpolate()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate.md).
  Structured results are always retained by group.

## Value

A `potentiomap_grouped_result` containing `results`, a deterministic
`manifest`, `group_keys`, captured `conditions`, and the original
`call`. Empty and failed groups remain in the manifest.

## Examples

``` r
data("synthetic_wells")
grouped <- transform(
  synthetic_wells,
  event = rep(c("spring", "autumn"), each = 16),
  unit = rep(c("upper", "lower"), times = 16)
)
result <- ps_interpolate_grouped(
  grouped, c("event", "unit"), value = "gw_elevation",
  name_col = "well_id", crs = "EPSG:26916",
  methods = "IDW", grid_res = 300
)
result$manifest
#>    event  unit      group_id method input_count retained_count  status
#> 1 autumn lower autumn__lower    IDW           8              8 success
#> 2 spring lower spring__lower    IDW           8              8 success
#> 3 autumn upper autumn__upper    IDW           8              8 success
#> 4 spring upper spring__upper    IDW           8              8 success
#>   surface_available warnings errors output_paths
#> 1              TRUE                             
#> 2              TRUE                             
#> 3              TRUE                             
#> 4              TRUE                             
```
