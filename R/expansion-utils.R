.ps_schema_version <- "0.2.0-1"

.ps_empty_conditions <- function() {
  data.frame(
    condition_id = character(), type = character(), class = character(),
    text = character(), function_name = character(), method = character(),
    group_id = character(), fold_id = character(), run_id = character(),
    candidate_id = character(), region_id = character(),
    stringsAsFactors = FALSE
  )
}

.ps_condition_rows <- function(conditions = list(), function_name = NA_character_,
                               method = NA_character_, group_id = NA_character_,
                               fold_id = NA_character_, run_id = NA_character_,
                               candidate_id = NA_character_,
                               region_id = NA_character_) {
  if (!length(conditions)) return(.ps_empty_conditions())
  rows <- lapply(seq_along(conditions), function(i) {
    z <- conditions[[i]]
    data.frame(
      condition_id = sprintf("condition_%04d", i),
      type = if (inherits(z, "error")) "error" else if (inherits(z, "warning")) "warning" else "message",
      class = class(z)[1], text = conditionMessage(z),
      function_name = function_name, method = method, group_id = group_id,
      fold_id = fold_id, run_id = run_id, candidate_id = candidate_id,
      region_id = region_id, stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

.ps_new_result <- function(fields, class, call = NULL, settings = list(),
                           metadata = list(), conditions = NULL,
                           warnings = character(), errors = character(),
                           summary = NULL, seed = NULL) {
  if (is.null(conditions)) conditions <- .ps_empty_conditions()
  if (is.null(summary)) summary <- data.frame()
  out <- c(fields, list(
    summary = summary,
    settings = settings,
    metadata = metadata,
    conditions = conditions,
    warnings = unique(as.character(warnings)),
    errors = unique(as.character(errors)),
    seed = seed,
    package_version = .package_version_string(),
    schema_version = .ps_schema_version,
    call = call
  ))
  class(out) <- c(class, "potentiomap_analysis")
  out
}

#' @export
print.potentiomap_analysis <- function(x, ...) {
  cat(sprintf("<%s>\n", class(x)[1]))
  if (is.data.frame(x$summary) && nrow(x$summary)) {
    print(utils::head(x$summary, 8L), row.names = FALSE)
  } else if (is.list(x$summary) && length(x$summary)) {
    print(x$summary)
  }
  if (is.data.frame(x$conditions) && nrow(x$conditions)) {
    cat("  conditions:", nrow(x$conditions), "\n")
  }
  invisible(x)
}

.ps_progress <- function(progress, index, total, id, status) {
  if (is.null(progress)) return(invisible(NULL))
  if (!is.function(progress)) {
    .ps_abort("`progress` must be a function or NULL.", "potentiomap_input_error")
  }
  progress(index, total, id, status)
  invisible(NULL)
}

.ps_stable_hash <- function(x) {
  raw <- serialize(x, NULL, version = 2)
  value <- 0
  for (b in as.integer(raw)) value <- (value * 131 + b + 1) %% 2147483647
  sprintf("%08x", as.integer(value))
}

.ps_stable_ids <- function(prefix, n) {
  if (!length(n) || n <= 0L) return(character())
  sprintf(paste0(prefix, "_%0", max(4L, nchar(as.character(n))), "d"), seq_len(n))
}

.ps_scalar_logical <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    .ps_abort(sprintf("`%s` must be TRUE or FALSE.", name),
              "potentiomap_input_error")
  }
  x
}

.ps_scalar_character <- function(x, name, allow_null = FALSE) {
  if (is.null(x) && allow_null) return(NULL)
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    .ps_abort(sprintf("`%s` must be one nonempty character value.", name),
              "potentiomap_input_error")
  }
  x
}

.ps_standard_points <- function(points, value = "Z", id = NULL,
                                name = "points") {
  pts <- if (inherits(points, "SpatVector")) {
    .as_points(points, name)
  } else if (inherits(points, "sf") || inherits(points, "sfc")) {
    .as_points(points, name)
  } else if (is.data.frame(points)) {
    if (!all(c("x", "y") %in% names(points))) {
      .ps_abort(sprintf("`%s` tables must contain `x` and `y` columns.", name),
                "potentiomap_input_error")
    }
    crs <- attr(points, "crs", exact = TRUE)
    if (is.null(crs)) {
      .ps_abort(sprintf("`%s` table must have a `crs` attribute or be converted with `ps_make_points()`.", name),
                "potentiomap_crs_error")
    }
    ps_make_points(points, value = value, name_col = id, crs = crs)
  } else {
    .as_points(points, name)
  }
  .require_crs(pts, name)
  vals <- terra::values(pts)
  if (!value %in% names(vals)) {
    .ps_abort(sprintf("Column `%s` was not found in `%s`.", value, name),
              "potentiomap_input_error")
  }
  if (value != "Z") vals$Z <- suppressWarnings(as.numeric(vals[[value]]))
  if (!"Name" %in% names(vals)) {
    if (!is.null(id) && id %in% names(vals)) vals$Name <- as.character(vals[[id]])
    else vals$Name <- .ps_stable_ids("P", nrow(vals))
  }
  vals$Name <- as.character(vals$Name)
  if (anyNA(vals$Name) || any(!nzchar(vals$Name)) || anyDuplicated(vals$Name)) {
    .ps_abort(sprintf("`%s` must have unique nonmissing observation IDs.", name),
              "potentiomap_input_error")
  }
  vals$Z <- suppressWarnings(as.numeric(vals$Z))
  terra::values(pts) <- vals
  pts
}

.ps_get_metadata <- function(x) {
  if (inherits(x, "potentiomap_result")) return(x$input_summary$metadata %||% list())
  if (inherits(x, "potentiomap_analysis")) return(x$metadata %||% list())
  attr(x, "potentiomap_metadata", exact = TRUE) %||% list()
}

.ps_set_metadata <- function(x, metadata) {
  attr(x, "potentiomap_metadata") <- metadata
  x
}

.ps_surface_metadata <- function(x, supplied = NULL) {
  meta <- .ps_get_metadata(x)
  if (!is.null(supplied)) meta <- utils::modifyList(meta, supplied)
  list(
    head_unit = meta$output_unit %||% meta$head_unit %||% meta$unit %||% NULL,
    vertical_datum = meta$vertical_datum %||% NULL,
    surface_reference = meta$surface_reference %||% NULL,
    surface_type = meta$surface_type %||% "head",
    source = meta
  )
}

.ps_surfaces_input <- function(surfaces) {
  if (inherits(surfaces, "potentiomap_result")) surfaces <- surfaces$surfaces
  if (inherits(surfaces, "SpatRaster") && terra::nlyr(surfaces) > 1L) {
    layer_names <- names(surfaces)
    surfaces <- lapply(seq_len(terra::nlyr(surfaces)), function(i) surfaces[[i]])
    names(surfaces) <- layer_names
  }
  if (inherits(surfaces, "SpatRaster")) surfaces <- list(surface = surfaces)
  if (!is.list(surfaces) || !length(surfaces) ||
      any(!vapply(surfaces, inherits, logical(1), "SpatRaster"))) {
    .ps_abort("`surfaces` must be a nonempty named list of SpatRaster objects or a potentiomap_result.",
              "potentiomap_input_error")
  }
  if (is.null(names(surfaces)) || any(!nzchar(names(surfaces))) || anyDuplicated(names(surfaces))) {
    .ps_abort("`surfaces` must have unique nonempty names.",
              "potentiomap_input_error")
  }
  surfaces <- lapply(surfaces, .as_surface)
  surfaces
}

.ps_metadata_equal <- function(a, b, field) {
  x <- a[[field]]
  y <- b[[field]]
  if (is.null(x) || is.null(y)) return(TRUE)
  identical(tolower(as.character(x)), tolower(as.character(y)))
}

.ps_assert_surface_compatible <- function(a, b, require_geometry = TRUE,
                                          names = c("surface_a", "surface_b")) {
  a <- .as_surface(a, names[1])
  b <- .as_surface(b, names[2])
  .require_crs(a, names[1]); .require_crs(b, names[2])
  if (!.same_crs(a, b)) {
    .ps_abort(sprintf("`%s` and `%s` must use the same CRS.", names[1], names[2]),
              "potentiomap_crs_error")
  }
  if (require_geometry &&
      !isTRUE(terra::compareGeom(a, b, stopOnError = FALSE))) {
    .ps_abort(sprintf("`%s` and `%s` raster geometry differs; choose an explicit alignment option.",
                      names[1], names[2]),
              "potentiomap_input_error")
  }
  ma <- .ps_surface_metadata(a); mb <- .ps_surface_metadata(b)
  if (!.ps_metadata_equal(ma, mb, "head_unit")) {
    .ps_abort("Head-surface units are incompatible.", "potentiomap_metadata_error")
  }
  if (!.ps_metadata_equal(ma, mb, "vertical_datum")) {
    .ps_abort("Head-surface vertical datums are incompatible.",
              "potentiomap_metadata_error")
  }
  if (!.ps_metadata_equal(ma, mb, "surface_type")) {
    .ps_abort("Surface types are incompatible.", "potentiomap_metadata_error")
  }
  invisible(list(a = a, b = b, metadata_a = ma, metadata_b = mb))
}

.ps_geometry_record <- function(r, source) {
  e <- terra::ext(r)
  data.frame(
    source = source, crs = terra::crs(r, proj = TRUE),
    nrow = terra::nrow(r), ncol = terra::ncol(r),
    xres = terra::res(r)[1], yres = terra::res(r)[2],
    xmin = e[1], xmax = e[2], ymin = e[3], ymax = e[4],
    stringsAsFactors = FALSE
  )
}

.ps_align_pair <- function(a, b, align = c("error", "to_a", "to_b", "template"),
                           template = NULL, method = c("bilinear", "near"),
                           names = c("a", "b")) {
  align <- match.arg(align)
  method <- match.arg(method)
  a <- .as_surface(a, names[1]); b <- .as_surface(b, names[2])
  .require_crs(a, names[1]); .require_crs(b, names[2])
  original <- rbind(.ps_geometry_record(a, names[1]),
                    .ps_geometry_record(b, names[2]))
  if (align == "error") {
    .ps_assert_surface_compatible(a, b, TRUE, names)
    target <- "none"
  } else {
    .ps_assert_surface_compatible(a, b, FALSE, names)
    target_r <- switch(align, to_a = a, to_b = b,
                       template = .as_surface(template, "template"))
    .require_crs(target_r, "alignment target")
    if (align == "to_a") b <- terra::resample(b, target_r, method = method)
    if (align == "to_b") a <- terra::resample(a, target_r, method = method)
    if (align == "template") {
      a <- terra::resample(a, target_r, method = method)
      b <- terra::resample(b, target_r, method = method)
    }
    target <- align
  }
  list(a = a, b = b, manifest = list(
    action = align, target = target, method = method,
    source_geometry = original,
    result_geometry = .ps_geometry_record(a, "result")
  ))
}

.ps_common_support <- function(a, b) {
  av <- terra::values(a, mat = FALSE)
  bv <- terra::values(b, mat = FALSE)
  common <- is.finite(av) & is.finite(bv)
  only_a <- is.finite(av) & !is.finite(bv)
  only_b <- !is.finite(av) & is.finite(bv)
  make <- function(v, name) {
    r <- a; terra::values(r) <- as.integer(v); names(r) <- name; r
  }
  list(common = make(common, "common_support"),
       only_a = make(only_a, "only_a"), only_b = make(only_b, "only_b"),
       common_index = common, only_a_index = only_a, only_b_index = only_b)
}

.ps_cell_area_values <- function(r) {
  r <- .as_surface(r)
  if (!terra::is.lonlat(r)) {
    return(rep(abs(prod(terra::res(r))), terra::ncell(r)))
  }
  terra::values(terra::cellSize(r, unit = "m"), mat = FALSE)
}

.ps_gradient <- function(surface, min_gradient = 1e-5) {
  .validate_number(min_gradient, "min_gradient", lower = 0, inclusive = TRUE)
  r <- .as_surface(surface)
  .require_projected(r, "surface")
  terrain <- terra::terrain(r, v = c("slope", "aspect"), unit = "degrees")
  magnitude <- tan(terrain[["slope"]] * pi / 180)
  direction <- terrain[["aspect"]]
  mv <- terra::values(magnitude, mat = FALSE)
  dv <- terra::values(direction, mat = FALSE)
  flat <- !is.finite(mv) | mv < min_gradient
  dv[flat] <- NA_real_
  terra::values(direction) <- dv
  names(magnitude) <- "gradient_magnitude"
  names(direction) <- "down_gradient_direction"
  flat_r <- r; terra::values(flat_r) <- as.integer(flat); names(flat_r) <- "flat_or_undefined"
  list(magnitude = magnitude, direction = direction, flat = flat_r)
}

.ps_angle_difference <- function(a, b) {
  d <- abs(a - b) %% 360
  pmin(d, 360 - d)
}

.ps_metric_values <- function(observed, predicted, metrics = c("me", "mae", "rmse", "medae", "maxae"),
                              weights = NULL) {
  residual <- predicted - observed
  ok <- is.finite(observed) & is.finite(predicted)
  if (is.null(weights)) weights <- rep(1, length(observed))
  ok <- ok & is.finite(weights) & weights >= 0
  if (!any(ok) || sum(weights[ok]) <= 0) {
    out <- setNames(rep(NA_real_, length(metrics)), metrics)
    return(c(out, finite_fraction = mean(is.finite(predicted))))
  }
  w <- weights[ok] / sum(weights[ok]); e <- residual[ok]
  values <- c(
    me = sum(w * e), mae = sum(w * abs(e)), rmse = sqrt(sum(w * e^2)),
    medae = stats::median(abs(e)), maxae = max(abs(e)),
    correlation = if (sum(ok) > 1L) stats::cor(observed[ok], predicted[ok]) else NA_real_,
    r_squared = if (sum(ok) > 1L) stats::cor(observed[ok], predicted[ok])^2 else NA_real_
  )
  c(values[metrics], finite_fraction = mean(is.finite(predicted)))
}

.ps_safe_file <- function(file, overwrite = FALSE, class = "potentiomap_export_error") {
  .ps_scalar_character(file, "file")
  parent <- dirname(file)
  if (!dir.exists(parent)) {
    ok <- dir.create(parent, recursive = TRUE, showWarnings = FALSE)
    if (!ok) .ps_abort(sprintf("Could not create output directory `%s`.", parent), class)
  }
  if (file.exists(file) && !isTRUE(overwrite)) {
    .ps_abort(sprintf("Output `%s` already exists; set `overwrite = TRUE` to replace it.", file), class)
  }
  normalizePath(parent, mustWork = TRUE)
  invisible(file)
}

.ps_capture_run <- function(expr) {
  warnings <- list(); messages <- list(); error <- NULL; value <- NULL
  value <- tryCatch(
    withCallingHandlers(expr,
      warning = function(w) { warnings[[length(warnings) + 1L]] <<- w; invokeRestart("muffleWarning") },
      message = function(m) { messages[[length(messages) + 1L]] <<- m; invokeRestart("muffleMessage") }
    ),
    error = function(e) { error <<- e; NULL }
  )
  list(value = value, warnings = warnings, messages = messages, error = error)
}
