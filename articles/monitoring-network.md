# Monitoring-network sensitivity and candidate locations

``` r

library(potentiomap)
data("synthetic_wells")
data("synthetic_candidate_sites")
p <- ps_make_points(synthetic_wells[1:12, ], "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
```

``` r

thin <- ps_network_thinning(p, retain = 0.75, repeats = 2,
                            method = "IDW", grid_res = 400, seed = 3)
thin$summary
```

    ##   planned_runs unique_retained_sets duplicate_retained_sets successful_runs
    ## 1            2                    1                       1               2

``` r

candidates <- terra::vect(subset(synthetic_candidate_sites, !excluded),
                          geom = c("x", "y"), crs = "EPSG:26916")
design <- ps_candidate_network(p, candidates, n_select = 2)
design$selected_sequence
```

    ##   sequence   candidate_id information_gain cost gain_per_unit_cost
    ## 1        1 candidate_0004         1095.677   NA                 NA
    ## 2        2 candidate_0002         1083.300   NA                 NA
    ##          objective
    ## 1 spatial_coverage
    ## 2 spatial_coverage

Influence and thinning are conditional on the observed network and
method. Candidate ranking is sequential and greedy, not globally optimal
or a claim that a location is drillable.
