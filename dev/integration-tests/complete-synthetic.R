# Complete fixed-seed integration analysis using only package synthetic data.
devtools::load_all(quiet = TRUE)
set.seed(20260717)

data("synthetic_events")
data("synthetic_wells")
data("synthetic_nested_wells")
data("synthetic_regions")
data("synthetic_candidate_sites")
data("synthetic_anisotropic_points")
data("synthetic_transect")

spring <- subset(synthetic_events, event == "spring")
autumn <- subset(synthetic_events, event == "autumn")
attr(spring, "crs") <- "EPSG:26916"
qa <- ps_check_observations(spring, "x", "y", "head", "well_id",
                            "datetime", "unit", "vertical_datum")
event <- ps_select_event(spring, "well_id", "datetime",
                         as.POSIXct("2025-03-15 12:00", tz = "UTC"), 10800)
screen_rules <- data.frame(unit = c("upper", "lower"), top = c(150, 130), bottom = c(130, 110))
screen_groups <- suppressWarnings(ps_screen_groups(synthetic_nested_wells,
  "rules", screen_top = "screen_top", screen_bottom = "screen_bottom",
  rules = screen_rules, overlap_required = 0.5))

points <- ps_make_points(synthetic_wells[1:18, ], "x", "y", "gw_elevation",
                         "well_id", "EPSG:26916")
interpolation <- suppressWarnings(ps_interpolate(points,
  methods = c("IDW", "TPS", "OK"), grid_res = 300,
  support = TRUE, return = "result"))
validation <- ps_validate(points, c("IDW", "TPS"), "kfold", folds = 3,
                          prediction_mode = "direct", seed = 21)
comparison <- ps_compare_methods(validation, "rmse")
tuning <- ps_tune_interpolation(points, "IDW",
  data.frame(idw_power = c(1.5, 2)), inner_design = "kfold",
  inner_folds = 3, refit = FALSE, seed = 21)

empirical <- suppressWarnings(ps_variogram(points, directions = c(0, 90)))
variogram_models <- suppressWarnings(ps_variogram_compare(empirical, c("Sph", "Exp")))
anis_points <- ps_make_points(synthetic_anisotropic_points, "x", "y", "head",
                              "point_id", "EPSG:26916")
anisotropy <- suppressWarnings(ps_anisotropy(anis_points, minimum_pairs = 5))

template <- interpolation$template
land <- template
xy <- terra::xyFromCell(land, seq_len(terra::ncell(land)))
terra::values(land) <- 185 - 0.0005 * (xy[, 1] - mean(xy[, 1]))
names(land) <- "land_surface"
drift_points <- points
land_at_points <- terra::extract(land, drift_points)[[2]]
terra::values(drift_points)$Z <- 0.7 * land_at_points + 39
external_drift <- suppressWarnings(ps_interpolate(
  drift_points, methods = "UK", template = template,
  trend = Z ~ land_surface, covariates = list(land_surface = land),
  return = "result"
))

ensemble <- ps_surface_ensemble(interpolation$surfaces[c("IDW", "TPS")])
disagreement <- ps_method_disagreement(interpolation$surfaces[c("IDW", "TPS")])
ok_result <- suppressWarnings(ps_interpolate(points, methods = "OK",
                                             template = template,
                                             return = "result"))
uncertainty <- ps_surface_uncertainty(ok_result, approach = "kriging_variance")
contour_uncertainty <- ps_contour_uncertainty(
  uncertainty, levels = 168, method = "gaussian_pointwise",
  accept_gaussian = TRUE
)
contours <- ps_contours(interpolation$surfaces$IDW, interval = 1)
supported_contours <- suppressWarnings(ps_contour_support(
  contours, support = interpolation$support,
  supported_distance = 500, approximate_distance = 1000
))
arrows <- suppressWarnings(ps_flow_arrows(interpolation$surfaces$IDW,
                                          res_factor = 3, scale = 40))

pa <- ps_make_points(spring, "x", "y", "head", "well_id", "EPSG:26916")
pb <- ps_make_points(autumn, "x", "y", "head", "well_id", "EPSG:26916")
head_change <- ps_head_change(pa, pb, "well_id", method = "IDW", grid_res = 350)
vertical_gradient <- ps_vertical_gradient(10, 12, 100, 80, positive = "upward")
influence <- ps_well_influence(points[1:7], "IDW", grid_res = 400)
thinning <- ps_network_thinning(points[1:12], retain = 0.75, repeats = 2,
                                method = "IDW", grid_res = 400, seed = 6)
candidates <- terra::vect(subset(synthetic_candidate_sites, !excluded),
                          geom = c("x", "y"), crs = "EPSG:26916")
candidate_design <- ps_candidate_network(points, candidates, n_select = 2)
sensitivity <- ps_surface_sensitivity(points[1:14], "IDW",
  data.frame(idw_power = c(1.5, 2), grid_res = 350), reference = 1)

regions <- terra::vect(synthetic_regions, geom = "wkt", crs = "EPSG:26916")
domain <- terra::as.polygons(terra::ext(500000, 503000, 4640000, 4642500),
                             crs = "EPSG:26916")
domain_split <- ps_split_domain(domain, regions, "region_id")
regional <- ps_interpolate_regions(points, regions, "region_id", "IDW",
                                   grid_res = 350)
depth <- ps_depth_to_water_surface(interpolation$surfaces$IDW, land,
                                   "potentiometric")
transect <- terra::vect(synthetic_transect, geom = "wkt", crs = "EPSG:26916")
profile <- ps_surface_profile(transect,
  list(head = interpolation$surfaces$IDW, land = land), n = 12)
section <- ps_cross_section(transect, interpolation$surfaces$IDW, land,
                            step = 300, vertical_exaggeration = 3)

output_dir <- tempfile("potentiomap-integration-")
dir.create(output_dir)
on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
style <- ps_export_style(interpolation$surfaces$IDW,
                         file.path(output_dir, "head.qml"), "qml",
                         "head_raster", units = "m")
report <- if (rmarkdown::pandoc_available()) ps_report(
  validation, file.path(output_dir, "validation.html"), "html",
  include_session = FALSE
) else NULL

stopifnot(
  inherits(qa, "potentiomap_observation_check"),
  inherits(event, "potentiomap_event_selection"),
  inherits(screen_groups, "potentiomap_screen_groups"),
  inherits(interpolation, "potentiomap_result"),
  inherits(validation, "potentiomap_validation"),
  inherits(tuning, "potentiomap_tuning"),
  inherits(ensemble, "potentiomap_ensemble"),
  inherits(uncertainty, "potentiomap_uncertainty"),
  inherits(head_change, "potentiomap_head_change"),
  inherits(regional, "potentiomap_regional_result"),
  inherits(section, "potentiomap_cross_section"),
  style$manifest$validated,
  is.null(report) || file.exists(report$file)
)

cat("Complete synthetic integration analysis passed.\n")
