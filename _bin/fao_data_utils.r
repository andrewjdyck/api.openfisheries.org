
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


# ---- FAO Global Production releases (2026.1.0 onwards) ----------------------
#
# FAO publishes each release as a zip at a versioned URL. The zip holds one long
# table, Global_production_quantity.csv, with one row per country, species,
# fishing area, production source, measure and year, plus code lists (CL_*.csv)
# that decode those codes. Countries are UN M49 numeric codes; the country code
# list maps them to ISO 3166 alpha-3.

fao_release_url <- function(version) {
  paste0("https://www.fao.org/fishery/static/Data/GlobalProduction_", version, ".zip")
}

# Downloads a release zip into dest_dir (skipped if it is already there) and
# returns its path.
download_fao_release <- function(version, dest_dir = "data/fao") {
  dest <- file.path(dest_dir, paste0("GlobalProduction_", version, ".zip"))
  if (!file.exists(dest)) {
    dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
    download.file(fao_release_url(version), dest, mode = "wb")
  }
  dest
}

# Reads one CSV from a release, given either the zip or a folder holding its
# extracted files. Every column is read as text so codes like "004" keep their
# leading zeros.
read_fao_release_file <- function(src, name) {
  con <- if (grepl("\\.zip$", src)) unz(src, name, encoding = "UTF-8") else file.path(src, name)
  read.csv(con, colClasses = "character", check.names = FALSE, encoding = "UTF-8")
}

read_fao_release <- function(src) {
  list(
    production = read_fao_release_file(src, "Global_production_quantity.csv"),
    countries = read_fao_release_file(src, "CL_FI_COUNTRY_GROUPS.csv"),
    species = read_fao_release_file(src, "CL_FI_SPECIES_GROUPS.csv"),
    areas = read_fao_release_file(src, "CL_FI_WATERAREA_GROUPS.csv")
  )
}

# Capture production in tonnes (live weight), in the same long format that
# clean_fao_data() returns, so the rest of the pipeline works unchanged:
#   iso3c, a3_code, inland, location_id, year, catch, S
# location_id is the FAO major fishing area code, and S holds FAO's SDMX status
# code (A official, I imputed, N not significant (<0.5 t), E estimated, ...).
#
# Rows for countries with no ISO3 code (former Ethiopia PDR, former Sudan, and
# "Other nei") are dropped unless keep_unmapped is TRUE, matching the old
# FishStatJ exports. years defaults to every year in the release.
clean_fao_release <- function(release, years = NULL, keep_unmapped = FALSE) {
  prod <- release$production
  capture <- prod[prod[["PRODUCTION_SOURCE_DET.CODE"]] == "CAPTURE" & prod[["MEASURE"]] == "Q_tlw", ]

  countries <- release$countries
  areas <- release$areas
  area_type <- areas$InlandMarine_Group_En[match(capture[["AREA.CODE"]], areas$Code)]
  if (anyNA(area_type)) {
    stop("Fishing area codes missing from the area code list: ",
         paste(unique(capture[["AREA.CODE"]][is.na(area_type)]), collapse = ", "))
  }

  d <- data.frame(
    iso3c = countries$ISO3_Code[match(capture[["COUNTRY.UN_CODE"]], countries$UN_Code)],
    un_code = capture[["COUNTRY.UN_CODE"]],
    a3_code = capture[["SPECIES.ALPHA_3_CODE"]],
    inland = as.numeric(area_type == "Inland waters"),
    location_id = as.integer(capture[["AREA.CODE"]]),
    year = as.integer(capture[["PERIOD"]]),
    catch = as.numeric(capture[["VALUE"]]),
    S = capture[["STATUS"]],
    stringsAsFactors = FALSE
  )
  d$iso3c[is.na(d$iso3c)] <- ""

  if (!keep_unmapped) d <- d[d$iso3c != "", ]

  # Two UN codes mapping to one ISO3 code (as the code list does for the former
  # Netherlands Antilles) would give two rows for the same series and year.
  key <- paste(d$iso3c, d$a3_code, d$location_id, d$year)
  mapped <- d$iso3c != ""
  if (anyDuplicated(key[mapped])) {
    dup <- unique(d$iso3c[mapped][duplicated(key[mapped])])
    stop("More than one UN country code maps to ISO3 code(s): ", paste(dup, collapse = ", "))
  }

  if (!is.null(years)) {
    missing_years <- setdiff(years, d$year)
    if (length(missing_years) > 0) {
      stop("Years not found in the FAO release: ", paste(missing_years, collapse = ", "))
    }
    d <- d[d$year %in% years, ]
  }

  d <- d[order(d$iso3c, d$a3_code, d$location_id, d$year), ]
  row.names(d) <- NULL
  d
}
