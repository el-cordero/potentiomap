# Calculate an empirical groundwater-head variogram

Calculates an ordinary or residual empirical variogram without fitting a
covariance model. Directions follow the gstat convention: degrees
clockwise from positive Y (North), periodic over 180 degrees. Pair
counts and projected coordinate units are retained.

## Usage

``` r
ps_variogram(
  points,
  formula = Z ~ 1,
  cutoff = NULL,
  width = NULL,
  boundaries = NULL,
  directions = 0,
  direction_tolerance = NULL,
  robust = FALSE,
  cloud = FALSE
)
```

## Arguments

- points:

  Groundwater-head points with a `Z` column.

- formula:

  Head/trend formula, such as `Z ~ 1` or `Z ~ elevation`.

- cutoff:

  Maximum pair distance.

- width:

  Positive lag width.

- boundaries:

  Optional strictly increasing lag upper boundaries.

- directions:

  Direction angles clockwise from North.

- direction_tolerance:

  Horizontal tolerance in degrees.

- robust:

  Use gstat's Cressie robust estimator.

- cloud:

  Return individual pair semivariances.

## Value

A `potentiomap_variogram` with empirical values, formula, directions,
point summary, settings and conditions.

## References

Pebesma (2004),
[doi:10.1016/j.cageo.2004.03.012](https://doi.org/10.1016/j.cageo.2004.03.012)
.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
v <- ps_variogram(pts, cutoff = 3000, width = 300)
head(v$empirical)
#>   np      dist     gamma dir.hor dir.ver   id
#> 1 15  175.0445 0.0744700       0       0 var1
#> 2 47  456.9771 0.5025138       0       0 var1
#> 3 53  751.7839 1.2764792       0       0 var1
#> 4 62 1037.5377 1.9806565       0       0 var1
#> 5 72 1362.8381 3.4161986       0       0 var1
#> 6 74 1649.0900 4.4004966       0       0 var1
# An empirical variogram does not establish one correct covariance model.
```
