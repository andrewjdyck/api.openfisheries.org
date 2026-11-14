source(file.path("..", "..", "_bin", "subsidies_utils.R"))

subsidies_fixture <- function() {
  data.frame(
    `Region Name` = c("Africa", "Africa", "Europe"),
    Country = c("Algeria", "Algeria", "Norway"),
    Class = c("A1", "B1", "A1"),
    Category = c("Beneficial", "Capacity-enhancing", "Beneficial"),
    Type = c("Fisheries mangt.", "Boat constsruct. & renov.", "Fisheries mangt."),
    `Constant 2018 USD` = c(100, 200, 50),
    `Data Type` = c("Reported", "Modeled", "Reported"),
    iso3c = c("DZA", "DZA", "NOR"),
    check.names = FALSE
  )
}

test_that("each country file contains only that country's rows", {
  out_dir <- withr::local_tempdir()
  output_subsidies_json(subsidies_fixture(), out_dir)

  dza <- jsonlite::fromJSON(file.path(out_dir, "DZA.json"))
  nor <- jsonlite::fromJSON(file.path(out_dir, "NOR.json"))

  expect_equal(nrow(dza), 2)
  expect_equal(dza$Subsidies, c(100, 200))
  expect_equal(nrow(nor), 1)
  expect_equal(nor$Subsidies, 50)
  expect_equal(
    names(nor),
    c("Class", "Category", "Type", "Subsidies", "Data Type", "Units")
  )
})

test_that("totals are summed by country, category, and type", {
  out_dir <- withr::local_tempdir()
  output_total_subsidies(subsidies_fixture(), out_dir)

  by_country <- jsonlite::fromJSON(file.path(out_dir, "subsidy_country_totals.json"))
  expect_equal(by_country$Subsidy[by_country$iso3c == "DZA"], 300)
  expect_equal(by_country$Subsidy[by_country$iso3c == "NOR"], 50)

  by_category <- jsonlite::fromJSON(file.path(out_dir, "subsidy_category_totals.json"))
  expect_equal(by_category$Subsidy[by_category$Category == "Beneficial"], 150)
})
