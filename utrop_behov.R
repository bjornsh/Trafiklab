#---------------------------------------------------------------------------------------------------
# Syfte
#---------------------------------------------------------------------------------------------------

### Identifiera alla hpl per linje som trafikeras av mer än 1 linje och därför
### behöver utrop när bussen kommer fram till hpl



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


#---------------------------------------------------------------------------------------------------
# Datahantering
#---------------------------------------------------------------------------------------------------

# Number of unique linjer per hpl
antal_linjer_per_hpl = gtfs %>% 
  # remove duplicates
  distinct(hpl_id, stop_name, route_short_name) %>% 
  # number of linjer per hpl
  group_by(hpl_id, stop_name) %>% 
  summarise(antal_linjer = n()) %>% 
  ungroup()
  
utrop_behov = gtfs %>% 
  # remove duplicates
  distinct(hpl_id, stop_name, route_short_name) %>% 
  left_join(., antal_linjer_per_hpl[,c("hpl_id", "antal_linjer")], by = "hpl_id") %>% 
  mutate(utrop = ifelse(antal_linjer > 1, "ja", "nej")) %>% 
  select(linje = route_short_name, hpl_id, stop_name, antal_linjer, utrop) %>% 
  arrange(linje)

write_xlsx(utrop_behov, paste0(output, "utrop_behov.xlsx"))
