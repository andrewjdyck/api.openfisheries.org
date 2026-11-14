
# Downloads a FAO Global Production release zip into data/fao/.
# The zip is not committed to git (see .gitignore); rerun this to get it.
#
# Run from the repository root:
#   Rscript _bin/download_fao_data.R [version]
# e.g.
#   Rscript _bin/download_fao_data.R 2026.1.0

source("./_bin/fao_data_utils.r")

FAO_RELEASE <- "2026.1.0"

args <- commandArgs(trailingOnly = TRUE)
version <- if (length(args) >= 1) args[1] else FAO_RELEASE

path <- download_fao_release(version)
message("FAO Global Production ", version, " is at ", path)
