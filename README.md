# Open Fisheries

Open data and open analytics for global fisheries economics.

## Mission

Open Fisheries aims to be a source for global fisheries economics. The goal is to make fisheries economics open: to do open analytics on maximum economic yield (MEY) versus maximum sustainable yield (MSY), and to democratize the algorithms used to estimate both.

## Background

Open Fisheries began in 2014 as an API for the UN Food and Agriculture Organization (FAO) global capture fisheries statistics. Annual landings are available by country and by species, along with global totals. The data is exported from FishStatJ, cleaned with R scripts, and published as static JSON files. A supplementary dataset on global fisheries subsidies is also published.

The API is being modernized into a queryable REST API. See [MVP.md](MVP.md) for the scope of that work and [TASKS.md](TASKS.md) for the plan.

## Using the API

The API is experimental. Feedback on what could work better is welcome (see Contact below).

The API supports GET requests and returns JSON, which can be read in nearly every programming language, including R and Python. Global landings by year:

    http://api.openfisheries.org/landings.json

Lists of all countries and species that can be used in API calls:

    http://api.openfisheries.org/landings/countries.json
    http://api.openfisheries.org/landings/species.json

Landings by country, using the ISO 3166 alpha-3 country code (here, the United States):

    http://api.openfisheries.org/landings/countries/USA.json

Landings by species, using the three-letter ASFIS species code (here, skipjack tuna):

    http://api.openfisheries.org/landings/species/SKJ.json

Fisheries subsidies by country, using the ISO 3166 alpha-3 country code:

    http://api.openfisheries.org/subsidies/USA.json

Older documentation used URLs of the form `http://openfisheries.org/api/landings.json`.

## Data sources

### FAO global capture production

Landings data is sourced from the UN Food and Agriculture Organization. The [FishStatJ](http://www.fao.org/fishery/statistics/software/fishstatj/en) capture production dataset is exported to CSV in `data/` with the following settings:

- Country column exported as ISO 3-letter code
- Species exported as ASFIS code
- Symbols exported as a separate column (the "S" column in the CSV)

The symbols in the FAO data mean:

- "0": Greater than 0, but less than 1 tonne
- "-": Equal to zero
- "F": FAO estimate

### Global fisheries subsidies

Subsidies data is from the global fisheries subsidies dataset of Sumaila et al., in constant 2018 USD.

## Building the data

The R scripts in `_bin/` build the JSON files in `docs/`, which GitHub Pages serves. Run them from the repository root:

    Rscript _bin/build_landings_api_data.R
    Rscript _bin/subsidies.R

Run the tests with:

    Rscript -e 'testthat::test_dir("tests/testthat")'

## Contact

twitter: [@openfisheries](http://twitter.com/openfisheries)

email: openfisheries [at] gmail [dot] com
