#' Generate hydraulic-gradient arrows
#'
#' Derives the local negative modeled-head gradient from a potentiometric
#' surface. Arrow direction comes from raster aspect; arrow length is a display
#' convention based on gradient, raster resolution, and `scale`. Arrows are map
#' symbols, not groundwater velocities, travel times, particle paths, or traced
#' groundwater paths.
#'
#' Endpoint checking compares each straight line with the supplied raster. It
#' can flag, shorten, or drop lines whose tip is nonfinite or higher than the
#' base. Shortening retains the original direction and repeatedly halves length;
#' arrows are never reversed or bent. A passing check does not establish that
#' the interpolated surface is physically correct.
#'
#' @param surface A one-layer groundwater-elevation `SpatRaster`.
#' @param res_factor Positive integer used to thin arrows on a coarser grid.
#' @param scale Positive cartographic length multiplier.
#' @param min_gradient Nonnegative gradient threshold.
#' @param log_gradient Store `log1p()` gradient in the returned raster.
#' @param log_arrow Use `log1p()` gradient for arrow display length.
#' @param out_dir Optional output directory. No files are written when `NULL`.
#' @param out_stub Safe file prefix.
#' @param endpoint_action One of `"flag"`, `"shorten"`, `"drop"`, or `"none"`.
#'   `"flag"` preserves geometry and warns; `"shorten"` retains direction while
#'   reducing failed lines; `"drop"` removes failures; `"none"` reproduces the
#'   version 0.1.0 unvalidated geometry.
#' @param endpoint_tolerance Nonnegative head tolerance.
#' @param endpoint_extraction Either `"bilinear"` or `"simple"` raster
#'   extraction.
#' @param max_shortening Positive maximum number of length halvings.
#' @param overwrite Overwrite gradient files when `out_dir` is supplied.
#'
#' @return A list containing at least `raster`, `points`, and `arrows`, plus
#'   `tips`, `bases`, `validation`, and `validation_summary`.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' surface <- ps_interpolate(pts, methods = "IDW", grid_res = 150)$IDW
#' flow <- ps_flow_arrows(surface, res_factor = 6, scale = 30,
#'                        endpoint_action = "shorten")
#' flow$validation_summary
ps_flow_arrows <- function(surface, res_factor = 7, scale = 50,
                           min_gradient = 1e-5, log_gradient = FALSE,
                           log_arrow = FALSE, out_dir = NULL,
                           out_stub = "gw",
                           endpoint_action = c("flag", "shorten", "drop", "none"),
                           endpoint_tolerance = 1e-6,
                           endpoint_extraction = c("bilinear", "simple"),
                           max_shortening = 12L, overwrite = TRUE) {
  endpoint_action <- match.arg(endpoint_action)
  endpoint_extraction <- match.arg(endpoint_extraction)
  .validate_integer(res_factor, "res_factor", lower = 0)
  .validate_number(scale, "scale", lower = 0)
  .validate_number(min_gradient, "min_gradient", lower = 0, inclusive = TRUE)
  .validate_number(endpoint_tolerance, "endpoint_tolerance", lower = 0,
                   inclusive = TRUE)
  .validate_integer(max_shortening, "max_shortening", lower = 0)
  if (!is.logical(log_gradient) || length(log_gradient) != 1L || is.na(log_gradient) ||
      !is.logical(log_arrow) || length(log_arrow) != 1L || is.na(log_arrow)) {
    .ps_abort("`log_gradient` and `log_arrow` must be TRUE or FALSE.",
              "potentiomap_input_error")
  }
  r <- .as_surface(surface)
  .require_crs(r, "surface")
  gwe <- r
  names(gwe) <- "gwe"
  slope_capture <- try(terra::terrain(gwe, v = "slope", unit = "radians"),
                       silent = TRUE)
  slope_rad <- if (inherits(slope_capture, "try-error")) {
    terra::terrain(gwe, v = "slope", unit = "degrees") * pi / 180
  } else slope_capture
  igrad <- tan(slope_rad)
  aspect <- terra::terrain(gwe, v = "aspect", unit = "degrees")
  igrad[igrad < min_gradient] <- NA
  igrad_out <- if (log_gradient) log1p(igrad) else igrad
  gradient_raster <- c(gwe, igrad_out, aspect)
  names(gradient_raster) <- c("gwe", "igrad", "aspect")

  coarse <- terra::rast(
    crs = terra::crs(r), ext = terra::ext(r),
    res = terra::res(r) * res_factor
  )
  sampled <- c(
    terra::resample(gwe, coarse, method = "bilinear"),
    terra::resample(igrad_out, coarse, method = "bilinear"),
    terra::resample(aspect, coarse, method = "near")
  )
  names(sampled) <- c("gwe", "igrad", "aspect")
  pts <- terra::as.points(sampled)
  vals <- terra::values(pts)
  keep <- is.finite(vals$igrad) & is.finite(vals$aspect)
  pts <- pts[keep]
  vals <- terra::values(pts)
  coords <- terra::crds(pts)

  if (!nrow(coords)) {
    arrows <- .empty_lines(terra::crs(r))
  } else {
    theta <- vals$aspect * pi / 180
    lengths <- if (log_arrow) log1p(vals$igrad) else vals$igrad
    arrow_len <- lengths * mean(terra::res(sampled)) * scale
    line_geoms <- lapply(seq_len(nrow(coords)), function(i) rbind(
      coords[i, ],
      c(coords[i, 1] + sin(theta[i]) * arrow_len[i],
        coords[i, 2] + cos(theta[i]) * arrow_len[i])
    ))
    arrows <- terra::vect(line_geoms, type = "lines", crs = terra::crs(r))
    vals$arrow_id <- seq_len(nrow(vals))
    terra::values(arrows) <- vals
  }

  handled <- .handle_arrow_endpoints(
    r, arrows, endpoint_action, endpoint_tolerance,
    endpoint_extraction, max_shortening
  )
  arrows <- handled$arrows
  bases <- ps_arrow_vertices(arrows, "first")
  tips <- ps_arrow_vertices(arrows, "last")

  if (!is.null(out_dir)) {
    if (!is.character(out_dir) || length(out_dir) != 1L || !nzchar(out_dir)) {
      .ps_abort("`out_dir` must be one nonempty path.",
                "potentiomap_export_error")
    }
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(out_dir)) {
      .ps_abort(sprintf("Could not create output directory `%s`.", out_dir),
                "potentiomap_export_error")
    }
    stub <- .safe_name(out_stub)
    files <- c(
      file.path(out_dir, paste0(stub, "_hgrad.tif")),
      file.path(out_dir, paste0(stub, "_hgrad_points.shp")),
      file.path(out_dir, paste0(stub, "_hgrad_arrows.shp"))
    )
    if (!overwrite && any(file.exists(files))) {
      .ps_abort("Gradient output exists and `overwrite = FALSE`.",
                "potentiomap_export_error")
    }
    written <- character()
    tryCatch({
      terra::writeRaster(gradient_raster, files[1], overwrite = overwrite)
      written <- c(written, files[1])
      terra::writeVector(pts, files[2], overwrite = overwrite)
      written <- c(written, files[2])
      terra::writeVector(arrows, files[3], overwrite = overwrite)
      written <- c(written, files[3])
    }, error = function(e) {
      unlink(written)
      .ps_abort(
        paste0("Could not write hydraulic-gradient products: ",
               conditionMessage(e)),
        "potentiomap_export_error"
      )
    })
  }
  list(
    raster = gradient_raster, points = pts, arrows = arrows,
    tips = tips, bases = bases,
    validation = handled$records,
    validation_summary = handled$summary
  )
}

#' Validate hydraulic-gradient arrow endpoints
#'
#' Samples modeled head at each line base and tip and checks finite raster
#' support along the line. A downhill pass requires a finite line and a tip no
#' higher than the base within `tolerance`. Geometry is not reversed or bent.
#'
#' @param surface One-layer modeled-head `SpatRaster`.
#' @param arrows Line `SpatVector` or readable vector path.
#' @param tolerance Nonnegative head tolerance.
#' @param extraction Either `"bilinear"` or `"simple"` endpoint extraction.
#'
#' @return A `potentiomap_arrow_validation` list with validated `arrows`, an
#'   arrow-level `records` data frame, and a concise `summary`.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' surface <- ps_interpolate(pts, methods = "IDW", grid_res = 150)$IDW
#' legacy <- ps_flow_arrows(surface, endpoint_action = "none")
#' checked <- ps_validate_arrows(surface, legacy$arrows)
#' checked$summary
ps_validate_arrows <- function(surface, arrows, tolerance = 1e-6,
                               extraction = c("bilinear", "simple")) {
  extraction <- match.arg(extraction)
  .validate_number(tolerance, "tolerance", lower = 0, inclusive = TRUE)
  r <- .as_surface(surface)
  lines <- if (inherits(arrows, "SpatVector")) arrows else tryCatch(
    terra::vect(arrows),
    error = function(e) .ps_abort("`arrows` must be a readable line vector.",
                                  "potentiomap_input_error")
  )
  if (nrow(lines) > 0L && terra::geomtype(lines) != "lines") {
    .ps_abort("`arrows` must contain line geometries.",
              "potentiomap_input_error")
  }
  if (!.same_crs(r, lines)) {
    .ps_abort("`surface` and `arrows` must use the same CRS.",
              "potentiomap_crs_error")
  }
  records <- .arrow_records(r, lines, tolerance, extraction)
  out <- list(arrows = lines, records = records,
              summary = .arrow_summary(records, nrow(lines)))
  class(out) <- "potentiomap_arrow_validation"
  out
}

#' @export
print.potentiomap_arrow_validation <- function(x, ...) {
  cat("<potentiomap_arrow_validation>\n")
  print(x$summary, row.names = FALSE)
  invisible(x)
}

.handle_arrow_endpoints <- function(surface, arrows, action, tolerance,
                                    extraction, max_shortening) {
  if (action == "none") {
    records <- .arrow_records(surface, arrows, tolerance, extraction)
    records$validation_status <- "not_checked"
    records$validation_reason <- "endpoint_action_none"
    return(list(arrows = arrows, records = records,
                summary = .arrow_summary(records, nrow(arrows), action)))
  }
  original <- .arrow_records(surface, arrows, tolerance, extraction)
  if (!nrow(original)) {
    return(list(arrows = arrows, records = original,
                summary = .arrow_summary(original, 0L, action)))
  }
  failed <- !original$downhill_pass
  if (action == "flag") {
    if (any(failed)) .arrow_failure_warning(original, action)
    return(list(arrows = arrows, records = original,
                summary = .arrow_summary(original, nrow(arrows), action)))
  }
  if (action == "drop") {
    kept <- arrows[!failed]
    original$validation_status[failed] <- "dropped"
    original$validation_reason[failed] <- paste0("dropped:",
                                                  original$validation_reason[failed])
    if (any(failed)) .arrow_failure_warning(original, action)
    return(list(arrows = kept, records = original,
                summary = .arrow_summary(original, nrow(kept), action)))
  }

  geoms <- lapply(seq_len(nrow(arrows)), function(i) {
    xy <- terra::crds(arrows[i], df = FALSE)
    xy[c(1L, nrow(xy)), , drop = FALSE]
  })
  steps <- integer(nrow(arrows))
  for (i in which(failed)) {
    base <- geoms[[i]][1, ]
    delta <- geoms[[i]][2, ] - base
    found <- FALSE
    for (step in seq_len(max_shortening)) {
      candidate <- rbind(base, base + delta * (0.5^step))
      candidate_line <- terra::vect(list(candidate), type = "lines",
                                    crs = terra::crs(arrows))
      candidate_record <- .arrow_records(surface, candidate_line,
                                         tolerance, extraction)
      geoms[[i]] <- candidate
      steps[i] <- step
      if (candidate_record$downhill_pass) {
        found <- TRUE
        break
      }
    }
    if (!found) steps[i] <- max_shortening
  }
  shortened <- terra::vect(geoms, type = "lines", crs = terra::crs(arrows))
  if (ncol(terra::values(arrows))) terra::values(shortened) <- terra::values(arrows)
  final <- .arrow_records(surface, shortened, tolerance, extraction)
  final$original_length <- original$original_length
  final$shortening_steps <- steps
  still_failed <- !final$downhill_pass
  final$validation_status[steps > 0 & !still_failed] <- "shortened_pass"
  final$validation_reason[steps > 0 & !still_failed] <- "shortened_to_finite_downhill_tip"
  final$validation_status[still_failed] <- "failed_after_shortening"
  final$validation_reason[still_failed] <- "no_valid_downhill_endpoint_after_shortening"
  if (any(still_failed)) .arrow_failure_warning(final, action)
  list(arrows = shortened, records = final,
       summary = .arrow_summary(final, nrow(shortened), action))
}

.arrow_records <- function(surface, arrows, tolerance, extraction) {
  n <- nrow(arrows)
  if (!n) {
    return(data.frame(
      arrow_id = integer(), base_x = numeric(), base_y = numeric(),
      tip_x = numeric(), tip_y = numeric(), base_head = numeric(),
      tip_head = numeric(), head_drop = numeric(), finite_base = logical(),
      finite_tip = logical(), finite_support = logical(), downhill_pass = logical(),
      tolerance = numeric(), original_length = numeric(), final_length = numeric(),
      shortening_steps = integer(), validation_status = character(),
      validation_reason = character(), stringsAsFactors = FALSE
    ))
  }
  bases <- ps_arrow_vertices(arrows, "first")
  tips <- ps_arrow_vertices(arrows, "last")
  bxy <- terra::crds(bases)
  txy <- terra::crds(tips)
  base_head <- as.numeric(terra::extract(surface, bases, method = extraction)[[2]])
  tip_head <- as.numeric(terra::extract(surface, tips, method = extraction)[[2]])
  finite_base <- is.finite(base_head)
  finite_tip <- is.finite(tip_head)
  line_support <- .line_finite_support(surface, arrows)
  finite_support <- finite_base & finite_tip & line_support
  downhill <- finite_support & tip_head <= base_head + tolerance
  lengths <- sqrt((txy[, 1] - bxy[, 1])^2 + (txy[, 2] - bxy[, 2])^2)
  reason <- vapply(seq_len(n), function(i) {
    x <- character()
    if (!finite_base[i]) x <- c(x, "nonfinite_base")
    if (!finite_tip[i]) x <- c(x, "nonfinite_tip")
    if (finite_base[i] && finite_tip[i] && !line_support[i]) {
      x <- c(x, "line_crosses_nonfinite_support")
    }
    if (finite_support[i] && !downhill[i]) x <- c(x, "tip_higher_than_base")
    if (!length(x)) "pass" else paste(x, collapse = ";")
  }, character(1))
  data.frame(
    arrow_id = seq_len(n), base_x = bxy[, 1], base_y = bxy[, 2],
    tip_x = txy[, 1], tip_y = txy[, 2], base_head = base_head,
    tip_head = tip_head, head_drop = base_head - tip_head,
    finite_base = finite_base, finite_tip = finite_tip,
    finite_support = finite_support, downhill_pass = downhill,
    tolerance = rep(tolerance, n), original_length = lengths,
    final_length = lengths, shortening_steps = integer(n),
    validation_status = ifelse(downhill, "pass", "failed"),
    validation_reason = reason, stringsAsFactors = FALSE
  )
}

.line_finite_support <- function(surface, arrows) {
  if (!nrow(arrows)) return(logical())
  extracted <- terra::extract(surface, arrows, cells = TRUE)
  if (!nrow(extracted)) return(rep(FALSE, nrow(arrows)))
  value_name <- names(surface)[1]
  by_id <- split(extracted[[value_name]], extracted$ID)
  vapply(seq_len(nrow(arrows)), function(i) {
    values <- by_id[[as.character(i)]]
    length(values) > 0L && all(is.finite(values))
  }, logical(1))
}

.arrow_summary <- function(records, retained, action = "validate") {
  data.frame(
    endpoint_action = action,
    arrows_generated = nrow(records),
    arrows_retained = retained,
    finite_support = sum(records$finite_support),
    downhill_pass = sum(records$downhill_pass),
    failed = sum(!records$downhill_pass),
    shortened = sum(records$shortening_steps > 0L),
    dropped = sum(records$validation_status == "dropped"),
    stringsAsFactors = FALSE
  )
}

.arrow_failure_warning <- function(records, action) {
  failed <- sum(!records$downhill_pass)
  .ps_warn(
    sprintf("%d hydraulic-gradient arrow endpoint(s) failed validation under `endpoint_action = \"%s\"`.",
            failed, action),
    "potentiomap_arrow_endpoint_warning",
    data = list(validation_summary = .arrow_summary(records, nrow(records), action))
  )
}

#' Extract arrow base or tip points
#'
#' @param arrows A line `SpatVector` or path to a line vector file.
#' @param which `"first"` for bases or `"last"` for tips.
#' @param out_file Optional vector output path.
#' @param overwrite Overwrite `out_file` when it exists.
#'
#' @return A point `terra::SpatVector`, including an empty point vector for zero
#'   arrows.
#' @export
#'
#' @examples
#' line <- terra::vect(list(rbind(c(0, 0), c(1, 1))), type = "lines",
#'                     crs = "EPSG:3857")
#' ps_arrow_vertices(line, "last")
ps_arrow_vertices <- function(arrows, which = c("last", "first"),
                              out_file = NULL, overwrite = TRUE) {
  which <- match.arg(which)
  lines <- if (inherits(arrows, "SpatVector")) arrows else terra::vect(arrows)
  if (nrow(lines) > 0L && terra::geomtype(lines) != "lines") {
    .ps_abort("`arrows` must contain line geometry.", "potentiomap_input_error")
  }
  if (!nrow(lines)) {
    pts <- .empty_points(terra::crs(lines))
  } else {
    verts <- lapply(seq_len(nrow(lines)), function(i) {
      xy <- terra::crds(lines[i], df = TRUE)
      if (which == "last") xy[nrow(xy), c("x", "y"), drop = FALSE] else {
        xy[1, c("x", "y"), drop = FALSE]
      }
    })
    verts <- do.call(rbind, verts)
    pts <- terra::vect(verts, geom = c("x", "y"), crs = terra::crs(lines))
    if (ncol(terra::values(lines))) terra::values(pts) <- terra::values(lines)
  }
  if (!is.null(out_file)) {
    if (!overwrite && file.exists(out_file)) {
      .ps_abort("Arrow-vertex output exists and `overwrite = FALSE`.",
                "potentiomap_export_error")
    }
    tryCatch(terra::writeVector(pts, out_file, overwrite = overwrite),
             error = function(e) .ps_abort(
               paste0("Could not write arrow vertices: ", conditionMessage(e)),
               "potentiomap_export_error"
             ))
  }
  pts
}
