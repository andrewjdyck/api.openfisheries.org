

# Read data from FISHSTATJ CSV Export
# Notes on this dataset:
#   1. the country column contains a 182 observations with null
read_fao_data <- function(data_file) {
   read.csv(
    data_file, 
    as.is=TRUE
  )
}

clean_landings_files <- function() {
  unlink('./api/landings/', recursive = TRUE)
  dir.create('./api/landings/')
}

clean_fao_data <- function(in_data, years) {
  # We only care about the weight of fish caught, so remove the number of fish measures
  names(in_data)[1:4] <- c("iso3c", "a3_code", "area", "measure")
  # data <- in_data[which(in_data$measure == "Quantity (tonnes)"), ]
  data <- in_data[which(in_data$measure == "Tonnes - live weight"), ]
  data$measure <- NULL
  
  # for parsing the areas
  data$inland <- as.numeric(grepl(" - Inland waters", data$area))
  data$location <- sub(" - Inland waters", "", data$area)
  locations <- data.frame(sort(unique(data$location)), c(1:length(unique(data$location))), stringsAsFactors=FALSE)
  names(locations) <- c("location", "location_id")
  data <- merge(data, locations, by.x="location", by.y="location")
  
  # Reshape to long format
  data$location <- NULL
  data$area <- NULL
  d <- reshape(
    data[which(data$iso3c!=""),], 
    direction="long", 
    varying=list(
      sapply(years, function(year) paste("X",year,sep="")),
      c("S", sapply(1:(length(years)-1), function(s) paste("S.",s,sep="")))
    ), 
    v.names=c("catch", "S"), 
    idvar=c("iso3c", "a3_code", "inland", "location_id"), 
    timevar="year", 
    times=years,
    new.row.names=NULL
  )
  d$S[which(d$S==".")] <- ""
  d[,c("created_date", "last_updated_date")] <- Sys.time()
  row.names(d) <- NULL
  out_data <<- d

  # Create a table of notes for the symbols field
  fao_data_notes <<- data.frame(
    symbol=c("0","-","t","F"),
    description=c("Greater than 0, but less than 1 tonne",
                  "Equal to zero",
                  "??",
                  "FAO estimate")
  )
}

