# Open Fisheries

Open data and open analytics for global fisheries economics.

## Mission

Open Fisheries aims to be a source for global fisheries economics. The goal is to make fisheries economics open: to do open analytics on maximum economic yield (MEY) versus maximum sustainable yield (MSY), and to democratize the algorithms used to estimate both.

## Background

Open Fisheries began in 2014 as an API for the UN Food and Agriculture Organization (FAO) global capture fisheries statistics. Annual landings are available by country and by species, along with global totals. The data is exported from FishStatJ, cleaned with R scripts, and published as static JSON files. A supplementary dataset on global fisheries subsidies is also published.

The current setup works, but it is not a true REST API. It is also labour-intensive to update, and the code and data are split across two repositories.

## Plan

### Phase 1: Modernize the API and open more data

- Modernize the catch API as a proper, queryable REST API that is free to host and easy to update.
- Keep existing URLs working so current users are not broken.
- Add Department of Fisheries and Oceans Canada (DFO) data as a second open data source.
- Optional: research funding to cover compute costs and build contacts in the fisheries community.

### Phase 2: Analysis and reporting

- Explore operating Open Fisheries as a consultancy.
- Report on the individual transferable quota (ITQ) marketplace.

### Phase 3: Exploratory

- Investigate Open Fisheries as a social enterprise and involvement in the ITQ marketplace.

## Repository layout (planned)

The project is being consolidated into a single repository:

- `pipeline/`: R scripts that clean and prepare the data
- `worker/`: the API
- `data/`: source data
- `docs/`: the website, served with GitHub Pages

## Data sources

- FAO Global Capture Production, exported from FishStatJ. Country is exported as an ISO 3166 alpha-3 code, and species as an ASFIS code.
- Global fisheries subsidies dataset (Sumaila et al.).
- DFO Canada data (planned).

## Contact

openfisheries [at] gmail [dot] com
