# Prepare the USGS Hot Springs, Arkansas, 2017 example used by this website.
#
# Source release: https://doi.org/10.5066/F7TD9WK0
# This script expects the official ScienceBase DBF attribute table and an NWIS
# site-service RDB response in a local working directory. It does not require or
# use the unavailable zero-byte geometry member in the current aggregate ZIP.

dbf_file <- "HotSprings_2017wellpts.dbf"
nwis_file <- "nwis_all_sites.rdb"

stopifnot(file.exists(dbf_file), file.exists(nwis_file))

attributes <- foreign::read.dbf(dbf_file, as.is = TRUE)
nwis <- read.delim(
  nwis_file,
  comment.char = "#",
  quote = "",
  sep = "\t",
  header = TRUE,
  colClasses = "character",
  check.names = FALSE
)
nwis <- nwis[nwis$agency_cd != "5s", , drop = FALSE]

match_row <- match(attributes$SiteID, nwis$site_no)
stopifnot(!anyNA(match_row))

prepared <- data.frame(
  site_id = attributes$SiteID,
  point_number = attributes$PtNum,
  local_aquifer_code = attributes$LocalAQ,
  measurement_date = as.character(attributes$WL_Date),
  depth_to_water_ft = attributes$WL_BLS,
  land_surface_elevation_ft_navd88 = attributes$Alt_ft,
  groundwater_elevation_ft_navd88 = attributes$ALTWL,
  longitude_nad83 = as.numeric(nwis$dec_long_va[match_row]),
  latitude_nad83 = as.numeric(nwis$dec_lat_va[match_row]),
  coordinate_datum = nwis$dec_coord_datum_cd[match_row]
)

# Restrict the software demonstration to one documented local aquifer code.
prepared <- prepared[prepared$local_aquifer_code == "330STNL", ]

write.csv(
  prepared,
  "usgs_hot_springs_stanley_shale_2017.csv",
  row.names = FALSE,
  na = ""
)
