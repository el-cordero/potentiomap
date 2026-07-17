# Temporal head change and vertical hydraulic gradients

``` r

library(potentiomap)
data("synthetic_events")
a <- subset(synthetic_events, event == "spring")
b <- subset(synthetic_events, event == "autumn")
pa <- ps_make_points(a, "x", "y", "head", "well_id", "EPSG:26916")
pb <- ps_make_points(b, "x", "y", "head", "well_id", "EPSG:26916")
```

``` r

change <- ps_head_change(pa, pb, "well_id", method = "IDW", grid_res = 350)
change$summary
```

    ##   event_a_wells event_b_wells paired_wells event_a_only event_b_only
    ## 1            18            18           16            2            2
    ##   duplicate_ids mean_paired_change mean_modeled_change
    ## 1             0          -0.634625          -0.6948615

``` r

gradient <- ps_vertical_gradient(upper_head = 10, lower_head = 12,
                                 upper_elevation = 100, lower_elevation = 80,
                                 positive = "upward")
gradient[c("signed_gradient", "direction_class", "sign_convention")]
```

    ## $signed_gradient
    ## [1] 0.1
    ## 
    ## $direction_class
    ## [1] "upward"
    ## 
    ## $sign_convention
    ## $sign_convention$positive
    ## [1] "upward"
    ## 
    ## $sign_convention$vertical_separation
    ## [1] "upper_elevation - lower_elevation"
    ## 
    ## $sign_convention$dh_dz
    ## [1] "(upper_head - lower_head) / vertical_separation"
    ## 
    ## $sign_convention$upward_gradient
    ## [1] "(lower_head - upper_head) / vertical_separation"
    ## 
    ## $sign_convention$interpretation
    ## [1] "Hydraulic-gradient driving potential; not vertical flux."
    ## 
    ## $sign_convention$screen_midpoint_assumption
    ## [1] FALSE

Paired measured change and modeled surface change remain separate. Head
change is not storage change, and a vertical hydraulic gradient is not
flux.
