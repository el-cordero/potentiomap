# Performance report

Date: 2026-07-17

Host: macOS 26.2 arm64, R 4.5.3, serial execution

Representative fixed synthetic benchmarks from
`dev/performance/benchmark-synthetic.R`:

| Function | Input | Raster / task | Method | Elapsed (s) | R object size (bytes) |
|---|---:|---|---|---:|---:|
| `ps_interpolate` | 32 wells | 100 m cells | IDW | 0.097 | 108,144 |
| `ps_validate` | 32 wells | direct predictions | IDW, 3-fold | 0.205 | 40,944 |
| `ps_tune_interpolation` | 32 wells | direct predictions | 3 candidates × 3 folds | 0.620 | 25,192 |
| `ps_interpolate` | 32 wells | 150 m cells | ordinary kriging | 0.079 | 54,184 |
| `ps_surface_uncertainty` | 32 wells | 21 × 22 cells | 10 conditional simulations | 1.513 | 24,696 |
| `ps_network_thinning` | 18 wells | 200 m cells | IDW, 3 replicates | 0.321 | 66,048 |
| `ps_report` | 32 predictions | HTML | offline render | 0.238 | 3,152 |

Installed versions included terra 1.9.27, sf 1.1.0, gstat 2.1.5, fields 17.1,
xml2 1.5.2, and rmarkdown 2.30. Times are single host observations, not
portable guarantees. `object.size()` is output allocation size, not peak RAM.
Larger grids, simulations, folds, candidates, and network replicates scale
work approximately with cells × realizations or fits; progress callbacks are
available and execution defaults to one core.
