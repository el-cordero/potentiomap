# Citing potentiomap

The website documents **potentiomap 0.2.0**. CRAN currently distributes
**0.1.0** while 0.2.0 is under review. The GitHub repository provides
the 0.2.0 source; use the installed package citation to identify the
version used in an analysis.

| item                 | value                             |
|:---------------------|:----------------------------------|
| Website version      | 0.2.0                             |
| Current CRAN version | 0.1.0                             |
| Permanent DOI        | 10.32614/CRAN.package.potentiomap |
| License              | GPL-3                             |

- CRAN: <https://CRAN.R-project.org/package=potentiomap>
- DOI: <https://doi.org/10.32614/CRAN.package.potentiomap>
- Source: <https://github.com/el-cordero/potentiomap>
- License: GPL-3

To install the website version while CRAN remains at 0.1.0:

``` r

install.packages("pak")
pak::pak("el-cordero/potentiomap")
```

## Recommended citation

Always prefer the result returned by the installed version:

``` r

citation("potentiomap")
```

    ## To cite package 'potentiomap' in publications use:
    ## 
    ##   Cordero E (2026). _potentiomap: Build Potentiometric Surfaces and
    ##   Hydraulic-Gradient Arrows_. R package version 0.2.0,
    ##   <https://el-cordero.github.io/potentiomap/>.
    ## 
    ## A BibTeX entry for LaTeX users is
    ## 
    ##   @Manual{,
    ##     title = {potentiomap: Build Potentiometric Surfaces and Hydraulic-Gradient Arrows},
    ##     author = {Elvin Cordero},
    ##     year = {2026},
    ##     note = {R package version 0.2.0},
    ##     url = {https://el-cordero.github.io/potentiomap/},
    ##   }

The printed citation includes BibTeX output when used through
`toBibtex(citation("potentiomap"))`. Authorship and availability
information comes from the installed package metadata; no affiliation or
biography is added by this website.
