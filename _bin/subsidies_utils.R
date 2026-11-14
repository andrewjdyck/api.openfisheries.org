
# Functions for preparing the global fisheries subsidies API files
# (Sumaila et al. dataset). Run _bin/subsidies.R to build the files.
library(dplyr)
library(jsonlite)

# Reads the Sumaila et al. CSV and adds an ISO 3166 alpha-3 code for each country.
read_subsidies <- function(data_file) {
  subsidies_in <- readr::read_csv(data_file, show_col_types = FALSE)

  # The first, unnamed column is a row number. readr calls it X1 in older
  # versions and ...1 in newer ones.
  subsidies_in %>%
    select(-any_of(c("X1", "...1"))) %>%
    mutate(iso3c = country_to_iso3c(Country))
}

# The following countries are not named in a typical manner or unambiguously:
#   Untd Arab Em -> "United Arab Emirates"
#   Micronesia   -> "Micronesia (Federated States of)"
#   Dominican Rp -> "Dominican Republic"
country_to_iso3c <- function(country) {
  iso3c <- countrycode::countrycode(country, origin = "country.name", destination = "iso3c")
  case_when(
    country == "Untd Arab Em" ~ "ARE",
    country == "Micronesia" ~ "FSM",
    country == "Dominican Rp" ~ "DOM",
    TRUE ~ iso3c
  )
}

# Writes one <ISO3>.json file per country, holding only that country's rows.
output_subsidies_json <- function(subsidies, out_dir = "docs/subsidies") {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  for (code in unique(subsidies$iso3c)) {
    df <- subsidies %>%
      filter(iso3c == code) %>%
      select(-c(`Region Name`, Country, iso3c)) %>%
      rename(Subsidies = `Constant 2018 USD`) %>%
      mutate(Units = "Constant 2018 USD")
    writeLines(toJSON(df), file.path(out_dir, paste0(code, ".json")))
  }
}

# Writes totals by country, by category, and by type and class.
output_total_subsidies <- function(subsidies, out_dir = "docs/subsidies") {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  subsidies <- subsidies %>% rename(Subsidies = `Constant 2018 USD`)

  subsidy_total_by_category <- aggregate(
    subsidies$Subsidies,
    by = list(Category = subsidies$Category),
    FUN = "sum"
  ) %>%
    rename(Subsidy = x)

  subsidy_total_by_type <- aggregate(
    subsidies$Subsidies,
    by = list(Type = subsidies$Type, Class = subsidies$Class),
    FUN = "sum"
  ) %>%
    rename(Subsidy = x)

  subsidy_total_by_country <- aggregate(
    subsidies$Subsidies,
    by = list(Country = subsidies$Country, iso3c = subsidies$iso3c),
    FUN = "sum"
  ) %>%
    rename(Subsidy = x)

  writeLines(toJSON(subsidy_total_by_country), file.path(out_dir, "subsidy_country_totals.json"))
  writeLines(toJSON(subsidy_total_by_category), file.path(out_dir, "subsidy_category_totals.json"))
  writeLines(toJSON(subsidy_total_by_type), file.path(out_dir, "subsidy_type_totals.json"))
}
