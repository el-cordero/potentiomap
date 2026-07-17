.ps_event_metadata_check <- function(a, b) {
  fields <- c("head_unit", "output_unit", "vertical_datum", "measurement_reference",
              "aquifer", "water_bearing_unit", "screen_selection_rule")
  ma <- .ps_get_metadata(a); mb <- .ps_get_metadata(b)
  incompatible <- fields[vapply(fields, function(nm) {
    av <- ma[[nm]]; bv <- mb[[nm]]
    !is.null(av) && !is.null(bv) && !identical(tolower(as.character(av)), tolower(as.character(bv)))
  }, logical(1))]
  if (length(incompatible)) {
    .ps_abort(sprintf("Event metadata differ for: %s.", paste(incompatible, collapse = ", ")),
              "potentiomap_metadata_error")
  }
  list(event_a = ma, event_b = mb, checked_fields = fields)
}

#' Compare paired measurements and modeled head change between events
#'
#' @param event_a,event_b Point observations for two identified events.
#' @param pair_by Well identifier column.
#' @param event_a_time,event_b_time Optional explicit event times.
#' @param method Interpolation method.
#' @param template,mask,grid_res Fixed surface controls.
#' @param interpolation_control Named interpolation arguments.
#' @param compare_gradient Compare down-gradient directions.
#' @return A `potentiomap_head_change` object. Modeled head change is not a
#'   storage, depletion, or volumetric-change estimate.
#' @examples
#' data("synthetic_events")
#' a <- subset(synthetic_events, event == "spring")
#' b <- subset(synthetic_events, event == "autumn")
#' pa <- ps_make_points(a, "x", "y", "head", "well_id", "EPSG:26916")
#' pb <- ps_make_points(b, "x", "y", "head", "well_id", "EPSG:26916")
#' change <- ps_head_change(pa, pb, "well_id", method = "IDW", grid_res = 300)
#' change$summary
#' # Modeled head change is not a storage-change estimate.
#' @export
ps_head_change <- function(event_a, event_b, pair_by,
                           event_a_time = NULL, event_b_time = NULL,
                           method = "TPS", template = NULL, mask = NULL,
                           grid_res = NULL, interpolation_control = list(),
                           compare_gradient = TRUE) {
  call <- match.call(); .ps_scalar_character(pair_by, "pair_by")
  .ps_scalar_logical(compare_gradient, "compare_gradient")
  a <- .ps_standard_points(event_a, id = pair_by, name = "event_a")
  b <- .ps_standard_points(event_b, id = pair_by, name = "event_b")
  if (!.same_crs(a, b)) .ps_abort("Event CRS differ.", "potentiomap_crs_error")
  av <- terra::values(a); bv <- terra::values(b)
  if (!pair_by %in% names(av) || !pair_by %in% names(bv)) .ps_abort("`pair_by` was not found in both events.", "potentiomap_head_change_error")
  aid <- as.character(av[[pair_by]]); bid <- as.character(bv[[pair_by]])
  duplicate_ids <- unique(c(aid[duplicated(aid) | duplicated(aid, fromLast = TRUE)],
                            bid[duplicated(bid) | duplicated(bid, fromLast = TRUE)]))
  if (length(duplicate_ids)) .ps_abort("Each event must contain at most one record per paired well.", "potentiomap_head_change_error")
  if (!is.null(event_a_time) && !is.null(event_b_time)) {
    ta <- as.POSIXct(event_a_time, tz = "UTC"); tb <- as.POSIXct(event_b_time, tz = "UTC")
    if (is.na(ta) || is.na(tb) || tb <= ta) .ps_abort("Event B time must be valid and later than event A time.", "potentiomap_head_change_error")
  } else {
    ta <- event_a_time; tb <- event_b_time
  }
  meta_check <- .ps_event_metadata_check(event_a, event_b)
  paired <- intersect(aid, bid); a_only <- setdiff(aid, bid); b_only <- setdiff(bid, aid)
  pa <- match(paired, aid); pb <- match(paired, bid)
  measured <- data.frame(
    well_id = paired,
    event_a_head = av$Z[pa], event_b_head = bv$Z[pb],
    measured_change_b_minus_a = bv$Z[pb] - av$Z[pa],
    event_a_x = terra::crds(a)[pa, 1], event_a_y = terra::crds(a)[pa, 2],
    event_b_x = terra::crds(b)[pb, 1], event_b_y = terra::crds(b)[pb, 2],
    location_shift = sqrt(rowSums((terra::crds(a)[pa, , drop = FALSE] - terra::crds(b)[pb, , drop = FALSE])^2)),
    stringsAsFactors = FALSE
  )
  combined <- rbind(a, b)
  if (is.null(template)) {
    if (is.null(grid_res)) grid_res <- max(diff(range(terra::crds(combined)[, 1])), diff(range(terra::crds(combined)[, 2]))) / 50
    template <- .surface_template(combined, grid_res, NULL, mask, NULL)
  }
  args_a <- c(list(points = a, methods = method, template = template, mask = mask, return = "result"), interpolation_control)
  args_b <- c(list(points = b, methods = method, template = template, mask = mask, return = "result"), interpolation_control)
  fit_a <- do.call(ps_interpolate, args_a); fit_b <- do.call(ps_interpolate, args_b)
  surface_a <- fit_a$surfaces[[1]]; surface_b <- fit_b$surfaces[[1]]
  comparison <- ps_compare_surfaces(surface_a, surface_b, direction = "b_minus_a", align = "error", compare_gradient = compare_gradient)
  summary <- data.frame(event_a_wells = nrow(a), event_b_wells = nrow(b),
                        paired_wells = length(paired), event_a_only = length(a_only),
                        event_b_only = length(b_only), duplicate_ids = length(duplicate_ids),
                        mean_paired_change = if (length(paired)) mean(measured$measured_change_b_minus_a, na.rm = TRUE) else NA_real_,
                        mean_modeled_change = comparison$summary$mean_difference)
  .ps_new_result(list(paired_measured_change = measured,
                      event_a_only_ids = a_only, event_b_only_ids = b_only,
                      duplicate_ids = duplicate_ids,
                      event_a_result = fit_a, event_b_result = fit_b,
                      modeled_change = comparison$signed_difference,
                      gradient_direction_change = comparison$gradient_direction_difference,
                      comparison = comparison),
                 "potentiomap_head_change", call,
                 settings = list(pair_by = pair_by, method = method,
                                 sign = "event B minus event A",
                                 event_a_time = ta, event_b_time = tb,
                                 compare_gradient = compare_gradient),
                 metadata = c(meta_check, list(surface_type = "head_change")),
                 warnings = "Modeled head change and paired-well measured change are distinct products. Neither is a storage, depletion, or volumetric-change estimate.",
                 summary = summary)
}

.ps_surface_change_metrics <- function(reference, alternative, contour_levels = NULL,
                                       threshold = NULL) {
  cmp <- ps_compare_surfaces(reference, alternative, direction = "b_minus_a",
                             align = "error", contour_levels = contour_levels,
                             compare_gradient = TRUE)
  d <- terra::values(cmp$signed_difference, mat = FALSE); ok <- is.finite(d)
  cell_area <- .ps_cell_area_values(cmp$signed_difference)
  gradient_values <- if (is.null(cmp$gradient_direction_difference)) numeric() else
    terra::values(cmp$gradient_direction_difference, mat = FALSE)
  data.frame(mean_absolute_difference = if (any(ok)) mean(abs(d[ok])) else NA_real_,
             maximum_absolute_difference = if (any(ok)) max(abs(d[ok])) else NA_real_,
             rmse_difference = if (any(ok)) sqrt(mean(d[ok]^2)) else NA_real_,
             affected_area_m2 = if (is.null(threshold)) NA_real_ else sum(cell_area[ok & abs(d) > threshold], na.rm = TRUE),
             finite_area_m2 = sum(cell_area[ok], na.rm = TRUE),
             finite_cells = sum(ok),
             contour_displacement = if (nrow(cmp$contour_displacement)) {
               mean(cmp$contour_displacement$mean_distance, na.rm = TRUE)
             } else NA_real_,
             median_gradient_direction_change = if (any(is.finite(gradient_values))) stats::median(gradient_values, na.rm = TRUE) else NA_real_)
}

#' Calculate conditional leave-one-well influence
#'
#' @param points Groundwater-head points.
#' @param method Interpolation method.
#' @param template,mask,grid_res Fixed surface controls.
#' @param contour_levels Optional comparison contours.
#' @param difference_threshold Optional absolute-difference area threshold.
#' @param interpolation_control Named interpolation controls.
#' @param progress Optional callback.
#' @return A `potentiomap_well_influence` object. Influence is conditional on
#'   this network and method and is not evidence that a well is erroneous.
#' @examples
#' data("synthetic_wells")
#' p <- ps_make_points(synthetic_wells[1:7, ], "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' influence <- ps_well_influence(p, method = "IDW", grid_res = 350)
#' influence$influence[, c("well_id", "held_out_residual", "status")]
#' # High conditional influence is not an automatic data-error classification.
#' @export
ps_well_influence <- function(points, method = "TPS", template = NULL,
                              mask = NULL, grid_res = NULL,
                              contour_levels = NULL,
                              difference_threshold = NULL,
                              interpolation_control = list(), progress = NULL) {
  call <- match.call(); pts <- .ps_standard_points(points); .require_projected(pts, "points")
  if (!is.null(difference_threshold)) .validate_number(difference_threshold, "difference_threshold", lower = 0, inclusive = TRUE)
  full_args <- c(list(points = pts, methods = method, template = template,
                      mask = mask, grid_res = grid_res, return = "result"), interpolation_control)
  full <- do.call(ps_interpolate, full_args); fixed_template <- full$template
  reference <- full$surfaces[[1]]; vals <- terra::values(pts); xy <- terra::crds(pts)
  rows <- list(); conditions <- list(); reduced <- list()
  for (i in seq_len(nrow(pts))) {
    id <- vals$Name[i]; .ps_progress(progress, i, nrow(pts), id, "started")
    cap <- .ps_capture_run(do.call(ps_interpolate, c(list(points = pts[-i], methods = method,
                                                          template = fixed_template, mask = mask,
                                                          return = "result"), interpolation_control)))
    if (is.null(cap$error)) {
      surface <- cap$value$surfaces[[1]]; reduced[[id]] <- surface
      predicted <- terra::extract(surface, pts[i], method = "bilinear")[[2]]
      metrics <- .ps_surface_change_metrics(reference, surface, contour_levels, difference_threshold)
      finite_change <- metrics$finite_cells - sum(is.finite(terra::values(reference, mat = FALSE)))
    } else {
      predicted <- NA_real_; metrics <- data.frame(mean_absolute_difference = NA_real_, maximum_absolute_difference = NA_real_, rmse_difference = NA_real_, affected_area_m2 = NA_real_, finite_area_m2 = NA_real_, finite_cells = 0L, contour_displacement = NA_real_, median_gradient_direction_change = NA_real_); finite_change <- NA_integer_
    }
    rows[[i]] <- data.frame(well_id = id, x = xy[i, 1], y = xy[i, 2], observed_head = vals$Z[i],
                           held_out_prediction = predicted,
                           held_out_residual = predicted - vals$Z[i], metrics,
                           finite_support_cell_change = finite_change,
                           status = if (is.null(cap$error)) "success" else "failed",
                           warning_count = length(cap$warnings), error_count = as.integer(!is.null(cap$error)),
                           warning_text = paste(vapply(cap$warnings, conditionMessage, character(1)), collapse = " | "),
                           error_text = if (is.null(cap$error)) "" else conditionMessage(cap$error),
                           stringsAsFactors = FALSE)
    conditions[[i]] <- .ps_condition_rows(c(cap$warnings, if (!is.null(cap$error)) list(cap$error) else list()),
                                           "ps_well_influence", method = method, run_id = id)
    .ps_progress(progress, i, nrow(pts), id, rows[[i]]$status)
  }
  manifest <- do.call(rbind, rows); cond <- do.call(rbind, conditions)
  .ps_new_result(list(influence = manifest, full_result = full,
                      reduced_surfaces = reduced),
                 "potentiomap_well_influence", call,
                 settings = list(method = method, contour_levels = contour_levels,
                                 difference_threshold = difference_threshold,
                                 fixed_geometry = TRUE),
                 metadata = .ps_surface_metadata(full), conditions = cond,
                 warnings = "Conditional influence may reflect location, network geometry, local gradient, unique hydrogeologic information, or an anomalous value; it is not an automatic removal rule.",
                 summary = manifest)
}

.ps_maximin_subset <- function(xy, n, seed) {
  set.seed(seed); center <- colMeans(xy); selected <- which.max(rowSums((xy - rep(center, each = nrow(xy)))^2))
  while (length(selected) < n) {
    d <- as.matrix(stats::dist(rbind(xy[selected, , drop = FALSE], xy)))
    candidate_rows <- length(selected) + seq_len(nrow(xy))
    nearest <- apply(d[candidate_rows, seq_along(selected), drop = FALSE], 1, min)
    nearest[selected] <- -Inf
    selected <- c(selected, which.max(nearest))
  }
  selected
}

#' Evaluate reproducible monitoring-network thinning scenarios
#'
#' @param points Groundwater-head points.
#' @param retain Fractions or exact retained counts.
#' @param design Random, spatial-coverage, or user subsets.
#' @param method Interpolation method.
#' @param repeats Number of planned runs per fraction.
#' @param subsets User-supplied lists of retained IDs.
#' @param template,mask,grid_res Fixed surface controls.
#' @param seed Deterministic seed.
#' @param progress Optional callback.
#' @return A `potentiomap_network_thinning` object.
#' @examples
#' data("synthetic_wells")
#' p <- ps_make_points(synthetic_wells[1:10, ], "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' thin <- ps_network_thinning(p, retain = 0.7, method = "IDW",
#'                             repeats = 2, grid_res = 350, seed = 8)
#' thin$summary
#' # Full-surface differences are descriptive, not error against truth.
#' @export
ps_network_thinning <- function(points, retain = c(0.75, 0.5, 0.25),
                                design = c("random", "spatial_coverage", "user"),
                                method = "TPS", repeats = 10, subsets = NULL,
                                template = NULL, mask = NULL, grid_res = NULL,
                                seed = 1, progress = NULL) {
  call <- match.call(); design <- match.arg(design); .validate_integer(repeats, "repeats", lower = 0)
  pts <- .ps_standard_points(points); .require_projected(pts, "points"); n_total <- nrow(pts)
  ids <- terra::values(pts)$Name; xy <- terra::crds(pts)
  if (design == "user") {
    if (!is.list(subsets) || !length(subsets)) .ps_abort("User thinning requires a nonempty list of retained-ID subsets.", "potentiomap_network_error")
    planned_sets <- subsets
  } else {
    if (!is.numeric(retain) || any(!is.finite(retain)) || any(retain <= 0)) .ps_abort("`retain` must contain positive fractions or counts.", "potentiomap_network_error")
    counts <- ifelse(retain <= 1, pmax(2, round(retain * n_total)), round(retain))
    if (any(counts >= n_total)) .ps_abort("Thinning must retain fewer than all observations.", "potentiomap_network_error")
    planned_sets <- list(); k <- 0L
    for (j in seq_along(counts)) for (r in seq_len(repeats)) {
      k <- k + 1L
      idx <- if (design == "random") { set.seed(seed + k - 1L); sample.int(n_total, counts[j]) } else .ps_maximin_subset(xy, counts[j], seed + k - 1L)
      planned_sets[[k]] <- ids[idx]
    }
  }
  for (z in planned_sets) if (!length(z) || any(!z %in% ids) || anyDuplicated(z)) .ps_abort("Every retained subset must contain unique known IDs.", "potentiomap_network_error")
  full <- ps_interpolate(pts, methods = method, template = template, mask = mask,
                         grid_res = grid_res, return = "result")
  reference <- full$surfaces[[1]]; rows <- list(); held <- list(); retained_manifest <- list(); conditions <- list()
  total_runs <- length(planned_sets)
  for (i in seq_along(planned_sets)) {
    retained_ids <- sort(unique(as.character(planned_sets[[i]]))); held_ids <- setdiff(ids, retained_ids)
    hash <- .ps_stable_hash(retained_ids); .ps_progress(progress, i, total_runs, hash, "started")
    train <- pts[match(retained_ids, ids)]; hold <- pts[match(held_ids, ids)]
    cap <- .ps_capture_run(ps_interpolate(train, methods = method, template = full$template,
                                          mask = mask, return = "result"))
    if (is.null(cap$error)) {
      surface <- cap$value$surfaces[[1]]
      pred <- terra::extract(surface, hold, method = "bilinear")[[2]]
      surface_metrics <- .ps_surface_change_metrics(reference, surface)
      errors <- .ps_metric_values(terra::values(hold)$Z, pred, c("me", "mae", "rmse", "maxae"))
    } else {
      pred <- rep(NA_real_, nrow(hold)); surface_metrics <- data.frame(mean_absolute_difference = NA_real_, maximum_absolute_difference = NA_real_, rmse_difference = NA_real_, affected_area_m2 = NA_real_, finite_area_m2 = NA_real_, finite_cells = 0, contour_displacement = NA_real_, median_gradient_direction_change = NA_real_)
      errors <- c(me = NA, mae = NA, rmse = NA, maxae = NA, finite_fraction = 0)
    }
    held[[i]] <- data.frame(run_id = sprintf("run_%04d", i), subset_hash = hash,
                            well_id = held_ids, observed = terra::values(hold)$Z,
                            predicted = pred, residual = pred - terra::values(hold)$Z)
    rows[[i]] <- data.frame(run_id = sprintf("run_%04d", i), subset_hash = hash,
                           retained_count = length(retained_ids), held_out_count = length(held_ids),
                           retained_fraction = length(retained_ids) / n_total,
                           me = errors[["me"]], mae = errors[["mae"]], rmse = errors[["rmse"]],
                           maxae = errors[["maxae"]], prediction_coverage = errors[["finite_fraction"]],
                           surface_metrics, status = if (is.null(cap$error)) "success" else "failed",
                           warning_text = paste(vapply(cap$warnings, conditionMessage, character(1)), collapse = " | "),
                           error_text = if (is.null(cap$error)) "" else conditionMessage(cap$error),
                           stringsAsFactors = FALSE)
    retained_manifest[[i]] <- data.frame(run_id = sprintf("run_%04d", i), subset_hash = hash,
                                         retained_ids = paste(retained_ids, collapse = "|"),
                                         held_out_ids = paste(sort(held_ids), collapse = "|"), stringsAsFactors = FALSE)
    conditions[[i]] <- .ps_condition_rows(c(cap$warnings, if (!is.null(cap$error)) list(cap$error) else list()), "ps_network_thinning", method = method, run_id = sprintf("run_%04d", i))
    .ps_progress(progress, i, total_runs, hash, rows[[i]]$status)
  }
  manifest <- do.call(rbind, rows); manifest$duplicate_retained_set <- duplicated(manifest$subset_hash) | duplicated(manifest$subset_hash, fromLast = TRUE)
  summary <- data.frame(planned_runs = nrow(manifest), unique_retained_sets = length(unique(manifest$subset_hash)),
                        duplicate_retained_sets = sum(duplicated(manifest$subset_hash)), successful_runs = sum(manifest$status == "success"))
  .ps_new_result(list(run_manifest = manifest,
                      retained_well_manifest = do.call(rbind, retained_manifest),
                      held_out_predictions = do.call(rbind, held),
                      validation_metrics = manifest[, c("run_id", "me", "mae", "rmse", "maxae", "prediction_coverage")],
                      full_surface_comparison = manifest[, c("run_id", "mean_absolute_difference", "maximum_absolute_difference", "rmse_difference", "finite_area_m2")],
                      full_result = full),
                 "potentiomap_network_thinning", call,
                 settings = list(retain = retain, design = design, method = method, repeats = repeats),
                 metadata = .ps_surface_metadata(full), conditions = do.call(rbind, conditions),
                 warnings = "Held-out measured-well error is predictive error; reduced-versus-full surface difference is descriptive and is not error against truth.",
                 summary = summary, seed = seed)
}

.ps_points_distance <- function(a, b) {
  matrix(as.numeric(sf::st_distance(sf::st_as_sf(a), sf::st_as_sf(b))), nrow = nrow(a), ncol = nrow(b))
}

.ps_constraint_membership <- function(points, polygon, relationship = "within") {
  if (is.null(polygon)) return(rep(TRUE, nrow(points)))
  p <- if (inherits(polygon, "SpatVector")) polygon else terra::vect(polygon)
  if (!.same_crs(points, p)) .ps_abort("Candidate constraints and points use different CRS.", "potentiomap_crs_error")
  mat <- sf::st_intersects(sf::st_as_sf(points), sf::st_as_sf(p), sparse = FALSE)
  apply(mat, 1, any)
}

#' Rank explicit candidate monitoring locations with recorded constraints
#'
#' @param existing_points Existing monitoring points.
#' @param candidates Explicit candidate point locations.
#' @param objective Candidate-scoring objective.
#' @param n_select Number selected by sequential greedy ranking.
#' @param target Explicit target points or raster for target-weighted objectives.
#' @param variogram_model,trend Model for kriging-variance reduction.
#' @param minimum_existing_distance,minimum_candidate_distance Spacing rules.
#' @param allowed_area,exclusion_area Spatial constraints.
#' @param cost Optional finite positive candidate costs.
#' @param user_score Optional supplied scores.
#' @param sequential Update scores after each choice.
#' @return A `potentiomap_candidate_network` object. The greedy sequence is not
#'   claimed to be globally optimal or to identify drillable sites.
#' @examples
#' data("synthetic_wells", "synthetic_candidate_sites")
#' p <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' c <- terra::vect(subset(synthetic_candidate_sites, !excluded),
#'                  geom = c("x", "y"), crs = "EPSG:26916")
#' design <- ps_candidate_network(p, c, n_select = 2,
#'                                objective = "spatial_coverage")
#' design$selected_sequence
#' # Sequential greedy selection is not a globally optimal drilling plan.
#' @export
ps_candidate_network <- function(existing_points, candidates,
                                 objective = c("spatial_coverage", "support_gap",
                                               "kriging_variance_reduction", "user_score"),
                                 n_select = 1, target = NULL,
                                 variogram_model = NULL, trend = NULL,
                                 minimum_existing_distance = 0,
                                 minimum_candidate_distance = 0,
                                 allowed_area = NULL, exclusion_area = NULL,
                                 cost = NULL, user_score = NULL,
                                 sequential = TRUE) {
  call <- match.call(); objective <- match.arg(objective); .validate_integer(n_select, "n_select", lower = 0)
  .validate_number(minimum_existing_distance, "minimum_existing_distance", lower = 0, inclusive = TRUE)
  .validate_number(minimum_candidate_distance, "minimum_candidate_distance", lower = 0, inclusive = TRUE)
  .ps_scalar_logical(sequential, "sequential")
  existing <- .ps_standard_points(existing_points, name = "existing_points")
  cand <- if (inherits(candidates, "SpatVector")) candidates else terra::vect(candidates)
  .require_projected(existing, "existing_points"); .require_crs(cand, "candidates")
  if (!.same_crs(existing, cand) || terra::geomtype(cand) != "points") .ps_abort("Candidates must be points in the existing network CRS.", "potentiomap_candidate_network_error")
  if (n_select > nrow(cand)) .ps_abort("`n_select` exceeds the candidate count.", "potentiomap_candidate_network_error")
  cv <- terra::values(cand)
  if (!"Name" %in% names(cv)) {
    cv <- data.frame(Name = .ps_stable_ids("candidate", nrow(cand)))
    terra::values(cand) <- cv
  }
  candidate_id <- as.character(cv$Name)
  d_existing <- apply(.ps_points_distance(cand, existing), 1, min)
  allowed <- .ps_constraint_membership(cand, allowed_area)
  excluded <- if (is.null(exclusion_area)) rep(FALSE, nrow(cand)) else .ps_constraint_membership(cand, exclusion_area)
  eligible <- allowed & !excluded & d_existing >= minimum_existing_distance
  reasons <- ifelse(!allowed, "outside_allowed_area", ifelse(excluded, "inside_exclusion_area", ifelse(d_existing < minimum_existing_distance, "too_close_to_existing", "eligible")))
  if (!is.null(cost) && (length(cost) != nrow(cand) || any(!is.finite(cost)) || any(cost <= 0))) .ps_abort("`cost` must be finite and positive for every candidate.", "potentiomap_candidate_network_error")
  if (objective == "user_score" && (is.null(user_score) || length(user_score) != nrow(cand) || any(!is.finite(user_score)))) .ps_abort("`user_score` must provide one finite value per candidate.", "potentiomap_candidate_network_error")
  target_points <- if (is.null(target)) cand else if (inherits(target, "SpatRaster")) terra::as.points(target, values = FALSE, na.rm = TRUE) else if (inherits(target, "SpatVector")) target else terra::vect(target)
  if (!.same_crs(existing, target_points)) .ps_abort("Target and network CRS differ.", "potentiomap_crs_error")
  if (objective == "support_gap" && is.null(target)) .ps_abort("Support-gap scoring requires an explicit target.", "potentiomap_candidate_network_error")
  if (objective == "kriging_variance_reduction" && (is.null(variogram_model) || is.null(trend))) .ps_abort("Kriging-variance reduction requires an explicit variogram model and trend.", "potentiomap_candidate_network_error")
  selected <- integer(); sequence_rows <- list(); score_history <- list()
  ex_xy <- terra::crds(existing, df = TRUE)
  current <- terra::vect(data.frame(X = ex_xy[, 1], Y = ex_xy[, 2],
                                    Z = terra::values(existing)$Z,
                                    Name = terra::values(existing)$Name),
                           geom = c("X", "Y"), crs = terra::crs(existing))
  before_nearest <- apply(.ps_points_distance(target_points, current), 1, min)
  before_variance <- NULL
  for (step in seq_len(n_select)) {
    scores <- rep(NA_real_, nrow(cand)); available <- eligible & !seq_len(nrow(cand)) %in% selected
    if (length(selected) && minimum_candidate_distance > 0) {
      available <- available & apply(.ps_points_distance(cand, cand[selected]), 1, min) >= minimum_candidate_distance
    }
    for (i in which(available)) {
      if (objective %in% c("spatial_coverage", "support_gap")) {
        d_new <- .ps_points_distance(target_points, cand[i])[, 1]
        scores[i] <- sum(pmax(0, before_nearest - pmin(before_nearest, d_new)), na.rm = TRUE)
      } else if (objective == "user_score") scores[i] <- user_score[i]
      else {
        base <- .kriging_frame(current); base_formula <- if (inherits(trend, "formula")) trend else stats::as.formula(trend)
        target_grid <- as.data.frame(terra::crds(target_points, df = TRUE)); names(target_grid) <- c("X", "Y")
        base_pred <- gstat::krige(base_formula, ~ X + Y, data = base, newdata = target_grid, model = variogram_model)
        add <- .kriging_frame(cand[i]); add$Z <- mean(base$Z); augmented <- rbind(base, add)
        aug_pred <- gstat::krige(base_formula, ~ X + Y, data = augmented, newdata = target_grid, model = variogram_model)
        scores[i] <- sum(base_pred$var1.var - aug_pred$var1.var, na.rm = TRUE)
        if (is.null(before_variance)) before_variance <- sum(base_pred$var1.var, na.rm = TRUE)
      }
    }
    if (!any(is.finite(scores))) break
    choice <- which.max(scores); selected <- c(selected, choice)
    gain <- scores[choice]
    sequence_rows[[step]] <- data.frame(sequence = step, candidate_id = candidate_id[choice], information_gain = gain,
                                        cost = if (is.null(cost)) NA_real_ else cost[choice],
                                        gain_per_unit_cost = if (is.null(cost)) NA_real_ else gain / cost[choice],
                                        objective = objective, stringsAsFactors = FALSE)
    score_history[[step]] <- data.frame(sequence = step, candidate_id = candidate_id,
                                        score = scores, eligible = available, selected = seq_len(nrow(cand)) == choice)
    if (sequential) {
      chosen_xy <- terra::crds(cand[choice], df = TRUE)
      chosen_point <- terra::vect(data.frame(X = chosen_xy[, 1], Y = chosen_xy[, 2],
                                             Z = mean(terra::values(current)$Z),
                                             Name = candidate_id[choice]),
                                    geom = c("X", "Y"), crs = terra::crs(current))
      current <- rbind(current, chosen_point)
      before_nearest <- apply(.ps_points_distance(target_points, current), 1, min)
    }
  }
  constraints <- data.frame(candidate_id = candidate_id, minimum_existing_distance = d_existing,
                            allowed = allowed, excluded = excluded, eligible = eligible,
                            reason = reasons, stringsAsFactors = FALSE)
  after_nearest <- apply(.ps_points_distance(target_points, current), 1, min)
  target_summary <- data.frame(target_count = nrow(target_points),
                               mean_nearest_before = mean(apply(.ps_points_distance(target_points, existing), 1, min)),
                               mean_nearest_after = mean(after_nearest),
                               total_coverage_improvement = sum(apply(.ps_points_distance(target_points, existing), 1, min) - after_nearest),
                               variance_before = before_variance %||% NA_real_,
                               variance_after = if (!is.null(before_variance) && length(sequence_rows)) before_variance - sum(vapply(sequence_rows, function(z) z$information_gain, numeric(1))) else NA_real_)
  .ps_new_result(list(candidate_scores = if (length(score_history)) do.call(rbind, score_history) else data.frame(),
                      selected_sequence = if (length(sequence_rows)) do.call(rbind, sequence_rows) else data.frame(),
                      constraint_failures = constraints[!constraints$eligible, , drop = FALSE],
                      constraint_manifest = constraints,
                      target_summary = target_summary),
                 "potentiomap_candidate_network", call,
                 settings = list(objective = objective, n_select = n_select,
                                 minimum_existing_distance = minimum_existing_distance,
                                 minimum_candidate_distance = minimum_candidate_distance,
                                 sequential = sequential),
                 metadata = .ps_surface_metadata(existing),
                 warnings = if (objective == "kriging_variance_reduction") "Variance reduction is conditional on the supplied covariance model and geometry, not the unknown future head; sequential greedy choices are not globally optimal." else if (objective == "user_score") "User scores are preserved and ranked but are not claimed to be hydrogeologically optimal." else "Sequential greedy candidate ranking is not globally optimal and does not establish drillability.",
                 summary = target_summary)
}

#' Evaluate explicit interpolation sensitivity scenarios
#'
#' @param points Groundwater-head points.
#' @param method Interpolation method.
#' @param scenarios Explicit data frame or named parameter grid.
#' @param reference Scenario ID or row used as reference.
#' @param template,mask Default mapping controls.
#' @param maximum_runs Maximum scenario guard.
#' @param contour_levels Optional contour levels.
#' @param compare_gradient Compare gradient direction.
#' @param seed Deterministic seed.
#' @param progress Optional callback.
#' @return A `potentiomap_sensitivity` object. No preferred scenario is selected.
#' @examples
#' data("synthetic_wells")
#' p <- ps_make_points(synthetic_wells[1:12, ], "x", "y", "gw_elevation",
#'                     "well_id", "EPSG:26916")
#' scenarios <- data.frame(idw_power = c(1.5, 2), grid_res = c(300, 300))
#' sensitivity <- ps_surface_sensitivity(p, "IDW", scenarios, reference = 1)
#' sensitivity$comparisons[, c("scenario_id", "mean_absolute_difference")]
#' # Sensitivity comparison does not select a universally preferred setting.
#' @export
ps_surface_sensitivity <- function(points, method, scenarios, reference = NULL,
                                   template = NULL, mask = NULL,
                                   maximum_runs = 100, contour_levels = NULL,
                                   compare_gradient = TRUE, seed = 1,
                                   progress = NULL) {
  call <- match.call(); .validate_integer(maximum_runs, "maximum_runs", lower = 0)
  .ps_scalar_logical(compare_gradient, "compare_gradient"); pts <- .ps_standard_points(points)
  tab <- if (is.data.frame(scenarios)) scenarios else if (is.list(scenarios) && !is.null(names(scenarios))) do.call(expand.grid, c(scenarios, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)) else NULL
  if (is.null(tab) || !nrow(tab)) .ps_abort("`scenarios` must be an explicit nonempty data frame or named parameter grid.", "potentiomap_sensitivity_error")
  if (nrow(tab) > maximum_runs) .ps_abort("Scenario count exceeds `maximum_runs`.", "potentiomap_sensitivity_error")
  if (nrow(tab) > 50L) .ps_warn(sprintf("Sensitivity analysis will fit %d scenarios.", nrow(tab)), "potentiomap_large_analysis_warning")
  tab$scenario_id <- if ("scenario_id" %in% names(tab)) as.character(tab$scenario_id) else .ps_stable_ids("scenario", nrow(tab))
  if (any(!nzchar(tab$scenario_id)) || anyDuplicated(tab$scenario_id)) .ps_abort("Scenario IDs must be unique and nonempty.", "potentiomap_sensitivity_error")
  reference_id <- if (is.null(reference)) tab$scenario_id[1] else if (is.numeric(reference)) tab$scenario_id[reference] else as.character(reference)
  if (length(reference_id) != 1L || !reference_id %in% tab$scenario_id) .ps_abort("Reference scenario was not found.", "potentiomap_sensitivity_error")
  surfaces <- list(); run_rows <- list(); conditions <- list(); runtime <- numeric(nrow(tab))
  reserved <- c("scenario_id", "mask", "template")
  for (i in seq_len(nrow(tab))) {
    id <- tab$scenario_id[i]; .ps_progress(progress, i, nrow(tab), id, "started")
    params <- as.list(tab[i, setdiff(names(tab), "scenario_id"), drop = FALSE]); params <- params[!vapply(params, function(z) length(z) == 1L && is.na(z), logical(1))]
    scenario_mask <- params$mask %||% mask; scenario_template <- params$template %||% template; params[intersect(names(params), reserved)] <- NULL
    start <- proc.time()[[3]]; cap <- .ps_capture_run(do.call(ps_interpolate, c(list(points = pts, methods = method, template = scenario_template, mask = scenario_mask, return = "result"), params))); runtime[i] <- proc.time()[[3]] - start
    if (!is.null(cap$value)) surfaces[[id]] <- cap$value$surfaces[[1]]
    run_rows[[i]] <- data.frame(scenario_id = id, status = if (is.null(cap$error)) "success" else "failed",
                                runtime_seconds = runtime[i], warning_count = length(cap$warnings), error_count = as.integer(!is.null(cap$error)),
                                warning_text = paste(vapply(cap$warnings, conditionMessage, character(1)), collapse = " | "),
                                error_text = if (is.null(cap$error)) "" else conditionMessage(cap$error), stringsAsFactors = FALSE)
    conditions[[i]] <- .ps_condition_rows(c(cap$warnings, if (!is.null(cap$error)) list(cap$error) else list()), "ps_surface_sensitivity", method = method, run_id = id)
    .ps_progress(progress, i, nrow(tab), id, run_rows[[i]]$status)
  }
  if (is.null(surfaces[[reference_id]])) .ps_abort("The reference scenario failed; comparisons are undefined.", "potentiomap_sensitivity_error")
  reference_surface <- surfaces[[reference_id]]; comparisons <- list()
  for (i in seq_len(nrow(tab))) {
    id <- tab$scenario_id[i]
    if (is.null(surfaces[[id]])) {
      comparisons[[i]] <- data.frame(scenario_id = id, reference_id = reference_id,
                                      mean_absolute_difference = NA_real_, maximum_absolute_difference = NA_real_,
                                      rmse_difference = NA_real_, contour_displacement = NA_real_,
                                      median_gradient_direction_change = NA_real_, finite_area_m2 = NA_real_,
                                      support_area_change_m2 = NA_real_)
    } else if (id == reference_id) {
      area <- sum(.ps_cell_area_values(reference_surface)[is.finite(terra::values(reference_surface, mat = FALSE))], na.rm = TRUE)
      comparisons[[i]] <- data.frame(scenario_id = id, reference_id = reference_id,
                                      mean_absolute_difference = 0, maximum_absolute_difference = 0,
                                      rmse_difference = 0, contour_displacement = 0,
                                      median_gradient_direction_change = 0, finite_area_m2 = area,
                                      support_area_change_m2 = 0)
    } else {
      aligned <- .ps_align_pair(reference_surface, surfaces[[id]], align = if (isTRUE(terra::compareGeom(reference_surface, surfaces[[id]], stopOnError = FALSE))) "error" else "to_a", method = "bilinear")
      metrics <- .ps_surface_change_metrics(aligned$a, aligned$b, contour_levels)
      ref_area <- sum(.ps_cell_area_values(reference_surface)[is.finite(terra::values(reference_surface, mat = FALSE))], na.rm = TRUE)
      comparisons[[i]] <- cbind(data.frame(scenario_id = id, reference_id = reference_id), metrics[, c("mean_absolute_difference", "maximum_absolute_difference", "rmse_difference", "contour_displacement", "median_gradient_direction_change", "finite_area_m2")], support_area_change_m2 = metrics$finite_area_m2 - ref_area)
    }
  }
  comparison <- merge(do.call(rbind, comparisons), do.call(rbind, run_rows), by = "scenario_id", all.x = TRUE)
  .ps_new_result(list(scenarios = tab, surfaces = surfaces,
                      run_manifest = do.call(rbind, run_rows), comparisons = comparison),
                 "potentiomap_sensitivity", call,
                 settings = list(method = method, reference_id = reference_id,
                                 contour_levels = contour_levels, compare_gradient = compare_gradient,
                                 maximum_runs = maximum_runs),
                 metadata = .ps_surface_metadata(pts), conditions = do.call(rbind, conditions),
                 warnings = "Sensitivity differences are conditional comparisons on reported common support; no preferred scenario is selected automatically.",
                 summary = comparison, seed = seed)
}

#' @export
as.data.frame.potentiomap_head_change <- function(x, ...) x$paired_measured_change
#' @export
as.data.frame.potentiomap_well_influence <- function(x, ...) x$influence
#' @export
as.data.frame.potentiomap_network_thinning <- function(x, ...) x$run_manifest
#' @export
as.data.frame.potentiomap_candidate_network <- function(x, ...) x$candidate_scores
#' @export
as.data.frame.potentiomap_sensitivity <- function(x, ...) x$comparisons
