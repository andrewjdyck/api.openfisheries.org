
# Builds the landings API files from either:
#   - a FAO Global Production release zip (or a folder of its extracted files),
#     e.g. data/fao/GlobalProduction_2026.1.0.zip, or
#   - an older FishStatJ capture production CSV export.
#
# Run from the repository root, in R or RStudio:
#   source("_bin/build_landings_api_data.R")
# or from a shell, optionally overriding the defaults below:
#   Rscript _bin/build_landings_api_data.R [data_file] [out_dir] [first_year] [last_year]

source("./_bin/fao_data_utils.r")
source("./_bin/prepare_api_json_data.r")

API_VERSION <- 0.4
API_URL <- "https://api.openfisheries.org"

build_landings_api <- function(data_file,
                               out_dir = "docs",
                               years = NULL,
                               clean = FALSE) {
  landings <- read_landings(data_file, years = years)
  message("Built landings from ", data_file, " for ",
          min(landings$year), "-", max(landings$year), "; writing to ", out_dir, "/")

  # Set clean = TRUE to delete existing per-country and per-species files first.
  # Note this also removes files for codes that are no longer in the FAO data,
  # which breaks those URLs for existing users.
  if (clean) clean_landings_files(out_dir)

  output_code_lists(out_dir)
  output_global_json(landings, out_dir)
  output_global_disagg_csv(landings, out_dir)
  output_country_json(landings, out_dir)
  output_species_json(landings, out_dir)
  output_api_metadata(out_dir, version = API_VERSION, url = API_URL)

  invisible(landings)
}

# Reads and cleans either input format into the long landings format.
read_landings <- function(data_file, years = NULL) {
  if (grepl("\\.zip$", data_file) || dir.exists(data_file)) {
    clean_fao_release(read_fao_release(data_file), years = years)
  } else {
    in_data <- read_fao_data(data_file)
    if (is.null(years)) years <- detect_fao_years(in_data)
    clean_fao_data(in_data, years = years)
  }
}

args <- commandArgs(trailingOnly = TRUE)
data_file <- if (length(args) >= 1) args[1] else "./data/fishstat_export_s_capture2020.csv"
out_dir <- if (length(args) >= 2) args[2] else "docs"
years <- if (length(args) >= 4) as.integer(args[3]):as.integer(args[4]) else NULL

build_landings_api(data_file, out_dir = out_dir, years = years)
