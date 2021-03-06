# Author: Josh Weinflash
# Created: 2017-03-10
# Purpose: Week 6 Makeover Monday -- dropoffs per area, time period

# set-up-environment ------------------------------------------------------
source("helper.R")
library("ggplot2")
library("ggmap")
library("rgdal")
library("DBI")

# query-database-for-counts -----------------------------------------------
con = dbConnect(RSQLite::SQLite(), dbname = "../data/taxi.db")

query = ('SELECT "Dropoff Community Area" AS area_no, 
          PRINTF("%s-%s", SUBSTR("Trip End Timestamp", 7, 4),
                          SUBSTR("Trip End Timestamp", 1, 2)) 
          AS period,
          COUNT(*) AS count
          FROM taxi
          WHERE area_no != "" AND period != ""
          GROUP BY period, area_no')

df_drop = dbGetQuery(con, query)

# normalize ---------------------------------------------------------------
# convert to quarters
df_drop$period = lubridate::quarter(as.Date(sprintf("%s-01", df_drop$period)), 
                                    with_year = TRUE)

# sum up counts belonging to the same (quarter, community area)
df_drop = plyr::ddply(df_drop, c("period", "area_no"), my_sum)

# calculate percent of traffic in each area per time period
df_drop = plyr::ddply(df_drop, "period", my_percent)

# reformat quarters for readability
df_drop$period = stringr::str_replace(df_drop$period, "\\.", "-Q")

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

ggp_chi = ggp_chi + facet_wrap("period", ncol = 4)

# modify-theme-elements ---------------------------------------------------
ggp_chi = ggp_chi + hrbrthemes::theme_ipsum_rc()

ggp_chi = ggp_chi + labs(x = "", y = "")
ggp_chi = ggp_chi + labs(title = paste("Does the season affect the most",
                                       "common dropoff locations in Chicago?"))

ggp_chi = ggp_chi + labs(subtitle = "Heatmaps shown by quarter for the years 2013 - 2016")

ggp_chi = ggp_chi + theme(legend.position = "bottom")
ggp_chi = ggp_chi + theme(axis.text = element_blank())
ggp_chi = ggp_chi + theme(strip.text = element_text(hjust = 0.5))
ggp_chi = ggp_chi + theme(panel.border = element_rect(color = "black", fill = NA))

# save-to-file ------------------------------------------------------------
ggsave("../plots/dropoffs.png", plot = ggp_chi, height = 12.75, 
       width = 8.5, units = "in")
