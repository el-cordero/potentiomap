# Candidate monitoring locations and design constraints

Candidate locations must be supplied explicitly. Allowed and exclusion
areas, spacing, cost, target areas, and any user scores remain visible.
[`ps_candidate_network()`](https://el-cordero.github.io/potentiomap/reference/ps_candidate_network.md)
supports coverage, support-gap, model-conditional kriging-variance
reduction, or preserved user scores. Sequential greedy selection updates
after each choice; it is not globally optimal and does not establish
access, ownership, constructability, or drillability.

``` r

design <- ps_candidate_network(existing, candidates, "support_gap",
                               n_select=3, target=weak_support,
                               exclusion_area=exclusions)
```
