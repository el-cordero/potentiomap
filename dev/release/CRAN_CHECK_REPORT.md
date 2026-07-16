# CRAN check report

Candidate source:
`/Users/ec/Documents/Data/PotentiometricSurfPackage/potentiomap/potentiomap_0.2.0.tar.gz`

Package-source commit: `1b94cdc3cfa11d303805a21d9674a7c7175d0ed5`
SHA-256: `ca119ee73f57322cc494b9605561fb32e608209e8e501e74910ff6437a88692b`

## Local environment

- R 4.5.3 (2026-03-11)
- aarch64-apple-darwin20
- macOS Tahoe 26.2 / Darwin 25.2.0 arm64
- Apple clang 16.0.0; GNU Fortran 14.2.0

## Results

### Standard check

Command: `R CMD check potentiomap_0.2.0.tar.gz`

Result: **Status: OK** with 0 errors, 0 warnings, and 0 notes.

Log: `dev/release/checks/R-CMD-check.log`

### CRAN-style check

Command: `R CMD check --as-cran potentiomap_0.2.0.tar.gz`

Result: 0 errors, 0 warnings, and 2 host-environment notes:

1. The local checker could not verify current time through its external clock
   service. No future-dated package file was identified.
2. The Apple-supplied HTML Tidy is from 2006, so optional HTML validation was
   skipped. Package Rd, PDF manual, examples, tests, vignettes, and rebuilt
   vignette outputs all passed.

The earlier package-content note for non-standard community files was resolved
by excluding those GitHub files from the source tarball. The two remaining
notes describe the local checking host, not package content or behavior.

Log: `dev/release/checks/R-CMD-check-as-cran.log`

## Additional checks

- 273 test expectations passed; 0 failed, warned, or skipped.
- Line coverage: 85.66474%.
- URL check: all 5 discovered URLs correct.
- Spelling check: no spelling errors after applying the reviewed scientific
  word list.
- Citation: `citation("potentiomap")` returns a package citation for version
  0.2.0 and the documentation URL.
- All four vignettes rebuilt. Individual elapsed times were 1.932, 0.472,
  0.305, and 0.325 seconds on this host.
- The slowest documented example was `ps_arrow_vertices` at 0.945 seconds;
  every other example was below 0.5 seconds.
- Namespace, S3 registration, code/documentation consistency, Rd contents,
  examples, tests, and PDF manual checks passed.

## External checks not run on the 0.2.0 candidate

- GitHub Actions matrix
- Win-builder
- External macOS checking service

Exact manual actions are recorded in `MANUAL_RELEASE_ACTIONS.md`. The public
CRAN check matrix for version 0.1.0 was inspected separately and all listed
Linux, Windows, and macOS flavors were OK on 2026-07-16.
