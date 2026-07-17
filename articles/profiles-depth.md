# Surface profiles, depth to water, and cross-sections

``` r

library(potentiomap)
data("synthetic_wells")
data("synthetic_transect")
p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
head <- ps_interpolate(p, methods = "IDW", grid_res = 300)$IDW
land <- head * 0 + 185
line <- terra::vect(synthetic_transect, geom = "wkt", crs = "EPSG:26916")
```

``` r

depth <- ps_depth_to_water_surface(head, land, "potentiometric")
depth$summary
```

    ##     surface_type finite_cells negative_cells near_zero_cells minimum_depth
    ## 1 potentiometric          169              0               0      14.16812
    ##   maximum_depth                               label
    ## 1      20.47199 depth to the potentiometric surface

``` r

profile <- ps_surface_profile(line, list(head = head, land = land), n = 12)
head(profile$profile)
```

    ##      line_id             sample_id sample_index chainage        x       y
    ## X  line_0001 line_0001_sample_0001            1    0.000 500000.0 4640400
    ## X1 line_0001 line_0001_sample_0002            2  313.926 500264.1 4640570
    ## X2 line_0001 line_0001_sample_0003            3  627.852 500528.1 4640740
    ## X3 line_0001 line_0001_sample_0004            4  941.778 500792.2 4640909
    ## X4 line_0001 line_0001_sample_0005            5 1255.704 501056.3 4641079
    ## X5 line_0001 line_0001_sample_0006            6 1569.630 501320.3 4641249
    ##    spacing     head land
    ## X       NA 169.4180  185
    ## X1 313.926 169.5389  185
    ## X2 313.926 169.6194  185
    ## X3 313.926 169.6007  185
    ## X4 313.926 169.6114  185
    ## X5 313.926 169.5145  185

``` r

section <- ps_cross_section(line, head, land, step = 300,
                            vertical_exaggeration = 3)
section$summary
```

    ##   profile_samples retained_wells omitted_wells maximum_chainage
    ## 1              13              0             0         3452.903
    ##   vertical_exaggeration
    ## 1                     3

A confined potentiometric surface is not relabeled a water table. The
cross-section does not invent hydrostratigraphy or represent a 3-D flow
model.
