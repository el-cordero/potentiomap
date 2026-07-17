devtools::load_all(quiet = TRUE)
master_seed <- 20260717L
derived_seeds <- master_seed + seq_len(6L) - 1L
data("synthetic_wells")
p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
                    "well_id", "EPSG:26916")

results <- list()
for (i in seq_along(derived_seeds)) {
  set.seed(derived_seeds[i])
  results[[i]] <- ps_validate(p, "IDW", "spatial_block", folds = 4,
                              prediction_mode = "direct", seed = derived_seeds[i])
}

# Exercise compact clustered and elongated geometries without using study data.
clustered_data <- synthetic_wells
clustered_data$x <- mean(clustered_data$x) +
  (clustered_data$x - mean(clustered_data$x)) * 0.15
clustered_data$y <- mean(clustered_data$y) +
  (clustered_data$y - mean(clustered_data$y)) * 0.15
clustered <- ps_make_points(clustered_data, "x", "y", "gw_elevation",
                            "well_id", "EPSG:26916")
elongated_data <- synthetic_wells
elongated_data$y <- mean(elongated_data$y) +
  0.05 * (elongated_data$x - mean(elongated_data$x)) +
  seq_len(nrow(elongated_data))
elongated <- ps_make_points(elongated_data, "x", "y", "gw_elevation",
                            "well_id", "EPSG:26916")
geometry_fits <- list(
  clustered = ps_interpolate(clustered, methods = "IDW", grid_res = 20),
  elongated = ps_interpolate(elongated, methods = "IDW", grid_res = 75)
)

fit <- suppressWarnings(ps_interpolate(p, methods = "OK", grid_res = 75,
                                      return = "result"))
simulation <- suppressMessages(ps_surface_uncertainty(
  fit, approach = "conditional_simulation", nsim = 20,
  keep_realizations = TRUE, seed = master_seed
))
thinning <- ps_network_thinning(p, c(.75, .5), repeats = 5,
                                method = "IDW", grid_res = 100,
                                seed = master_seed)
tuning <- ps_tune_interpolation(p, "IDW",
  list(idw_power = seq(1, 3, .5), idw_nmax = c(8, 15, 24)),
  inner_design = "spatial_block", inner_folds = 4,
  maximum_runs = 200, refit = FALSE, seed = master_seed)

output_dir <- tempfile("potentiomap-stress-")
dir.create(output_dir)
on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)
backed <- terra::writeRaster(fit$surfaces$OK,
                             file.path(output_dir, "file-backed.tif"))
style <- ps_export_style(backed, file.path(output_dir, "style.sld"),
                         "sld", "head_raster")
limited <- fit$surfaces$OK
limited_values <- terra::values(limited, mat = FALSE)
limited_values[seq(1, length(limited_values), by = 11)] <- NA_real_
terra::values(limited) <- limited_values
missing_support <- ps_prediction_support(p, surface = limited)

# Repeated exports use distinct deterministic stubs and are removed on exit.
export_manifests <- lapply(1:3, function(i) ps_export_surfaces(
  list(OK = fit$surfaces$OK), output_dir,
  out_stub = sprintf("stress-%02d", i), vector_format = "gpkg",
  write_png = FALSE
))
protected_file <- export_manifests[[1]]$raster
protected_size <- file.info(protected_file)$size
protected_error <- try(ps_export_surfaces(
  list(OK = fit$surfaces$OK), output_dir, out_stub = "stress-01",
  vector_format = "gpkg", write_png = FALSE, overwrite = FALSE
), silent = TRUE)

# A non-directory destination exercises classed failed-write cleanup.
blocked_destination <- file.path(output_dir, "occupied")
writeLines("occupied", blocked_destination)
failed_write <- try(ps_export_surfaces(
  list(OK = fit$surfaces$OK), blocked_destination
), silent = TRUE)
if (rmarkdown::pandoc_available()) {
  for (i in 1:3) ps_report(results[[i]],
    file.path(output_dir, sprintf("report-%02d.html", i)),
    include_session = FALSE)
}

stopifnot(
  length(results) == length(derived_seeds),
  terra::nlyr(simulation$realizations) == 20,
  nrow(thinning$run_manifest) == 10,
  nrow(tuning$candidates) == 15,
  style$manifest$validated,
  all(vapply(geometry_fits, function(x) inherits(x$IDW, "SpatRaster"),
             logical(1))),
  any(terra::values(missing_support$rasters$finite_prediction,
                    mat = FALSE) == 0, na.rm = TRUE),
  length(export_manifests) == 3,
  inherits(protected_error, "try-error"),
  file.info(protected_file)$size == protected_size,
  inherits(failed_write, "try-error")
)
cat("Extended stress tests passed with master seed", master_seed, "\n")
