# Assign or validate monitoring-well screen groups

Preserves an existing water-bearing-unit field, applies explicit
interval rules, or creates descriptive depth/elevation bins. Screen
intervals alone do not establish hydrostratigraphic identity, and depth
bins are never labeled as aquifers.

## Usage

``` r
ps_screen_groups(
  data,
  mode = c("existing", "rules", "depth_bins"),
  unit_col = NULL,
  screen_top,
  screen_bottom,
  rules = NULL,
  breaks = NULL,
  labels = NULL,
  overlap_required = 0.5,
  ambiguous_action = c("report", "error")
)
```

## Arguments

- data:

  Observation data frame.

- mode:

  Existing labels, explicit interval rules, or descriptive bins.

- unit_col:

  Existing-label column.

- screen_top, screen_bottom:

  Screen-elevation column names; top must be greater than bottom.

- rules:

  Data frame with `unit`, `top`, and `bottom` absolute elevations.

- breaks, labels:

  Bin specification for `depth_bins`.

- overlap_required:

  Minimum fraction of screen length overlapping a rule.

- ambiguous_action:

  Return or error on multiple qualifying groups.

## Value

A `potentiomap_screen_groups` with assignments, overlap records,
ambiguous/unclassified records, rules and summary.

## Examples

``` r
d <- data.frame(well = c("A", "B"), top = c(10, 5), bottom = c(8, 1))
rules <- data.frame(unit = c("shallow", "deep"), top = c(12, 6), bottom = c(6, 0))
g <- ps_screen_groups(d, "rules", screen_top = "top", screen_bottom = "bottom", rules = rules)
g$assigned
#>   well top bottom screen_group
#> 1    A  10      8      shallow
#> 2    B   5      1         deep
# Rule assignments remain conditional on user-supplied hydrogeologic rules.
```
