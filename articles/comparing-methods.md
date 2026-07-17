# Comparing TPS, IDW, OK, and UK

TPS, IDW, ordinary kriging, and universal kriging encode different
assumptions. Request them explicitly and inspect method conditions,
support, residuals, and fit objects.
[`ps_compare_methods()`](https://el-cordero.github.io/potentiomap/reference/ps_compare_methods.md)
ranks only within one validation design, support subset, and objective.
It does not identify a universally best method, and a requested method
is never silently replaced.

``` r

v <- ps_validate(points, c("TPS","IDW","OK","UK"), "spatial_block", folds=5)
ps_compare_methods(v, metric="rmse", support_subset="supported")
```
