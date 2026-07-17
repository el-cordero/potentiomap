# Prediction support, surface uncertainty, and contour uncertainty

``` r

library(potentiomap)
data("synthetic_wells")
p <- ps_make_points(synthetic_wells[1:16, ], "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
fit <- suppressWarnings(ps_interpolate(p, methods = "OK", grid_res = 350,
                                      support = TRUE, return = "result"))
```

``` r

fit$support$summary
```

    ##             support_class cells percent
    ## 1               supported    54 44.6281
    ## 2   outside_training_hull    67 55.3719
    ## 3 beyond_maximum_distance     0  0.0000
    ## 4            outside_mask     0  0.0000
    ## 5  prediction_unavailable     0  0.0000
    ## 6    multiple_limitations     0  0.0000

``` r

u <- ps_surface_uncertainty(fit, approach = "kriging_variance")
u$method_manifest
```

    ##   method         approach
    ## 1     OK kriging_variance
    ##                                                                                                             assumptions
    ## 1 Model-conditional kriging variance under the fitted trend and variogram; this is not total hydrogeologic uncertainty.
    ##   simulation_count seed
    ## 1                0    1

``` r

band <- ps_contour_uncertainty(u, 168, method = "gaussian_pointwise",
                               accept_gaussian = TRUE)
band$level_manifest
```

    ##   level probability             method pointwise_band_area_m2
    ## 1   168         0.9 gaussian_pointwise                8207500
    ##   finite_realizations gaussian_assumption
    ## 1                   0                TRUE

Support categories are not confidence classes. Kriging variance is
conditional on the fitted covariance model, and the contour product is
pointwise rather than a simultaneous confidence region.
