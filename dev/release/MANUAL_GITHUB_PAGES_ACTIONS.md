# Manual GitHub Pages actions

Checked on 2026-07-16: <https://el-cordero.github.io/potentiomap/> returns HTTP
200 and documents version 0.1.0. The locally built 0.2.0 pkgdown site has not
been published. No remote publication was performed during this release work.

After the reviewed 0.2.0 changes reach `main`:

1. Open **Settings > Pages** in `el-cordero/potentiomap`.
2. Under **Build and deployment**, select **Deploy from a branch**.
3. Select branch **gh-pages**, folder **/(root)**, and save. If `gh-pages` does
   not yet exist, complete step 4 first and return to this setting.
4. Open **Actions > pkgdown.yaml** and run **Run workflow** on `main`. The
   committed workflow builds the package site and deploys only `docs/` to
   `gh-pages`.
5. Confirm that the workflow succeeds and that `gh-pages` contains the rendered
   site rather than package source files.
6. Open <https://el-cordero.github.io/potentiomap/> in a private browser window.
   Confirm version 0.2.0, the four articles, the organized reference index,
   NEWS, GitHub and Issues links, site search, and the contour-support page.
7. Open
   <https://el-cordero.github.io/potentiomap/reference/ps_contour_support.html>
   and confirm the new API documentation.
8. Re-run the URL check against the published site and update the release
   reports before treating the CRAN tarball as final.

The source `docs/` directory is intentionally ignored. The deployment workflow
rebuilds it from package source and publishes rendered files to `gh-pages`.
