# Conditional simulation and model-conditional uncertainty

Conditional Gaussian realizations require a retained kriging trend,
variogram, conditioning data, and prediction grid.
[`ps_surface_uncertainty()`](https://el-cordero.github.io/potentiomap/reference/ps_surface_uncertainty.md)
records the seed, simulation count, model, random-path behavior, and
nugget treatment. The result is conditional on the covariance model and
Gaussian assumptions; it does not include all measurement,
conceptual-model, datum, or boundary uncertainty.

``` r

u <- ps_surface_uncertainty(ok_result, approach="conditional_simulation",
                            nsim=200, seed=17, keep_realizations=TRUE)
```
