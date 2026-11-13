
# Builds the landings API files from a FishStatJ capture production export.
#
# Run from the repository root, in R or RStudio:
#   source("_bin/build_landings_api_data.R")
# or from a shell, optionally overriding the defaults below:
#   Rscript _bin/build_landings_api_data.R [data_file] [out_dir] [first_year] [last_year]

source("./_bin/fao_data_utils.r")
source("./_bin/prepare_api_json_data.r")

API_VERSION <- 0.4
API_URL <- "http://api.openfisheries.org"

build_landings_api <- function(data_file,
                               out_dir = "docs",
                               years = NULL,
                               clean = FALSE) {
  in_data <- read_fao_data(data_file)
  if (is.null(years)) years <- detect_fao_years(in_data)
  message("Building landings API from ", data_file, " for ",
          min(years), "-", max(years), " into ", out_dir, "/")

  landings <- clean_fao_data(in_data, years = years)

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

args <- commandArgs(trailingOnly = TRUE)
data_file <- if (length(args) >= 1) args[1] else "./data/fishstat_export_s_capture2020.csv"
out_dir <- if (length(args) >= 2) args[2] else "docs"
years <- if (length(args) >= 4) as.integer(args[3]):as.integer(args[4]) else NULL

build_landings_api(data_file, out_dir = out_dir, years = years)
