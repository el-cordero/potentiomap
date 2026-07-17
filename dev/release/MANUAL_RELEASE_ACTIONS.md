# Manual release actions

The implementation and local candidate checks are complete. The following
external or maintainer-authorized actions remain:

1. Review the uncommitted working-tree changes and release reports; preserve
   the pre-existing user-owned untracked `LICENSE`.
2. Commit intentionally on `release/0.2.0`, then push and open a pull request.
3. Require Linux R-release, Linux R-devel, Windows R-release, macOS R-release,
   coverage, and extended synthetic workflows to pass on that commit.
4. Run Win-builder and another current CRAN-compatible service on the exact
   post-commit source candidate; confirm that a current HTML Tidy validates the
   manual.
5. Review and merge only after those checks pass.
6. Build and publish the locally verified pkgdown site, then confirm that it
   documents 0.2.0 and re-run the URL audit.
7. Rebuild from the merged commit and repeat tests, coverage, content
   inspection, ordinary check, and `--as-cran`; record the new SHA-256.
8. Submit only that byte-identical checked tarball with finalized CRAN comments.
9. Create the version tag and GitHub release in the maintainer-approved order.

No commit, push, pull request, merge, tag, GitHub release, site deployment, or
CRAN submission was performed by this task.
