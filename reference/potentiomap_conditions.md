# potentiomap condition classes

Important warnings and errors raised by potentiomap have stable S3
classes so calling code can respond without matching the complete
message text. All package warnings inherit from `potentiomap_warning`;
all package errors inherit from `potentiomap_error`.

## Details

Specific classes include `potentiomap_input_error`,
`potentiomap_metadata_error`, `potentiomap_crs_error`,
`potentiomap_arrow_endpoint_warning`,
`potentiomap_uk_instability_warning`,
`potentiomap_kriging_convergence_warning`,
`potentiomap_tps_gcv_boundary_warning`,
`potentiomap_contour_level_warning`,
`potentiomap_contour_support_warning`,
`potentiomap_contour_support_error`,
`potentiomap_contour_threshold_error`,
`potentiomap_contour_uncertainty_error`, `potentiomap_support_warning`,
and `potentiomap_export_error`.
