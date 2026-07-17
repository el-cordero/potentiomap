# Comparing monitoring events

Before comparison, verify units, vertical datum, measurement reference,
water-bearing unit, screen-selection rule, and event timing.
[`ps_head_change()`](https://el-cordero.github.io/potentiomap/reference/ps_head_change.md)
returns paired-well measured changes separately from the modeled
B-minus-A surface difference and accounts for changing membership.
Modeled head change is not storage, depletion, recharge, or volumetric
change.

``` r

change <- ps_head_change(event_a, event_b, pair_by="well_id",
                         event_a_time=t1, event_b_time=t2, method="TPS")
```
