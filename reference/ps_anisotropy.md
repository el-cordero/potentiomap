# Explore directional anisotropy in hydraulic head

Calculates directional variograms and exploratory fitted ranges. The
major continuity direction is periodic over 180 degrees and uses gstat's
clockwise-from-North convention. Weak evidence is warned and anisotropy
is never activated in interpolation unless supplied explicitly.

## Usage

``` r
ps_anisotropy(
  points,
  formula = Z ~ 1,
  directions = seq(0, 135, by = 45),
  tolerance = 22.5,
  cutoff = NULL,
  width = NULL,
  model = "Sph",
  minimum_pairs = 20,
  validation = FALSE
)
```

## Arguments

- points:

  Groundwater-head points.

- formula:

  Variogram trend formula.

- directions:

  Direction angles.

- tolerance:

  Direction tolerance in degrees.

- cutoff, width:

  Variogram controls.

- model:

  Candidate directional model.

- minimum_pairs:

  Minimum total pairs required for a directional fit.

- validation:

  Optionally request a documented isotropic/anisotropic validation
  comparison (recorded as not run when no validation design is
  supplied).

## Value

A `potentiomap_anisotropy` with empirical values, directional fits,
major direction, minor-to-major range ratio, and conditions.

## Examples

``` r
data("synthetic_wells")
pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                      "well_id", "EPSG:26916")
a <- ps_anisotropy(pts, minimum_pairs = 5)
#> Warning: 43 lag-direction bin(s) contain fewer than five pairs.
#> Warning: Directional evidence is weak or unstable; no precise anisotropy estimate is justified.
a$summary
#>   major_continuity_direction minor_to_major_range_ratio usable_directions
#> 1                         NA                         NA                 0
#>                   angle_convention
#> 1 clockwise from North; modulo 180
# This exploratory result is not applied automatically.
```
