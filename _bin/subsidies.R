
# Builds the subsidies API files from the Sumaila et al. dataset.
#
# Run from the repository root, in R or RStudio:
#   source("_bin/subsidies.R")
# or from a shell, optionally overriding the defaults below:
#   Rscript _bin/subsidies.R [data_file] [out_dir]

source("./_bin/subsidies_utils.R")

args <- commandArgs(trailingOnly = TRUE)
data_file <- if (length(args) >= 1) args[1] else
  "./data/subsidies/1-s2.0-S2352340919310613-mmc1/Suppl Mat/Sumaila_dataset.csv"
out_dir <- if (length(args) >= 2) args[2] else "docs/subsidies"

subsidies <- read_subsidies(data_file)

# One JSON file for each ISO-3 code
output_subsidies_json(subsidies, out_dir)

# One JSON file each for totals by country, by category, and by type and class
output_total_subsidies(subsidies, out_dir)
