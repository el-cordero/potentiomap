# Synthetic groundwater monitoring wells

A small artificial monitoring dataset with coordinates, land-surface
elevation, positive depth below land surface, and calculated groundwater
elevation. Elevations and depths are synthetic metres relative to a
synthetic example datum.

## Usage

``` r
synthetic_wells
```

## Format

A data frame with 32 rows and 6 columns:

- well_id:

  Synthetic well identifier.

- x:

  Synthetic easting in EPSG:26916 metres.

- y:

  Synthetic northing in EPSG:26916 metres.

- surface_elevation:

  Synthetic land-surface elevation in metres.

- depth_to_water:

  Positive depth below land surface in metres.

- gw_elevation:

  Synthetic groundwater elevation in metres.

## Examples

``` r
data("synthetic_wells")
head(synthetic_wells)
#>   well_id        x       y surface_elevation depth_to_water gw_elevation
#> 1   MW-01 502848.7 4641228            185.13          18.48       166.65
#> 2   MW-02 502914.4 4642016            183.89          18.39       165.50
#> 3   MW-03 500994.1 4640210            190.43          18.97       171.45
#> 4   MW-04 502599.8 4642407            184.35          18.66       165.70
#> 5   MW-05 502043.2 4640219            189.02          20.02       169.00
#> 6   MW-06 501681.3 4640750            188.40          18.87       169.53
```
