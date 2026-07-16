# Manual release actions

The following external actions remain outside the local implementation and
must be performed by an authorized maintainer.

1. Review the commits on `release/0.2.0` and the final release reports.
2. Authenticate GitHub access and push the release branch.
3. Open and review a pull request into `main` without rewriting history.
4. Confirm Linux R release/devel, Windows R release, and macOS R release CI.
5. Run Win-builder and an appropriate macOS check service on the exact release
   candidate source.
6. Enable unrestricted public issue creation and set repository information as
   described in `MANUAL_GITHUB_SETTINGS.md`.
7. Merge only after required checks pass.
8. Publish and verify pkgdown using `MANUAL_GITHUB_PAGES_ACTIONS.md`.
9. Rebuild the source tarball from the merged commit, repeat the ordered release
   checks, and update all reports so the checked tarball and submission tarball
   are byte-for-byte the same file.
10. Submit that tarball to CRAN with the finalized `cran-comments.md` only after
    the website URL documents version 0.2.0.
11. Create a version tag and GitHub release only after the release policy and
    CRAN sequence have been reviewed by the maintainer.

No branch push, pull request, merge, tag, GitHub release, website deployment,
or CRAN submission was performed during the local release work.
