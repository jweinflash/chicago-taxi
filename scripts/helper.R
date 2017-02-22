# @Author: Josh Weinflash
# @Created: February 20 2017
# @Purpose: Week 6 Makeover Monday -- helper file

# count-trips-laf ---------------------------------------------------------
count_trips_laf = function(d_data, l_prev) {
  # function used with process_blocks to count the number of
  # trips between (pickup, dropoff) per year
  #
  # Args:
  #   d_data: current block of data (data.frame)
  #   l_prev: list of results from processing previous block (list)
  #
  # Returns: data.table
  
  # convert to data.table for fast group by operations
  d_data = data.table(d_data)
  
  # initial processing
  if (is.null(l_prev)) {
    
    # replace full timestamp with just the year
    d_data[, trip_start := substr(trip_start, 7, 10)]
    
    # count trips from (pickup, dropoff) by year
    d_data = d_data[, .N, by = .(trip_start, pickup_tract, dropoff_tract)]
    
    # return list of data for next round of processing
    return(list(d_data = d_data, blocks_processed = 1))
    
    # final processing
  } else if (nrow(d_data) == 0) {
    
    return(l_prev$d_data)
    
  } else {
    
    # replace full timestamp with just year
    d_data[, trip_start := substr(trip_start, 7, 10)]
    
    # count trips from (pickup, dropoff) by year
    d_data = d_data[, .N, by = .(trip_start, pickup_tract, dropoff_tract)]
    
    # append this data to what's found in list and count again
    l_prev$d_data = rbindlist(list(l_prev$d_data, d_data))
    l_prev$d_data = l_prev$d_data[, .(N = sum(N)), by = .(trip_start, pickup_tract, dropoff_tract)]
    
    # update number of blocks processed and return
    l_prev$blocks_processed = l_prev$blocks_processed + 1
    print(sprintf("%i blocks processed", l_prev$blocks_processed))
    return(l_prev)
  }
}


# unique-lon-lat-laf ------------------------------------------------------
store_lon_lat_laf = function(d_data, l_prev) {
  # function used with process_blocks to find the unique (tract, lon, lat)
  # records
  #
  # Args:
  #   d_data: current block of data (data.frame)
  #   l_prev: list of results from processing previous block
  #
  # Returns: data.table
  
  # convert to data.table for fast 'unique' (distinct rows) operation
  d_data = data.table(tract = c(d_data$pickup_tract, d_data$dropoff_tract),
                      lon = c(d_data$pickup_longitude, d_data$dropoff_longitude),
                      lat = c(d_data$pickup_latitude, d_data$dropoff_latitude))
  
  # initial processing
  if (is.null(l_prev)) {
    
    return(list(d_data = unique(d_data), blocks_processed = 1))

    # final processing
  } else if (nrow(d_data) == 0) {
    
    return(l_prev$d_data)
    
  } else {
    
    # append any new (tract, lon, lat) records to data
    l_prev$d_data = rbindlist(list(l_prev$d_data, unique(d_data)))
    l_prev$d_data = unique(l_prev$d_data)
    
    # update number of blocks processed and return
    l_prev$blocks_processed = l_prev$blocks_processed + 1
    print(sprintf("%i blocks processed", l_prev$blocks_processed))
    return(l_prev)
  }
}
