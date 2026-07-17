# Build a plot-ready potentiometric cross-section

Build a plot-ready potentiometric cross-section

## Usage

``` r
ps_cross_section(
  transect,
  head_surface,
  land_surface = NULL,
  wells = NULL,
  screen_top = NULL,
  screen_bottom = NULL,
  well_id = NULL,
  maximum_well_offset = NULL,
  support = NULL,
  uncertainty = NULL,
  step = NULL,
  vertical_exaggeration = 1
)
```

## Arguments

- transect:

  One line feature.

- head_surface:

  Head surface raster.

- land_surface:

  Optional land-surface raster.

- wells:

  Optional monitoring wells.

- screen_top, screen_bottom, well_id:

  Optional absolute-elevation columns.

- maximum_well_offset:

  Maximum perpendicular offset retained.

- support, uncertainty:

  Optional rasters sampled along the transect.

- step:

  Explicit profile spacing.

- vertical_exaggeration:

  Plot setting recorded without changing data.

## Value

A `potentiomap_cross_section` object. It does not invent
hydrostratigraphy or represent a three-dimensional numerical flow model.

## Examples

``` r
data("synthetic_wells", "synthetic_transect")
p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
s <- ps_interpolate(p, methods = "IDW", grid_res = 250)$IDW
line <- terra::vect(synthetic_transect, geom = "wkt", crs = "EPSG:26916")
section <- ps_cross_section(line, s, step = 250, vertical_exaggeration = 5)
section$summary
#>   profile_samples retained_wells omitted_wells maximum_chainage
#> 1              15              0             0         3452.916
#>   vertical_exaggeration
#> 1                     5
# The section is not a three-dimensional groundwater-flow model.
```
