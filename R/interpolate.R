#' Interpolate potentiometric surfaces
#'
#' Creates one raster per requested interpolation method. The default method is
#' thin-plate spline (`"TPS"`). Other built-in methods are inverse distance
#' weighting (`"IDW"`), ordinary kriging (`"OK"`), and universal kriging with
#' quadratic drift (`"UK"`). Advanced users can also pass named custom
#' interpolation functions through `custom_methods`.
#'
#' @param points A point `SpatVector`, `sf` object, or coordinate table with a
#'   groundwater elevation column.
#' @param value Groundwater elevation column name when `points` is not already
#'   standardized. Defaults to `"Z"`.
#' @param methods Character vector of interpolation methods. Built-in values are
#'   `"TPS"`, `"IDW"`, `"OK"`, and `"UK"`. Names supplied in `custom_methods`
#'   can also be used.
#' @param grid_res Output raster cell size in map units.
#' @param template Optional template `SpatRaster`; overrides `grid_res`,
#'   `padding`, and `mask` extent construction.
#' @param mask Optional AOI polygon used to crop and mask output rasters.
#' @param padding Padding added around the convex hull extent when building a
#'   template from points.
#' @param idw_power,idw_nmax IDW power and maximum neighbors.
#' @param tps_lambda Thin-plate spline smoothing parameter. `NULL` lets
#'   `fields::Tps()` choose by GCV.
#' @param kr_auto_cutoff Use automatic variogram cutoff and lag width.
#' @param kr_cutoff,kr_width Manual variogram cutoff and lag width.
#' @param custom_methods Optional named list of custom interpolation functions.
#'   Each function is called as `fun(points, template, grid)` and must return
#'   either a `SpatRaster` matching `template` or a numeric vector with one value
#'   per template cell.
#' @param x,y,name_col,crs Used when `points` is a coordinate table.
#'
#' @return A named list of `SpatRaster` surfaces.
#' @export
#'
#' @examples
#' data("synthetic_wells")
#' pts <- ps_make_points(synthetic_wells, "x", "y", "gw_elevation",
#'                       "well_id", "EPSG:26916")
#' surfaces <- ps_interpolate(pts, grid_res = 100)
#' names(surfaces)
ps_interpolate <- function(points, value = "Z",
                           methods = "TPS",
                           grid_res = NULL, template = NULL, mask = NULL,
                           padding = NULL, idw_power = 2, idw_nmax = 15,
                           tps_lambda = NULL, kr_auto_cutoff = TRUE,
                           kr_cutoff = NA_real_, kr_width = NA_real_,
                           custom_methods = NULL,
                           x = "x", y = "y", name_col = NULL, crs = NULL) {
  pts <- if (inherits(points, "SpatVector")) {
    if (!"Z" %in% names(terra::values(points))) {
      ps_make_points(points, value = value, name_col = name_col, crs = crs)
    } else {
      points
    }
  } else {
    ps_make_points(points, x = x, y = y, value = value,
                   name_col = name_col, crs = crs)
  }
  if (nrow(pts) < 5) {
    stop("At least five valid points are needed for interpolation.",
         call. = FALSE)
  }

  if (is.function(methods)) {
    custom_methods <- c(list(custom = methods), custom_methods)
    methods <- "custom"
  } else if (is.list(methods) && !is.character(methods)) {
    if (is.null(names(methods)) || any(names(methods) == "")) {
      names(methods) <- paste0("custom_", seq_along(methods))
    }
    custom_methods <- c(methods, custom_methods)
    methods <- names(methods)
  }
  methods <- as.character(methods)
  if (!is.null(custom_methods)) {
    if (!is.list(custom_methods) || any(!vapply(custom_methods, is.function, logical(1)))) {
      stop("`custom_methods` must be a named list of functions.", call. = FALSE)
    }
    if (is.null(names(custom_methods)) || any(names(custom_methods) == "")) {
      stop("Every custom method must have a name.", call. = FALSE)
    }
  }

  tmpl <- .surface_template(pts, grid_res, template, mask, padding)
  grid <- as.data.frame(terra::xyFromCell(tmpl, seq_len(terra::ncell(tmpl))))
  names(grid) <- c("X", "Y")

  out <- list()
  for (method in methods) {
    builtin <- toupper(method)
    out[[method]] <- switch(
      builtin,
      IDW = .interp_idw(pts, tmpl, grid, idw_power, idw_nmax),
      TPS = .interp_tps(pts, tmpl, grid, tps_lambda),
      OK = .interp_ok(pts, tmpl, grid, kr_auto_cutoff, kr_cutoff, kr_width),
      UK = .interp_uk(pts, tmpl, grid, kr_auto_cutoff, kr_cutoff, kr_width),
      .interp_custom(method, custom_methods, pts, tmpl, grid)
    )
    names(out[[method]]) <- method
    if (!is.null(mask)) {
      out[[method]] <- .apply_mask(out[[method]], mask)
    }
  }
  out
}

.interp_custom <- function(method, custom_methods, points, template, grid) {
  if (is.null(custom_methods) || !method %in% names(custom_methods)) {
    stop("Unsupported method `", method, "`. Use one of TPS, IDW, OK, UK, ",
         "or provide a matching function in `custom_methods`.", call. = FALSE)
  }
  result <- custom_methods[[method]](points = points, template = template,
                                     grid = grid)
  if (inherits(result, "SpatRaster")) {
    return(result)
  }
  if (is.numeric(result) && length(result) == terra::ncell(template)) {
    r <- template
    terra::values(r) <- result
    return(r)
  }
  stop("Custom method `", method, "` must return a SpatRaster or a numeric ",
       "vector with one value per template cell.", call. = FALSE)
}

.surface_template <- function(points, grid_res, template, mask, padding) {
  if (!is.null(template)) {
    if (inherits(template, "SpatRaster")) {
      return(template)
    }
    return(terra::rast(template))
  }
  if (is.null(grid_res)) {
    stop("`grid_res` is required when `template` is not supplied.",
         call. = FALSE)
  }
  geom <- if (is.null(mask)) terra::convHull(points) else .project_like(mask, points)
  ex <- terra::ext(geom)
  if (is.null(padding)) {
    padding <- grid_res * 2
  }
  if (length(padding) == 1) {
    padding <- rep(padding, 2)
  }
  ex[1] <- ex[1] - padding[1]
  ex[2] <- ex[2] + padding[1]
  ex[3] <- ex[3] - padding[2]
  ex[4] <- ex[4] + padding[2]
  terra::rast(crs = terra::crs(points), extent = ex, resolution = grid_res)
}

.interp_idw <- function(points, template, grid, idw_power, idw_nmax) {
  pts_sf <- sf::st_as_sf(points)
  grid_sf <- sf::st_as_sf(grid, coords = c("X", "Y"), crs = terra::crs(points))
  model <- gstat::gstat(
    id = "Z", formula = Z ~ 1, data = pts_sf,
    set = list(idp = idw_power)
  )
  pred <- if (is.null(idw_nmax)) {
    stats::predict(model, grid_sf)
  } else {
    stats::predict(model, grid_sf, nmax = idw_nmax)
  }
  pred_col <- intersect(c("Z.pred", "var1.pred"), names(pred))[1]
  if (is.na(pred_col)) {
    pred_col <- grep("\\.pred$", names(pred), value = TRUE)[1]
  }
  r <- template
  terra::values(r) <- as.numeric(pred[[pred_col]])
  r
}

.interp_tps <- function(points, template, grid, tps_lambda) {
  xy <- as.matrix(terra::crds(points, df = TRUE))
  z <- terra::values(points)$Z
  fit <- fields::Tps(x = xy, Y = z, lambda = tps_lambda)
  pred <- stats::predict(fit, as.matrix(grid))
  r <- template
  terra::values(r) <- as.numeric(pred)
  r
}

.interp_ok <- function(points, template, grid, kr_auto_cutoff, kr_cutoff,
                       kr_width) {
  pts <- .kriging_frame(points)
  pts$resid <- pts$Z - mean(pts$Z, na.rm = TRUE)
  vg_fit <- .build_variogram(pts, kr_auto_cutoff, kr_cutoff, kr_width)
  pred <- gstat::krige(Z ~ 1, locations = ~ X + Y, data = pts,
                       newdata = grid, model = vg_fit)
  r <- template
  terra::values(r) <- pred$var1.pred
  r
}

.interp_uk <- function(points, template, grid, kr_auto_cutoff, kr_cutoff,
                       kr_width) {
  pts <- .kriging_frame(points)
  pts <- .add_quadratic_terms(pts)
  fit <- stats::lm(Z ~ x + y + x2 + y2 + xy, data = pts)
  pts$resid <- stats::resid(fit)
  vg_fit <- .build_variogram(pts, kr_auto_cutoff, kr_cutoff, kr_width)
  gd <- .add_quadratic_terms(grid)
  pred <- gstat::krige(Z ~ x + y + x2 + y2 + xy,
                       locations = ~ X + Y, data = pts,
                       newdata = gd, model = vg_fit)
  r <- template
  terra::values(r) <- pred$var1.pred
  r
}

.kriging_frame <- function(points) {
  pts <- as.data.frame(terra::crds(points, df = TRUE))
  names(pts) <- c("X", "Y")
  pts$Z <- terra::values(points)$Z
  pts
}

.add_quadratic_terms <- function(df) {
  df$x <- df$X
  df$y <- df$Y
  df$x2 <- df$x^2
  df$y2 <- df$y^2
  df$xy <- df$x * df$y
  df
}

.build_variogram <- function(pts, kr_auto_cutoff, kr_cutoff, kr_width) {
  if (kr_auto_cutoff) {
    xspan <- diff(range(pts$X))
    yspan <- diff(range(pts$Y))
    cutoff <- 0.5 * max(xspan, yspan)
    width <- cutoff / 15
  } else {
    cutoff <- kr_cutoff
    width <- kr_width
  }
  empirical <- gstat::variogram(
    resid ~ 1, ~ X + Y, data = pts,
    cutoff = cutoff, width = width
  )
  psill0 <- stats::var(pts$resid, na.rm = TRUE)
  model0 <- gstat::vgm(
    psill = psill0, model = "Sph",
    range = cutoff / 3, nugget = 0.1 * psill0
  )
  gstat::fit.variogram(
    empirical, model0,
    fit.sills = TRUE, fit.ranges = TRUE, fit.method = 7
  )
}

.project_like <- function(x, y) {
  vx <- if (inherits(x, "SpatVector")) x else terra::vect(x)
  if (terra::crs(vx) != terra::crs(y)) {
    vx <- terra::project(vx, terra::crs(y))
  }
  vx
}

.apply_mask <- function(raster, mask) {
  mask <- .project_like(mask, raster)
  mask <- terra::aggregate(mask, dissolve = TRUE)
  terra::mask(terra::crop(raster, mask), mask)
}
