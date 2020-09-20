library(countrycode)
library(readr)
library(dplyr)
library(jsonlite)


output_subsidies_json <- function(input_df) {
  
  subsidies <- input_df
  
  countries <- unique(subsidies$iso3c)
  
  for (iso3c in countries) {
    filename <- paste0('./docs/subsidies/', iso3c, '.json')
    df <- subsidies %>% 
      filter(iso3c == iso3c) %>% 
      select(-c(`Region Name`, Country, iso3c)) %>%
      rename(Subsidies = `Constant 2018 USD`) %>%
      mutate(Units = 'Constant 2018 USD')
    writeLines(toJSON(df), filename)
  }
}

output_total_subsidies <- function(input_df) {
  subsidies <- input_df %>% rename(Subsidies = `Constant 2018 USD`)
  
  subsidy_total_by_category <- aggregate(
    subsidies$Subsidies,
    by=list(Category=subsidies$Category),
    FUN="sum"
  ) %>%
    rename(Subsidy = x)
  
  subsidy_total_by_type <- aggregate(
    subsidies$Subsidies,
    by=list(Type=subsidies$Type, Class=subsidies$Class),
    FUN="sum"
  ) %>%
    rename(Subsidy = x)
  
  subsidy_total_by_country <- aggregate(
    subsidies$Subsidies,
    by=list(Country=subsidies$Country, iso3c=subsidies$iso3c),
    FUN="sum"
  ) %>%
    rename(Subsidy = x)
  
  writeLines(toJSON(subsidy_total_by_country), './docs/subsidies/subsidy_country_totals.json')
  writeLines(toJSON(subsidy_total_by_category), './docs/subsidies/subsidy_category_totals.json')
  writeLines(toJSON(subsidy_total_by_type), './docs/subsidies/subsidy_type_totals.json')
}

subsidies_in <- readr::read_csv('./data/subsidies/1-s2.0-S2352340919310613-mmc1/Suppl Mat/Sumaila_dataset.csv')
# Following countries are not named in a typical manner or unambiguously
# - Untd Arab Em -> "United Arab Emirates"
# - Micronesia -> "Micronesia (Federated States of)"
# - Dominican Rp -> "Dominican Republic"
subsidies <- subsidies_in %>%
  select(-X1) %>%
  mutate(iso3c = countrycode::countrycode(Country, origin='country.name', destination='iso3c')) %>%
  mutate(iso3c = ifelse(
    Country == 'Untd Arab Em', 'ARE', ifelse(
      Country == 'Micronesia', 'FSM', ifelse(
        Country == 'Dominican Rp', 'DOM', iso3c
      )
    )
  ))

# Outputs 1 json doc for each ISO-3 code
output_subsidies_json(subsidies)

# Outputs 1 json file for totals by subsidy class and 1 json file for totals by subsidy types.
output_total_subsidies(subsidies)
