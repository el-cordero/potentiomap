# URL and local-link report

Date: 2026-07-17

- `urlchecker::url_check()` checked 13 discovered external URLs: **all
  correct**.
- The final local pkgdown build contained 174 HTML pages. An XML-based crawl of
  every local `href` and `src` found **0 broken local links**.
- `pkgdown::build_site(examples = FALSE, new_process = FALSE)` completed; its
  warnings were Pandoc's deprecation notice for `--highlight-style`, not broken
  pages.
- Desktop and 390 × 844 mobile visual inspection found no console errors,
  missing images, page overflow, or inaccessible navigation; code blocks scroll
  within the mobile viewport.

The public documentation URL still serves the previously deployed release.
Publishing the locally verified 0.2.0 site remains a manual post-review action;
no remote deployment was performed.
