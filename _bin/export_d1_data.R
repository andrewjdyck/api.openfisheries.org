
# Exports a FAO Global Production release as CSV and SQL files that can be
# loaded into a Cloudflare D1 (SQLite) database.
#
# Run from the repository root:
#   Rscript _bin/export_d1_data.R [release_zip] [out_dir] [rows_per_file]
#
# Writes (out_dir defaults to data/d1/, which is not committed to git):
#   csv/countries.csv, csv/species.csv, csv/areas.csv, csv/landings.csv
#   sql/0000_schema.sql           tables and release metadata
#   sql/0001_lookups.sql          countries, species and fishing areas
#   sql/0002_landings_001.sql ... landings, at most rows_per_file rows each
#   sql/9999_indexes.sql          secondary indexes, applied after loading
#
# Load them in order with, for example:
#   for f in data/d1/sql/*.sql; do npx wrangler d1 execute <db> --remote --file="$f"; done
#
# The D1 free plan limits rows written per day (100,000 at the time of writing),
# so the landings are split into files of at most rows_per_file rows. Load one
# per day on the free plan, or all at once on a paid plan.

source("./_bin/fao_data_utils.r")
source("./_bin/d1_utils.R")

FAO_RELEASE <- "2026.1.0"

export_d1_data <- function(release_zip, out_dir = "data/d1", version = FAO_RELEASE,
                           rows_per_file = 100000) {
  release <- read_fao_release(release_zip)
  cleaned <- clean_fao_release(release)
  landings <- d1_landings(cleaned)
  tables <- list(
    countries = d1_countries(release, cleaned),
    species = d1_species(release, landings),
    areas = d1_areas(release),
    landings = landings
  )

  csv_dir <- file.path(out_dir, "csv")
  sql_dir <- file.path(out_dir, "sql")
  unlink(c(csv_dir, sql_dir), recursive = TRUE)
  dir.create(csv_dir, recursive = TRUE)
  dir.create(sql_dir, recursive = TRUE)

  for (name in names(tables)) {
    write.csv(tables[[name]], file.path(csv_dir, paste0(name, ".csv")), row.names = FALSE, na = "")
  }

  writeLines(d1_schema_sql(version), file.path(sql_dir, "0000_schema.sql"))
  writeLines(
    c(sql_inserts(tables$countries, "countries"),
      sql_inserts(tables$species, "species"),
      sql_inserts(tables$areas, "areas")),
    file.path(sql_dir, "0001_lookups.sql")
  )
  chunks <- split(seq_len(nrow(landings)), ceiling(seq_len(nrow(landings)) / rows_per_file))
  for (i in seq_along(chunks)) {
    writeLines(
      sql_inserts(landings[chunks[[i]], ], "landings"),
      file.path(sql_dir, sprintf("0002_landings_%03d.sql", i))
    )
  }
  writeLines(d1_index_sql(), file.path(sql_dir, "9999_indexes.sql"))

  message("Wrote ", nrow(landings), " landings rows in ", length(chunks), " files, ",
          nrow(tables$countries), " countries, ", nrow(tables$species), " species, ",
          nrow(tables$areas), " areas to ", out_dir, "/")
  invisible(tables)
}

args <- commandArgs(trailingOnly = TRUE)
release_zip <- if (length(args) >= 1) args[1] else download_fao_release(FAO_RELEASE)
out_dir <- if (length(args) >= 2) args[2] else "data/d1"
rows_per_file <- if (length(args) >= 3) as.integer(args[3]) else 100000

export_d1_data(release_zip, out_dir, rows_per_file = rows_per_file)
