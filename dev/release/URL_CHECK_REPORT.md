# URL and local-link report

Date: 2026-07-17

- `urlchecker::url_check()` checked 15 discovered external URLs: **all
  correct**.
- CRAN's reported relative file URIs for `CONTRIBUTING.md` and
  `CODE_OF_CONDUCT.md` were replaced with absolute public GitHub URLs; both
  links passed the live audit and the exact tarball's incoming feasibility
  check.
- The final local pkgdown build contained 174 HTML pages. An XML-based crawl of
  every local `href` and `src` found **0 broken local links**.
- `pkgdown::build_site(examples = FALSE, new_process = FALSE)` completed; its
  warnings were Pandoc's deprecation notice for `--highlight-style`, not broken
  pages.
- Desktop and 390 × 844 mobile visual inspection found no console errors,
  missing images, page overflow, or inaccessible navigation; code blocks scroll
  within the mobile viewport.

The public documentation site was deployed successfully from `main` and serves
version 0.2.0.
