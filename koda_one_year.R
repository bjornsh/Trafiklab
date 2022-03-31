#---------------------------------------------------------------------------------------------------
# Syfte
#---------------------------------------------------------------------------------------------------

### Create one DF with historical planned timetable data that only includes 
### journeys that were actually implemented

### Utmaning: every package with historical planned data includes journeys that may not be 
### implemented due to an update to the timetable data that is included in a later Rebus update

### Solution: download data for each day of the year separately, exclude all data within 
### data package that does not belong to this day.
### Repeat for each other days of the year and merge all 365 files into one 

# https://www.trafiklab.se/api/trafiklab-apis/koda/

#---------------------------------------------------------------------------------------------------
# clean
#---------------------------------------------------------------------------------------------------
rm(list = ls())
invisible(gc())



#---------------------------------------------------------------------------------------------------
# set up
#---------------------------------------------------------------------------------------------------

# libraries
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, 
               httr, # download url
               fst, # save data
               tidytransit) # gtfs hantering


# avoid scientific notation
options(scipen=999)


# create output directory
dir.create(paste0(getwd(), "/koda"))
dir.create(paste0(getwd(), "/temp"))

# Trafiklab key
api_fil <- read_file(paste0("Z:/api"))
key = gsub('^.*trafiklab_koda: \\s*|\\s*\r.*$', "", api_fil)

# get paths
mapp_koda = paste0(getwd(),"/koda/")
mapp_temp = paste0(getwd(), "/temp/")


#---------------------------------------------------------------------------------------------------
# Download data
#---------------------------------------------------------------------------------------------------

start = Sys.time()

## create date vector
date_vector = seq(as.Date("2021-07-22"), as.Date("2021-07-22"), by="days")

rkm = "ul" 
year = substr(date_vector[1], 1, 4)


get_koda <- function(rkm, datum, key){
  # create url
  url <- paste0("https://api.koda.trafiklab.se/KoDa/api/v2/gtfs-static/", rkm, "?date=", datum, "&key=", key)
  # download data using url
  GET(url, write_disk(paste0(mapp_temp, "koda_", rkm, "_", datum, ".zip"), overwrite=TRUE))
  }


# download multiple gtfs files from Trafiklab (1 månad = 2min)
for(i in 1:length(date_vector)){
  get_koda("ul", date_vector[i], key)
}

stop_download = Sys.time()

#---------------------------------------------------------------------------------------------------
# check that data is ok
#---------------------------------------------------------------------------------------------------

# identify files too small to be correct
x <- list.files(paste0(mapp_temp), full.names = TRUE)

# identify files smaller than 10 000 bytes
too_small = x[sapply(x, file.size) < 10000] 
ok_size = x[sapply(x, file.size) >= 10000]



#---------------------------------------------------------------------------------------------------
# load, filter, convert to DF and append files (1 månad = 3min)
#---------------------------------------------------------------------------------------------------

final = data.frame()

for(i in 1:length(date_vector)){
  temp = tidytransit::read_gtfs(paste0(mapp_temp, "koda_", rkm, "_", date_vector[i], ".zip"))
  
  temp = filter_feed_by_date(temp, date_vector[i])
  
  # join lists and create df 
  temp = temp$stop_times %>%  
    left_join(., temp$trips, by = "trip_id") %>% 
    left_join(., temp$stops, by = "stop_id") %>% 
    left_join(., temp$routes, by = "route_id") %>%
    # create hpl ID
    mutate(hpl_id = substr(stop_id, 8, 13),
           # create column with date
           datum = date_vector[i]) %>% 
    # remove unnecessary columns
    select(-c(route_long_name, parent_station, location_type, pickup_type, drop_off_type))
  
  # append dfs
  final = bind_rows(final, temp)
  
  # remove gtfs zip file
  file.remove(paste0(mapp_temp, "koda_", rkm, "_", date_vector[i], ".zip"))
  
  # clean cache
  invisible(gc())
  }

stop_datahantering = Sys.time()

### write file
fst::write.fst(final, paste0(mapp_koda, "koda_", rkm, year, ".fst"))

stop_save = Sys.time()


stop_save - start
stop_download - start
stop_save - stop_download

#### TODO
# om zip fil är mindre än 1MB, kasta sökvägen i en lista så det kan hanteras senare
# om zip fil är mindre än 1MB, kan den inte läsas och skriptet slutar, kräver en IF statement
# lägg till kolumn med datum i df innan append



