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

query = ('SELECT "Dropoff Community Area" AS area_no,
          PRINTF("%s %s %s", SUBSTR("Trip End Timestamp", 1, 10),
                             SUBSTR("Trip End Timestamp", 12, 2),
                             SUBSTR("Trip End Timestamp", -2, 2))
          AS time,
          COUNT(*) AS count
          FROM (SELECT * FROM taxi LIMIT 1000)
          WHERE area_no != "" and SUBSTR(time, -2, 2) = "PM"
          GROUP BY area_no, time')

df_drop = dbGetQuery(con, query)

# normalize ---------------------------------------------------------------
# convert time to date
df_drop$time = lubridate::mdy_h(df_drop$time)

# add column indicating weekday or weekend
df_drop$evening_type = ifelse(lubridate::wday(df_drop$time) < 6, 
                              "Weekday evening", "Weekend evening")

# add column for hour grouping
df_drop$time_period = sapply(df_drop$time, group_hour, USE.NAMES = FALSE)

# count number of trips by weekday/weekend, time period, community area
df_drop = plyr::count(df_drop, vars = c("area_no", "evening_type", "time_period"))

# normalize counts to show percentage
df_drop = plyr::ddply(df_drop, c("evening_type", "time_period"), my_percent2)

# get-community-areas -----------------------------------------------------
sp_comm = readOGR("../data/", "community-area")

# note: city of chicago's data uses WGS84 coordinates. google maps
# uses this too, so we're aligned (no need to convert)
print(proj4string(sp_comm))

# convert to dataframe form so it's amenable to ggplot
df_comm = extract_community_area_data(sp_comm)

# merge-count-and-lon-lat-data --------------------------------------------
df_drop = merge(df_drop, df_comm, by.x = "area_no", by.y = "area_no")

df_drop = df_drop[order(df_drop$order), ]

# construct-main-plot -----------------------------------------------------
ggm_chi = get_googlemap("Chicago, Illinois", zoom = 10, maptype = "roadmap")

ggp_chi = ggmap(ggm_chi, base_layer = ggplot(df_drop, aes_string("lon", "lat")), 
                maprange = TRUE, extent = "device")

ggp_chi = ggp_chi + geom_polygon(aes_string(group = "area_no", fill = "percent"),
                                 color = "black", size = 0.2, alpha = 0.5)

ggp_chi = ggp_chi + scale_fill_gradient(name = "Percentage of dropoffs",
                                        labels = scales::percent,
                                        low = "#f7fcf5", high = "#00441b",
                                        guide = "legend")

ggp_chi = ggp_chi + facet_grid("evening_type ~ time_period", switch = "y")

# modify-theme-elements ---------------------------------------------------
ggp_chi = ggp_chi + hrbrthemes::theme_ipsum_rc()

ggp_chi = ggp_chi + labs(x = "", y = "")
ggp_chi = ggp_chi + labs(title = paste("Does the evening time affect the most",
                                       "common dropoff locations in Chicago?"))

ggp_chi = ggp_chi + labs(subtitle = paste("Heatmaps shown for weekday (Sunday - Thursday) and",
                                          "weekend (Friday - Saturday) evenings in 3 hour chunks"))

ggp_chi = ggp_chi + theme(legend.position = "bottom")
ggp_chi = ggp_chi + theme(axis.text = element_blank())
ggp_chi = ggp_chi + theme(strip.text = element_text(hjust = 0.5))
ggp_chi = ggp_chi + theme(panel.border = element_rect(color = "black", fill = NA))

# save-to-file ------------------------------------------------------------
ggsave("../plots/evening-dropoffs.png", plot = ggp_chi, height = 8, 
       width = 12.75, units = "in")
