# Vertical-gradient sign conventions

For absolute representative elevations, vertical separation is upper
minus lower elevation. The upward-driving gradient is
`(lower_head-upper_head) / vertical_separation`.
[`ps_vertical_gradient()`](https://el-cordero.github.io/potentiomap/reference/ps_vertical_gradient.md)
can return upward- or downward-positive values and always records the
convention. Reversed, zero, or unidentified separations fail. A
hydraulic gradient indicates driving potential; it is not groundwater
flux.

``` r

ps_vertical_gradient(upper_head=10, lower_head=12,
                     upper_elevation=100, lower_elevation=80,
                     positive="upward")
```
