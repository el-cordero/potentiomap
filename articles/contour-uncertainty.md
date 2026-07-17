# Pointwise contour uncertainty versus approximate contours

Prediction-support classes and contour-uncertainty bands answer
different questions. Support classes describe monitoring geometry and
finite prediction.
[`ps_contour_uncertainty()`](https://el-cordero.github.io/potentiomap/reference/ps_contour_uncertainty.md)
uses retained realizations for empirical crossings or an explicitly
accepted pointwise Gaussian assumption. Its band is pointwise, not a
simultaneous confidence region. Approximate support contours are not
statistical confidence contours.

``` r

band <- ps_contour_uncertainty(u, levels=seq(164,172,2),
                               method="empirical_crossing")
```
