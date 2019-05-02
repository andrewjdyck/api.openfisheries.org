

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
      a3_code=out_data$a3_code,
      year=out_data$year
    ), 
    FUN="sum"
  )
  names(species_data)[3] <- 'catch'
  species_data <<- species_data
}


write_single_country_json <- function(c) {
  temp1 <- country_data[which(country_data$iso3c==c), c('year', 'catch')]
  # temp2 <- out_data[which(out_data$iso3c==c), c('year', 'a3_code', 'catch')]
  # row.names(temp2) <- NULL
  # names(temp2)[2] <- 'species'
  writeLines(
    toJSON(temp1),
    paste0('./api/landings/countries/', c, '.json')
  )
  # writeLines(
  #   toJSON(temp2),
  #   paste0('./api/landings/countries/', c, '_species.json')
  # )
}

output_country_json <- function(countries) {
  sapply(countries, function(x) 
    write_single_country_json(x)
  )
}

write_single_species_json <- function(species) {
  temp1 <- species_data[which(species_data$a3_code==species), c('year', 'catch')]
  writeLines(
    toJSON(temp1),
    paste('./api/landings/species/', species, '.json', sep = '')
  )
}

output_species_json <- function(species) {
  sapply(species, function(x) 
    write_single_species_json(x)
  )
}

return_global_catch_json <- function(dataset) {
  return_data <- aggregate(
    dataset$catch,
    by=list(year=dataset$year),
    FUN="sum"
  )
  names(return_data)[2] <- 'catch'
  toJSON(return_data)
}

output_global_json <- function(dataset) {
  json_string <- return_global_catch_json(dataset)
  writeLines(json_string, './api/landings.json')
}

output_global_disagg_csv <- function(dataset) {
  temp1 <- out_data[, c('iso3c', 'a3_code', 'inland', 'year', 'catch')]
  names(temp1)[2] <- 'species'
  writeLines(temp1, './api/landings/global_fao_disagg.csv')
}

# end