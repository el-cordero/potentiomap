# Evaluate reproducible monitoring-network thinning scenarios

Evaluate reproducible monitoring-network thinning scenarios

## Usage

``` r
ps_network_thinning(
  points,
  retain = c(0.75, 0.5, 0.25),
  design = c("random", "spatial_coverage", "user"),
  method = "TPS",
  repeats = 10,
  subsets = NULL,
  template = NULL,
  mask = NULL,
  grid_res = NULL,
  seed = 1,
  progress = NULL
)
```

## Arguments

- points:

  Groundwater-head points.

- retain:

  Fractions or exact retained counts.

- design:

  Random, spatial-coverage, or user subsets.

- method:

  Interpolation method.

- repeats:

  Number of planned runs per fraction.

- subsets:

  User-supplied lists of retained IDs.

- template, mask, grid_res:

  Fixed surface controls.

- seed:

  Deterministic seed.

- progress:

  Optional callback.

## Value

A `potentiomap_network_thinning` object.

## Examples

``` r
data("synthetic_wells")
p <- ps_make_points(synthetic_wells[1:10, ], "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
thin <- ps_network_thinning(p, retain = 0.7, method = "IDW",
                            repeats = 2, grid_res = 350, seed = 8)
thin$summary
#>   planned_runs unique_retained_sets duplicate_retained_sets successful_runs
#> 1            2                    2                       0               2
# Full-surface differences are descriptive, not error against truth.
```
