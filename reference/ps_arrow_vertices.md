# Extract arrow base or tip points

Extract arrow base or tip points

## Usage

``` r
ps_arrow_vertices(
  arrows,
  which = c("last", "first"),
  out_file = NULL,
  overwrite = TRUE
)
```

## Arguments

- arrows:

  A line `SpatVector` or path to a line vector file.

- which:

  `"first"` for bases or `"last"` for tips.

- out_file:

  Optional vector output path.

- overwrite:

  Overwrite `out_file` when it exists.

## Value

A point
[`terra::SpatVector`](https://rspatial.github.io/terra/reference/SpatVector-class.html),
including an empty point vector for zero arrows.

## Examples

``` r
line <- terra::vect(list(rbind(c(0, 0), c(1, 1))), type = "lines",
                    crs = "EPSG:3857")
ps_arrow_vertices(line, "last")
#> class       : SpatVector
#> geometry    : points
#> dimensions  : 1, 0  (geometries, attributes)
#> extent      : 1, 1, 1, 1  (xmin, xmax, ymin, ymax)
#> coord. ref. : WGS 84 / Pseudo-Mercator (EPSG:3857)
```
