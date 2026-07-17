# Observation QA, event selection, and screen grouping

Use
[`ps_check_observations()`](https://el-cordero.github.io/potentiomap/reference/ps_check_observations.md)
before mapping to inventory identifiers, coordinates, head, units,
datum, event time, depth, and screen issues. Unusual values remain
review flags.
[`ps_select_event()`](https://el-cordero.github.io/potentiomap/reference/ps_select_event.md)
then chooses at most one measurement per well under a recorded rule,
while
[`ps_screen_groups()`](https://el-cordero.github.io/potentiomap/reference/ps_screen_groups.md)
preserves existing units or applies explicit rules. A time window is not
proof of a synoptic event, and descriptive depth bins are not aquifers.

``` r

checked <- ps_check_observations(records, x="x", y="y", value="head", id="well")
event <- ps_select_event(records, "well", "time", center, window=86400)
groups <- ps_screen_groups(records, "rules", screen_top="top",
                           screen_bottom="bottom", rules=unit_rules)
```
