# Generate deterministic homepage and 0.2.0 gallery assets from package outputs.
# Run from the package root with: Rscript data-raw/make-website-figures.R

if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("Install devtools before running this script.", call. = FALSE)
}

devtools::load_all(".", quiet = TRUE)
suppressPackageStartupMessages(library(terra))
set.seed(20260717)

dir.create("pkgdown/assets/gallery", recursive = TRUE, showWarnings = FALSE)
dir.create("pkgdown/assets", recursive = TRUE, showWarnings = FALSE)

data("synthetic_wells", package = "potentiomap")
data("synthetic_events", package = "potentiomap")
data("synthetic_candidate_sites", package = "potentiomap")
data("synthetic_transect", package = "potentiomap")

head_cols <- hcl.colors(64, "RdYlBu", rev = TRUE)
diff_cols <- hcl.colors(64, "Blue-Red 3", rev = TRUE)

open_png <- function(file, width = 1500, height = 1000) {
  grDevices::png(file, width = width, height = height, res = 150)
  graphics::par(bg = "white", fg = "#17252d", col.axis = "#17252d",
                col.lab = "#17252d", col.main = "#17252d")
}

close_png <- function() {
  grDevices::dev.off()
}

draw_flow <- function(x, col = "#17252d", length = 0.045) {
  base <- terra::crds(ps_arrow_vertices(x, "first"))
  tip <- terra::crds(ps_arrow_vertices(x, "last"))
  length_xy <- sqrt((base[, 1] - tip[, 1])^2 + (base[, 2] - tip[, 2])^2)
  keep <- is.finite(base[, 1]) & is.finite(base[, 2]) &
    is.finite(tip[, 1]) & is.finite(tip[, 2]) & length_xy > 1
  graphics::arrows(base[keep, 1], base[keep, 2], tip[keep, 1], tip[keep, 2],
                   length = length, angle = 24, col = col, lwd = 1.15)
}

points <- ps_make_points(
  synthetic_wells[1:18, ],
  "x", "y", "gw_elevation", "well_id", "EPSG:26916"
)
fit <- ps_interpolate(
  points,
  methods = c("IDW", "TPS", "OK"),
  grid_res = 300,
  support = TRUE,
  return = "result"
)
contours <- ps_contours(fit$surfaces$IDW, interval = 1)
contour_support <- ps_contour_support(
  contours,
  support = fit$support,
  supported_distance = 500,
  approximate_distance = 1000
)
flow <- ps_flow_arrows(
  fit$surfaces$IDW,
  res_factor = 3,
  scale = 40,
  endpoint_action = "shorten"
)

# Homepage: requested surface/arrows and contour-support overview.
open_png("man/figures/home-overview.png", width = 1800, height = 760)
par(mfrow = c(1, 2), mar = c(2.5, 2.5, 3.2, 1))
plot(fit$surfaces$IDW, col = head_cols,
     main = "Modeled surface and gradient direction", axes = FALSE)
plot(contours, add = TRUE, col = "#52646d", lwd = 0.8)
draw_flow(flow$arrows, length = 0.04)
plot(points, add = TRUE, pch = 21, bg = "white", cex = 0.55)
plot(contour_support, legend_position = NULL,
     main = "Contour support: user-defined criteria")
plot(points, add = TRUE, pch = 21, bg = "white", cex = 0.55)
legend("bottomright", c("supported", "approximate", "unsupported"),
       lty = c(1, 2, 3), title = "Criteria", cex = 0.78, bty = "n")
close_png()

# Observation QA and selected monitoring-event timing.
spring <- subset(synthetic_events, event == "spring")
attr(spring, "crs") <- "EPSG:26916"
qa <- ps_check_observations(
  spring, "x", "y", "head", "well_id", "datetime", "unit",
  "vertical_datum"
)
event <- ps_select_event(
  spring, "well_id", "datetime",
  as.POSIXct("2025-03-15 12:00", tz = "UTC"), 3 * 60 * 60
)
open_png("pkgdown/assets/gallery/22-observation-qa-events.png")
par(mfrow = c(1, 2), mar = c(7, 4, 3.2, 1))
qa_counts <- unlist(qa$summary[1, c("retained_count", "removed_count",
                                   "warning_count", "error_count")])
barplot(qa_counts, names.arg = c("retained", "removed", "warnings", "errors"),
        las = 2, col = c("#4f9daf", "#d77c63", "#f3cf72", "#a4492d"),
        border = NA, ylab = "Record count", main = "Observation QA")
selected_order <- order(event$selected$datetime)
plot(event$selected$datetime[selected_order], seq_along(selected_order),
     pch = 21, bg = "#176b87", yaxt = "n",
     xlab = "Selected time (UTC)", ylab = "Well",
     main = "Selected spring event")
axis(2, at = seq_along(selected_order),
     labels = event$selected$well_id[selected_order], las = 2, cex.axis = 0.62)
abline(v = as.POSIXct("2025-03-15 12:00", tz = "UTC"),
       lty = 2, col = "#a4492d")
close_png()

# Validation outcomes for the declared held-out-well task.
validation <- ps_validate(
  points, methods = c("IDW", "TPS"), design = "kfold", folds = 3,
  prediction_mode = "direct", seed = 21
)
comparison <- ps_compare_methods(validation, metric = "rmse")
open_png("pkgdown/assets/gallery/23-validation-comparison.png")
par(mfrow = c(1, 2), mar = c(4, 4, 3.2, 1))
ps_validation_plot(validation, type = "observed_predicted")
title(main = "Held-out synthetic wells")
barplot(comparison$ranking$rmse,
        names.arg = comparison$ranking$method,
        col = "#4f9daf", border = NA,
        ylab = "RMSE (synthetic head units)",
        main = "Three-fold validation")
close_png()

# Prediction-support classes.
open_png("pkgdown/assets/gallery/24-prediction-support.png")
par(mar = c(3, 3, 3.2, 5))
plot(fit$support$rasters[["support_class_code"]],
     col = c("#d8efe8", "#f3cf72", "#d77c63"),
     main = "Prediction support (user-defined criteria)")
plot(points, add = TRUE, pch = 21, bg = "white", cex = 0.7)
close_png()

# Descriptive method disagreement.
disagreement <- ps_method_disagreement(fit$surfaces[c("IDW", "TPS")])
open_png("pkgdown/assets/gallery/25-method-disagreement.png")
par(mar = c(3, 3, 3.2, 5))
plot(disagreement$rasters[["range"]], col = hcl.colors(64, "YlOrRd"),
     main = "IDW–TPS head range")
plot(points, add = TRUE, pch = 21, bg = "white", cex = 0.7)
close_png()

# Model-conditional ordinary-kriging standard error.
ok_uncertainty <- ps_surface_uncertainty(
  ps_interpolate(points, methods = "OK", template = fit$template,
                 return = "result"),
  approach = "kriging_variance"
)
open_png("pkgdown/assets/gallery/26-kriging-uncertainty.png")
par(mar = c(3, 3, 3.2, 5))
plot(ok_uncertainty$standard_deviation, col = hcl.colors(64, "YlOrRd"),
     main = "Ordinary-kriging prediction standard error")
plot(points, add = TRUE, pch = 21, bg = "white", cex = 0.7)
close_png()

# Modeled event difference.
autumn <- subset(synthetic_events, event == "autumn")
spring_points <- ps_make_points(spring, "x", "y", "head", "well_id", "EPSG:26916")
autumn_points <- ps_make_points(autumn, "x", "y", "head", "well_id", "EPSG:26916")
change <- ps_head_change(
  spring_points, autumn_points, "well_id", method = "IDW", grid_res = 350
)
change_limit <- max(abs(minmax(change$modeled_change)), na.rm = TRUE)
open_png("pkgdown/assets/gallery/27-head-change.png")
par(mar = c(3, 3, 3.2, 5))
plot(change$modeled_change, col = diff_cols,
     range = c(-change_limit, change_limit),
     main = "Modeled head change: autumn minus spring")
plot(spring_points, add = TRUE, pch = 21, bg = "white", cex = 0.65)
close_png()

# Leave-one-well influence.
influence <- ps_well_influence(points[1:7], method = "IDW", grid_res = 400)
open_png("pkgdown/assets/gallery/28-well-influence.png")
par(mar = c(8, 4, 3.2, 1))
influence_order <- order(influence$influence$rmse_difference, decreasing = TRUE)
barplot(influence$influence$rmse_difference[influence_order],
        names.arg = influence$influence$well_id[influence_order], las = 2,
        col = "#4f9daf", border = NA,
        ylab = "Leave-one-well surface RMSE difference",
        main = "Monitoring-well influence under IDW")
close_png()

# Constrained candidate set and selected sequence.
candidate_points <- vect(
  subset(synthetic_candidate_sites, !excluded),
  geom = c("x", "y"), crs = "EPSG:26916"
)
candidate_design <- ps_candidate_network(
  points, candidate_points, objective = "spatial_coverage", n_select = 2
)
selected_indices <- as.integer(sub(
  "candidate_0+", "", candidate_design$selected_sequence$candidate_id
))
selected_points <- candidate_points[selected_indices]
open_png("pkgdown/assets/gallery/29-candidate-network.png")
par(mar = c(3, 3, 3.2, 1))
plot(points, pch = 21, bg = "#176b87", cex = 0.9,
     main = "Existing network and feasible candidates")
plot(candidate_points, add = TRUE, pch = 24, bg = "#f3cf72", cex = 1.2)
plot(selected_points, add = TRUE, pch = 24, bg = "#d65f4b", cex = 1.55)
legend("bottomleft", c("existing", "candidate", "selected"),
       pch = c(21, 24, 24),
       pt.bg = c("#176b87", "#f3cf72", "#d65f4b"), bty = "n")
close_png()

# Depth/profile and plot-ready cross-section.
land <- fit$template
xy <- xyFromCell(land, seq_len(ncell(land)))
values(land) <- 185 - 0.0005 * (xy[, 1] - mean(xy[, 1]))
names(land) <- "land_surface"
depth <- ps_depth_to_water_surface(
  fit$surfaces$IDW, land, surface_type = "potentiometric"
)
transect <- vect(synthetic_transect, geom = "wkt", crs = "EPSG:26916")
profile <- ps_surface_profile(
  transect, list(head = fit$surfaces$IDW, land = land), n = 12
)
section <- ps_cross_section(
  transect, fit$surfaces$IDW, land, step = 300, vertical_exaggeration = 3
)
open_png("pkgdown/assets/gallery/30-depth-profile-section.png")
par(mfrow = c(1, 2), mar = c(4, 4, 3.2, 1))
plot(depth$depth, col = hcl.colors(64, "YlGnBu"),
     main = "Depth to modeled potentiometric surface")
plot(transect, add = TRUE, col = "#a4492d", lwd = 2)
plot(section, lwd = 2, col = "#176b87",
     main = "Transect section (3× vertical exaggeration)")
legend("bottomleft", c("modeled head", "land"), lty = c(1, 2),
       col = c("#176b87", "black"), bty = "n")
close_png()

message("Generated homepage overview and gallery assets 22–30.")
