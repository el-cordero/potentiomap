# Nested tuning without information leakage

Candidate parameters must be compared on fixed inner partitions. When an
outer design is requested,
[`ps_tune_interpolation()`](https://el-cordero.github.io/potentiomap/reference/ps_tune_interpolation.md)
sees each outer holdout only after selecting parameters inside that
outer training set. Every failed candidate remains in the manifest.
Without outer validation, scores are tuning performance and should not
be presented as unbiased final performance.

``` r

tuned <- ps_tune_interpolation(
  points, "IDW", list(idw_power=c(1, 1.5, 2), idw_nmax=c(8, 15)),
  inner_design="spatial_block", outer_design="kfold", seed=31
)
```
