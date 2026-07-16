# Development-only synthetic resource benchmark.
# Run from the potentiomap package root.

if (!requireNamespace("terra", quietly = TRUE)) {
  stop("The 'terra' package is required.")
}

pkg_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(pkg_root, "DESCRIPTION"))) {
  stop("Run this script from the potentiomap package root.")
}

devtools_available <- requireNamespace("devtools", quietly = TRUE)
if (devtools_available) {
  devtools::load_all(pkg_root, quiet = TRUE)
} else if (!requireNamespace("potentiomap", quietly = TRUE)) {
  stop("Install potentiomap or install 'devtools' to load the source tree.")
}

set.seed(20260716)
n <- 80L
wells <- data.frame(
  x = stats::runif(n, 500000, 530000),
  y = stats::runif(n, 4640000, 4670000)
)
wells$head <- 170 - 0.00015 * (wells$x - 500000) +
  0.00008 * (wells$y - 4640000) + stats::rnorm(n, sd = 0.2)
wells$id <- sprintf("B%03d", seq_len(n))

points <- ps_make_points(
  wells, x = "x", y = "y", value = "head", name_col = "id",
  crs = "EPSG:26916"
)

target_cells <- c(10000L, 40000L, 160000L)
rows <- vector("list", length(target_cells))

for (i in seq_along(target_cells)) {
  target <- target_cells[[i]]
  resolution <- sqrt((30000 * 30000) / target)
  output_dir <- tempfile(sprintf("potentiomap-benchmark-%s-", target))
  dir.create(output_dir, recursive = TRUE)
  on.exit(unlink(output_dir, recursive = TRUE, force = TRUE), add = TRUE)

  elapsed <- system.time({
    surface <- ps_interpolate(
      points,
      methods = "IDW",
      grid_res = resolution,
      idw_nmax = 15,
      duplicate_action = "error"
    )$IDW
    arrows <- ps_flow_arrows(
      surface,
      scale = 25,
      res_factor = 12,
      endpoint_action = "shorten"
    )
    raster_path <- file.path(output_dir, "surface.tif")
    terra::writeRaster(surface, raster_path, overwrite = TRUE)
  })

  rows[[i]] <- data.frame(
    timestamp_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    os = paste(Sys.info()[c("sysname", "release", "machine")], collapse = " "),
    r_version = R.version.string,
    potentiomap_version = as.character(utils::packageVersion("potentiomap")),
    terra_version = as.character(utils::packageVersion("terra")),
    fields_version = as.character(utils::packageVersion("fields")),
    gstat_version = as.character(utils::packageVersion("gstat")),
    method = "IDW",
    target_cells = target,
    actual_rows = terra::nrow(surface),
    actual_columns = terra::ncol(surface),
    actual_cells = terra::ncell(surface),
    arrow_count = nrow(arrows$arrows),
    elapsed_seconds = unname(elapsed[["elapsed"]]),
    raster_bytes = unname(file.info(raster_path)$size),
    terra_tempdir = terra::terraOptions()$tempdir,
    stringsAsFactors = FALSE
  )
}

result <- do.call(rbind, rows)
results_dir <- file.path(pkg_root, "dev", "benchmarks", "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
output <- file.path(
  results_dir,
  paste0("resource-behavior-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".csv")
)
utils::write.csv(result, output, row.names = FALSE)
print(result)
message("Wrote ", output)
