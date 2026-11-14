source(file.path("..", "..", "_bin", "fao_data_utils.r"))
source(file.path("..", "..", "_bin", "prepare_api_json_data.r"))
source(file.path("..", "..", "_bin", "d1_utils.R"))

# Writes a tiny stand-in for an extracted FAO Global Production release and
# returns its folder.
write_release_fixture <- function(dir) {
  write_csv <- function(df, name) {
    write.csv(df, file.path(dir, name), row.names = FALSE)
  }
  write_csv(data.frame(
    COUNTRY.UN_CODE = c("124", "124", "124", "840", "840", "840", "896", "124"),
    SPECIES.ALPHA_3_CODE = c("COD", "COD", "COD", "SKJ", "SKJ", "COD", "COD", "SAL"),
    AREA.CODE = c("21", "21", "02", "77", "77", "21", "21", "21"),
    PRODUCTION_SOURCE_DET.CODE = c("CAPTURE", "CAPTURE", "CAPTURE", "CAPTURE", "CAPTURE",
                                   "MARINE", "CAPTURE", "CAPTURE"),
    MEASURE = c("Q_tlw", "Q_tlw", "Q_tlw", "Q_tlw", "Q_tlw", "Q_tlw", "Q_tlw", "Q_no_1"),
    PERIOD = c(2000, 2001, 2000, 2000, 2001, 2000, 2000, 2000),
    VALUE = c(10, 0, 0, 5.5, 6, 99, 7, 1000),
    STATUS = c("A", "A", "N", "I", "A", "A", "A", "A"),
    check.names = FALSE
  ), "Global_production_quantity.csv")
  write_csv(data.frame(
    UN_Code = c("124", "840", "896", "530", "532"),
    ISO3_Code = c("CAN", "USA", "", "ANT", "ANT"),
    Name_En = c("Canada", "United States of America", "Other nei",
                "Netherlands Antilles [former]", "Netherlands Antilles [former -1985]"),
    Continent_Group_En = c("Americas", "Americas", "", "Americas", "Americas")
  ), "CL_FI_COUNTRY_GROUPS.csv")
  write_csv(data.frame(
    `3A_Code` = c("COD", "SKJ", "SAL"),
    Name_En = c("Atlantic cod", "Skipjack tuna", "Atlantic salmon"),
    Scientific_Name = c("Gadus morhua", "Katsuwonus pelamis", "Salmo salar"),
    ISSCAAP_Group_En = c("Cods, hakes, haddocks", "Tunas, bonitos, billfishes", "Salmons"),
    Major_Group = c("PISCES", "PISCES", "PISCES"),
    check.names = FALSE
  ), "CL_FI_SPECIES_GROUPS.csv")
  write_csv(data.frame(
    Code = c("02", "21", "77"),
    Name_En = c("America, North - Inland waters", "Atlantic, Northwest", "Pacific, Eastern Central"),
    InlandMarine_Group_En = c("Inland waters", "Marine areas", "Marine areas")
  ), "CL_FI_WATERAREA_GROUPS.csv")
  dir
}

test_that("clean_fao_release keeps capture in tonnes and maps countries to ISO3", {
  release <- read_fao_release(write_release_fixture(withr::local_tempdir()))
  landings <- clean_fao_release(release)

  # Aquaculture (MARINE), numbers of fish (Q_no_1) and countries without an
  # ISO3 code (896, "Other nei") are dropped
  expect_equal(nrow(landings), 5)
  expect_setequal(unique(landings$iso3c), c("CAN", "USA"))
  expect_false("SAL" %in% landings$a3_code)

  # Codes keep their leading zeros, inland is taken from the area code list
  can_inland <- landings[landings$iso3c == "CAN" & landings$inland == 1, ]
  expect_equal(can_inland$location_id, 2L)
  expect_equal(can_inland$S, "N")

  usa <- landings[landings$iso3c == "USA", ]
  expect_equal(usa$catch, c(5.5, 6))
  expect_equal(usa$S, c("I", "A"))
})

test_that("clean_fao_release can keep unmapped countries and filter years", {
  release <- read_fao_release(write_release_fixture(withr::local_tempdir()))

  all_rows <- clean_fao_release(release, keep_unmapped = TRUE)
  expect_equal(sum(all_rows$iso3c == ""), 1)

  y2001 <- clean_fao_release(release, years = 2001)
  expect_equal(sort(y2001$iso3c), c("CAN", "USA"))
  expect_error(clean_fao_release(release, years = 1999), "1999")
})

test_that("clean_fao_release rejects two UN codes for one ISO3 code", {
  release <- read_fao_release(write_release_fixture(withr::local_tempdir()))
  # The same series and year reported under both of ANT's UN codes
  ant_530 <- release$production[1, ]
  ant_530[["COUNTRY.UN_CODE"]] <- "530"
  ant_532 <- ant_530
  ant_532[["COUNTRY.UN_CODE"]] <- "532"
  release$production <- rbind(release$production, ant_530, ant_532)
  expect_error(clean_fao_release(release), "ANT")
})

test_that("unknown fishing areas are an error", {
  release <- read_fao_release(write_release_fixture(withr::local_tempdir()))
  release$production[1, "AREA.CODE"] <- "99"
  expect_error(clean_fao_release(release), "99")
})

test_that("release data builds the legacy files", {
  out_dir <- withr::local_tempdir()
  landings <- clean_fao_release(read_fao_release(write_release_fixture(withr::local_tempdir())))
  output_global_json(landings, out_dir)
  output_country_json(landings, out_dir)

  global <- jsonlite::fromJSON(file.path(out_dir, "landings.json"))
  expect_equal(global$catch, c(15.5, 6))
  usa <- jsonlite::fromJSON(file.path(out_dir, "landings", "countries", "USA.json"))
  expect_equal(usa$catch, c(5.5, 6))
})

test_that("D1 export drops official zeros but keeps not-significant rows", {
  release <- read_fao_release(write_release_fixture(withr::local_tempdir()))
  cleaned <- clean_fao_release(release)
  d1 <- d1_landings(cleaned)

  expect_equal(names(d1), c("iso3c", "a3_code", "area", "year", "catch", "status"))
  expect_equal(nrow(d1), 4)
  expect_true(any(d1$status == "N" & d1$catch == 0))
  expect_false(any(d1$status == "A" & d1$catch == 0))

  countries <- d1_countries(release, cleaned)
  expect_equal(sort(countries$iso3c), c("CAN", "USA"))
})

test_that("SQL inserts escape quotes and batch rows", {
  df <- data.frame(name = c("Côte d'Ivoire", NA), value = c(1.5, 2))
  sql <- sql_inserts(df, "t", batch_size = 1)
  expect_length(sql, 2)
  expect_match(sql[1], "'Côte d''Ivoire'", fixed = TRUE)
  expect_match(sql[2], "(NULL,2)", fixed = TRUE)

  db <- sql_inserts(data.frame(x = c(0, 1234.5, 97380864.48)), "t")
  expect_match(db, "(0),\n(1234.5),\n(97380864.48)", fixed = TRUE)
})
