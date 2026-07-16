# Structured potentiometric-surface result

A `potentiomap_result` is the opt-in return from
`ps_interpolate(..., return = "result")`. It retains the ordinary named
surface list together with method diagnostics and processing context.

## Details

Fields are:

- `surfaces`: named `SpatRaster` list.

- `diagnostics`: method-attributed fit and prediction diagnostics.

- `method_parameters`: interpolation controls used for each method.

- `input_summary`: observation counts, metadata, and dropped records.

- `observation_count`: retained observation count.

- `dropped_records`: summary of excluded input records.

- `grid_geometry`: output dimensions, resolution, extent, and cell
  count.

- `crs`: output coordinate reference system.

- `mask_summary`: whether and how a mask was supplied.

- `support`: optional result from
  [`ps_prediction_support()`](https://el-cordero.github.io/potentiomap/reference/ps_prediction_support.md).

- `conditions`: captured warnings and messages by method.

- `package_version`: potentiomap version.

- `call`: original interpolation call.
