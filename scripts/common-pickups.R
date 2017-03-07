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

# sum of counts belonging to the same (quarter, community area)
df_pick = plyr::ddply(df_pick, c("period", "area_no"), my_sum)

# get-community-areas -----------------------------------------------------
sp_comm = readOGR("../data/", "community-area")

# note: city of chicago's data uses coordinates under the WGS84 standard. 
# stamen uses this too, so we're all set
print(proj4string(sp_comm))

# convert to dataframe form so it works with ggplot
# df_comm = extract_community_area_data(sp_comm)
df_comm = fortify(sp_comm)

# merge-count-and-lon-lat-data --------------------------------------------
df_pick = merge(df_pick, df_comm, by.x = "area_no", by.y = "id")

df_pick = df_pick[order(df_pick$order), ]

# build-plot --------------------------------------------------------------

# first get the "bounding box" that contains Chicago (needed for stamen maps)
ggm_chi = get_googlemap("Chicago, Illinois")
bbox = bb2bbox(attr(ggm_chi, "bb"))

# pull the stamenmap with these bounds
ggm_chi = get_stamenmap(bbox, zoom = 10, maptype = "toner-lite")

# construct plot
ggp_chi = ggmap(ggm_chi, base_layer = ggplot(df_pick, aes_string("long", "lat")), 
                maprange = TRUE, extent = "device")

ggp_chi = ggp_chi + geom_polygon(aes_string(fill = "count"))
ggp_chi = ggp_chi + facet_wrap("period")

ggp_chi = ggp_chi + scale_fill_gradient(low = "#f7fcf5", high = "#00441b",
                                        guide = "legend")

ggp_chi = ggp_chi + theme(legend.position = "top")

# save-to-file ------------------------------------------------------------
ggsave("../plots/pickups.png", plot = ggp_chi, height = 11, 
       width = 8.5,units = "in")
