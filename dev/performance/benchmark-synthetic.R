# Representative serial benchmarks for the 0.2.0 release candidate.
# Run outside routine package checks. All inputs are public synthetic fixtures.
devtools::load_all(quiet = TRUE)
data("synthetic_wells")
points <- ps_make_points(
  synthetic_wells, "x", "y", "gw_elevation", "well_id", "EPSG:26916"
)
output_dir <- tempfile("potentiomap-benchmark-")
dir.create(output_dir)
on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)

rows <- list()
record <- function(label, input_size, raster_size, method, expression) {
  started <- proc.time()[["elapsed"]]
  value <- suppressWarnings(suppressMessages(force(expression)))
  elapsed <- proc.time()[["elapsed"]] - started
  rows[[length(rows) + 1L]] <<- data.frame(
    function_name = label,
    input_size = input_size,
    raster_size = raster_size,
    method = method,
    elapsed_seconds = round(elapsed, 3),
    output_bytes = as.numeric(object.size(value)),
    stringsAsFactors = FALSE
  )
  value
}

idw <- record(
  "ps_interpolate", nrow(points), "100 m cells", "IDW",
  ps_interpolate(points, methods = "IDW", grid_res = 100,
                 return = "result", support = TRUE)
)
validation <- record(
  "ps_validate", nrow(points), "direct predictions", "IDW, 3-fold",
  ps_validate(points, methods = "IDW", design = "kfold", folds = 3,
              prediction_mode = "direct", seed = 20260717)
)
tuning <- record(
  "ps_tune_interpolation", nrow(points), "direct predictions",
  "IDW, 3 candidates x 3 folds",
  ps_tune_interpolation(
    points, "IDW", data.frame(idw_power = c(1.5, 2, 2.5)),
    inner_design = "kfold", inner_folds = 3, refit = FALSE,
    seed = 20260717
  )
)
ok <- record(
  "ps_interpolate", nrow(points), "150 m cells", "ordinary kriging",
  ps_interpolate(points, methods = "OK", grid_res = 150, return = "result")
)
simulation <- record(
  "ps_surface_uncertainty", nrow(points),
  paste(terra::nrow(ok$template), "x", terra::ncol(ok$template), "cells"),
  "10 conditional simulations",
  ps_surface_uncertainty(ok, approach = "conditional_simulation", nsim = 10,
                         keep_realizations = TRUE, seed = 20260717)
)
thinning <- record(
  "ps_network_thinning", min(18, nrow(points)), "200 m cells",
  "IDW, 3 replicates",
  ps_network_thinning(points[seq_len(min(18, nrow(points)))], retain = 0.75,
                      repeats = 3, method = "IDW", grid_res = 200,
                      seed = 20260717)
)
if (rmarkdown::pandoc_available()) {
  report <- record(
    "ps_report", nrow(validation$predictions), "not applicable", "HTML",
    ps_report(validation, file.path(output_dir, "benchmark.html"),
              include_session = FALSE)
  )
}

results <- do.call(rbind, rows)
write.csv(results, row.names = FALSE)
