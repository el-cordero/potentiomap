# Validate and split an explicit hydrogeologic domain

Validate and split an explicit hydrogeologic domain

## Usage

``` r
ps_split_domain(
  domain,
  regions,
  region_id,
  points = NULL,
  overlap_action = c("error", "priority"),
  gap_action = c("report", "error"),
  boundary_action = c("error", "assign_by_priority", "duplicate")
)
```

## Arguments

- domain:

  Domain polygon.

- regions:

  Explicit region polygons.

- region_id:

  Unique region identifier field.

- points:

  Optional monitoring points to assign.

- overlap_action:

  Error or preserve priority order.

- gap_action:

  Report or error for domain gaps.

- boundary_action:

  Error, priority assignment, or duplicate assignments.

## Value

A `potentiomap_domain_split` object. Regions are never inferred from
monitoring points and invalid geometry is never silently repaired.

## Examples

``` r
data("synthetic_regions")
regions <- terra::vect(synthetic_regions, geom = "wkt", crs = "EPSG:26916")
domain <- terra::as.polygons(terra::ext(500000, 503000, 4640000, 4642500),
                             crs = "EPSG:26916")
split <- ps_split_domain(domain, regions, "region_id")
split$summary
#>   region_count overlap_count overlap_area gap_count gap_area assigned_points
#> 1            2             0            0         0        0               0
#>   ambiguous_points unassigned_points
#> 1                0                 0
# Explicit regions are not inferred groundwater-flow boundaries.
```
