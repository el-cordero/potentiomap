# Interpolate potentiometric surfaces

Creates one raster per requested interpolation method. The default
method is thin-plate spline (`"TPS"`). Other built-in methods are
inverse distance weighting (`"IDW"`), ordinary kriging (`"OK"`), and
universal kriging with quadratic drift (`"UK"`). Advanced users can also
pass named custom interpolation functions through `custom_methods`.

## Usage

``` r
ps_interpolate(
  points,
  value = "Z",
  methods = "TPS",
  grid_res = NULL,
  template = NULL,
  mask = NULL,
  padding = NULL,
  idw_power = 2,
  idw_nmax = 15,
  tps_lambda = NULL,
  kr_auto_cutoff = TRUE,
  kr_cutoff = NA_real_,
  kr_width = NA_real_,
  custom_methods = NULL,
  x = "x",
  y = "y",
  name_col = NULL,
  crs = NULL
)
```

## Arguments

- points:

  A point `SpatVector`, `sf` object, or coordinate table with a data
  column to interpolate.

- value:

  Data column name when `points` is not already standardized. Defaults
  to `"Z"`.

- methods:

  Character vector of interpolation methods. Built-in values are
  `"TPS"`, `"IDW"`, `"OK"`, and `"UK"`. Names supplied in
  `custom_methods` can also be used.

- grid_res:

  Output raster cell size in map units.

- template:

  Optional template `SpatRaster`; overrides `grid_res`, `padding`, and
  `mask` extent construction.

- mask:

  Optional AOI polygon used to crop and mask output rasters.

- padding:

  Padding added around the convex hull extent when building a template
  from points.

- idw_power, idw_nmax:

  IDW power and maximum neighbors.

- tps_lambda:

  Thin-plate spline smoothing parameter. `NULL` lets
  [`fields::Tps()`](https://rdrr.io/pkg/fields/man/Tps.html) choose by
  GCV.

- kr_auto_cutoff:

  Use automatic variogram cutoff and lag width.

- kr_cutoff, kr_width:

  Manual variogram cutoff and lag width.

- custom_methods:

  Optional named list of custom interpolation functions. Each function
  is called as `fun(points, template, grid)` and must return either a
  `SpatRaster` matching `template` or a numeric vector with one value
  per template cell.

- x, y, name_col, crs:

  Used when `points` is a coordinate table.

## Value

A named list of `SpatRaster` surfaces.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
surfaces <- ps_interpolate(pts, grid_res = 100)
#> Warning: 
#> Grid searches over lambda (nugget and sill variances) with  minima at the endpoints: 
#>   (GCV) Generalized Cross-Validation 
#>    minimum at  right endpoint  lambda  =  1.812476e-05 (eff. df= 30.40003 )
names(surfaces)
#> [1] "TPS"
```
