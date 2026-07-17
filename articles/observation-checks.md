# Preparing and checking groundwater observations

``` r

library(potentiomap)
data("synthetic_events")
```

Observation review should precede interpolation. The issue table records
deterministic failures and review flags without declaring unusual values
wrong.

``` r

spring <- subset(synthetic_events, event == "spring")
attr(spring, "crs") <- "EPSG:26916"
checked <- ps_check_observations(
  spring, x = "x", y = "y", value = "head", id = "well_id",
  datetime = "datetime", unit = "unit", vertical_datum = "vertical_datum"
)
checked$summary
```

    ##   original_count retained_count removed_count issue_count error_count
    ## 1             18             18             0           0           0
    ##   warning_count review_count
    ## 1             0            0

``` r

event <- ps_select_event(spring, "well_id", "datetime",
                         as.POSIXct("2025-03-15 12:00", tz = "UTC"), 3 * 3600)
event$summary
```

    ##               target_time            window_start              window_end
    ## 1 2025-03-15 12:00:00 UTC 2025-03-15 09:00:00 UTC 2025-03-15 15:00:00 UTC
    ##     selected_minimum_time   selected_maximum_time actual_span_seconds
    ## 1 2025-03-15 10:00:00 UTC 2025-03-15 14:00:00 UTC               14400
    ##   well_count tie_count excluded_count
    ## 1         18         0              0

Records inside a time window are not automatically synoptic. Screen bins
are descriptive unless explicit hydrogeologic rules support unit names.
