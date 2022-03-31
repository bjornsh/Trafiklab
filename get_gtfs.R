#---------------------------------------------------------------------------------------------------
# Syfte
#---------------------------------------------------------------------------------------------------

### Create template download of static GTFS timetable data from Trafiklab



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
pacman::p_load(tidyverse, httr, writexl)


# avoid scientific notation
options(scipen=999)


# create output directory
dir.create(paste0(getwd(), "/output"))
dir.create(paste0(getwd(), "/input"))

# get paths
api_fil <- read_file(paste0("Z:/api"))
trafiklab_key = gsub('^.*trafiklab_gtfsstatik: \\s*|\\s*\r.*$', "", api_fil)
output = paste0(getwd(),"/output/")
input = paste0(getwd(),"/input/")

# datum för nedladdning
today = str_remove_all(Sys.Date(), "-")



#---------------------------------------------------------------------------------------------------
# Download data
#---------------------------------------------------------------------------------------------------

# define RKM
rkm = "ul"



url <- paste0("https://opendata.samtrafiken.se/gtfs/", rkm, "/", rkm, ".zip?key=", trafiklab_key)
GET(url, write_disk(paste0(input, "trafiklab_", rkm, ".zip"), overwrite=TRUE))
unzip(paste0(input, "/trafiklab_", rkm, ".zip"), exdir = paste0(input, "/trafiklab_", rkm))


#---------------------------------------------------------------------------------------------------
# Load data
#---------------------------------------------------------------------------------------------------

routes = read.csv2(paste0(input, "/trafiklab_", rkm, "/routes.txt"), 
                   sep = ",", encoding="UTF-8", stringsAsFactors=FALSE)
stops = read.csv2(paste0(input, "/trafiklab_", rkm, "/stops.txt"), 
                  sep = ",", encoding="UTF-8", stringsAsFactors=FALSE)
stop_times = read.csv2(paste0(input, "/trafiklab_", rkm, "/stop_times.txt"), 
                       sep = ",", encoding="UTF-8", stringsAsFactors=FALSE)
trips = read.csv2(paste0(input, "/trafiklab_", rkm, "/trips.txt"), 
                  sep = ",", encoding="UTF-8", stringsAsFactors=FALSE)
calendar_dates = read.csv2(paste0(input, "/trafiklab_", rkm, "/calendar_dates.txt"), 
                           sep = ",", encoding="UTF-8", stringsAsFactors=FALSE)
# linjenät koordinater
shapes = read.csv2(paste0(input, "/trafiklab_", rkm, "/shapes.txt"), 
                   sep = ",", encoding="UTF-8", stringsAsFactors=FALSE)



#---------------------------------------------------------------------------------------------------
# Merge data
#---------------------------------------------------------------------------------------------------
gtfs = stop_times %>%  
  left_join(., trips, by = "trip_id") %>% 
  left_join(., stops, by = "stop_id") %>% 
  left_join(., routes, by = "route_id") %>% 
  mutate(hpl_id = substr(stop_id, 8, 13))

