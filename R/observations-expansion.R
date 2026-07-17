.ps_issue_table <- function() {
  data.frame(
    issue_id = character(), record_id = character(), issue_code = character(),
    severity = character(), field = character(), message = character(),
    suggested_review = character(), stringsAsFactors = FALSE
  )
}

.ps_add_issue <- function(issues, rows, record_ids, code, severity, field,
                          message, review) {
  rows <- which(rows)
  if (!length(rows)) return(issues)
  add <- data.frame(
    issue_id = NA_character_, record_id = record_ids[rows], issue_code = code,
    severity = severity, field = field, message = message,
    suggested_review = review, stringsAsFactors = FALSE
  )
  rbind(issues, add)
}

#' Check groundwater observation records
#'
#' Reports deterministic input conflicts and statistical review flags before
#' interpolation. Unusual values are never automatically treated as errors or
#' deleted. Coordinate distance checks require a known projected CRS; longitude
#' and latitude are flagged for planar analysis. Screen and head comparisons
#' assume all elevations use one documented vertical datum.
#'
#' @param data A data frame, `sf` object, or point `SpatVector`.
#' @param x,y,value,id,datetime,unit,vertical_datum,depth,surface_elevation
#'   Optional column names for location, measurement, timing, unit, datum, and
#'   land-surface fields.
#' @param screen_top,screen_bottom,unit_group Optional screen-elevation and
#'   hydrogeologic-unit column names.
#' @param duplicate_tolerance Nonnegative coordinate distance within which
#'   different records are flagged as colocated. Use projected map units.
#' @param action Return only the report or also deterministically remove records
#'   with missing IDs, coordinates, or heads.
#' @return A `potentiomap_observation_check` with `issues`, original `data`,
#'   `retained`, `removed`, counts, settings, metadata, and conditions.
#' @export
#' @examples
#' d <- data.frame(id = c("A", "A"), x = c(0, 0), y = c(0, 0),
#'                 head = c(10, 11))
#' attr(d, "crs") <- "EPSG:26920"
#' check <- ps_check_observations(d, "x", "y", "head", "id")
#' check$issues
#' # Flags require hydrogeologic review; they do not prove a record is wrong.
ps_check_observations <- function(data, x = NULL, y = NULL, value = NULL,
                                  id = NULL, datetime = NULL, unit = NULL,
                                  vertical_datum = NULL, depth = NULL,
                                  surface_elevation = NULL, screen_top = NULL,
                                  screen_bottom = NULL, unit_group = NULL,
                                  duplicate_tolerance = 0,
                                  action = c("report", "return_clean")) {
  call <- match.call(); action <- match.arg(action)
  .validate_number(duplicate_tolerance, "duplicate_tolerance", lower = 0,
                   inclusive = TRUE)
  spatial <- inherits(data, "SpatVector") || inherits(data, "sf") || inherits(data, "sfc")
  if (inherits(data, "SpatVector")) {
    d <- terra::values(data); xy <- terra::crds(data, df = TRUE)
    crs <- terra::crs(data); lonlat <- terra::is.lonlat(data)
  } else if (inherits(data, "sf") || inherits(data, "sfc")) {
    obj <- sf::st_as_sf(data); d <- sf::st_drop_geometry(obj)
    xy <- sf::st_coordinates(obj)[, 1:2, drop = FALSE]
    crs <- sf::st_crs(obj)$wkt %||% ""; lonlat <- isTRUE(sf::st_is_longlat(obj))
  } else if (is.data.frame(data)) {
    d <- data; xy <- matrix(NA_real_, nrow(d), 2L)
    if (!is.null(x) && x %in% names(d)) xy[, 1] <- suppressWarnings(as.numeric(d[[x]]))
    if (!is.null(y) && y %in% names(d)) xy[, 2] <- suppressWarnings(as.numeric(d[[y]]))
    crs <- attr(data, "crs", exact = TRUE) %||% ""; lonlat <- FALSE
  } else {
    .ps_abort("`data` must be a data frame, sf object, or point SpatVector.",
              "potentiomap_validation_error")
  }
  n <- nrow(d); row_id <- sprintf("record_%04d", seq_len(n))
  col <- function(nm, default = rep(NA, n)) {
    if (is.null(nm) || !nm %in% names(d)) default else d[[nm]]
  }
  ids <- as.character(col(id, row_id)); heads <- suppressWarnings(as.numeric(col(value)))
  times <- col(datetime); units <- as.character(col(unit)); datums <- as.character(col(vertical_datum))
  depths <- suppressWarnings(as.numeric(col(depth))); lands <- suppressWarnings(as.numeric(col(surface_elevation)))
  tops <- suppressWarnings(as.numeric(col(screen_top))); bottoms <- suppressWarnings(as.numeric(col(screen_bottom)))
  groups <- as.character(col(unit_group))
  issues <- .ps_issue_table()
  add <- function(rows, code, severity, field, message, review) {
    issues <<- .ps_add_issue(issues, rows, row_id, code, severity, field, message, review)
  }
  add(is.na(ids) | !nzchar(ids), "missing_identifier", "error", id %||% "id",
      "Observation identifier is missing.", "Assign a stable well or observation identifier.")
  add(!is.finite(xy[, 1]) | !is.finite(xy[, 2]), "missing_coordinate", "error",
      paste(c(x, y), collapse = "/"), "One or both coordinates are missing.",
      "Recover coordinates from an authoritative location record.")
  add((!is.na(xy[, 1]) & !is.finite(xy[, 1])) | (!is.na(xy[, 2]) & !is.finite(xy[, 2])),
      "nonfinite_coordinate", "error", paste(c(x, y), collapse = "/"),
      "A coordinate is nonfinite.", "Correct or exclude the deterministic invalid coordinate.")
  if (!nzchar(crs)) add(rep(TRUE, n), "missing_crs", "error", "crs",
                        "Coordinate reference system is missing.",
                        "Assign the known CRS; do not guess it from coordinate values.")
  if (lonlat) add(rep(TRUE, n), "geographic_crs_for_planar_analysis", "warning", "crs",
                  "Longitude/latitude is unsuitable for implicit planar distances.",
                  "Transform to an appropriate projected CRS or choose an explicit geodesic analysis.")
  add(is.na(heads), "missing_head", "error", value %||% "head",
      "Hydraulic head is missing.", "Recover the measurement or exclude it explicitly.")
  add(!is.na(heads) & !is.finite(heads), "nonfinite_head", "error", value %||% "head",
      "Hydraulic head is nonfinite.", "Correct or exclude the deterministic invalid value.")
  if (!is.null(unit)) add(is.na(units) | !nzchar(units), "missing_unit", "error", unit,
                          "Head unit is missing.", "Document the measurement unit before conversion or comparison.")
  if (!is.null(vertical_datum)) add(is.na(datums) | !nzchar(datums), "missing_vertical_datum", "error", vertical_datum,
                                    "Vertical datum is missing.", "Recover the named vertical reference; do not infer it from the horizontal CRS.")
  duplicate_record <- duplicated(d) | duplicated(d, fromLast = TRUE)
  add(duplicate_record, "duplicate_record", "warning", "record",
      "The complete record is duplicated.", "Confirm whether it is a duplicate import or an intentional repeat.")
  if (!is.null(datetime)) {
    key <- paste(ids, as.character(times), sep = "|")
    add(duplicated(key) | duplicated(key, fromLast = TRUE), "duplicate_well_datetime", "warning",
        paste(id, datetime, sep = "/"), "Multiple records share a well and time.",
        "Resolve the duplicate explicitly; values are not averaged automatically.")
    add(is.na(times) | !nzchar(as.character(times)), "missing_event_time", "warning", datetime,
        "Event time is missing.", "Recover measurement time before selecting a monitoring event.")
    parsed <- suppressWarnings(as.POSIXct(times, tz = "UTC"))
    if (sum(is.finite(as.numeric(parsed))) > 1L) {
      span <- diff(range(parsed, na.rm = TRUE))
      if (as.numeric(span, units = "hours") > 24) {
        add(rep(TRUE, n), "non_synoptic_span", "warning", datetime,
            "Observation times span more than 24 hours.",
            "Choose and document an acceptable event window for the study objective.")
      }
    }
  }
  finite_xy <- is.finite(xy[, 1]) & is.finite(xy[, 2])
  if (sum(finite_xy) > 1L) {
    distm <- as.matrix(stats::dist(xy[finite_xy, , drop = FALSE]))
    diag(distm) <- Inf
    near <- apply(distm <= duplicate_tolerance, 1, any)
    coordinate_dup <- rep(FALSE, n); coordinate_dup[which(finite_xy)] <- near
    add(coordinate_dup, "duplicate_coordinate", "warning", paste(c(x, y), collapse = "/"),
        "Another observation is at the same or tolerance-equivalent coordinate.",
        "Review colocated screens, repeated measurements, and interpolation duplicate policy.")
  }
  if (any(!is.na(ids) & nzchar(ids))) {
    by_id <- split(seq_len(n), ids)
    same_id_diff <- rep(FALSE, n)
    conflict <- rep(FALSE, n)
    for (idx in by_id) {
      if (length(idx) > 1L && length(unique(paste(xy[idx, 1], xy[idx, 2]))) > 1L) same_id_diff[idx] <- TRUE
      hv <- heads[idx][is.finite(heads[idx])]
      if (length(unique(hv)) > 1L && (is.null(datetime) || length(unique(as.character(times[idx]))) == 1L)) conflict[idx] <- TRUE
    }
    add(same_id_diff, "same_id_different_coordinate", "error", id %||% "id",
        "One identifier occurs at different coordinates.", "Resolve well identity or location history.")
    add(conflict, "conflicting_head", "warning", value %||% "head",
        "The same well/event has conflicting heads.", "Review measurement qualifiers and do not average silently.")
  }
  add(!is.na(depths) & depths < 0, "invalid_depth_sign", "warning", depth %||% "depth",
      "A depth is negative under the common positive-down convention.",
      "Confirm the recorded depth sign and reference.")
  if (!is.null(depth) && !is.null(surface_elevation) && !is.null(value)) {
    mismatch <- is.finite(lands) & is.finite(depths) & is.finite(heads) &
      abs((lands - depths) - heads) > sqrt(.Machine$double.eps) * pmax(1, abs(heads))
    add(mismatch, "inconsistent_surface_minus_depth", "warning", paste(surface_elevation, depth, value, sep = "/"),
        "Land elevation minus depth does not equal the supplied head.",
        "Check units, datum, measuring-point offset, and depth sign.")
  }
  add(is.finite(tops) & is.finite(bottoms) & tops < bottoms, "reversed_screen_interval", "error",
      paste(screen_top, screen_bottom, sep = "/"), "Screen top is below screen bottom.",
      "Confirm that both are absolute elevations using the same datum.")
  add(is.finite(tops) & is.finite(bottoms) & is.finite(heads) & (heads > tops | heads < bottoms),
      "head_outside_screen", "warning", value %||% "head",
      "Head lies outside the screen-elevation interval.",
      "This can be physically valid under pressure; review reference information rather than deleting it.")
  if (!is.null(screen_top) || !is.null(screen_bottom)) {
    add(!is.finite(tops) | !is.finite(bottoms), "missing_screen_information", "warning",
        paste(screen_top, screen_bottom, sep = "/"), "Screen interval is incomplete.",
        "Recover construction information before assigning a water-bearing unit.")
  }
  if (sum(is.finite(heads)) >= 4L) {
    qs <- stats::quantile(heads, c(.25, .75), na.rm = TRUE); spread <- diff(qs)
    extreme <- is.finite(heads) & (heads < qs[1] - 3 * spread | heads > qs[2] + 3 * spread)
    add(extreme, "extreme_value_flag", "review", value %||% "head",
        "Head is an extreme value relative to the supplied records.",
        "Review field notes and hydrogeologic context; unusual values are not removed automatically.")
  }
  if (!is.null(unit_group)) add(is.na(groups) | !nzchar(groups), "ambiguous_unit_group", "warning", unit_group,
                                "Water-bearing-unit group is missing or ambiguous.",
                                "Use construction logs and an explicit grouping rule.")
  if (nrow(issues)) issues$issue_id <- sprintf("issue_%05d", seq_len(nrow(issues)))
  deterministic_codes <- c("missing_identifier", "missing_coordinate", "nonfinite_coordinate",
                           "missing_head", "nonfinite_head")
  remove_ids <- unique(issues$record_id[issues$issue_code %in% deterministic_codes])
  keep <- !row_id %in% remove_ids
  retained <- if (action == "return_clean") d[keep, , drop = FALSE] else d
  removed <- if (action == "return_clean") {
    out <- d[!keep, , drop = FALSE]
    if (nrow(out)) out$removal_reason <- vapply(row_id[!keep], function(z) {
      paste(unique(issues$issue_code[issues$record_id == z & issues$issue_code %in% deterministic_codes]), collapse = "|")
    }, character(1))
    out
  } else d[0, , drop = FALSE]
  summary <- data.frame(
    original_count = n, retained_count = nrow(retained), removed_count = nrow(removed),
    issue_count = nrow(issues), error_count = sum(issues$severity == "error"),
    warning_count = sum(issues$severity == "warning"), review_count = sum(issues$severity == "review")
  )
  .ps_new_result(list(issues = issues, data = d, retained = retained, removed = removed),
                 "potentiomap_observation_check", call, settings = list(
                   duplicate_tolerance = duplicate_tolerance, action = action,
                   spatial_input = spatial), metadata = list(crs = crs), summary = summary)
}

#' Select a groundwater monitoring event
#'
#' Selects at most one record per well inside a symmetric time window. The
#' result records the actual measurement span; being inside a window does not
#' by itself make an event synoptic and repeated values are never averaged.
#'
#' @param data Observation data frame.
#' @param id,datetime Column names for well ID and measurement time.
#' @param center Target time coercible to `POSIXct`.
#' @param window Nonnegative seconds, a `difftime`, or a string accepted by
#'   `as.difftime()`.
#' @param rule Deterministic selection rule.
#' @param quality Optional quality column for `best_quality`; lower sorted value
#'   is preferred and time distance breaks ties.
#' @param timezone Time zone used to parse and retain times.
#' @param maximum_span Optional maximum selected-event span.
#' @param maximum_span_action Warn or error when the maximum is exceeded.
#' @return A `potentiomap_event_selection` containing selected, excluded and tie
#'   records plus an event summary.
#' @export
#' @examples
#' d <- data.frame(well = c("A", "A", "B"),
#'   time = c("2026-01-01 00:00", "2026-01-01 02:00", "2026-01-01 01:00"))
#' ev <- ps_select_event(d, "well", "time", "2026-01-01 01:00", 3 * 3600)
#' ev$selected
#' # The recorded span still requires a study-specific synoptic judgment.
ps_select_event <- function(data, id, datetime, center, window,
                            rule = c("nearest", "earliest", "latest", "best_quality"),
                            quality = NULL, timezone = "UTC", maximum_span = NULL,
                            maximum_span_action = c("warn", "error")) {
  call <- match.call(); rule <- match.arg(rule); maximum_span_action <- match.arg(maximum_span_action)
  if (!is.data.frame(data)) .ps_abort("`data` must be a data frame.", "potentiomap_event_selection_error")
  for (nm in c(id, datetime)) if (!is.character(nm) || length(nm) != 1L || !nm %in% names(data)) {
    .ps_abort("`id` and `datetime` must name columns in `data`.", "potentiomap_event_selection_error")
  }
  if (rule == "best_quality" && (is.null(quality) || !quality %in% names(data))) {
    .ps_abort("`quality` must name a column for `rule = \"best_quality\"`.", "potentiomap_event_selection_error")
  }
  center_time <- suppressWarnings(tryCatch(
    as.POSIXct(center, tz = timezone), error = function(e) NULL
  ))
  times <- suppressWarnings(tryCatch(
    as.POSIXct(data[[datetime]], tz = timezone), error = function(e) NULL
  ))
  if (is.null(center_time) || is.null(times) ||
      !is.finite(as.numeric(center_time)) || anyNA(times)) {
    .ps_abort("`center` and every event time must be parseable.", "potentiomap_event_selection_error")
  }
  seconds <- if (inherits(window, "difftime")) as.numeric(window, units = "secs") else as.numeric(window)
  .validate_number(seconds, "window", lower = 0, inclusive = TRUE)
  ids <- as.character(data[[id]])
  if (anyNA(ids) || any(!nzchar(ids))) .ps_abort("Event-selection IDs must be nonmissing.", "potentiomap_event_selection_error")
  delta <- abs(as.numeric(difftime(times, center_time, units = "secs")))
  eligible <- delta <= seconds
  selected_index <- integer(); tie_index <- integer()
  for (well in unique(ids)) {
    idx <- which(ids == well & eligible)
    if (!length(idx)) next
    ord <- switch(rule,
      nearest = order(delta[idx], times[idx], idx),
      earliest = order(times[idx], delta[idx], idx),
      latest = order(-as.numeric(times[idx]), delta[idx], idx),
      best_quality = order(data[[quality]][idx], delta[idx], times[idx], idx, na.last = TRUE)
    )
    chosen <- idx[ord[1]]; selected_index <- c(selected_index, chosen)
    primary <- switch(rule, nearest = delta[idx], earliest = as.numeric(times[idx]),
                      latest = -as.numeric(times[idx]), best_quality = data[[quality]][idx])
    tied <- idx[!is.na(primary) & primary == primary[match(chosen, idx)]]
    if (length(tied) > 1L) tie_index <- c(tie_index, tied)
  }
  selected_index <- sort(selected_index)
  selected <- data[selected_index, , drop = FALSE]
  selected[[datetime]] <- times[selected_index]
  excluded <- data[-selected_index, , drop = FALSE]
  excluded$exclusion_reason <- ifelse(!eligible[-selected_index], "outside_window", "not_selected_by_rule")
  ties <- data[sort(unique(tie_index)), , drop = FALSE]
  if (nrow(ties)) ties[[datetime]] <- times[sort(unique(tie_index))]
  span <- if (nrow(selected) > 1L) diff(range(selected[[datetime]])) else as.difftime(0, units = "secs")
  if (!is.null(maximum_span)) {
    max_seconds <- if (inherits(maximum_span, "difftime")) as.numeric(maximum_span, units = "secs") else as.numeric(maximum_span)
    .validate_number(max_seconds, "maximum_span", lower = 0, inclusive = TRUE)
    if (as.numeric(span, units = "secs") > max_seconds) {
      msg <- "Selected event exceeds `maximum_span`; records inside a window are not automatically synoptic."
      if (maximum_span_action == "error") .ps_abort(msg, "potentiomap_event_selection_error")
      .ps_warn(msg, "potentiomap_event_selection_warning")
    }
  }
  summary <- data.frame(
    target_time = format(center_time, tz = timezone, usetz = TRUE),
    window_start = format(center_time - seconds, tz = timezone, usetz = TRUE),
    window_end = format(center_time + seconds, tz = timezone, usetz = TRUE),
    selected_minimum_time = if (nrow(selected)) format(min(selected[[datetime]]), tz = timezone, usetz = TRUE) else NA_character_,
    selected_maximum_time = if (nrow(selected)) format(max(selected[[datetime]]), tz = timezone, usetz = TRUE) else NA_character_,
    actual_span_seconds = as.numeric(span, units = "secs"), well_count = nrow(selected),
    tie_count = length(unique(tie_index)), excluded_count = nrow(excluded), stringsAsFactors = FALSE
  )
  .ps_new_result(list(selected = selected, excluded = excluded, ties = ties),
                 "potentiomap_event_selection", call,
                 settings = list(rule = rule, timezone = timezone, window_seconds = seconds,
                                 maximum_span = maximum_span, maximum_span_action = maximum_span_action),
                 summary = summary)
}

#' Assign or validate monitoring-well screen groups
#'
#' Preserves an existing water-bearing-unit field, applies explicit interval
#' rules, or creates descriptive depth/elevation bins. Screen intervals alone do
#' not establish hydrostratigraphic identity, and depth bins are never labeled as
#' aquifers.
#'
#' @param data Observation data frame.
#' @param mode Existing labels, explicit interval rules, or descriptive bins.
#' @param unit_col Existing-label column.
#' @param screen_top,screen_bottom Screen-elevation column names; top must be
#'   greater than bottom.
#' @param rules Data frame with `unit`, `top`, and `bottom` absolute elevations.
#' @param breaks,labels Bin specification for `depth_bins`.
#' @param overlap_required Minimum fraction of screen length overlapping a rule.
#' @param ambiguous_action Return or error on multiple qualifying groups.
#' @return A `potentiomap_screen_groups` with assignments, overlap records,
#'   ambiguous/unclassified records, rules and summary.
#' @export
#' @examples
#' d <- data.frame(well = c("A", "B"), top = c(10, 5), bottom = c(8, 1))
#' rules <- data.frame(unit = c("shallow", "deep"), top = c(12, 6), bottom = c(6, 0))
#' g <- ps_screen_groups(d, "rules", screen_top = "top", screen_bottom = "bottom", rules = rules)
#' g$assigned
#' # Rule assignments remain conditional on user-supplied hydrogeologic rules.
ps_screen_groups <- function(data, mode = c("existing", "rules", "depth_bins"),
                             unit_col = NULL, screen_top, screen_bottom,
                             rules = NULL, breaks = NULL, labels = NULL,
                             overlap_required = 0.5,
                             ambiguous_action = c("report", "error")) {
  call <- match.call(); mode <- match.arg(mode); ambiguous_action <- match.arg(ambiguous_action)
  if (!is.data.frame(data)) .ps_abort("`data` must be a data frame.", "potentiomap_screen_group_error")
  if (!all(c(screen_top, screen_bottom) %in% names(data))) {
    .ps_abort("Screen top and bottom columns were not found.", "potentiomap_screen_group_error")
  }
  .validate_number(overlap_required, "overlap_required", lower = 0, inclusive = TRUE)
  if (overlap_required > 1) .ps_abort("`overlap_required` cannot exceed one.", "potentiomap_screen_group_error")
  top <- suppressWarnings(as.numeric(data[[screen_top]])); bottom <- suppressWarnings(as.numeric(data[[screen_bottom]]))
  valid <- is.finite(top) & is.finite(bottom) & top > bottom
  if (any(!valid)) .ps_warn(sprintf("%d screen interval(s) are missing, zero, or reversed.", sum(!valid)),
                            "potentiomap_screen_group_warning")
  assigned <- data; assigned$screen_group <- NA_character_
  overlap <- data.frame(record_id = character(), unit = character(), overlap_length = numeric(),
                        overlap_fraction = numeric(), qualifies = logical(), stringsAsFactors = FALSE)
  if (mode == "existing") {
    if (is.null(unit_col) || !unit_col %in% names(data)) {
      .ps_abort("`unit_col` must name an existing grouping column.", "potentiomap_screen_group_error")
    }
    assigned$screen_group <- as.character(data[[unit_col]])
    rules_used <- data.frame(mode = "existing", unit_col = unit_col)
  } else if (mode == "rules") {
    if (!is.data.frame(rules) || !all(c("unit", "top", "bottom") %in% names(rules)) || !nrow(rules)) {
      .ps_abort("`rules` must contain `unit`, `top`, and `bottom` columns.", "potentiomap_screen_group_error")
    }
    rt <- as.numeric(rules$top); rb <- as.numeric(rules$bottom)
    if (any(!is.finite(rt) | !is.finite(rb) | rt <= rb) || anyNA(rules$unit) || anyDuplicated(rules$unit)) {
      .ps_abort("Rules require unique units and finite top-above-bottom intervals.", "potentiomap_screen_group_error")
    }
    rows <- list()
    for (i in seq_len(nrow(data))) for (j in seq_len(nrow(rules))) {
      amount <- if (valid[i]) max(0, min(top[i], rt[j]) - max(bottom[i], rb[j])) else NA_real_
      fraction <- if (valid[i]) amount / (top[i] - bottom[i]) else NA_real_
      rows[[length(rows) + 1L]] <- data.frame(record_id = sprintf("record_%04d", i), unit = as.character(rules$unit[j]),
        overlap_length = amount, overlap_fraction = fraction,
        qualifies = is.finite(fraction) && fraction >= overlap_required, stringsAsFactors = FALSE)
    }
    overlap <- do.call(rbind, rows)
    for (i in seq_len(nrow(data))) {
      units <- overlap$unit[overlap$record_id == sprintf("record_%04d", i) & overlap$qualifies]
      if (length(units) == 1L) assigned$screen_group[i] <- units
    }
    rules_used <- rules
  } else {
    if (is.null(breaks) || !is.numeric(breaks) || length(breaks) < 2L || any(!is.finite(breaks)) || is.unsorted(breaks, strictly = TRUE)) {
      .ps_abort("`breaks` must be a strictly increasing finite numeric vector.", "potentiomap_screen_group_error")
    }
    if (is.null(labels)) labels <- paste0("descriptive_screen_bin_", seq_len(length(breaks) - 1L))
    if (length(labels) != length(breaks) - 1L || anyNA(labels) || any(!nzchar(labels))) {
      .ps_abort("`labels` must provide one nonempty label per interval.", "potentiomap_screen_group_error")
    }
    midpoint <- (top + bottom) / 2
    assigned$screen_group <- as.character(cut(midpoint, breaks = breaks, labels = labels,
                                               include.lowest = TRUE, right = FALSE))
    rules_used <- data.frame(mode = "descriptive_screen_depth_bins",
                             lower = head(breaks, -1), upper = tail(breaks, -1), label = labels)
  }
  if (mode == "rules") {
    counts <- vapply(seq_len(nrow(data)), function(i) sum(overlap$record_id == sprintf("record_%04d", i) & overlap$qualifies), integer(1))
  } else counts <- ifelse(is.na(assigned$screen_group), 0L, 1L)
  ambiguous <- assigned[counts > 1L, , drop = FALSE]
  unclassified <- assigned[counts == 0L, , drop = FALSE]
  if (nrow(ambiguous) && ambiguous_action == "error") {
    .ps_abort(sprintf("%d screen(s) meet more than one grouping rule.", nrow(ambiguous)), "potentiomap_screen_group_error")
  }
  if (nrow(ambiguous)) .ps_warn(sprintf("%d screen(s) remain ambiguous.", nrow(ambiguous)),
                                "potentiomap_screen_group_warning")
  summary <- data.frame(mode = mode, record_count = nrow(data), assigned_count = sum(counts == 1L),
                        ambiguous_count = nrow(ambiguous), unclassified_count = nrow(unclassified),
                        invalid_interval_count = sum(!valid))
  .ps_new_result(list(assigned = assigned, overlap = overlap, ambiguous = ambiguous,
                      unclassified = unclassified, rules = rules_used),
                 "potentiomap_screen_groups", call,
                 settings = list(overlap_required = overlap_required,
                                 ambiguous_action = ambiguous_action), summary = summary)
}

#' @export
as.data.frame.potentiomap_observation_check <- function(x, ...) x$issues
#' @export
as.data.frame.potentiomap_event_selection <- function(x, ...) x$selected
#' @export
as.data.frame.potentiomap_screen_groups <- function(x, ...) x$assigned
