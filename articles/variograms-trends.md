# Variograms, anisotropy, and external drift

``` r

library(potentiomap)
data("synthetic_anisotropic_points")
p <- ps_make_points(synthetic_anisotropic_points, "x", "y", "head",
                    "point_id", "EPSG:26916")
```

``` r

v <- suppressWarnings(ps_variogram(p, directions = c(0, 45, 90, 135)))
head(v$empirical[, c("np", "dist", "gamma", "dir.hor")])
```

    ##   np      dist        gamma dir.hor
    ## 1  2  29.47621 2.432955e-05       0
    ## 2  1 146.87500 1.444485e-02       0
    ## 3  3 221.59240 3.313863e-03       0
    ## 4  4 282.13430 4.181855e-02       0
    ## 5  6 388.00746 3.936191e-02       0
    ## 6  6 462.37606 8.419526e-02       0

``` r

models <- suppressWarnings(ps_variogram_compare(v, c("Sph", "Exp")))
models$ranking[, c("model", "weighted_sse", "singular")]
```

    ##   model weighted_sse singular
    ## 1   Sph           NA       NA
    ## 2   Exp           NA       NA

``` r

a <- suppressWarnings(ps_anisotropy(p, minimum_pairs = 5))
a$summary
```

    ##   major_continuity_direction minor_to_major_range_ratio usable_directions
    ## 1                         NA                         NA                 0
    ##                   angle_convention
    ## 1 clockwise from North; modulo 180

Directional evidence is exploratory and is not applied automatically.
External drift must be supplied as scientifically defensible covariates
available over the full prediction domain; association does not
establish causality.
