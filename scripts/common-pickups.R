# @Author: Josh Weinflash
# @Created: 2017-02-28
# @Purpose: Week 6 Makeover Monday

# set-up-environment ------------------------------------------------------
source("helper.R")
library("ggplot2")
library("ggmap")
library("rgdal")
library("DBI")

# query-database-for-counts -----------------------------------------------
con = dbConnect(RSQLite::SQLite(), dbname = "../data/taxi.db")

query = paste('SELECT period, area_no, COUNT(*) AS count
               FROM (
                SELECT "Pickup Community Area" AS area_no, 
                        PRINTF("%s-%s", SUBSTR("Trip Start Timestamp", 7, 4),
                                        SUBSTR("Trip Start Timestamp", 1, 2)) AS period
                FROM taxi
                LIMIT 100
               )
              GROUP BY period, area_no'
)

df_pick = dbGetQuery(con, query)

# convert to quarters
df_pick$period = lubridate::quarter(as.Date(sprintf("%s-01", df_pick$period)), 
                                    with_year = TRUE)

# get-community-areas -----------------------------------------------------
sp_comm = readOGR("../data/", "community-area")

# note: city of chicago's data uses coordinates under the WGS84 standard. 
# This is good, since it's also what google maps uses
print(proj4string(sp_comm))

# convert to dataframe form so it works with ggplot
df_comm = extract_community_area_data(sp_comm)

# merge-count-and-lon-lat-data --------------------------------------------
df_pick = merge(df_pick, df_comm, by = "area_no", all.x = TRUE)

# build-plot --------------------------------------------------------------

# first get the "bounding box" that contains Chicago (needed for stamen maps)
gm_chi = get_googlemap("Chicago, Illinois")
bbox = bb2bbox(attr(gm_chi, "bb"))

# pull the stamenmap with these bounds
gm_chi = get_stamenmap(bbox, zoom = 10, maptype = "toner-lite")

# TODO: show boundaries based on comm. areas; fill using counts
gp_chi = ggmap(gm_chi, base_layer = ggplot(df_comm, aes_string("lon", "lat")), 
               maprange = TRUE, extent = "device")

gp_chi = gp_chi + geom_path(aes_string(group = "area_no"))

# save-to-file ------------------------------------------------------------
ggsave("../plots/pickups.png", plot = gp_chi, height = 11, width = 8.5, 
       units = "in")
