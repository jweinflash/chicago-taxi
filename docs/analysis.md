
Processing 105 million taxi trips and visualizing it with ggmap
===============================================================

[Andy](https://twitter.com/VizWizBI?lang=en) and his team had an interesting challenge for [week 6 of Makeover Monday](https://trimydata.com/2017/02/07/makeover-monday-week-6-2017-inside-chicagos-taxi-data/) (yes, I know I'm a few weeks behind ;). The goal was to create a visualization that showed how Chicagoans use taxis to get around the city. The challenge to me was particularly interesting because it (1) involved a large amount of data (~42GB of trip records), requiring us to be a bit careful with how we approach it, and (2) is inherently spatial in nature. I'd been meaning to play with `R`'s [ggmap](https://github.com/dkahle/ggmap) package for a while now for just this sort of thing, so I thought this would be a great chance to try it out.

#### General precursory thoughts for handling a dataset of this size

The first thing to realize about working with a dataset this big is that we don't need to load *all of it* (i.e. every record) for the analysis we're interested in doing. Rather, we just need some subset or aggregation of it. This is good, because the subset / aggregation we're interested in is likely (or more likely, at least) to fit into memory, which gives us a chance to analyze it with our usual tools. To me, the most natural thing to do in this situation is to import the data into a database, like [SQLite](https://www.sqlite.org/cli.html). Once there, we can execute queries for the particular subset / aggregation we need, and then boom, we're off to the races. There are a lot of nice tutorials about initializing the database (e.g. item 8 in the SQLite link above) and interacting with it from `R` (like [Hadley Wickham's tutorial](https://cran.r-project.org/web/packages/RSQLite/vignettes/RSQLite.html)), so I'm not going to spend much time working through these things in this post.

#### Getting acquainted with the data

[The dataset that we'll be working with](https://data.cityofchicago.org/Transportation/Taxi-Trips/wrvz-psew) is essentially a logfile of taxi trips. Each record holds information about a single trip, and contains fields like the pickup time, pickup area, dropoff time, dropoff area, total fare, and so on. Below are the first five rows and a few columns of the data to give you a sense of its structure.

    ##     Trip Start Timestamp Pickup Community Area Trip Miles   Fare
    ## 1 04/06/2016 08:45:00 PM                     8        0.1  $8.75
    ## 2 10/22/2013 08:45:00 PM                    32          0 $15.25
    ## 3 09/21/2013 04:30:00 PM                                0 $12.65
    ## 4 08/14/2014 12:45:00 AM                     8        1.8 $57.85
    ## 5 07/21/2014 12:45:00 PM                     7        5.5 $15.25

#### Answering a particular question: what are the most common pickup locations in Chicago?

One angle that I was interested in exploring was to see which locations are the most popular for taxi pickups. Since the city has such cold winters, I was also curious about whether these locations remain the most popular throughout the year. We'll build up a visualization with `ggmap` and `ggplot2` to answer this.

#### Step 1: Querying the data

Querying the data for this is pretty simple to do. We just need to get the `COUNT` of pickups per `Pickup Community Area`, per say each quarter, so that we can study the trend over time. SQL's `GROUP BY` makes this easy to do:

``` r
con = dbConnect(RSQLite::SQLite(), dbname = "../data/taxi.db")

query = ('SELECT "Pickup Community Area" AS area_no, 
          PRINTF("%s-%s", SUBSTR("Trip Start Timestamp", 7, 4),
                          SUBSTR("Trip Start Timestamp", 1, 2))
          AS period,
          COUNT(*) AS count
          FROM taxi
          WHERE area_no != "" AND period != ""
          GROUP BY period, area_no')

df_pick = dbGetQuery(con, query)
```

**Note that in the query, I'm not grouping the counts by quarter, but by month and year**. SQLite doesn't have great support for datetime data, so I figured it'd be easier to extract the counts this way first, and then use `R`'s functionality to get the quarter-based numbers we're looking for. At this point, the data in `df_pick` looks something like like this:

    ##   area_no  period count
    ## 1       2 2013-01     1
    ## 2      22 2013-01     1
    ## 3      24 2013-01     1
    ## 4      28 2013-01     7
    ## 5       3 2013-01     3
    ## 6      31 2013-01     1

Converting to quarter-based counts is pretty straightforward -- we just replace each `YYYY-MM` date with a `YYYY-Q` date and sum up the counts belonging to the same period. I do this with the below code (which, note, converts the quarter based counts to percentages).

``` r
# convert to quarters
df_pick$period = lubridate::quarter(as.Date(sprintf("%s-01", df_pick$period)), 
                                    with_year = TRUE)

# sum up counts belonging to the same (quarter, community area)
df_pick = plyr::ddply(df_pick, c("period", "area_no"), my_sum)

# convert counts to percent
df_pick = plyr::ddply(df_pick, "period", my_percent)

# reformat quarters for readability
df_pick$period = stringr::str_replace(df_pick$period, "\\.", "-Q")
```

At this point, our data is structured like the small subset below. Each record represents the percentage of pickups that occured at the indicated `area_no` in that `period` (quarter) of time. We now have the "count" data we need -- the next step is to connect it with spatial information so that we can visualize it with `ggmap`.

    ##    period area_no     percent
    ## 1 2013-Q1       1 0.004415011
    ## 2 2013-Q1      14 0.002207506
    ## 3 2013-Q1      15 0.004415011
    ## 4 2013-Q1      16 0.002207506
    ## 5 2013-Q1       2 0.004415011
    ## 6 2013-Q1      21 0.002207506

#### Step 2: Loading and integrating the spatial data

Spatial information for the city of Chicago can be downloaded [here](https://data.cityofchicago.org/Facilities-Geographic-Boundaries/Boundaries-Community-Areas-current-/cauq-8yn6) (be sure to download it as a `shapefile`). Before we get into the details of this data, just know that it contains boundary information for each of the `Pickup Community Areas` we selected in our query. This boundary information is important; we'll need it to demarcate each of the communities in our ggmap.

The `shapefile` that we downloaded isn't actually a single file, but a zip containing four files: a `.shp`, `.shx`, `.dbf` and `.prj`. The `.shp` is the most important, as it contains the actual "geometry" (i.e. outline) of the communities. The others aren't as important, but if you're interested, you can see the Wikipedia page on the file structure [here](https://en.wikipedia.org/wiki/Shapefile).

``` r
sp_comm = readOGR("../data/", "community-area")
```

The data structure that we loaded looks a bit nasty at first glance:

``` r
print(str(sp_comm, list.len = 2))
```

    ## Formal class 'SpatialPolygonsDataFrame' [package "sp"] with 5 slots
    ##   ..@ data       :'data.frame':  77 obs. of  9 variables:
    ##   .. ..$ perimeter : num [1:77] 0 0 0 0 0 0 0 0 0 0 ...
    ##   .. ..$ community : Factor w/ 77 levels "ALBANY PARK",..: 18 56 26 29 37 40 69 34 77 61 ...
    ##   .. .. [list output truncated]
    ##   ..@ polygons   :List of 77
    ##   .. ..$ :Formal class 'Polygons' [package "sp"] with 5 slots
    ##   .. .. .. ..@ Polygons :List of 1
    ##   .. .. .. .. ..$ :Formal class 'Polygon' [package "sp"] with 5 slots
    ##   .. .. .. .. .. .. ..@ labpt  : num [1:2] -87.6 41.8
    ##   .. .. .. .. .. .. ..@ area   : num 0.000463
    ##   .. .. .. .. .. .. .. [list output truncated]
    ##   .. .. .. ..@ plotOrder: int 1
    ##   .. .. .. .. [list output truncated]
    ##   .. ..$ :Formal class 'Polygons' [package "sp"] with 5 slots
    ##   .. .. .. ..@ Polygons :List of 1
    ##   .. .. .. .. ..$ :Formal class 'Polygon' [package "sp"] with 5 slots
    ##   .. .. .. .. .. .. ..@ labpt  : num [1:2] -87.6 41.8
    ##   .. .. .. .. .. .. ..@ area   : num 0.00017
    ##   .. .. .. .. .. .. .. [list output truncated]
    ##   .. .. .. ..@ plotOrder: int 1
    ##   .. .. .. .. [list output truncated]
    ##   .. .. [list output truncated]
    ##   .. [list output truncated]
    ## NULL

But it actually has a fairly reasonable structure. We'll make use of two slots from this object:

1.  **The `data` slot**. It's of class `data.frame` and holds information about each community's geographic information, like its `shape_area` and `shape_len`. Note it has 77 rows, one for each community.
2.  **The `polygons` slot**. It's of class `list` and holds `Polygon` objects. Each `Polygon` contains a `coords` matrix that lists the (longitude, latitude) pairs that trace its boundary. Note that there are 77 of these as well; this is the case because each one corresponds to a community from `data`. They match in terms of offset, so the first community in `data` maps to the first `Polygon`, the second community to the second `Polygon`, and so forth.

We need to extract the `coords` information from each `Polygon` and link it to the community it represents so that we can draw them properly on our map. I do this with the `extract_community_area_data` function below. **Note that if you're not interested in munging around with these data structures, `ggplot2`'s `fortify` function will give you just about the same output!**

``` r
extract_community_area_data = function(spdf) {
  # function to convert the 'SpatialPolygonsDataFrame'
  # into something useable for ggplot
  #
  # Args:
  #   spdf: SpatialPolygonsDataFrame (objected retunred from readOGR)
  #
  # Returns: data.frame

  # extract the 'data' and 'polygons' slots from the object
  df_comm = spdf@data
  l_polys = spdf@polygons
  
  # init list to hold output
  l_dfs = vector("list", length = length(l_polys))
  
  # extract number + name + polygon coords for each community area
  for (i in seq_along(l_polys)) {
    
    p_poly = l_polys[[i]]
    m_cord = p_poly@Polygons[[1]]@coords # oddly, p_poly@Polygons is of type list;
                                         # to access its data members you need to first index 
                                         # to the first element
    
    l_dfs[[i]] = data.frame("area_no" = rep(as.character(df_comm$area_numbe)[i], nrow(m_cord)),
                            "area_nm" = rep(as.character(df_comm$community)[i], nrow(m_cord)),
                            "lon" = m_cord[, 1],
                            "lat" = m_cord[, 2],
                            "order" = seq_len(nrow(m_cord)),
                            stringsAsFactors = FALSE)
  }
  
  return(plyr::rbind.fill(l_dfs))
}
```

Running this function on `sp_comm` gives us the following output:

``` r
df_comm = extract_community_area_data(sp_comm)

print(head(df_comm))
```

    ##   area_no area_nm       lon      lat order
    ## 1      35 DOUGLAS -87.60914 41.84469     1
    ## 2      35 DOUGLAS -87.60915 41.84466     2
    ## 3      35 DOUGLAS -87.60916 41.84459     3
    ## 4      35 DOUGLAS -87.60917 41.84452     4
    ## 5      35 DOUGLAS -87.60917 41.84446     5
    ## 6      35 DOUGLAS -87.60915 41.84424     6

Nice! We now have the spatial data in a form that will be easy to integrate with the count data we queried in step one.
