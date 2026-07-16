# URL check report

Date: 2026-07-16

`urlchecker::url_check()` discovered and checked 5 package-documentation URLs.
Result: **All URLs are correct.**

Additional public inspection established:

- <https://CRAN.R-project.org/package=potentiomap> resolves to the CRAN 0.1.0
  package page.
- <https://github.com/el-cordero/potentiomap> is a public repository.
- <https://github.com/el-cordero/potentiomap/issues> is visible, but public issue
  creation is restricted and must be enabled manually.
- <https://el-cordero.github.io/potentiomap/> returns HTTP 200 but currently
  documents version 0.1.0, not this 0.2.0 release candidate.

The package website URL is technically live. The 0.2.0 tarball must not be
treated as submission-ready until the new pkgdown site is published and the
URLs are rechecked, as described in `MANUAL_GITHUB_PAGES_ACTIONS.md`.
