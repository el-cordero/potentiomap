# Rank explicit candidate monitoring locations with recorded constraints

Rank explicit candidate monitoring locations with recorded constraints

## Usage

``` r
ps_candidate_network(
  existing_points,
  candidates,
  objective = c("spatial_coverage", "support_gap", "kriging_variance_reduction",
    "user_score"),
  n_select = 1,
  target = NULL,
  variogram_model = NULL,
  trend = NULL,
  minimum_existing_distance = 0,
  minimum_candidate_distance = 0,
  allowed_area = NULL,
  exclusion_area = NULL,
  cost = NULL,
  user_score = NULL,
  sequential = TRUE
)
```

## Arguments

- existing_points:

  Existing monitoring points.

- candidates:

  Explicit candidate point locations.

- objective:

  Candidate-scoring objective.

- n_select:

  Number selected by sequential greedy ranking.

- target:

  Explicit target points or raster for target-weighted objectives.

- variogram_model, trend:

  Model for kriging-variance reduction.

- minimum_existing_distance, minimum_candidate_distance:

  Spacing rules.

- allowed_area, exclusion_area:

  Spatial constraints.

- cost:

  Optional finite positive candidate costs.

- user_score:

  Optional supplied scores.

- sequential:

  Update scores after each choice.

## Value

A `potentiomap_candidate_network` object. The greedy sequence is not
claimed to be globally optimal or to identify drillable sites.

## Examples

``` r
data("synthetic_wells", "synthetic_candidate_sites")
p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
c <- terra::vect(subset(synthetic_candidate_sites, !excluded),
                 geom = c("x", "y"), crs = "EPSG:26916")
design <- ps_candidate_network(p, c, n_select = 2,
                               objective = "spatial_coverage")
design$selected_sequence
#>   sequence   candidate_id information_gain cost gain_per_unit_cost
#> 1        1 candidate_0002         960.1709   NA                 NA
#> 2        2 candidate_0001         517.0042   NA                 NA
#>          objective
#> 1 spatial_coverage
#> 2 spatial_coverage
# Sequential greedy selection is not a globally optimal drilling plan.
```
