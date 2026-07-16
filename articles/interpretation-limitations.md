# Interpretation, assumptions, and limitations

`potentiomap` organizes a reproducible spatial workflow. It does not
determine whether observations represent one hydraulic system or whether
an interpolated surface is adequate for a particular decision.

## Before interpolation

- Prefer a synoptic measurement round when the objective is a spatial
  snapshot. Record date, time, time datum, weather or recharge context,
  and known pumping.
- Confirm the measuring point, its offset from land surface,
  land-surface elevation, corrections, units, and vertical datum. Do not
  mix NAVD 88, NGVD 29, local datums, or assumed elevations without a
  documented conversion.
- Confirm that positive depth-to-water values mean depth below land
  surface. Flowing wells may have negative depth-to-water values under
  that convention.
- Review aquifer assignment, open or screened interval, well depth,
  nested-well construction, and confining units. Nearby wells can
  measure different heads because they represent different depth
  intervals or hydraulic units.
- Flag pumped, recently pumped, obstructed, dry, flowing, or otherwise
  non-static wells. Decide whether each measurement represents the
  mapping objective; retain the decision trail.

The [USGS Groundwater Technical
Procedures](https://pubs.usgs.gov/tm/1a1/) cover standardized
measuring-point establishment and water-level measurement. USGS
furnished-record guidance also identifies site status, measuring-point
offsets, corrections, well construction, and measurement timing as
important documentation.

## Network support and boundaries

- Sparse or clustered networks constrain spatial detail unevenly. A fine
  grid does not resolve that limitation.
- Extrapolation beyond the outer wells is weakly supported. A
  rectangular raster should not be mistaken for a defensible aquifer
  boundary.
- Surface-water features may represent recharge, discharge, or neither,
  depending on hydraulic connection and timing. Their role is not
  inferred from map proximity alone.
- Faults, aquitards, divides, pumping centers, recharge zones, and
  domain edges can alter the shape of the potentiometric surface.
  `potentiomap` does not add these conceptual boundaries automatically.
- Nested wells should not be collapsed into one horizontal location
  without first resolving vertical hydraulic differences.

USGS describes groundwater hydrology as interpretive because the
resource is not directly observable everywhere; monitoring networks
provide point evidence from which spatial understanding is interpolated
and extrapolated.

## Interpolation and validation

TPS, IDW, ordinary kriging, and universal kriging encode different
assumptions. No method is universally best. Select parameters with the
monitoring geometry, conceptual hydrogeologic model, and intended use in
mind. When results support consequential decisions, use an appropriate
validation design, inspect residuals and geostatistical diagnostics,
evaluate plausible alternatives, and document uncertainty.

Smoothing changes the modeled surface. It can support cartographic
generalization, but it is not an accuracy correction. Retain the
original surface and record the smoothing statistic, window, weights,
and iteration count. Excessive smoothing can erase local variation or
move contours.

## Hydraulic gradients are not velocities

A hydraulic gradient is change in head per unit distance.
[`ps_flow_arrows()`](https://el-cordero.github.io/potentiomap/reference/ps_flow_arrows.md)
uses the interpolated surface to infer the direction of decreasing
modeled head. Its line length can be scaled for display and its density
follows raster sampling, not monitoring density.

Groundwater velocity additionally depends on hydraulic conductivity and
effective porosity, and flow paths can be affected by heterogeneity,
anisotropy, vertical gradients, sources, sinks, and boundaries. The
[USGS discussion of Darcy’s
law](https://pubs.usgs.gov/circ/2002/circ1224/html/understanding.html)
distinguishes hydraulic gradient from average linear velocity.

Hydraulic-gradient arrows do not represent groundwater velocity, travel
time, particle paths, or contaminant transport. The package is not a
process-based groundwater-flow model and does not replace hydrogeologic
judgment.

## Review record for a defensible map

At minimum, retain:

1.  original measurements and qualifiers;
2.  aquifer and screened-interval selection;
3.  horizontal CRS and vertical datum;
4.  measuring-point and land-surface corrections;
5.  interpolation method and every parameter;
6.  template geometry, mask, and extrapolation limits;
7.  smoothing and contour settings;
8.  gradient-arrow settings;
9.  warnings, diagnostics, and validation results; and
10. package and dependency versions.

An interpolated surface is a model conditioned on data and assumptions.
Treat it as one line of evidence within the conceptual hydrogeologic
interpretation.

## Review table

Use a compact review table to keep the result and its limiting evidence
together in a project record.

| product | review_evidence | does_not_establish |
|:---|:---|:---|
| Observation set | Timing, aquifer, screened interval, datum, corrections, and qualifiers | One hydraulic system or error-free head values |
| Modeled surface | Method, parameters, grid, mask, diagnostics, and validation | A uniquely correct potentiometric surface |
| Contours | Interval or levels, source surface, and omitted-level manifest | Observed groundwater elevations between wells |
| Support classes | User-defined thresholds, hull rule, resolution, and reason fields | Statistical confidence without a suitable uncertainty model |
| Hydraulic-gradient arrows | Source surface, density, scale, endpoint validation, and direction check | Velocity, travel time, particle paths, or contaminant transport |
