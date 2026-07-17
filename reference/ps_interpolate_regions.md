# Interpolate explicit regions independently

Interpolate explicit regions independently

## Usage

``` r
ps_interpolate_regions(
  points,
  regions,
  region_id,
  methods = "TPS",
  template = NULL,
  grid_res = NULL,
  interpolation_control = list(),
  mosaic = TRUE,
  overlap_priority = NULL,
  progress = NULL
)
```

## Arguments

- points:

  Groundwater-head points.

- regions:

  Region polygons.

- region_id:

  Unique region field.

- methods:

  Interpolation methods.

- template, grid_res:

  Mapping geometry controls.

- interpolation_control:

  Named interpolation arguments.

- mosaic:

  Return a boundary-preserving mosaic.

- overlap_priority:

  Required region priority when regions overlap.

- progress:

  Optional callback.

## Value

A `potentiomap_regional_result` object. No groundwater-flow boundary
conditions are imposed and no smoothing occurs across region boundaries.

## Examples

``` r
data("synthetic_wells", "synthetic_regions")
p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")
regions <- terra::vect(synthetic_regions, geom = "wkt", crs = "EPSG:26916")
regional <- ps_interpolate_regions(p, regions, "region_id", "IDW",
                                   grid_res = 300)
regional$region_method_manifest
#>             region_id method observation_count
#> 1 western_compartment    IDW                 7
#> 2 eastern_compartment    IDW                18
#>                                                                                               observation_ids
#> 1                                                                   MW-03|MW-08|MW-18|MW-22|MW-25|MW-27|MW-29
#> 2 MW-01|MW-02|MW-04|MW-05|MW-06|MW-09|MW-10|MW-11|MW-13|MW-16|MW-19|MW-20|MW-21|MW-24|MW-26|MW-28|MW-31|MW-32
#>    status warning_count error_count warning_text error_text
#> 1 success             0           0                        
#> 2 success             0           0                        
# Independent regional fits do not impose flow-boundary conditions.
```
