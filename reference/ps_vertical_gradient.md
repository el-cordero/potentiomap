# Calculate a vertical hydraulic gradient

Uses absolute upper and lower observation elevations. With an
upward-positive convention, the primary gradient is
`(lower_head - upper_head) / (upper_elevation - lower_elevation)`. The
result indicates potential vertical direction and is not vertical
groundwater flux.

## Usage

``` r
ps_vertical_gradient(
  upper_head,
  lower_head,
  upper_elevation,
  lower_elevation,
  positive = c("upward", "downward"),
  tolerance = 0,
  align = c("error", "to_upper", "to_lower", "template"),
  template = NULL,
  event_metadata = NULL
)
```

## Arguments

- upper_head, lower_head:

  Numeric paired heads or one-layer rasters.

- upper_elevation, lower_elevation:

  Matching absolute elevations, not unidentified depths.

- positive:

  Sign convention.

- tolerance:

  Nonnegative near-zero gradient tolerance.

- align, template:

  Explicit raster alignment controls.

- event_metadata:

  Optional list documenting compatible event, datum, units, interval and
  screen-midpoint assumptions.

## Value

A `potentiomap_vertical_gradient` with component products, direction
class, support, and sign convention. No flux field is returned.

## Examples

``` r
vg <- ps_vertical_gradient(10, 12, 100, 90)
vg$gradient
#> [1] 0.2
# The positive gradient indicates upward driving potential, not flux.
```
