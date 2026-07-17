.ps_polygon_vector <- function(x, name) {
  v <- if (inherits(x, "SpatVector")) x else tryCatch(terra::vect(x), error = function(e) NULL)
  if (is.null(v) || !terra::geomtype(v) %in% c("polygons")) {
    .ps_abort(sprintf("`%s` must contain polygon geometry.", name), "potentiomap_region_error")
  }
  .require_crs(v, name)
  valid <- sf::st_is_valid(sf::st_as_sf(v))
  if (anyNA(valid) || any(!valid)) {
    .ps_abort(sprintf("`%s` contains invalid geometry; no implicit repair was attempted.", name), "potentiomap_region_error")
  }
  v
}

.ps_empty_polygon <- function(crs) {
  sf::st_as_sf(data.frame(id = character(), geometry = sf::st_sfc(crs = sf::st_crs(crs))))
}

.ps_overlap_sf <- function(regions, ids) {
  sf_regions <- sf::st_as_sf(regions); rows <- list(); k <- 0L
  if (nrow(sf_regions) > 1L) for (i in seq_len(nrow(sf_regions) - 1L)) for (j in (i + 1L):nrow(sf_regions)) {
    inter <- suppressWarnings(sf::st_intersection(sf::st_geometry(sf_regions[i, ]), sf::st_geometry(sf_regions[j, ])))
    if (length(inter) && !all(sf::st_is_empty(inter)) && sum(as.numeric(sf::st_area(inter))) > 0) {
      k <- k + 1L; rows[[k]] <- sf::st_sf(region_a = ids[i], region_b = ids[j], geometry = inter)
    }
  }
  if (length(rows)) do.call(rbind, rows) else sf::st_sf(region_a = character(), region_b = character(), geometry = sf::st_sfc(crs = sf::st_crs(sf_regions)))
}

#' Validate and split an explicit hydrogeologic domain
#'
#' @param domain Domain polygon.
#' @param regions Explicit region polygons.
#' @param region_id Unique region identifier field.
#' @param points Optional monitoring points to assign.
#' @param overlap_action Error or preserve priority order.
#' @param gap_action Report or error for domain gaps.
#' @param boundary_action Error, priority assignment, or duplicate assignments.
#' @return A `potentiomap_domain_split` object. Regions are never inferred from
#'   monitoring points and invalid geometry is never silently repaired.
#' @examples
#' data("synthetic_regions")
#' regions <- terra::vect(synthetic_regions, geom = "wkt", crs = "EPSG:26916")
#' domain <- terra::as.polygons(terra::ext(500000, 503000, 4640000, 4642500),
#'                              crs = "EPSG:26916")
#' split <- ps_split_domain(domain, regions, "region_id")
#' split$summary
#' # Explicit regions are not inferred groundwater-flow boundaries.
#' @export
ps_split_domain <- function(domain, regions, region_id, points = NULL,
                            overlap_action = c("error", "priority"),
                            gap_action = c("report", "error"),
                            boundary_action = c("error", "assign_by_priority", "duplicate")) {
  call <- match.call(); overlap_action <- match.arg(overlap_action); gap_action <- match.arg(gap_action); boundary_action <- match.arg(boundary_action)
  dom <- .ps_polygon_vector(domain, "domain"); reg <- .ps_polygon_vector(regions, "regions")
  if (!.same_crs(dom, reg)) .ps_abort("Domain and region CRS differ.", "potentiomap_crs_error")
  rv <- terra::values(reg)
  if (!region_id %in% names(rv)) .ps_abort("`region_id` was not found.", "potentiomap_region_error")
  ids <- as.character(rv[[region_id]])
  if (anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids)) .ps_abort("Region IDs must be unique, nonmissing, and nonempty.", "potentiomap_region_error")
  overlap <- .ps_overlap_sf(reg, ids)
  if (nrow(overlap) && overlap_action == "error") .ps_abort("Region polygons overlap; use explicit priority only when scientifically intended.", "potentiomap_region_overlap_error")
  dgeom <- sf::st_union(sf::st_as_sf(dom)); rgeom <- sf::st_union(sf::st_as_sf(reg))
  gap_geom <- suppressWarnings(sf::st_difference(dgeom, rgeom))
  gap <- if (length(gap_geom) && !all(sf::st_is_empty(gap_geom))) sf::st_sf(gap_id = seq_along(gap_geom), geometry = gap_geom) else sf::st_sf(gap_id = integer(), geometry = sf::st_sfc(crs = sf::st_crs(sf::st_as_sf(dom))))
  gap_area <- if (nrow(gap)) sum(as.numeric(sf::st_area(gap))) else 0
  if (gap_area > 0 && gap_action == "error") .ps_abort("Regions leave a gap inside the domain.", "potentiomap_region_gap_error")
  assignments <- data.frame(); ambiguous <- data.frame(); unassigned <- data.frame()
  if (!is.null(points)) {
    p <- if (inherits(points, "SpatVector")) points else terra::vect(points)
    .require_crs(p, "points"); if (!.same_crs(p, reg)) .ps_abort("Points and regions use different CRS.", "potentiomap_crs_error")
    pv <- terra::values(p); point_ids <- if ("Name" %in% names(pv)) as.character(pv$Name) else .ps_stable_ids("point", nrow(p))
    relation <- sf::st_intersects(sf::st_as_sf(p), sf::st_as_sf(reg), sparse = TRUE)
    boundary <- sf::st_touches(sf::st_as_sf(p), sf::st_as_sf(reg), sparse = TRUE)
    rows <- list(); amb <- list(); un <- list()
    for (i in seq_len(nrow(p))) {
      matches <- relation[[i]]; on_boundary <- length(boundary[[i]]) > 0L
      if (!length(matches)) {
        un[[length(un) + 1L]] <- data.frame(point_id = point_ids[i], reason = "outside_all_regions")
      } else if (length(matches) > 1L || on_boundary) {
        amb[[length(amb) + 1L]] <- data.frame(point_id = point_ids[i], matching_regions = paste(ids[matches], collapse = "|"), on_boundary = on_boundary)
        if (boundary_action == "error") .ps_abort("One or more points are on a boundary or ambiguously assigned.", "potentiomap_region_boundary_error")
        chosen <- if (boundary_action == "duplicate") matches else matches[1]
        for (j in chosen) rows[[length(rows) + 1L]] <- data.frame(point_id = point_ids[i], region_id = ids[j], assignment = if (on_boundary) boundary_action else "overlap_priority")
      } else rows[[length(rows) + 1L]] <- data.frame(point_id = point_ids[i], region_id = ids[matches], assignment = "within")
    }
    assignments <- if (length(rows)) do.call(rbind, rows) else data.frame(point_id = character(), region_id = character(), assignment = character())
    ambiguous <- if (length(amb)) do.call(rbind, amb) else data.frame(point_id = character(), matching_regions = character(), on_boundary = logical())
    unassigned <- if (length(un)) do.call(rbind, un) else data.frame(point_id = character(), reason = character())
  }
  summary <- data.frame(region_count = nrow(reg), overlap_count = nrow(overlap),
                        overlap_area = if (nrow(overlap)) sum(as.numeric(sf::st_area(overlap))) else 0,
                        gap_count = nrow(gap), gap_area = gap_area,
                        assigned_points = nrow(assignments), ambiguous_points = nrow(ambiguous),
                        unassigned_points = nrow(unassigned))
  .ps_new_result(list(regions = reg, point_assignments = assignments,
                      overlap_polygons = overlap, gap_polygons = gap,
                      ambiguous_points = ambiguous, unassigned_points = unassigned),
                 "potentiomap_domain_split", call,
                 settings = list(region_id = region_id, overlap_action = overlap_action,
                                 gap_action = gap_action, boundary_action = boundary_action,
                                 region_priority = ids),
                 metadata = list(crs = terra::crs(reg)), summary = summary)
}

#' Interpolate explicit regions independently
#'
#' @param points Groundwater-head points.
#' @param regions Region polygons.
#' @param region_id Unique region field.
#' @param methods Interpolation methods.
#' @param template,grid_res Mapping geometry controls.
#' @param interpolation_control Named interpolation arguments.
#' @param mosaic Return a boundary-preserving mosaic.
#' @param overlap_priority Required region priority when regions overlap.
#' @param progress Optional callback.
#' @return A `potentiomap_regional_result` object. No groundwater-flow boundary
#'   conditions are imposed and no smoothing occurs across region boundaries.
#' @examples
#' data("synthetic_wells", "synthetic_regions")
#' p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' regions <- terra::vect(synthetic_regions, geom = "wkt", crs = "EPSG:26916")
#' regional <- ps_interpolate_regions(p, regions, "region_id", "IDW",
#'                                    grid_res = 300)
#' regional$region_method_manifest
#' # Independent regional fits do not impose flow-boundary conditions.
#' @export
ps_interpolate_regions <- function(points, regions, region_id, methods = "TPS",
                                   template = NULL, grid_res = NULL,
                                   interpolation_control = list(), mosaic = TRUE,
                                   overlap_priority = NULL, progress = NULL) {
  call <- match.call(); .ps_scalar_logical(mosaic, "mosaic")
  pts <- .ps_standard_points(points); reg <- .ps_polygon_vector(regions, "regions")
  if (!.same_crs(pts, reg)) .ps_abort("Points and regions use different CRS.", "potentiomap_crs_error")
  rv <- terra::values(reg); if (!region_id %in% names(rv)) .ps_abort("`region_id` was not found.", "potentiomap_region_error")
  ids <- as.character(rv[[region_id]]); if (anyNA(ids) || anyDuplicated(ids)) .ps_abort("Region IDs must be complete and unique.", "potentiomap_region_error")
  overlap <- .ps_overlap_sf(reg, ids)
  if (nrow(overlap)) {
    if (is.null(overlap_priority) || !setequal(overlap_priority, ids)) .ps_abort("Overlapping regions require an explicit complete `overlap_priority`.", "potentiomap_region_overlap_error")
    order_ids <- overlap_priority
  } else order_ids <- ids
  if (is.null(template)) {
    if (is.null(grid_res)) .ps_abort("Supply `template` or `grid_res`.", "potentiomap_region_error")
    template <- .surface_template(pts, grid_res, NULL, reg, NULL)
  }
  relation <- sf::st_intersects(sf::st_as_sf(pts), sf::st_as_sf(reg), sparse = TRUE)
  surfaces <- list(); manifest <- list(); conditions <- list(); k <- 0L
  total <- length(ids) * length(methods)
  for (ridx in seq_along(ids)) {
    region <- ids[ridx]; indices <- which(vapply(relation, function(z) ridx %in% z, logical(1)))
    for (method in methods) {
      k <- k + 1L; run_id <- paste(region, method, sep = "::"); .ps_progress(progress, k, total, run_id, "started")
      cap <- if (length(indices) < 5L) list(value = NULL, warnings = list(), messages = list(), error = .ps_condition(sprintf("Region `%s` has %d observations; at least five are required.", region, length(indices)), "potentiomap_region_sample_error", "error")) else
        .ps_capture_run(do.call(ps_interpolate, c(list(points = pts[indices], methods = method,
                                                       template = template, mask = reg[ridx], return = "result"),
                                                  interpolation_control)))
      if (!is.null(cap$value)) {
        region_surface <- terra::extend(cap$value$surfaces[[1]], template)
        if (!isTRUE(terra::compareGeom(region_surface, template, stopOnError = FALSE))) {
          region_surface <- terra::resample(region_surface, template, method = "bilinear")
        }
        surfaces[[region]][[method]] <- region_surface
      }
      manifest[[k]] <- data.frame(region_id = region, method = method,
                                  observation_count = length(indices),
                                  observation_ids = paste(sort(terra::values(pts)$Name[indices]), collapse = "|"),
                                  status = if (is.null(cap$error)) "success" else if (length(indices) < 5L) "underpopulated" else "failed",
                                  warning_count = length(cap$warnings), error_count = as.integer(!is.null(cap$error)),
                                  warning_text = paste(vapply(cap$warnings, conditionMessage, character(1)), collapse = " | "),
                                  error_text = if (is.null(cap$error)) "" else conditionMessage(cap$error), stringsAsFactors = FALSE)
      conditions[[k]] <- .ps_condition_rows(c(cap$warnings, if (!is.null(cap$error)) list(cap$error) else list()), "ps_interpolate_regions", method = method, region_id = region)
      .ps_progress(progress, k, total, run_id, manifest[[k]]$status)
    }
  }
  mosaics <- list(); region_index <- NULL
  if (mosaic) {
    for (method in methods) {
      ordered <- Filter(Negate(is.null), lapply(order_ids, function(id) surfaces[[id]][[method]]))
      if (length(ordered)) {
        out <- ordered[[1]]
        if (length(ordered) > 1L) for (i in 2:length(ordered)) out <- terra::cover(out, ordered[[i]])
        mosaics[[method]] <- out
      }
    }
    region_index <- template; terra::values(region_index) <- NA_integer_
    for (i in rev(seq_along(order_ids))) {
      ridx <- match(order_ids[i], ids); zone <- terra::rasterize(reg[ridx], template, field = ridx)
      region_index <- terra::cover(zone, region_index)
    }
    names(region_index) <- "region_index"
  }
  manifest_df <- do.call(rbind, manifest)
  .ps_new_result(list(region_surfaces = surfaces, mosaic = mosaics,
                      region_index = region_index, region_method_manifest = manifest_df),
                 "potentiomap_regional_result", call,
                 settings = list(region_id = region_id, methods = methods,
                                 mosaic = mosaic, overlap_priority = overlap_priority,
                                 independent_regions = TRUE),
                 metadata = .ps_surface_metadata(pts), conditions = do.call(rbind, conditions),
                 warnings = "Regions are fit independently without cross-boundary smoothing; this does not implement groundwater-flow boundary conditions.",
                 summary = aggregate(observation_count ~ region_id, manifest_df, max))
}

.ps_slerp_lonlat <- function(a, b, fraction) {
  to_cartesian <- function(x) {
    lon <- x[1] * pi / 180
    lat <- x[2] * pi / 180
    c(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
  }
  va <- to_cartesian(a)
  vb <- to_cartesian(b)
  angle <- acos(max(-1, min(1, sum(va * vb))))
  if (angle < sqrt(.Machine$double.eps)) {
    v <- (1 - fraction) * va + fraction * vb
  } else {
    v <- (sin((1 - fraction) * angle) * va +
            sin(fraction * angle) * vb) / sin(angle)
  }
  v <- v / sqrt(sum(v^2))
  c(atan2(v[2], v[1]) * 180 / pi,
    atan2(v[3], sqrt(v[1]^2 + v[2]^2)) * 180 / pi)
}

.ps_geodesic_line_sample <- function(line_sfc, count, output_crs) {
  geographic <- if (isTRUE(sf::st_is_longlat(line_sfc))) {
    line_sfc
  } else {
    sf::st_transform(line_sfc, 4326)
  }
  coordinates <- sf::st_coordinates(geographic)[, 1:2, drop = FALSE]
  if (nrow(coordinates) < 2L) {
    .ps_abort("A profile line must contain at least two distinct vertices.",
              "potentiomap_profile_error")
  }
  vertices <- sf::st_sfc(lapply(seq_len(nrow(coordinates)), function(i) {
    sf::st_point(coordinates[i, ])
  }), crs = sf::st_crs(geographic))
  segment_length <- as.numeric(sf::st_distance(
    vertices[-length(vertices)], vertices[-1], by_element = TRUE
  ))
  if (any(!is.finite(segment_length)) || sum(segment_length) <= 0) {
    .ps_abort("A profile line must have positive finite geodesic length.",
              "potentiomap_profile_error")
  }
  cumulative <- c(0, cumsum(segment_length))
  chainage <- seq(0, sum(segment_length), length.out = count)
  sampled_coordinates <- t(vapply(chainage, function(target) {
    segment <- min(length(segment_length),
                   max(1L, findInterval(target, cumulative,
                                        rightmost.closed = TRUE)))
    fraction <- (target - cumulative[segment]) / segment_length[segment]
    .ps_slerp_lonlat(coordinates[segment, ],
                     coordinates[segment + 1L, ],
                     max(0, min(1, fraction)))
  }, numeric(2)))
  points <- sf::st_sfc(lapply(seq_len(nrow(sampled_coordinates)), function(i) {
    sf::st_point(sampled_coordinates[i, ])
  }), crs = sf::st_crs(geographic))
  if (!isTRUE(sf::st_is_longlat(line_sfc))) {
    points <- sf::st_transform(points, output_crs)
  }
  list(points = points, chainage = chainage)
}

.ps_profile_samples <- function(lines, step, n, distance_method) {
  sf_lines <- sf::st_as_sf(lines)
  if (any(!sf::st_geometry_type(sf_lines) %in% c("LINESTRING", "MULTILINESTRING"))) .ps_abort("`lines` must contain line geometry.", "potentiomap_profile_error")
  if (distance_method == "projected" && isTRUE(sf::st_is_longlat(sf_lines))) .ps_abort("Projected profile distance requires a projected CRS; choose explicit geodesic behavior for longitude/latitude.", "potentiomap_profile_error")
  rows <- list(); geoms <- list(); k <- 0L
  for (i in seq_len(nrow(sf_lines))) {
    line <- sf::st_cast(sf::st_geometry(sf_lines[i, ]), "LINESTRING")[[1]]
    line_sfc <- sf::st_sfc(line, crs = sf::st_crs(sf_lines))
    length_geometry <- if (distance_method == "geodesic" &&
                           !isTRUE(sf::st_is_longlat(line_sfc))) {
      sf::st_transform(line_sfc, 4326)
    } else {
      line_sfc
    }
    length_value <- as.numeric(sf::st_length(length_geometry))
    count <- if (!is.null(n)) n else max(2L, ceiling(length_value / step) + 1L)
    if (distance_method == "geodesic") {
      geodesic_sample <- .ps_geodesic_line_sample(
        line_sfc, count, sf::st_crs(sf_lines)
      )
      pts <- geodesic_sample$points
      chain <- geodesic_sample$chainage
    } else {
      fractions <- seq(0, 1, length.out = count)
      sampled <- sf::st_line_sample(line_sfc, sample = fractions)
      pts <- sf::st_cast(sampled, "POINT")
      chain <- c(0, cumsum(if (length(pts) > 1L) {
        as.numeric(sf::st_distance(pts[-length(pts)], pts[-1],
                                   by_element = TRUE))
      } else numeric()))
    }
    xy <- sf::st_coordinates(pts)
    line_id <- if ("line_id" %in% names(sf_lines)) as.character(sf_lines$line_id[i]) else sprintf("line_%04d", i)
    for (j in seq_len(nrow(xy))) {
      k <- k + 1L; rows[[k]] <- data.frame(line_id = line_id, sample_id = sprintf("%s_sample_%04d", line_id, j), sample_index = j, chainage = chain[j], x = xy[j, 1], y = xy[j, 2], spacing = if (j == 1L) NA_real_ else chain[j] - chain[j - 1], stringsAsFactors = FALSE)
      geoms[[k]] <- pts[j]
    }
  }
  list(table = do.call(rbind, rows), geometry = do.call(c, geoms))
}

#' Extract one or more surface profiles along explicit lines
#'
#' @param lines One or more line features.
#' @param surfaces Named compatible surfaces or an interpolation result.
#' @param step,n Explicit spacing or count per line.
#' @param support Optional support/uncertainty rasters to extract.
#' @param distance_method Projected or explicit geodesic distance.
#' @return A `potentiomap_profile` with monotonically increasing chainage.
#' @examples
#' data("synthetic_wells", "synthetic_transect")
#' p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' s <- ps_interpolate(p, methods = "IDW", grid_res = 250)$IDW
#' line <- terra::vect(synthetic_transect, geom = "wkt", crs = "EPSG:26916")
#' profile <- ps_surface_profile(line, list(head = s), n = 12)
#' head(profile$profile)
#' # Unsupported raster sections remain missing rather than being invented.
#' @export
ps_surface_profile <- function(lines, surfaces, step = NULL, n = NULL,
                               support = NULL,
                               distance_method = c("projected", "geodesic")) {
  call <- match.call(); distance_method <- match.arg(distance_method)
  line_v <- if (inherits(lines, "SpatVector")) lines else terra::vect(lines); .require_crs(line_v, "lines")
  surf <- .ps_surfaces_input(surfaces)
  if (any(!vapply(surf, .same_crs, logical(1), line_v))) .ps_abort("Lines and surfaces use different CRS.", "potentiomap_crs_error")
  if (!is.null(step) && !is.null(n)) .ps_abort("Supply only one of `step` and `n`.", "potentiomap_profile_error")
  if (is.null(step) && is.null(n)) step <- min(terra::res(surf[[1]]))
  if (!is.null(step)) .validate_number(step, "step", lower = 0)
  if (!is.null(n)) .validate_integer(n, "n", lower = 1)
  sampled <- .ps_profile_samples(line_v, step, n, distance_method)
  sample_v <- terra::vect(sampled$table, geom = c("x", "y"), crs = terra::crs(line_v))
  table <- sampled$table
  for (nm in names(surf)) table[[nm]] <- terra::extract(surf[[nm]], sample_v, method = "bilinear")[[2]]
  support_surfaces <- if (is.null(support)) list() else if (inherits(support, "SpatRaster")) {
    z <- lapply(seq_len(terra::nlyr(support)), function(i) support[[i]]); names(z) <- names(support); z
  } else if (is.list(support)) support else .ps_abort("`support` must contain raster layers.", "potentiomap_profile_error")
  for (nm in names(support_surfaces)) {
    if (!.same_crs(support_surfaces[[nm]], line_v)) .ps_abort("Support and profile CRS differ.", "potentiomap_crs_error")
    table[[paste0("support_", nm)]] <- terra::extract(support_surfaces[[nm]], sample_v, method = "near")[[2]]
  }
  summary <- aggregate(cbind(chainage, spacing) ~ line_id, table, function(z) c(min = min(z, na.rm = TRUE), max = max(z, na.rm = TRUE), median = stats::median(z, na.rm = TRUE)))
  .ps_new_result(list(profile = table, sample_points = sample_v),
                 "potentiomap_profile", call,
                 settings = list(step = step, n = n, distance_method = distance_method,
                                 surface_names = names(surf)),
                 metadata = .ps_surface_metadata(surf[[1]]), summary = summary)
}

#' Build a plot-ready potentiometric cross-section
#'
#' @param transect One line feature.
#' @param head_surface Head surface raster.
#' @param land_surface Optional land-surface raster.
#' @param wells Optional monitoring wells.
#' @param screen_top,screen_bottom,well_id Optional absolute-elevation columns.
#' @param maximum_well_offset Maximum perpendicular offset retained.
#' @param support,uncertainty Optional rasters sampled along the transect.
#' @param step Explicit profile spacing.
#' @param vertical_exaggeration Plot setting recorded without changing data.
#' @return A `potentiomap_cross_section` object. It does not invent
#'   hydrostratigraphy or represent a three-dimensional numerical flow model.
#' @examples
#' data("synthetic_wells", "synthetic_transect")
#' p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' s <- ps_interpolate(p, methods = "IDW", grid_res = 250)$IDW
#' line <- terra::vect(synthetic_transect, geom = "wkt", crs = "EPSG:26916")
#' section <- ps_cross_section(line, s, step = 250, vertical_exaggeration = 5)
#' section$summary
#' # The section is not a three-dimensional groundwater-flow model.
#' @export
ps_cross_section <- function(transect, head_surface, land_surface = NULL,
                             wells = NULL, screen_top = NULL,
                             screen_bottom = NULL, well_id = NULL,
                             maximum_well_offset = NULL, support = NULL,
                             uncertainty = NULL, step = NULL,
                             vertical_exaggeration = 1) {
  call <- match.call(); .validate_number(vertical_exaggeration, "vertical_exaggeration", lower = 0)
  if (!is.null(maximum_well_offset)) .validate_number(maximum_well_offset, "maximum_well_offset", lower = 0, inclusive = TRUE)
  surfaces <- list(head = head_surface); if (!is.null(land_surface)) surfaces$land_surface <- land_surface
  extras <- list(); if (!is.null(support)) extras$support <- support
  if (!is.null(uncertainty)) extras$uncertainty <- uncertainty
  profile <- ps_surface_profile(transect, surfaces, step = step, support = extras)
  table <- profile$profile
  if (!is.null(land_surface)) table$depth <- table$land_surface - table$head
  well_table <- omitted <- data.frame()
  if (!is.null(wells)) {
    w <- if (inherits(wells, "SpatVector")) wells else terra::vect(wells); .require_crs(w, "wells")
    if (!.same_crs(w, head_surface)) .ps_abort("Wells and cross-section CRS differ.", "potentiomap_crs_error")
    wv <- terra::values(w); ids <- if (!is.null(well_id) && well_id %in% names(wv)) as.character(wv[[well_id]]) else .ps_stable_ids("well", nrow(w))
    if (!is.null(screen_top) || !is.null(screen_bottom)) {
      if (is.null(screen_top) || is.null(screen_bottom) || !all(c(screen_top, screen_bottom) %in% names(wv))) .ps_abort("Both screen elevation columns are required.", "potentiomap_cross_section_error")
      reference <- .ps_get_metadata(wells)$screen_vertical_reference %||% attr(wells, "screen_vertical_reference", exact = TRUE)
      if (is.null(reference) || !identical(tolower(reference), "absolute_elevation")) .ps_abort("Screen values require explicit `absolute_elevation` vertical-reference metadata.", "potentiomap_cross_section_error")
      if (any(wv[[screen_top]] < wv[[screen_bottom]], na.rm = TRUE)) .ps_abort("Screen top must not be below screen bottom.", "potentiomap_cross_section_error")
    }
    sample_points <- profile$sample_points; distances <- .ps_points_distance(w, sample_points)
    nearest <- max.col(-distances, ties.method = "first"); offsets <- distances[cbind(seq_len(nrow(w)), nearest)]
    well_table <- data.frame(well_id = ids, chainage = table$chainage[nearest],
                             perpendicular_offset = offsets,
                             x = terra::crds(w)[, 1], y = terra::crds(w)[, 2],
                             screen_top = if (!is.null(screen_top)) wv[[screen_top]] else NA_real_,
                             screen_bottom = if (!is.null(screen_bottom)) wv[[screen_bottom]] else NA_real_,
                             stringsAsFactors = FALSE)
    keep <- if (is.null(maximum_well_offset)) rep(TRUE, nrow(well_table)) else well_table$perpendicular_offset <= maximum_well_offset
    omitted <- transform(well_table[!keep, , drop = FALSE], reason = "beyond_maximum_well_offset")
    well_table <- well_table[keep, , drop = FALSE]
  }
  summary <- data.frame(profile_samples = nrow(table), retained_wells = nrow(well_table),
                        omitted_wells = nrow(omitted), maximum_chainage = max(table$chainage),
                        vertical_exaggeration = vertical_exaggeration)
  .ps_new_result(list(profile = table, wells = well_table,
                      omitted_wells = omitted, profile_result = profile),
                 "potentiomap_cross_section", call,
                 settings = list(step = step, maximum_well_offset = maximum_well_offset,
                                 vertical_exaggeration = vertical_exaggeration),
                 metadata = .ps_surface_metadata(head_surface),
                 warnings = "Cross-section well offsets remain explicit; no hydrostratigraphy is invented and this is not a three-dimensional numerical flow model.",
                 summary = summary)
}

#' @export
plot.potentiomap_cross_section <- function(x, ...) {
  tab <- x$profile; ylim <- range(c(tab$head, tab$land_surface, x$wells$screen_top, x$wells$screen_bottom), finite = TRUE)
  graphics::plot(tab$chainage, tab$head, type = "l", xlab = "Chainage", ylab = "Elevation", ylim = ylim, ...)
  if ("land_surface" %in% names(tab)) graphics::lines(tab$chainage, tab$land_surface, lty = 2)
  if (nrow(x$wells)) graphics::segments(x$wells$chainage, x$wells$screen_bottom,
                                        x$wells$chainage, x$wells$screen_top, lwd = 2)
  invisible(list(profile = tab, wells = x$wells))
}

#' @export
as.data.frame.potentiomap_domain_split <- function(x, ...) x$point_assignments
#' @export
as.data.frame.potentiomap_regional_result <- function(x, ...) x$region_method_manifest
#' @export
as.data.frame.potentiomap_profile <- function(x, ...) x$profile
#' @export
as.data.frame.potentiomap_cross_section <- function(x, ...) x$profile
