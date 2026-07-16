# Plot classified contour support

Draws supported sections as solid, approximate sections as dashed, and
optionally unsupported sections as dotted. Colors and line widths are
not assigned by the result and can be supplied through .... The title
and legend identify the classes as user-defined support criteria, not
statistical confidence.

## Usage

``` r
# S3 method for class 'potentiomap_contour_support'
plot(
  x,
  show_unsupported = TRUE,
  label_levels = FALSE,
  legend_position = "topright",
  main = "Contour support (user-defined criteria)",
  ...
)
```

## Arguments

- x:

  A potentiomap_contour_support result.

- show_unsupported:

  Draw unsupported sections.

- label_levels:

  Label contour values where possible.

- legend_position:

  Base-graphics legend position, or NULL to omit it.

- main:

  Plot title.

- ...:

  Additional arguments passed to terra::plot().

## Value

Invisibly returns x.
