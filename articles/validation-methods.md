# Validating and comparing interpolation methods

``` r

library(potentiomap)
data("synthetic_wells")
p <- ps_make_points(synthetic_wells[1:16, ], "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
```

Validation designs represent different prediction tasks. Spatial
separation is appropriate when transfer to unsampled areas matters;
random folds answer a different question.

``` r

v <- ps_validate(p, c("IDW", "TPS"), design = "kfold", folds = 3,
                 prediction_mode = "direct", seed = 12)
```

    ## [inverse distance weighted interpolation]
    ## [inverse distance weighted interpolation]
    ## Warning: 
    ## Grid searches over lambda (nugget and sill variances) with  minima at the endpoints: 
    ##   (GCV) Generalized Cross-Validation 
    ##    minimum at  right endpoint  lambda  =  0.0001771007 (eff. df= 9.500013 )
    ## [inverse distance weighted interpolation]

``` r

v$fold_manifest[, c("fold_id", "training_count", "validation_count")]
```

    ##                 fold_id training_count validation_count
    ## xmin  repeat_001_fold_2             11                5
    ## xmin1 repeat_001_fold_1             10                6
    ## xmin2 repeat_001_fold_3             11                5

``` r

comparison <- ps_compare_methods(v, metric = "rmse")
comparison$ranking[, c("method", "rmse", "finite_coverage", "rank")]
```

    ##   method      rmse finite_coverage rank
    ## 1    IDW 1.3198115               1    2
    ## 7    TPS 0.4293667               1    1

These scores are conditional on the recorded folds; they are not
universal method rankings or automatic map accuracy.
