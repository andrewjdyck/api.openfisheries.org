

# Prepare API data
library(jsonlite)

prep_fao_fishstat_data <- function(dataset) {
  country_list <<- unique(dataset[, "iso3c"])
  country_data <- aggregate(
    out_data$catch, 
    by=list(
      iso3c=out_data$iso3c,
      year=out_data$year
    ), 
    FUN="sum"
  )
  names(country_data)[3] <- 'catch'
  country_data <<- country_data
  
  species_list <<- unique(dataset[, 'a3_code'])
  species_data <<- aggregate(
    out_data$catch, 
    by=list(
      iso3c=out_data$a3_code,
      year=out_data$year
    ), 
    FUN="sum"
  )
  names(species_data)[3] <- 'catch'
  species_data <<- species_data
}


return_single_country_json <- function(c) {
  writeLines(
    toJSON(country_data[which(country_data$iso3c==c), c('year', 'catch')]),
  paste('./api/landings/countries/', c, '.json', sep = '')
  )
}

output_country_json <- function(countries) {
  sapply(countries, function(x) 
    return_single_country_json(x)
  )
}

return_single_species_json <- function(c) {
  writeLines(
    toJSON(country_data[which(species_data$a3_code==c), c('year', 'catch')]),
    paste('./api/landings/species/', c, '.json', sep = '')
  )
}

output_species_json <- function(countries) {
  sapply(species, function(x) 
    return_single_species_json(x)
  )
}

