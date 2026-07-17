# Reverse-dependency report

Date: 2026-07-17

The current CRAN package index was queried through
`available.packages()`/`tools::package_dependencies()` for Depends, Imports,
LinkingTo, Suggests, and Enhances relationships. CRAN currently lists
potentiomap 0.1.0 and reports **no direct or recursive reverse dependencies**.
There were therefore no registered reverse-dependent packages to install and
check.

This does not assert that private, internal, or GitHub-only scripts do not use
the API. Baseline defaults and positional signatures were retained for that
reason.
