# Compare paired measurements and modeled head change between events

Compare paired measurements and modeled head change between events

## Usage

``` r
ps_head_change(
  event_a,
  event_b,
  pair_by,
  event_a_time = NULL,
  event_b_time = NULL,
  method = "TPS",
  template = NULL,
  mask = NULL,
  grid_res = NULL,
  interpolation_control = list(),
  compare_gradient = TRUE
)
```

## Arguments

- event_a, event_b:

  Point observations for two identified events.

- pair_by:

  Well identifier column.

- event_a_time, event_b_time:

  Optional explicit event times.

- method:

  Interpolation method.

- template, mask, grid_res:

  Fixed surface controls.

- interpolation_control:

  Named interpolation arguments.

- compare_gradient:

  Compare down-gradient directions.

## Value

A `potentiomap_head_change` object. Modeled head change is not a
storage, depletion, or volumetric-change estimate.

## Examples

``` r
data("synthetic_events")
a <- subset(synthetic_events, event == "spring")
b <- subset(synthetic_events, event == "autumn")
pa <- ps_make_points(a, "x", "y", "head", "well_id", "EPSG:26916")
pb <- ps_make_points(b, "x", "y", "head", "well_id", "EPSG:26916")
change <- ps_head_change(pa, pb, "well_id", method = "IDW", grid_res = 300)
change$summary
#>   event_a_wells event_b_wells paired_wells event_a_only event_b_only
#> 1            18            18           16            2            2
#>   duplicate_ids mean_paired_change mean_modeled_change
#> 1             0          -0.634625          -0.6903359
# Modeled head change is not a storage-change estimate.
```
