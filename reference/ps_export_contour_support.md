# Export classified contour-support products

Writes the classified line layer and optional CSV summaries. GeoPackage
is recommended because it preserves long field names more reliably than
a shapefile. The line_type field is a portable style suggestion; the
support class and reasons remain explicit attributes.

## Usage

``` r
ps_export_contour_support(
  x,
  out_dir,
  out_stub = "gw",
  vector_format = c("gpkg", "shapefile"),
  write_summary = TRUE,
  write_thresholds = TRUE,
  overwrite = TRUE
)
```

## Arguments

- x:

  A potentiomap_contour_support result.

- out_dir:

  Output directory.

- out_stub:

  Safe output filename prefix.

- vector_format:

  "gpkg" or "shapefile".

- write_summary, write_thresholds:

  Write CSV sidecars.

- overwrite:

  Overwrite existing files.

## Value

A data frame listing written products.

## Examples

``` r
# See ps_contour_support() for classification. GeoPackage is recommended.
```
