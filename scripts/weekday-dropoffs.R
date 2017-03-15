# Author: Josh Weinflash
# Created: 2017-03-10
# Purpose: Week 6 Makeover Monday -- morning dropoffs - wday vs wend

# set-up-environment ------------------------------------------------------
source("helper.R")
library("ggplot2")
library("ggmap")
library("rgdal")
library("DBI")

# query-database-for-counts -----------------------------------------------
con = dbConnect(RSQLite::SQLite(), dbname = "../data/taxi.db")

query = paste('SELECT "Dropoff Community Area" AS area_no,
               PRINTF("%s %s %s", SUBSTR("Trip End Timestamp", 1, 10),
                                  SUBSTR("Trip End Timestamp", 12, 2),
                                  SUBSTR("Trip End Timestamp", -2, 2))
                      AS time,
               COUNT(*) AS count
               FROM (SELECT * FROM taxi LIMIT 10000)
               WHERE area_no IS NOT NULL and SUBSTR(time, -2, 2) = "AM"
               GROUP BY area_no, time')

df_drop = dbGetQuery(con, query)

# TODO: convert to weekday\ninterval format

