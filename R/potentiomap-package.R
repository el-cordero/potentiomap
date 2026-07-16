#' Build potentiometric surfaces and hydraulic-gradient arrows
#'
#' potentiomap prepares groundwater-head observations, interpolates mapped
#' potentiometric surfaces, reports model diagnostics and prediction support,
#' creates contour inventories, and derives local hydraulic-gradient arrow
#' symbols. It is intended for hydrogeologists, environmental scientists, and
#' GIS users reviewing groundwater-level data.
#'
#' Main functions:
#'
#' - [ps_make_points()] and [ps_potentiometric_points()] prepare observations.
#' - [ps_interpolate()] and [ps_interpolate_grouped()] create surfaces.
#' - [ps_diagnostics()] and [ps_prediction_support()] describe model behavior
#'   and where predictions have limited observational support.
#' - [ps_contours()] inventories requested contour levels.
#' - [ps_flow_arrows()] and [ps_validate_arrows()] create and check local
#'   negative-gradient symbols.
#' - [ps_quicklook()] and [ps_export_surfaces()] review and save products.
#'
#' Hydraulic-gradient arrows are map symbols derived from the local gradient of
#' a modeled surface. Their lengths are display conventions. They are not
#' traced groundwater paths, groundwater velocities, or travel times. A finite
#' surface or a passing arrow-tip check does not establish hydrogeologic
#' validity; users should evaluate measurements, method assumptions, spatial
#' trend, prediction support, and intended map use.
#'
#' Project links:
#'
#' - Documentation: <https://el-cordero.github.io/potentiomap/>
#' - Source: <https://github.com/el-cordero/potentiomap>
#' - Issues: <https://github.com/el-cordero/potentiomap/issues>
#' - CRAN: <https://CRAN.R-project.org/package=potentiomap>
#'
#' Use `citation("potentiomap")` for citation guidance.
#'
#' @aliases potentiomap
#' @keywords internal
"_PACKAGE"
