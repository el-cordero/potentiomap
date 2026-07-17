# Profiles and cross-sections

[`ps_surface_profile()`](https://el-cordero.github.io/potentiomap/reference/ps_surface_profile.md)
samples explicit line features at a documented count or spacing and
preserves unsupported values.
[`ps_cross_section()`](https://el-cordero.github.io/potentiomap/reference/ps_cross_section.md)
adds land surface, depth, support, uncertainty, projected wells,
perpendicular offsets, and absolute screen elevations. Wells beyond the
offset rule are inventoried. The result does not invent
hydrostratigraphy and is not a three-dimensional groundwater-flow model.

``` r

profile <- ps_surface_profile(transect, surfaces, step=25)
section <- ps_cross_section(transect, head, dem, wells, maximum_well_offset=50)
```
