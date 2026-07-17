# Interpolation within user-defined hydrogeologic regions

[`ps_split_domain()`](https://el-cordero.github.io/potentiomap/reference/ps_split_domain.md)
detects invalid geometry, overlaps, gaps, ambiguous boundary points, and
unassigned points without repairing or inferring regions.
[`ps_interpolate_regions()`](https://el-cordero.github.io/potentiomap/reference/ps_interpolate_regions.md)
uses only observations assigned to each explicit polygon, preserves
underpopulated failures, and does not smooth or average across
boundaries. These independent interpolations do not implement
groundwater-flow boundary conditions.

``` r

split <- ps_split_domain(domain, regions, "unit_id", points)
regional <- ps_interpolate_regions(points, regions, "unit_id", "TPS")
```
