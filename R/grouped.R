#' Interpolate grouped groundwater observations
#'
#' Runs separate analyses for explicit event, aquifer, water-bearing-unit,
#' season, or other grouping columns. Training records are never combined across
#' groups. A shared template controls only output geometry; it does not share
#' observations or fit information.
#'
#' @param data Observation data accepted by [ps_make_points()].
#' @param group_cols One or more explicit grouping columns.
#' @param value,x,y,name_col,crs Point-preparation arguments.
#' @param template_mode `"shared"` for one output grid or `"group"` for a grid
#'   derived independently within each group.
#' @param mask Optional shared mask, or a named list when `mask_mode = "group"`.
#' @param mask_mode `"shared"` or `"group"`.
#' @param output_dir Optional directory for group exports. No files are written
#'   when `NULL`.
#' @param progress Optional function called as
#'   `progress(index, total, group_id, status)`.
#' @param ... Arguments passed to [ps_interpolate()]. Structured results are
#'   always retained by group.
#'
#' @return A `potentiomap_grouped_result` containing `results`, a deterministic
#'   `manifest`, `group_keys`, captured `conditions`, and the original `call`.
#'   Empty and failed groups remain in the manifest.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' grouped <- transform(
#'   synthetic_wells,
#'   event = rep(c("spring", "autumn"), each = 16),
#'   unit = rep(c("upper", "lower"), times = 16)
#' )
#' result <- ps_interpolate_grouped(
#'   grouped, c("event", "unit"), value = "gw_elevation",
#'   name_col = "well_id", crs = "EPSG:26916",
#'   methods = "IDW", grid_res = 300
#' )
#' result$manifest
ps_interpolate_grouped <- function(data, group_cols, value = "Z",
                                   x = "x", y = "y", name_col = NULL,
                                   crs = NULL,
                                   template_mode = c("shared", "group"),
                                   mask = NULL,
                                   mask_mode = c("shared", "group"),
                                   output_dir = NULL, progress = NULL, ...) {
  call <- match.call()
  template_mode <- match.arg(template_mode)
  mask_mode <- match.arg(mask_mode)
  if (!is.character(group_cols) || !length(group_cols) || anyNA(group_cols) ||
      any(!nzchar(group_cols)) || anyDuplicated(group_cols)) {
    .ps_abort("`group_cols` must contain unique nonempty column names.",
              "potentiomap_input_error")
  }
  if (!is.null(progress) && !is.function(progress)) {
    .ps_abort("`progress` must be a function or NULL.",
              "potentiomap_input_error")
  }
  pts <- if (inherits(data, "SpatVector") && "Z" %in% names(terra::values(data))) {
    .as_points(data, "data")
  } else {
    ps_make_points(data, x = x, y = y, value = value,
                   name_col = name_col, crs = crs)
  }
  values <- terra::values(pts)
  missing_groups <- setdiff(group_cols, names(values))
  if (length(missing_groups)) {
    .ps_abort(
      sprintf("Grouping column(s) not found: %s.",
              paste(missing_groups, collapse = ", ")),
      "potentiomap_input_error"
    )
  }
  key_source <- if (is.data.frame(data) &&
                    all(group_cols %in% names(data))) data[group_cols] else values[group_cols]
  key_values <- lapply(key_source, function(z) {
    if (is.factor(z)) levels(z) else sort(unique(as.character(z)), na.last = TRUE)
  })
  key_grid <- do.call(expand.grid, c(key_values, stringsAsFactors = FALSE))
  names(key_grid) <- group_cols
  if (!nrow(key_grid)) {
    .ps_abort("No grouping combinations are available.",
              "potentiomap_input_error")
  }
  key_grid$group_id <- apply(key_grid, 1, function(z) .safe_name(paste(z, collapse = "__")))
  if (anyDuplicated(key_grid$group_id)) {
    key_grid$group_id <- paste0(key_grid$group_id, "_", seq_len(nrow(key_grid)))
  }
  dots <- list(...)
  dots$return <- NULL
  requested_methods <- dots$methods %||% "TPS"
  if (!is.character(requested_methods)) requested_methods <- names(requested_methods) %||% "custom"

  shared_template <- dots$template
  if (template_mode == "shared" && is.null(shared_template)) {
    shared_template <- .surface_template(
      pts, dots$grid_res %||% NULL, NULL,
      if (mask_mode == "shared") mask else NULL,
      dots$padding %||% NULL
    )
  }
  results <- list()
  manifest_rows <- list()
  condition_rows <- list()
  total <- nrow(key_grid)
  for (i in seq_len(total)) {
    key <- key_grid[i, , drop = FALSE]
    selected <- rep(TRUE, nrow(values))
    for (column in group_cols) {
      target <- as.character(key[[column]])
      observed <- as.character(values[[column]])
      selected <- selected & if (is.na(target)) is.na(observed) else observed == target
    }
    group_points <- pts[selected]
    group_id <- key$group_id
    if (!nrow(group_points)) {
      manifest_rows[[group_id]] <- .group_manifest_rows(
        key, requested_methods, 0L, 0L, "empty", FALSE,
        warnings = "", errors = "", outputs = ""
      )
      if (!is.null(progress)) progress(i, total, group_id, "empty")
      next
    }
    group_mask <- if (mask_mode == "shared") mask else {
      if (!is.list(mask) || is.null(mask[[group_id]])) NULL else mask[[group_id]]
    }
    args <- c(
      list(points = group_points, return = "result"), dots,
      list(mask = group_mask)
    )
    args$template <- if (template_mode == "shared") shared_template else dots$template
    captured_warnings <- character()
    captured_messages <- character()
    error_text <- ""
    result <- tryCatch(
      withCallingHandlers(
        do.call(ps_interpolate, args),
        warning = function(w) {
          captured_warnings <<- c(captured_warnings, conditionMessage(w))
          invokeRestart("muffleWarning")
        },
        message = function(m) {
          captured_messages <<- c(captured_messages, conditionMessage(m))
          invokeRestart("muffleMessage")
        }
      ),
      error = function(e) {
        error_text <<- conditionMessage(e)
        NULL
      }
    )
    if (is.null(result)) {
      manifest_rows[[group_id]] <- .group_manifest_rows(
        key, requested_methods, nrow(group_points), nrow(group_points),
        "failed", FALSE, paste(unique(captured_warnings), collapse = " | "),
        error_text, ""
      )
      if (!is.null(progress)) progress(i, total, group_id, "failed")
      next
    }
    results[[group_id]] <- result
    output_paths <- ""
    if (!is.null(output_dir)) {
      group_dir <- file.path(output_dir, group_id)
      exports <- ps_export_surfaces(result, group_dir, out_stub = group_id)
      output_paths <- paste(unlist(exports[, -1, drop = FALSE]), collapse = " | ")
    }
    manifest_rows[[group_id]] <- .group_manifest_rows(
      key, names(result$surfaces), nrow(group_points), result$observation_count,
      "success", TRUE, paste(unique(captured_warnings), collapse = " | "),
      "", output_paths
    )
    if (nrow(result$conditions)) {
      group_conditions <- result$conditions
      group_conditions$group_id <- group_id
      condition_rows[[group_id]] <- group_conditions
    }
    if (!is.null(progress)) progress(i, total, group_id, "success")
  }
  manifest <- do.call(rbind, manifest_rows)
  rownames(manifest) <- NULL
  conditions <- if (length(condition_rows)) {
    out <- do.call(rbind, condition_rows)
    rownames(out) <- NULL
    out
  } else data.frame(
    method = character(), type = character(), class = character(),
    text = character(), group_id = character(), stringsAsFactors = FALSE
  )
  out <- list(results = results, manifest = manifest,
              group_keys = key_grid, conditions = conditions, call = call)
  class(out) <- "potentiomap_grouped_result"
  out
}

.group_manifest_rows <- function(key, methods, input_count, retained_count,
                                 status, surface_available, warnings, errors,
                                 outputs) {
  methods <- as.character(methods)
  base <- key[rep(1, length(methods)), , drop = FALSE]
  base$method <- methods
  base$input_count <- input_count
  base$retained_count <- retained_count
  base$status <- status
  base$surface_available <- surface_available
  base$warnings <- warnings
  base$errors <- errors
  base$output_paths <- outputs
  base
}

#' @export
print.potentiomap_grouped_result <- function(x, ...) {
  cat("<potentiomap_grouped_result>\n")
  cat("  groups:", nrow(x$group_keys), "\n")
  print(table(x$manifest$status))
  invisible(x)
}
