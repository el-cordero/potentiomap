# Building a technical analysis report

[`ps_report()`](https://el-cordero.github.io/potentiomap/reference/ps_report.md)
renders offline HTML or DOCX from a package-owned R Markdown template.
Relevant settings, diagnostics, validation, support, uncertainty,
change, network products, conditions, limitations, and optional session
information are included when present. Reports never claim professional
certification, regulator approval, or independent hydrogeologic
verification, and they do not recommend a method unless the input
records an explicit user decision.

``` r

ps_report(result, "analysis.html", include_session=TRUE)
```
