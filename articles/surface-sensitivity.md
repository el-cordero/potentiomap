# Grid, boundary, and parameter sensitivity

Use an explicit scenario table to vary resolution, padding, masks,
smoothing, neighbors, trends, or covariance controls.
[`ps_surface_sensitivity()`](https://el-cordero.github.io/potentiomap/reference/ps_surface_sensitivity.md)
keeps failed scenarios, identifies one reference, reports common support
and support area change separately, and makes the self-comparison
exactly zero. It does not select a preferred scenario automatically.

``` r

scenarios <- expand.grid(grid_res=c(50,100), idw_power=c(1.5,2,3))
s <- ps_surface_sensitivity(points, "IDW", scenarios, reference=1)
```
