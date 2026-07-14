# Troubleshooting and common errors

The messages below are captured from the released package; they are not
invented examples.

## Input and CRS errors

``` r

data.frame(
  situation = c("coordinate table without CRS", "missing groundwater-elevation column"),
  observed_message = c(
    capture_error(ps_make_points(synthetic_wells, "x", "y", "gw_elevation", "well_id")),
    capture_error(ps_make_points(synthetic_wells, "x", "y", "not_a_field", "well_id", "EPSG:26916"))
  )
)
#>                              situation
#> 1         coordinate table without CRS
#> 2 missing groundwater-elevation column
#>                                       observed_message
#> 1 `crs` is required when `data` is a coordinate table.
#> 2                       Missing column(s): not_a_field
```

For geographic longitude/latitude, release 0.1.0 accepts a valid
geographic CRS. Check
[`terra::is.lonlat()`](https://rspatial.github.io/terra/reference/is.lonlat.html)
and transform to an appropriate projected CRS before distance-based
interpolation. Assigning a projected CRS to longitude and latitude
numbers is not a transformation.

## Too few observations and unsupported methods

``` r

points <- ps_make_points(
  synthetic_wells, "x", "y", "gw_elevation", "well_id", "EPSG:26916"
)
data.frame(
  situation = c("four observations", "unknown method"),
  observed_message = c(
    capture_error(ps_interpolate(points[1:4], methods = "IDW", grid_res = 100)),
    capture_error(ps_interpolate(points, methods = "UNKNOWN", grid_res = 100))
  )
)
#>           situation
#> 1 four observations
#> 2    unknown method
#>                                                                                                 observed_message
#> 1                                                       At least five valid points are needed for interpolation.
#> 2 Unsupported method `UNKNOWN`. Use one of TPS, IDW, OK, UK, or provide a matching function in `custom_methods`.
```

Kriging can also fail or warn when the point count, spatial
configuration, lag classes, or empirical variogram do not support a
stable fit. Preserve the actual warning, inspect the variogram and fit,
reconsider cutoff and width, and do not silently substitute a
preferred-looking surface.

## Missing values and duplicate coordinates

[`ps_make_points()`](https://el-cordero.github.io/potentiomap/reference/ps_make_points.md)
drops rows whose coordinate or value cannot be converted to a finite
number. Compare row counts before and after standardization.

``` r

problem <- synthetic_wells
problem$gw_elevation[2] <- NA
problem <- rbind(problem, problem[1, ])
prepared <- ps_make_points(problem, "x", "y", "gw_elevation", "well_id", "EPSG:26916")
xy <- as.data.frame(crds(prepared))
data.frame(
  input_rows = nrow(problem),
  prepared_rows = nrow(prepared),
  duplicate_coordinate_rows = sum(duplicated(xy) | duplicated(xy, fromLast = TRUE))
)
#>   input_rows prepared_rows duplicate_coordinate_rows
#> 1         33            32                         2
```

Release 0.1.0 does not reconcile duplicate coordinates automatically.
Review whether duplicates represent repeat readings, nested wells, or
data errors; resolve them according to the monitoring design before
interpolation.

## Smoothing and contour errors

``` r

surface <- ps_interpolate(points, methods = "IDW", grid_res = 100)$IDW
#> [inverse distance weighted interpolation]
empty_surface <- surface
values(empty_surface) <- NA_real_
data.frame(
  situation = c("even smoothing window", "surface without finite values"),
  observed_message = c(
    capture_error(ps_smooth_surface(surface, window_size = 4)),
    capture_error(ps_contours(empty_surface, interval = 1))
  )
)
#>                       situation
#> 1         even smoothing window
#> 2 surface without finite values
#>                                        observed_message
#> 1 `window_size` must be an odd integer of 3 or greater.
#> 2                       `surface` has no finite values.
```

If contours are excessively dense or sparse, compare the interval with
the surface range and head precision. Explicit `levels` can be clearer
than a very small regular interval.

## AOI, grid size, and memory

Check that observations and the AOI overlap after transformation.
Release 0.1.0 can predict into a distant AOI rather than treating
non-overlap as an error, so an explicit overlap check is part of QA.

``` r

aoi <- ps_sample_aoi()
width_m <- xmax(aoi) - xmin(aoi)
height_m <- ymax(aoi) - ymin(aoi)
resolutions <- c(200, 100, 25, 5)
data.frame(
  resolution_m = resolutions,
  approximate_cells = ceiling(width_m / resolutions) * ceiling(height_m / resolutions)
)
#>   resolution_m approximate_cells
#> 1          200               270
#> 2          100              1044
#> 3           25             16472
#> 4            5            411800
```

Cell count grows with the inverse square of cell size. Start with a
resolution supported by well spacing and intended map scale; test finer
grids only when there is a defensible need.

## Flat surfaces and arrow density

Flat or nearly flat gradients can be removed by `min_gradient`. Reduce
it only when small gradients are meaningful relative to measurement and
interpolation uncertainty. Increase `res_factor` to reduce arrow
density; adjust `scale` for cartographic length. Neither setting creates
additional monitoring information.

## Export checks

- Test `file.access(output_directory, 2) == 0` before a long export.
- Release 0.1.0 writes with overwrite enabled inside
  [`ps_export_surfaces()`](https://el-cordero.github.io/potentiomap/reference/ps_export_surfaces.md)
  and the optional flow outputs; use a deliberate event-specific
  directory.
- Keep every `.shp`, `.shx`, `.dbf`, `.prj`, and `.cpg` component
  together.
- Read outputs back with
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
  or
  [`terra::vect()`](https://rspatial.github.io/terra/reference/vect.html)
  and compare CRS, dimensions, attribute names, and feature counts.
- If files become too large, revisit domain extent, raster resolution,
  number of methods, and whether every intermediate belongs in the
  deliverable.
