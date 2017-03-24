# Author: Josh Weinflash
# Created: 2017-02-28
# Purpose: Week 6 Makeover Monday

# set-up-environment ------------------------------------------------------


# ---- extract-spatial-data -----------------------------------------------
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

# ---- misc functions -----------------------------------------------------
my_sum = function(df) {
  # quick function to add up the counts 
  # belonging to a particular community in a 
  # particular quarter (used with ddply)
  #
  # Args:
  #   df: data.frame
  #
  # Returns: data.frame

  df_out = data.frame("period" = df$period[1],
                      "area_no" = df$area_no[1],
                      "count" = sum(df$count),
                      stringsAsFactors = FALSE)
  
  return(df_out)
}

my_percent = function(df) {
  # quick function to calculate the percent of traffic
  # per each community area (used with ddply)
  #
  # Args:
  #   df: data.frame
  #
  # Returns: data.frame
  
  df_out = data.frame("period" = df$period,
                      "area_no" = df$area_no,
                      "percent" = df$count / sum(df$count),
                      stringsAsFactors = FALSE)
  
  return(df_out)
}

my_percent2 = function(df) {
  # quick function to calculate the percent of traffic
  # per each community area (for evening-dropoffs; used
  # with ddply)
  #
  # Args:
  #   df: data.frame
  #
  # Returns: data.frame
  
  df_out = data.frame("area_no" = df$area_no,
                      "evening_type" = df$evening_type,
                      "time_period" = df$time_period,
                      "percent" = df$freq / sum(df$freq),
                      stringsAsFactors = FALSE)
  
  return(df_out)
}

group_hour = function(dt) {
  # function to group the dropoff times
  # into three hour groups. Used with apply
  # family
  #
  # Args:
  #   df: POSIXct 
  #
  # Returns: string

  my_hour = lubridate::hour(dt)
  
  if (my_hour < 15) {
    
    return("12PM - 3PM")
    
  } else if (my_hour < 18) {
    
    return("3PM - 6PM")
    
  } else if (my_hour < 21) {
    
    return("6PM - 9PM")
    
  } else {
    
    return("9PM - 12AM")
  }
}
