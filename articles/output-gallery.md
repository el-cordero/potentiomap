# Output gallery

Every image below shows an output generated with `potentiomap`.
Synthetic head values are labeled as synthetic units and should not be
interpreted as field elevations. Warm colors represent higher modeled
head and cool colors represent lower modeled head; contours, symbols,
and arrowheads provide non-color cues.

![Synthetic monitoring wells distributed inside an irregular area of
interest, with point fill progressing from blue lower heads to red
higher heads.](../gallery/01-monitoring-network.png)

### Monitoring network

**Method:** released synthetic points. **Units:** UTM metres; synthetic
head units. Network geometry conditions every interpolation.
[Preparation
code](https://el-cordero.github.io/potentiomap/articles/preparing-observations.md).

![Synthetic well points labeled with standardized observation names
inside the area of interest.](../gallery/02-standardized-points.png)

### Standardized potentiometric points

**Method:**
[`ps_make_points()`](https://el-cordero.github.io/potentiomap/reference/ps_make_points.md).
**Units:** UTM metres; synthetic head units in `Z`. [Preparation
pathways](https://el-cordero.github.io/potentiomap/articles/preparing-observations.md).

![Thin-plate spline surface shaded blue at lower synthetic heads and red
at higher heads, with monitoring wells.](../gallery/03-tps-surface.png)

### TPS surface

**Method:** thin-plate spline. **Units:** synthetic head units; 75-metre
cells. [Method
comparison](https://el-cordero.github.io/potentiomap/articles/interpolation-methods.md).

![Inverse-distance-weighted surface shaded blue at lower synthetic heads
and red at higher heads, with monitoring
wells.](../gallery/04-idw-surface.png)

### IDW surface

**Method:** inverse distance weighting. **Units:** synthetic head units;
75-metre cells. [IDW
parameters](https://el-cordero.github.io/potentiomap/articles/interpolation-parameters.md).

![Ordinary-kriging surface shaded blue at lower synthetic heads and red
at higher heads, with monitoring wells.](../gallery/05-ok-surface.png)

### Ordinary-kriging surface

**Method:** ordinary kriging with the released variogram workflow.
**Units:** synthetic head units; 75-metre cells. [Warnings and
comparison](https://el-cordero.github.io/potentiomap/articles/interpolation-methods.md).

![Universal-kriging surface shaded blue at lower synthetic heads and red
at higher heads, with monitoring wells.](../gallery/06-uk-surface.png)

### Universal-kriging surface

**Method:** universal kriging with quadratic drift. **Units:** synthetic
head units; 75-metre cells. [Warnings and
comparison](https://el-cordero.github.io/potentiomap/articles/interpolation-methods.md).

![Four panels compare TPS, IDW, ordinary kriging, and universal kriging
using one head scale, the same grid, contours, and
wells.](../gallery/07-methods-comparison.png)

### Four-method comparison

**Methods:** TPS, IDW, OK, UK. **Units:** synthetic head units;
identical 75-metre cells. No method is universally preferred. [Full
comparison](https://el-cordero.github.io/potentiomap/articles/interpolation-methods.md).

![One-unit TPS contours drawn as blue lines over the area of interest
with monitoring wells.](../gallery/08-contours-only.png)

### Contour-only product

**Method:**
[`ps_contours()`](https://el-cordero.github.io/potentiomap/reference/ps_contours.md)
from TPS. **Units:** one synthetic head unit. [Contour
settings](https://el-cordero.github.io/potentiomap/articles/contours-smoothing.md).

![TPS modeled surface with dark one-unit contour lines and white
monitoring wells.](../gallery/09-surface-contours.png)

### Surface plus contours

**Method:** TPS and regular contours. **Units:** synthetic head units.
[Quick
start](https://el-cordero.github.io/potentiomap/articles/quick-start.md).

![IDW modeled surface and contours with each synthetic monitoring well
labeled by identifier.](../gallery/10-labeled-wells.png)

### Surface plus labeled wells

**Method:** IDW with point labels. **Units:** synthetic head units.
Labels connect the map to reviewable observations. [Observation
fields](https://el-cordero.github.io/potentiomap/articles/preparing-observations.md).

![Three panels compare the original TPS surface, one-pass mean
smoothing, and two-pass median smoothing on one head
scale.](../gallery/11-smoothing-surfaces.png)

### Unsmoothed and smoothed surfaces

**Methods:** original TPS, focal mean, focal median. **Units:**
synthetic head units. Smoothing changes the model. [Smoothing
cautions](https://el-cordero.github.io/potentiomap/articles/contours-smoothing.md).

![Original and mean-smoothed TPS surfaces with one-unit contours,
displayed side by side.](../gallery/12-smoothing-contours.png)

### Unsmoothed and smoothed contours

**Method:** contours before and after focal mean smoothing. **Units:**
synthetic head units. [Retain the
original](https://el-cordero.github.io/potentiomap/articles/contours-smoothing.md).

![Hydraulic-gradient magnitude raster colored from light yellow lower
magnitude to dark red higher magnitude, with modeled-head
contours.](../gallery/13-gradient-raster.png)

### Hydraulic-gradient raster

**Method:** terrain derivative of the TPS surface. **Units:** head
change per horizontal map unit. [Gradient
products](https://el-cordero.github.io/potentiomap/articles/flow-arrows.md).

![TPS surface and contours with a sparse set of black arrowheads
pointing toward decreasing modeled
head.](../gallery/14-arrows-sparse.png)

### Sparse arrow layout

**Method:**
[`ps_flow_arrows()`](https://el-cordero.github.io/potentiomap/reference/ps_flow_arrows.md),
larger `res_factor`. **Units:** direction from modeled head; length is
cartographic. [Arrow
controls](https://el-cordero.github.io/potentiomap/articles/flow-arrows.md).

![TPS surface and contours with a denser set of black arrowheads
pointing toward decreasing modeled
head.](../gallery/15-arrows-dense.png)

### Dense arrow layout

**Method:**
[`ps_flow_arrows()`](https://el-cordero.github.io/potentiomap/reference/ps_flow_arrows.md),
smaller `res_factor`. **Units:** direction from modeled head; density is
not monitoring density. [Arrow
controls](https://el-cordero.github.io/potentiomap/articles/flow-arrows.md).

![Sparse arrow lines over a TPS surface with orange circular symbols
marking the final vertex of each line.](../gallery/16-arrow-tips.png)

### Arrow-tip points

**Method:** `ps_arrow_vertices(which = “last”)`. **Units:** UTM metres.
Tips support the downgradient check. [Direction
verification](https://el-cordero.github.io/potentiomap/articles/flow-arrows.md).

![Sparse arrow lines over a TPS surface with blue square symbols marking
the first vertex of each line.](../gallery/17-arrow-bases.png)

### Arrow-base points

**Method:** `ps_arrow_vertices(which = “first”)`. **Units:** UTM metres.
[Direction
verification](https://el-cordero.github.io/potentiomap/articles/flow-arrows.md).

![Native potentiomap quicklook PNG of the synthetic TPS surface with
blue and white contours and labeled
wells.](../gallery/18-exported-quicklook.png)

### Exported native quicklook

**Method:**
[`ps_export_surfaces()`](https://el-cordero.github.io/potentiomap/reference/ps_export_surfaces.md)
and
[`ps_quicklook()`](https://el-cordero.github.io/potentiomap/reference/ps_quicklook.md).
**Units:** synthetic head units. [Export and read
back](https://el-cordero.github.io/potentiomap/articles/exporting-products.md).

![Three synthetic monitoring-event TPS surfaces shown on the same grid
and head scale for January, April, and July
2026.](../gallery/19-repeated-events.png)

### Repeated monitoring events

**Method:** external R iteration around TPS on a common template.
**Units:** synthetic head units. [Event
workflow](https://el-cordero.github.io/potentiomap/articles/repeated-events.md).

![Thirty-six public USGS Stanley Shale wells shown inside a buffered
analysis polygon near Hot Springs,
Arkansas.](../gallery/20-real-world-network.png)

### Public monitoring network

**Source:** USGS 2017 Stanley Shale subset. **Units:** NAD83 UTM zone
15N metres. [Source and
filtering](https://el-cordero.github.io/potentiomap/articles/real-world-usgs.md).

![TPS surface from 36 USGS Stanley Shale wells, with twenty-foot
contours and well points, shaded blue at lower and red at higher
groundwater-level altitude.](../gallery/21-real-world-surface.png)

### Public-data software example

**Method:** TPS with 20-foot contours. **Units:** feet above NAVD 88;
75-metre cells. This is not the official interpreted surface. [Complete
example](https://el-cordero.github.io/potentiomap/articles/real-world-usgs.md).

Hydraulic-gradient arrows in this gallery indicate decreasing modeled
head. They do not represent groundwater velocity, travel time, particle
paths, or contaminant transport.
