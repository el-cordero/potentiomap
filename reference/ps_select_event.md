# Select a groundwater monitoring event

Selects at most one record per well inside a symmetric time window. The
result records the actual measurement span; being inside a window does
not by itself make an event synoptic and repeated values are never
averaged.

## Usage

``` r
ps_select_event(
  data,
  id,
  datetime,
  center,
  window,
  rule = c("nearest", "earliest", "latest", "best_quality"),
  quality = NULL,
  timezone = "UTC",
  maximum_span = NULL,
  maximum_span_action = c("warn", "error")
)
```

## Arguments

- data:

  Observation data frame.

- id, datetime:

  Column names for well ID and measurement time.

- center:

  Target time coercible to `POSIXct`.

- window:

  Nonnegative seconds, a `difftime`, or a string accepted by
  [`as.difftime()`](https://rdrr.io/r/base/difftime.html).

- rule:

  Deterministic selection rule.

- quality:

  Optional quality column for `best_quality`; lower sorted value is
  preferred and time distance breaks ties.

- timezone:

  Time zone used to parse and retain times.

- maximum_span:

  Optional maximum selected-event span.

- maximum_span_action:

  Warn or error when the maximum is exceeded.

## Value

A `potentiomap_event_selection` containing selected, excluded and tie
records plus an event summary.

## Examples

``` r
d <- data.frame(well = c("A", "A", "B"),
  time = c("2026-01-01 00:00", "2026-01-01 02:00", "2026-01-01 01:00"))
ev <- ps_select_event(d, "well", "time", "2026-01-01 01:00", 3 * 3600)
ev$selected
#>   well                time
#> 1    A 2026-01-01 00:00:00
#> 3    B 2026-01-01 01:00:00
# The recorded span still requires a study-specific synoptic judgment.
```
