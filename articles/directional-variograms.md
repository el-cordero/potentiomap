# Directional variograms and anisotropy

Angles follow gstat: clockwise from positive Y (north) and periodic over
180 degrees. Inspect pair counts and stability before interpreting
directional ranges.
[`ps_anisotropy()`](https://el-cordero.github.io/potentiomap/reference/ps_anisotropy.md)
reports an exploratory major-continuity direction and minor-to-major
range ratio only when supported. Weak or conflicting evidence produces a
warning, and the result is never activated automatically.

``` r

a <- ps_anisotropy(points, directions=seq(0,135,45), minimum_pairs=20)
```
