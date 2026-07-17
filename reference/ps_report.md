# Render a package-owned technical report

Render a package-owned technical report

## Usage

``` r
ps_report(
  x,
  output_file,
  format = c("html", "docx"),
  title = NULL,
  sections = "auto",
  include_session = TRUE,
  include_conditions = TRUE,
  overwrite = FALSE
)
```

## Arguments

- x:

  A potentiomap analysis or interpolation result.

- output_file:

  Selected `.html` or `.docx` output.

- format:

  HTML or Word.

- title:

  Optional safely escaped title.

- sections:

  `"auto"` or a character vector selecting from `"summary"`,
  `"metadata"`, `"settings"`, `"validation"`, `"uncertainty"`,
  `"change_network"`, `"conditions"`, `"limitations"`, and `"session"`.

- include_session:

  Include session information.

- include_conditions:

  Include captured conditions.

- overwrite:

  Permit replacement of an existing output.

## Value

An invisible report manifest.

## Examples

``` r
data("synthetic_wells")
p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
checked <- ps_check_observations(p, value = "Z", id = "Name")
if (rmarkdown::pandoc_available()) {
  file <- tempfile(fileext = ".html")
  ps_report(checked, file, "html", include_session = FALSE)
}
#>                                    file format                        title
#> 1 /tmp/RtmpCNDnfY/file1d4c137e209f.html   html Potentiomap technical report
#>   sections include_session include_conditions package_version
#> 1     auto           FALSE               TRUE           0.2.0
# Generated reports are not professional certification.
```
