
# Prepare and write the landings API files from the cleaned FAO data
# (the output of clean_fao_data()).
library(jsonlite)

# Total catch by year, optionally broken down by another column (e.g. "iso3c").
summarise_catch <- function(landings, by = character(0)) {
  groups <- c(by, "year")
  totals <- aggregate(landings$catch, by = landings[groups], FUN = "sum")
  names(totals)[ncol(totals)] <- "catch"
  totals
}

write_json_file <- function(x, path) {
  writeLines(toJSON(x), path)
}

# Writes one <code>.json file per value of code_col, each holding year and catch.
write_code_files <- function(totals, code_col, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  for (code in unique(totals[[code_col]])) {
    rows <- totals[which(totals[[code_col]] == code), c("year", "catch")]
    write_json_file(rows, file.path(dir, paste0(code, ".json")))
  }
}

output_global_json <- function(landings, out_dir) {
  write_json_file(summarise_catch(landings), file.path(out_dir, "landings.json"))
}

output_country_json <- function(landings, out_dir) {
  totals <- summarise_catch(landings, by = "iso3c")
  write_code_files(totals, "iso3c", file.path(out_dir, "landings", "countries"))
}

output_species_json <- function(landings, out_dir) {
  totals <- summarise_catch(landings, by = "a3_code")
  write_code_files(totals, "a3_code", file.path(out_dir, "landings", "species"))
}

output_global_disagg_csv <- function(landings, out_dir) {
  disagg <- landings[, c("iso3c", "a3_code", "inland", "year", "catch")]
  names(disagg)[2] <- "species"
  write.csv(
    disagg,
    file.path(out_dir, "landings", "global_fao_disagg.csv"),
    quote = FALSE,
    row.names = FALSE
  )
}

# Copies the country and species code lists that the API publishes.
output_code_lists <- function(out_dir, data_dir = "data") {
  landings_dir <- file.path(out_dir, "landings")
  dir.create(landings_dir, recursive = TRUE, showWarnings = FALSE)
  for (f in c("countries.json", "species.json")) {
    file.copy(file.path(data_dir, f), file.path(landings_dir, f), overwrite = TRUE)
  }
}

output_api_metadata <- function(out_dir, version, url) {
  write_json_file(data.frame(version = version, url = url), file.path(out_dir, "api.json"))
}

# Removes the per-country and per-species files so that codes dropped from a
# new FAO release do not linger. Leaves the code lists and other files alone.
clean_landings_files <- function(out_dir) {
  unlink(file.path(out_dir, "landings", c("countries", "species")), recursive = TRUE)
}
