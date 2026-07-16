# Units, vertical references, and grouped groundwater observations

Groundwater elevation calculated from depth requires an explicit sign
and measurement reference. With positive depth below land surface:

`groundwater elevation = land-surface elevation - depth to water`.

``` r

library(potentiomap)
data("synthetic_wells")
points <- ps_potentiometric_points(
  synthetic_wells,
  x = "x", y = "y", depth_col = "depth_to_water",
  surface_col = "surface_elevation", name_col = "well_id",
  crs = "EPSG:26916", depth_unit = "m", surface_unit = "m",
  output_unit = "ft", vertical_datum = "synthetic example datum",
  surface_reference = "land_surface", depth_sign = "positive_down",
  metadata_mode = "strict"
)
ps_metadata(points)
#> $depth_unit
#> [1] "m"
#> 
#> $surface_unit
#> [1] "m"
#> 
#> $output_unit
#> [1] "ft"
#> 
#> $vertical_datum
#> [1] "synthetic example datum"
#> 
#> $surface_reference
#> [1] "land_surface"
#> 
#> $depth_sign
#> [1] "positive_down"
#> 
#> $measuring_point_offset
#> [1] 0
#> 
#> $metadata_mode
#> [1] "strict"
#> 
#> $international_foot_metres
#> [1] 0.3048
knitr::kable(data.frame(
  well = head(terra::values(points)$Name),
  groundwater_elevation_ft = head(terra::values(points)$Z)
))
```

| well  | groundwater_elevation_ft |
|:------|-------------------------:|
| MW-01 |                 546.7520 |
| MW-02 |                 542.9790 |
| MW-03 |                 562.5328 |
| MW-04 |                 543.6024 |
| MW-05 |                 554.4619 |
| MW-06 |                 556.2008 |

The supported length units are metres and international feet, using
exactly `1 ft = 0.3048 m`. A horizontal CRS does not supply a vertical
datum. potentiomap records the stated datum but does not transform
between vertical datums, infer datum compatibility, or guess
measuring-point offsets. R-level metadata may not survive every GIS
vector format, so preserve a sidecar manifest when those details must
accompany exports.

Separate events and water-bearing units before fitting surfaces.

``` r

grouped_data <- transform(
  synthetic_wells,
  event = rep(c("spring", "autumn"), each = 16),
  unit = rep(c("upper", "lower"), times = 16)
)
grouped <- ps_interpolate_grouped(
  grouped_data, c("event", "unit"), value = "gw_elevation",
  name_col = "well_id", crs = "EPSG:26916",
  methods = "IDW", grid_res = 400
)
knitr::kable(grouped$manifest)
```

| event | unit | group_id | method | input_count | retained_count | status | surface_available | warnings | errors | output_paths |
|:---|:---|:---|:---|---:|---:|:---|:---|:---|:---|:---|
| autumn | lower | autumn\_\_lower | IDW | 8 | 8 | success | TRUE |  |  |  |
| spring | lower | spring\_\_lower | IDW | 8 | 8 | success | TRUE |  |  |  |
| autumn | upper | autumn\_\_upper | IDW | 8 | 8 | success | TRUE |  |  |  |
| spring | upper | spring\_\_upper | IDW | 8 | 8 | success | TRUE |  |  |  |

Each row is assigned to exactly one group. A shared template
standardizes output geometry but does not share observations or fitted
information. Empty and failed groups remain in the manifest. A simple
progress callback can report group completion without adding another
package dependency.
