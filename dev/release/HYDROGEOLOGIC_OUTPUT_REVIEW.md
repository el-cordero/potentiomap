# Hydrogeologic output review

Date: 2026-07-17

| Feature | Units / datum / sign | Support and uncertainty language | Prohibited interpretation review |
|---|---|---|---|
| Observation, event, screen checks | Preserves supplied head units, time zone, screen elevation reference, and named vertical datum | Flags deterministic conflicts and review conditions; statistical outliers are not deleted automatically | Screen overlap/bins are not aquifers; selected events are not silently averaged or assumed synoptic |
| Interpolation, variograms, external drift | Head and covariate units remain metadata; projected CRS is required for planar distance and direction | Variogram/trend/model conditions are retained; covariates are predictors | A surface is not a process model; drift does not establish causality; hull is not aquifer boundary |
| Validation and tuning | Residual is predicted minus observed in head units | Results are conditional on the recorded resampling prediction task and support subset | LOOCV/spatial transfer are not interchangeable; tuning scores are not design-unbiased map accuracy |
| Ensemble and disagreement | Head spread retains head units; directional disagreement is 0–180° | Method spread/disagreement is named explicitly | An ensemble is not automatically better and disagreement is not statistical uncertainty |
| Kriging, simulation, and contour uncertainty | Variance is squared head units; SE/quantiles are head units; probabilities are dimensionless | Kriging/simulation products are model conditional; contour bands are pointwise unless proved otherwise | Simulations are not truths; pointwise bands are not simultaneous confidence regions |
| Contour support and arrows | Distance uses projected CRS units; gradients/arrows use modeled-head decline | Support classes remain user-defined observation support, not confidence | Arrows are not paths, velocities, travel times, particle tracks, or Darcy flux |
| Surface/head change | Difference is event B minus A unless the recorded direction says otherwise | Common and one-sided support are reported | Change is not storage, depletion, recharge, budget, or volume; percent datum-head change is not a default |
| Vertical gradient | Sign convention and positive direction are stored; vertical separation must be positive and compatible | Overlapping/ambiguous intervals warn | Hydraulic gradient is not vertical flux; no conductivity or flux field is produced |
| Depth products | Exact land elevation minus head; negatives retained; matching units/datum required | Only common finite support is interpreted | Confined output is depth to the potentiometric surface, not necessarily water-table depth |
| Regions | User region IDs and explicit overlap/gap/boundary rules are retained | Regions are fitted independently and support is not smoothed across boundaries | Regions are not numerical no-flow/specified-head/general-head boundary conditions |
| Networks and candidates | Distance/cost units and deterministic selections are recorded | Influence, thinning, and gains are conditional descriptive analyses | Influence does not identify bad data; rankings are not globally optimal, drillable, or guaranteed |
| Profiles/cross-sections | Chainage and offsets use projected units or explicit geodesic metres; elevations retain their datum | Unsupported samples remain `NA`; well offsets/exclusions are inventoried | Plan-view sections are visualizations, not 3-D groundwater-flow models |
| GIS/report exports | Units, field names, line styles, settings, conditions, and package version are exported | Report limitations remain visible and selected sections are honored | Styling and automated reports do not constitute hydrogeologic judgment, certification, or regulatory approval |

Across features, raster alignment defaults to error, resampling must be chosen,
nonfinite values are never replaced by zero, and no vertical datum is inferred
from the horizontal CRS.
