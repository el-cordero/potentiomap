# Classify modeled contour sections by local prediction support

Divides modeled contour lines according to user-defined spatial-support
criteria. Sections close to groundwater observations may be classified
as supported, while sections crossing larger monitoring gaps may be
classified as approximate or unsupported. Classification occurs at the
resolution of the supplied prediction-support raster and does not move,
smooth, close, or convert the contour lines.

## Usage

``` r
ps_contour_support(
  contours,
  points = NULL,
  surface = NULL,
  support = NULL,
  uncertainty = NULL,
  supported_distance = NULL,
  approximate_distance = NULL,
  distance_reference = c("map_units", "median_nearest_neighbor"),
  require_inside_hull = TRUE,
  neighbor_radius = NULL,
  minimum_neighbors = NULL,
  supported_uncertainty = NULL,
  approximate_uncertainty = NULL,
  combine = c("worst", "distance", "uncertainty"),
  keep_unsupported = TRUE,
  minimum_segment_length = 0,
  return = c("result", "segments"),
  uncertainty_type = NULL,
  uncertainty_units = NULL
)
```

## Arguments

- contours:

  Nonempty line SpatVector or line-vector input readable by
  terra::vect(). A recognizable contour-level field is required.

- points:

  Optional groundwater observation points. Required when support is not
  supplied and for relative-spacing or neighbor criteria unless the
  support result retains its training points.

- surface:

  Optional one-layer potentiometric-surface SpatRaster. Required with
  points when support is not supplied. When both a surface and support
  result are supplied, their geometry must match.

- support:

  Optional
  [`ps_prediction_support()`](https://el-cordero.github.io/potentiomap/reference/ps_prediction_support.md)
  result. Its existing distance, training-hull, mask, and
  finite-prediction layers are reused.

- uncertainty:

  Optional one-layer raster containing a user-identified uncertainty
  measure. It is never resampled and must match support geometry.

- supported_distance, approximate_distance:

  Optional paired nonnegative distance thresholds. The approximate
  threshold must be at least the supported threshold. No default
  distances are assumed.

- distance_reference:

  Either "map_units" or "median_nearest_neighbor". In the latter case,
  supplied thresholds are multipliers of the calculated median
  nearest-neighbor spacing.

- require_inside_hull:

  When TRUE, cells outside the training convex hull cannot be supported
  but may remain approximate when other criteria permit. A convex hull
  is not an aquifer boundary.

- neighbor_radius, minimum_neighbors:

  Optional paired local-density criterion in projected map units and
  unique observation locations.

- supported_uncertainty, approximate_uncertainty:

  Optional paired thresholds in the units or scale of uncertainty.

- combine:

  "worst" combines all active primary criteria, "distance" uses
  distance, and "uncertainty" uses uncertainty. Finite prediction, mask,
  requested hull, and neighbor rules remain applicable.

- keep_unsupported:

  Retain unsupported line sections when TRUE.

- minimum_segment_length:

  Nonnegative minimum retained line length in projected map units.

- return:

  "result" for a potentiomap_contour_support object or "segments" for
  only the classified line SpatVector.

- uncertainty_type:

  Required description when uncertainty is supplied, such as "kriging
  prediction variance" or "user support index".

- uncertainty_units:

  Optional units or scale description for the supplied uncertainty
  raster.

## Value

A potentiomap_contour_support list with segments, a line-length summary,
thresholds, the support information used, settings, and captured
conditions; or only segments. Segment attributes include the original
contour level and source ID, support class and reason, distance, hull
and finite-support statistics, optional neighbor and uncertainty
statistics, length, threshold reference, and a line_type style hint.

## Details

Distance thresholds can be expressed in projected map units or as
multiples of the median nearest-neighbor spacing among unique
observation locations. Optional training-hull, local-neighbor, and
user-identified uncertainty criteria can modify the result. With combine
= "worst", the least supported active criterion determines the cell
class. Finite prediction and mask status are always enforced.

These classes describe local observation support for the mapped contour.
They are not statistical confidence intervals. Proximity to wells does
not prove that a contour is correct, and distance from wells does not
prove that it is wrong. A solid contour remains an interpolation between
observations; an approximate contour is still generated from the modeled
surface. Appropriate criteria depend on network geometry, hydrogeology,
interpolation method, raster resolution, and intended map use.

## Examples

``` r
data("synthetic_wells")
wells <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                        "well_id", "EPSG:26916")
surface <- ps_interpolate(wells, methods = "IDW", grid_res = 300)$IDW
support <- ps_prediction_support(wells, surface = surface)
contours <- ps_contours(surface, interval = 1)
classified <- suppressWarnings(ps_contour_support(
  contours, support = support,
  supported_distance = 500, approximate_distance = 1200,
  require_inside_hull = TRUE
))
classified$summary
#>    contour_level support_class segment_count total_line_length
#> 7            165     supported             1          822.0633
#> 1            165   approximate             1          196.3884
#> 8            166     supported             1         1518.0847
#> 2            166   approximate             2         2458.4830
#> 9            167     supported             1         2846.4464
#> 3            167   approximate             2         1074.9705
#> 10           168     supported             1         2701.9709
#> 4            168   approximate             3         1272.6860
#> 11           169     supported             1         3414.6854
#> 5            169   approximate             2         1291.8373
#> 12           170     supported             1         2448.2991
#> 6            170   approximate             3         3012.5166
#>    retained_line_length removed_line_length
#> 7              822.0633                   0
#> 1              196.3884                   0
#> 8             1518.0847                   0
#> 2             2458.4830                   0
#> 9             2846.4464                   0
#> 3             1074.9705                   0
#> 10            2701.9709                   0
#> 4             1272.6860                   0
#> 11            3414.6854                   0
#> 5             1291.8373                   0
#> 12            2448.2991                   0
#> 6             3012.5166                   0
```
