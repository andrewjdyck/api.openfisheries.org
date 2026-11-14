source(file.path("..", "..", "_bin", "fao_data_utils.r"))
source(file.path("..", "..", "_bin", "prepare_api_json_data.r"))

# A tiny stand-in for a FishStatJ export as read by read.csv():
# five descriptor columns, then X<year> and S/S.<n> symbol columns.
fao_fixture <- function() {
  data.frame(
    Country = c("CAN", "CAN", "USA", "USA", ""),
    Species = c("COD", "COD", "COD", "SKJ", "COD"),
    Area = c(
      "Atlantic, Northwest", "Canada - Inland waters", "Atlantic, Northwest",
      "Pacific, Eastern Central", "Atlantic, Northwest"
    ),
    Source = c(rep("Capture production", 4), "Capture production"),
    Unit = c(rep("Tonnes - live weight", 4), "Tonnes - live weight"),
    X2000 = c(10, 1, 20, 5, 99),
    S = c("", "", "F", "", ""),
    X2001 = c(11, 2, 21, 6, 99),
    S.1 = c("", "-", "", "F", ""),
    X2002 = c(12, 3, 22, 7, 99),
    S.2 = c("F", "", "", "", ""),
    stringsAsFactors = FALSE
  )
}

test_that("years are detected from the export columns", {
  expect_equal(detect_fao_years(fao_fixture()), 2000:2002)
})

test_that("clean_fao_data reshapes to one row per series and year", {
  landings <- clean_fao_data(fao_fixture())

  # Rows with no country are dropped
  expect_false(any(landings$iso3c == ""))
  expect_equal(nrow(landings), 4 * 3)
  expect_equal(sort(unique(landings$year)), 2000:2002)

  can_inland <- landings[landings$iso3c == "CAN" & landings$inland == 1, ]
  expect_equal(can_inland$catch[order(can_inland$year)], c(1, 2, 3))
})

test_that("a subset of years keeps each year's own symbol column", {
  landings <- clean_fao_data(fao_fixture(), years = 2001:2002)
  expect_equal(sort(unique(landings$year)), 2001:2002)

  usa_skj <- landings[landings$a3_code == "SKJ", ]
  expect_equal(usa_skj$S[usa_skj$year == 2001], "F")

  can_cod <- landings[landings$iso3c == "CAN" & landings$inland == 0, ]
  expect_equal(can_cod$S[can_cod$year == 2002], "F")
})

test_that("unknown years are rejected", {
  expect_error(clean_fao_data(fao_fixture(), years = 1999:2001), "1999")
})

test_that("country, species, and global files hold the right totals", {
  out_dir <- withr::local_tempdir()
  landings <- clean_fao_data(fao_fixture())

  output_global_json(landings, out_dir)
  output_country_json(landings, out_dir)
  output_species_json(landings, out_dir)

  global <- jsonlite::fromJSON(file.path(out_dir, "landings.json"))
  expect_equal(global$year, 2000:2002)
  expect_equal(global$catch, c(36, 40, 44))

  can <- jsonlite::fromJSON(file.path(out_dir, "landings", "countries", "CAN.json"))
  expect_equal(names(can), c("year", "catch"))
  expect_equal(can$catch, c(11, 13, 15))

  cod <- jsonlite::fromJSON(file.path(out_dir, "landings", "species", "COD.json"))
  expect_equal(cod$catch, c(31, 34, 37))
})

test_that("clean_landings_files only removes per-code folders", {
  out_dir <- withr::local_tempdir()
  dir.create(file.path(out_dir, "landings", "countries"), recursive = TRUE)
  writeLines("[]", file.path(out_dir, "landings", "countries.json"))

  clean_landings_files(out_dir)

  expect_false(dir.exists(file.path(out_dir, "landings", "countries")))
  expect_true(file.exists(file.path(out_dir, "landings", "countries.json")))
})
