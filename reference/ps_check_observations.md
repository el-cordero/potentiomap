# Check groundwater observation records

Reports deterministic input conflicts and statistical review flags
before interpolation. Unusual values are never automatically treated as
errors or deleted. Coordinate distance checks require a known projected
CRS; longitude and latitude are flagged for planar analysis. Screen and
head comparisons assume all elevations use one documented vertical
datum.

## Usage

``` r
ps_check_observations(
  data,
  x = NULL,
  y = NULL,
  value = NULL,
  id = NULL,
  datetime = NULL,
  unit = NULL,
  vertical_datum = NULL,
  depth = NULL,
  surface_elevation = NULL,
  screen_top = NULL,
  screen_bottom = NULL,
  unit_group = NULL,
  duplicate_tolerance = 0,
  action = c("report", "return_clean")
)
```

## Arguments

- data:

  A data frame, `sf` object, or point `SpatVector`.

- x, y, value, id, datetime, unit, vertical_datum, depth,
  surface_elevation:

  Optional column names for location, measurement, timing, unit, datum,
  and land-surface fields.

- screen_top, screen_bottom, unit_group:

  Optional screen-elevation and hydrogeologic-unit column names.

- duplicate_tolerance:

  Nonnegative coordinate distance within which different records are
  flagged as colocated. Use projected map units.

- action:

  Return only the report or also deterministically remove records with
  missing IDs, coordinates, or heads.

## Value

A `potentiomap_observation_check` with `issues`, original `data`,
`retained`, `removed`, counts, settings, metadata, and conditions.

## Examples

``` r
d <- data.frame(id = c("A", "A"), x = c(0, 0), y = c(0, 0),
                head = c(10, 11))
attr(d, "crs") <- "EPSG:26920"
check <- ps_check_observations(d, "x", "y", "head", "id")
check$issues
#>      issue_id   record_id           issue_code severity field
#> 1 issue_00001 record_0001 duplicate_coordinate  warning   x/y
#> 2 issue_00002 record_0002 duplicate_coordinate  warning   x/y
#> 3 issue_00003 record_0001     conflicting_head  warning  head
#> 4 issue_00004 record_0002     conflicting_head  warning  head
#>                                                                  message
#> 1 Another observation is at the same or tolerance-equivalent coordinate.
#> 2 Another observation is at the same or tolerance-equivalent coordinate.
#> 3                             The same well/event has conflicting heads.
#> 4                             The same well/event has conflicting heads.
#>                                                                       suggested_review
#> 1 Review colocated screens, repeated measurements, and interpolation duplicate policy.
#> 2 Review colocated screens, repeated measurements, and interpolation duplicate policy.
#> 3                           Review measurement qualifiers and do not average silently.
#> 4                           Review measurement qualifiers and do not average silently.
# Flags require hydrogeologic review; they do not prove a record is wrong.
```
