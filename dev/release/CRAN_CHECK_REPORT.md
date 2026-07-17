# CRAN check report

Date: 2026-07-17

Exact candidate: `/Users/ec/Documents/Data/PotentiometricSurfPackage/potentiomap/potentiomap_0.2.0.tar.gz`

SHA-256: `9c89c6bffe7018ae786f71cb7f4270862b6f9b6daded8c17b54c14124853ae59`

## Local environment

- R 4.5.3 (2026-03-11)
- aarch64-apple-darwin20
- macOS Tahoe 26.2 / Darwin 25.2.0 arm64
- Apple clang 16.0.0; GNU Fortran 14.2.0

## Results on the exact tarball

- Ordinary `R CMD check`: **Status: OK**, 0 errors, 0 warnings, 0 notes.
- Isolated `R CMD check --as-cran`: **0 errors, 0 warnings, 1
  host-environment NOTE**.
- The only NOTE states that the Apple-supplied HTML Tidy is too old for the
  optional HTML-manual validation. Package installation, namespace, code, data,
  all examples, 897 test expectations, vignettes, rebuilt vignette outputs,
  PDF manual, incoming URL feasibility, and detritus checks passed.

The HTML Tidy NOTE does not identify a package HTML error: validation was not
performed because the local checker is obsolete. It must still be confirmed by
Linux/Windows hosted checks with a current Tidy installation. The authoritative
isolated CRAN log is:
`/private/tmp/potentiomap-as-cran-final-20260717/potentiomap.Rcheck/00check.log`.

The installed package occupied 3,732 KiB on this host. Spelling reported zero
findings, all 13 external URLs passed, and all 174 local website pages had zero
broken local links.
