
# Utilities for reading and cleaning a FishStatJ capture production CSV export.
#
# The export has five descriptor columns (country, species, area, source, unit)
# followed by one column per year and a symbol column after each year:
#   1950, S, 1951, S, ...
# read.csv() renames these to X1950, S, X1951, S.1, ... so the symbol column for
# the n-th year in the file is "S" for the first year and "S.<n-1>" after that.

read_fao_data <- function(data_file) {
  read.csv(data_file, as.is = TRUE)
}

# All years present in the export, in file order.
detect_fao_years <- function(in_data) {
  year_cols <- grep("^X[0-9]{4}$", names(in_data), value = TRUE)
  as.integer(sub("^X", "", year_cols))
}

# Name of the symbol column that belongs to each year.
fao_symbol_columns <- function(in_data, years) {
  file_years <- detect_fao_years(in_data)
  position <- match(years, file_years)
  ifelse(position == 1, "S", paste0("S.", position - 1))
}

# Returns a long data frame with one row per country, species, area type,
# location and year: iso3c, a3_code, inland, location_id, year, catch, S.
#
# years defaults to every year in the export. Pass a subset, e.g. 1960:2018,
# to restrict the output.
clean_fao_data <- function(in_data, years = detect_fao_years(in_data)) {
  missing_years <- setdiff(years, detect_fao_years(in_data))
  if (length(missing_years) > 0) {
    stop("Years not found in the FAO export: ", paste(missing_years, collapse = ", "))
  }

  names(in_data)[1:5] <- c("iso3c", "a3_code", "area", "source", "measure")

  # We only care about the weight of fish caught, so remove the number of fish measures
  data <- in_data[which(in_data$measure == "Tonnes - live weight"), ]
  data$measure <- NULL

  # Split the area into a location and an inland/marine flag
  data$inland <- as.numeric(grepl(" - Inland waters", data$area))
  data$location <- sub(" - Inland waters", "", data$area)
  location_names <- sort(unique(data$location))
  locations <- data.frame(
    location = location_names,
    location_id = seq_along(location_names),
    stringsAsFactors = FALSE
  )
  data <- merge(data, locations, by = "location")

  # Only capture production
  data <- data[which(data$source == "Capture production"), ]

  # Reshape to long format
  data$location <- NULL
  data$area <- NULL
  data$source <- NULL
  d <- reshape(
    data[which(data$iso3c != ""), ],
    direction = "long",
    varying = list(
      paste0("X", years),
      fao_symbol_columns(in_data, years)
    ),
    v.names = c("catch", "S"),
    idvar = c("iso3c", "a3_code", "inland", "location_id"),
    timevar = "year",
    times = years,
    new.row.names = NULL
  )
  d$S[which(d$S == ".")] <- ""
  row.names(d) <- NULL
  d
}

# Meaning of the values in the FAO symbol ("S") column.
fao_symbol_notes <- function() {
  data.frame(
    symbol = c("0", "-", "t", "F"),
    description = c(
      "Greater than 0, but less than 1 tonne",
      "Equal to zero",
      "??",
      "FAO estimate"
    )
  )
}
