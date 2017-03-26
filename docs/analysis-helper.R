# Author: Josh Weinflash
# Created: 2017-03-19
# Purpose: Week 6 Makeover Monday -- helper for Rmd file

# ---- sample-of-raw-data-md ----------------------------------------------
con = dbConnect(RSQLite::SQLite(), dbname = "../data/taxi.db")
qry = "SELECT * FROM taxi LIMIT 10"
df_sample = dbGetQuery(con, qry)

cols = c("Trip Start Timestamp", "Pickup Community Area",
         "Trip Miles", "Fare")
        
print(df_sample[1:5, cols])

# ---- sample-of-monthly-counts-md ----------------------------------------
con = dbConnect(RSQLite::SQLite(), dbname = "../data/taxi.db")

query = ('SELECT "Pickup Community Area" AS area_no, 
         PRINTF("%s-%s", SUBSTR("Trip Start Timestamp", 7, 4),
                         SUBSTR("Trip Start Timestamp", 1, 2))
         AS period,
         COUNT(*) AS count
         FROM (SELECT * FROM taxi LIMIT 10000)
         WHERE area_no != "" AND period != ""
         GROUP BY period, area_no')

df_pick = dbGetQuery(con, query)

print(head(df_pick))

# ---- normalize-md -------------------------------------------------------
# convert to quarters
df_pick$period = lubridate::quarter(as.Date(sprintf("%s-01", df_pick$period)), 
                                    with_year = TRUE)

# sum up counts belonging to the same (quarter, community area)
df_pick = plyr::ddply(df_pick, c("period", "area_no"), my_sum)

# convert count of pickups to percentage of total 
df_pick = plyr::ddply(df_pick, "period", my_percent)

# reformat quarters for readability
df_pick$period = stringr::str_replace(df_pick$period, "\\.", "-Q")

print(head(df_pick))

# ---- load-spatial-data-md -----------------------------------------------
sp_comm = readOGR("../data/", "community-area")

# ---- str-spatial-data-md ------------------------------------------------
print(str(sp_comm, list.len = 2))

# ---- str-extracted-spatial-data-md --------------------------------------
df_comm = extract_community_area_data(sp_comm)

print(head(df_comm))

# ---- str-reminder-md ----------------------------------------------------
print(head(df_pick)); print(head(df_comm))

# ---- merge-md -----------------------------------------------------------
# merge the two data.frames
df_pick = merge(df_pick, df_comm, by.x = "area_no", by.y = "area_no")

# order it by `order` so when we facet the polygons are drawn correctly
df_pick = df_pick[order(df_pick$order), ]

print(head(df_pick))
