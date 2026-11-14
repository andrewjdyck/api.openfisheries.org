
# Functions for exporting a FAO Global Production release to Cloudflare D1.
# Run _bin/export_d1_data.R to build the files. Needs _bin/fao_data_utils.r.

# Landings rows to load: drop rows that are an official zero (catch 0 with
# status A), which carry no information. Rows with status N (not significant,
# under 0.5 t) are kept even though FAO records them as 0.
d1_landings <- function(landings) {
  keep <- !(landings$catch == 0 & landings$S == "A")
  out <- landings[keep, c("iso3c", "a3_code", "location_id", "year", "catch", "S")]
  names(out) <- c("iso3c", "a3_code", "area", "year", "catch", "status")
  row.names(out) <- NULL
  out
}

# landings here is the output of clean_fao_release(), which keeps each row's
# UN code. The code list can repeat an ISO3 code for former entities (e.g.
# Netherlands Antilles), so match on the UN codes the data actually uses.
d1_countries <- function(release, landings) {
  cl <- release$countries
  cl <- cl[cl$UN_Code %in% unique(landings$un_code), ]
  data.frame(iso3c = cl$ISO3_Code, un_code = cl$UN_Code, name = cl$Name_En,
             continent = cl$Continent_Group_En, stringsAsFactors = FALSE)
}

d1_species <- function(release, landings) {
  sp <- release$species
  sp <- sp[sp[["3A_Code"]] %in% unique(landings$a3_code), ]
  data.frame(a3_code = sp[["3A_Code"]], name = sp$Name_En, scientific_name = sp$Scientific_Name,
             isscaap_group = sp$ISSCAAP_Group_En, major_group = sp$Major_Group,
             stringsAsFactors = FALSE)
}

d1_areas <- function(release) {
  ar <- release$areas
  data.frame(area = as.integer(ar$Code), name = ar$Name_En,
             inland = as.integer(ar$InlandMarine_Group_En == "Inland waters"),
             stringsAsFactors = FALSE)
}

sql_value <- function(x) {
  if (is.numeric(x)) {
    out <- format(x, scientific = FALSE, trim = TRUE, digits = 15, drop0trailing = TRUE)
    out[is.na(x)] <- "NULL"
    out
  } else {
    out <- paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
    out[is.na(x)] <- "NULL"
    out
  }
}

# INSERT statements for a data frame, batch_size rows per statement (D1 limits
# the size of a single statement).
sql_inserts <- function(df, table, batch_size = 500) {
  if (nrow(df) == 0) return(character(0))
  cols <- vapply(df, sql_value, character(nrow(df)))
  if (is.null(dim(cols))) cols <- matrix(cols, nrow = 1)
  tuples <- paste0("(", apply(cols, 1, paste, collapse = ","), ")")
  batches <- split(tuples, ceiling(seq_along(tuples) / batch_size))
  header <- paste0("INSERT INTO ", table, " (", paste(names(df), collapse = ","), ") VALUES\n")
  vapply(batches, function(b) paste0(header, paste(b, collapse = ",\n"), ";"), character(1))
}

d1_schema_sql <- function(version) {
  c(
    "DROP TABLE IF EXISTS landings;",
    "DROP TABLE IF EXISTS countries;",
    "DROP TABLE IF EXISTS species;",
    "DROP TABLE IF EXISTS areas;",
    "DROP TABLE IF EXISTS metadata;",
    "CREATE TABLE countries (iso3c TEXT PRIMARY KEY, un_code TEXT NOT NULL, name TEXT NOT NULL, continent TEXT);",
    "CREATE TABLE species (a3_code TEXT PRIMARY KEY, name TEXT, scientific_name TEXT, isscaap_group TEXT, major_group TEXT);",
    "CREATE TABLE areas (area INTEGER PRIMARY KEY, name TEXT NOT NULL, inland INTEGER NOT NULL);",
    paste0(
      "CREATE TABLE landings (iso3c TEXT NOT NULL, a3_code TEXT NOT NULL, area INTEGER NOT NULL, ",
      "year INTEGER NOT NULL, catch REAL NOT NULL, status TEXT NOT NULL, ",
      "PRIMARY KEY (iso3c, a3_code, area, year));"
    ),
    "CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);",
    sql_inserts(data.frame(
      key = c("source", "release", "unit", "url"),
      value = c("FAO Global Production (capture)", version, "tonnes (live weight)", fao_release_url(version))
    ), "metadata")
  )
}

d1_index_sql <- function() {
  c(
    "CREATE INDEX IF NOT EXISTS landings_species_year ON landings (a3_code, year);",
    "CREATE INDEX IF NOT EXISTS landings_year ON landings (year);"
  )
}
