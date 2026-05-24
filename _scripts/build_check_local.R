# Build, test, run examples, and check potentiomap locally.
# Run from the package root:
#   source("_scripts/build_check_local.R")

stopifnot(file.exists("DESCRIPTION"))
desc <- read.dcf("DESCRIPTION")
pkg <- unname(desc[1, "Package"])
version <- unname(desc[1, "Version"])
if (pkg != "potentiomap") {
  stop("This script must be run from the potentiomap package root.", call. = FALSE)
}

run_step <- function(label, expr) {
  cat("\n", strrep("=", 72), "\n", sep = "")
  cat(label, "\n")
  cat(strrep("=", 72), "\n", sep = "")
  force(expr)
  invisible(TRUE)
}

run_cmd <- function(label, command, args = character()) {
  run_step(label, {
    status <- system2(command, args = args)
    if (!identical(status, 0L)) {
      stop(label, " failed with status ", status, call. = FALSE)
    }
  })
}

run_step("Regenerating documentation with roxygen2", {
  if (!requireNamespace("roxygen2", quietly = TRUE)) {
    stop("Install roxygen2 before running this script.", call. = FALSE)
  }
  roxygen2::roxygenise()
})

run_step("Running testthat suite", {
  if (!requireNamespace("devtools", quietly = TRUE)) {
    stop("Install devtools before running this script.", call. = FALSE)
  }
  devtools::test()
})

example_out <- file.path(tempdir(), paste0("potentiomap_full_example_", Sys.Date()))
Sys.setenv(POTENTIOMAP_EXAMPLE_OUT_DIR = example_out)

run_step("Running full local example script", {
  source("_scripts/example_run_all_functions.R", local = new.env(parent = globalenv()))
})

tarball <- sprintf("%s_%s.tar.gz", pkg, version)
if (file.exists(tarball)) {
  unlink(tarball)
}
if (dir.exists(sprintf("%s.Rcheck", pkg))) {
  unlink(sprintf("%s.Rcheck", pkg), recursive = TRUE)
}

run_cmd("Building source package", "R", c("CMD", "build", "."))
if (!file.exists(tarball)) {
  stop("Expected build output was not created: ", tarball, call. = FALSE)
}

run_cmd("Running R CMD check", "R", c("CMD", "check", "--no-manual", tarball))

cat("\nAll local QA steps completed successfully.\n")
cat("Example output directory:", example_out, "\n")
cat("Built package:", normalizePath(tarball), "\n")
