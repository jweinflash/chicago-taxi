# @Author: Josh Weinflash
# @Created: February 12 2017
# @Purpose: Week 6 Makeover Monday

# set-environment ---------------------------------------------------------
source("helper.R")
library("data.table")
library("LaF")

# connect-with-data -------------------------------------------------------
v_cols = c("trip_id" = "string",
           "taxi_id" = "string",
           "trip_start" = "string",
           "trip_end" = "string",
           "trip_seconds" = "integer",
           "trip_miles" = "double",
           "pickup_tract" = "string",
           "dropoff_tract" = "string",
           "pickup_area" = "string",
           "dropoff_area" = "string",
           "fare" = "string",        # $ in front
           "tips" = "string",        # $ in front
           "tolls" = "string",       # $ in front
           "extras" = "string",      # $ in front
           "trip_total" = "string",
           "payment_type" = "string",
           "company" = "string",
           "pick_latitude" = "double",
           "pickup_longitude" = "double",
           "pickup_location" = "string",
           "dropoff_latitude" = "double",
           "dropoff_longitude" = "double",
           "dropoff_location" = "string")

laf_obj = laf_open_csv("../data/taxi-trips.csv", column_names = names(v_cols),
                       column_types = unname(v_cols), trim = TRUE, skip = 1)

# count-trips-blockwise ---------------------------------------------------
dt_trips = process_blocks(laf_obj, count_trips_laf, 
                          columns = c(3, 7, 8), nrows = 10^6)
# get-unique-lon-lats -----------------------------------------------------
dt_trcts = process_blocks(laf_obj, store_lon_lat_laf,
                          columns = c(7, 8, 18, 19, 21, 22), nrows = 10^6)

# oddly there's a bunch of different "centroid" lon/lats per tract.
# hmph -> maybe just take the median to be the center.
dt_trcts = dt_trcts[, .(lon = median(lon, na.rm = TRUE), 
                        lat = median(lat, na.rm = TRUE)),
                        by = tract]

# save-to-file ------------------------------------------------------------
saveRDS(dt_trips, "../data/taxi-trips-clean.rds")
saveRDS(dt_trcts, "../data/tract-lon-lat-mapping.rds")
