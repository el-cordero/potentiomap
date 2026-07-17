# Extract one or more surface profiles along explicit lines

Extract one or more surface profiles along explicit lines

## Usage

``` r
ps_surface_profile(
  lines,
  surfaces,
  step = NULL,
  n = NULL,
  support = NULL,
  distance_method = c("projected", "geodesic")
)
```

## Arguments

- lines:

  One or more line features.

- surfaces:

  Named compatible surfaces or an interpolation result.

- step, n:

  Explicit spacing or count per line.

- support:

  Optional support/uncertainty rasters to extract.

- distance_method:

  Projected or explicit geodesic distance.

## Value

A `potentiomap_profile` with monotonically increasing chainage.

## Examples

``` r
data("synthetic_wells", "synthetic_transect")
p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
s <- ps_interpolate(p, methods = "IDW", grid_res = 250)$IDW
line <- terra::vect(synthetic_transect, geom = "wkt", crs = "EPSG:26916")
profile <- ps_surface_profile(line, list(head = s), n = 12)
head(profile$profile)
#>      line_id             sample_id sample_index chainage        x       y
#> X  line_0001 line_0001_sample_0001            1    0.000 500000.0 4640400
#> X1 line_0001 line_0001_sample_0002            2  313.926 500264.1 4640570
#> X2 line_0001 line_0001_sample_0003            3  627.852 500528.1 4640740
#> X3 line_0001 line_0001_sample_0004            4  941.778 500792.2 4640909
#> X4 line_0001 line_0001_sample_0005            5 1255.704 501056.3 4641079
#> X5 line_0001 line_0001_sample_0006            6 1569.630 501320.3 4641249
#>    spacing     head
#> X       NA 169.4203
#> X1 313.926 169.5333
#> X2 313.926 169.6151
#> X3 313.926 169.5974
#> X4 313.926 169.5790
#> X5 313.926 169.5119
# Unsupported raster sections remain missing rather than being invented.
```
