# Open Fisheries: Tasks

Plan and task list for the MVP described in [MVP.md](MVP.md).

## Plan

1. **Fix the existing pipeline**: bugs in the R scripts that build today's API files. *(Mostly done.)*
2. **Prepare the 2026 data**: read the FAO Global Production 2026.1.0 release with the R pipeline.
3. **Build the `/v1/` API** on Cloudflare Workers, D1, and Hono, and deploy it to a workers.dev test URL.
4. **Serve the legacy URLs** from the same Worker, and check every one against the current files.
5. **Add the MCP server** to the same Worker.
6. **Cut over DNS** so api.openfisheries.org points at the Worker, with a rollback plan.

## Current state

- `api.openfisheries.org` repo: 2,510 generated JSON files (plus `global_fao_disagg.csv` and `CNAME`) in `docs/`, served via GitHub Pages (from `main` / `docs`) at the api.openfisheries.org subdomain. R scripts in `_bin/`, tests in `tests/testthat/`. Old FAO CSV exports tracked in `data/`; the newest is `fishstat_export_s_capture2020.csv` (1950 to 2018).
- `openfisheries.github.io` repo: built Hugo output (Hugo 0.54.0) with no source, served at www.openfisheries.org. Contains a stale copy of the API output. The site does not call the API.
- `ropenfisheries` R package does not call the API.
- Known consumer: the rOpenSci `rfisheries` R package wraps this API.

## 1. Fix the existing pipeline

- [x] Subsidies filter bug: the loop variable `iso3c` masked the column, so `filter(iso3c == iso3c)` kept every row and all 152 per-country files in `docs/subsidies/` were identical. Fixed and regenerated.
- [x] Refactor the pipeline: removed the global variables, the year range is detected from the export (and can be overridden), and the output folder is a parameter that defaults to `docs/`. The output is byte for byte identical to the old pipeline's.
- [x] Remove the duplicate `output_global_json` call, and make cleanup an opt-in that only removes the per-country and per-species folders.
- [x] Add `testthat` unit tests. Run with `Rscript -e 'testthat::test_dir("tests/testthat")'`.
- [x] HTTPS: made the `api` DNS record in Cloudflare "DNS only" (grey cloud) so GitHub could issue a certificate, then turned on "Enforce HTTPS" in GitHub Pages. `API_URL` in `_bin/build_landings_api_data.R`, `docs/api.json`, and the README URLs now use https. Plain http requests are redirected to https.
- [x] Add the missing `docs/landings/species/AUX.json` (giant catfish) and `CON.json` (stromboid conchs). The pipeline generated them, but they were never committed, probably because AUX and CON are reserved file names on Windows. Avoid regenerating or committing `docs/` from Windows, or these two files will go missing again.
- [x] Rerun `Rscript _bin/subsidies.R` with the real `countrycode` package (versions 1.6.1 and 1.9.0, from conda-forge) and confirm there is no diff in `docs/subsidies/`.

## 2. Prepare the 2026 data

- [ ] Download https://www.fao.org/fishery/static/Data/GlobalProduction_2026.1.0.zip and inspect it.
  - [ ] Identify the main data file and its code lists (countries, species, fishing areas, production source, units).
  - [ ] Check how countries are coded. If it uses UN M49 numeric codes rather than ISO alpha-3, use the country code list to map them.
  - [ ] Note how the status symbols (the old "S" column) are represented.
- [ ] Add a reader to `_bin/fao_data_utils.r` that turns the new files into the same long format `clean_fao_data()` returns (iso3c, a3_code, inland, location_id, year, catch, S), plus unit tests on a small fixture.
- [ ] Compare against the current `docs/landings/` files for overlapping years (1950 to 2018). Explain any differences, since FAO revises past figures.
- [ ] Write the cleaned data in a form D1 can load (CSV, or SQL insert files).
- [ ] Keep the zip out of git. Add it to `.gitignore`, and commit only the extracted files the pipeline needs, if they are small enough.

## 3. Build the `/v1/` API

- [ ] Set up Cloudflare.
  - [ ] Create a Cloudflare account and install `wrangler`.
  - [ ] Create a `worker/` folder with a Hono app in TypeScript.
- [ ] Database.
  - [ ] Design the D1 schema: a `landings` table (country, species, area, inland, year, catch, symbol), plus `countries` and `species` lookup tables, with indexes on country, species, and year.
  - [ ] Write a load script that takes the pipeline output and loads it into D1 (local first, then remote).
- [ ] Endpoints.
  - [ ] `GET /v1/landings` with filters `country`, `species`, `year_from`, `year_to`, `inland`, and pagination (`limit`, `offset` or a cursor).
  - [ ] Totals by year, optionally grouped by country or species, so callers do not have to sum rows themselves.
  - [ ] `GET /v1/countries` and `GET /v1/species` for code lookups.
  - [ ] Include the data source and FAO release version in responses.
  - [ ] Send `Access-Control-Allow-Origin: *` on every response.
- [ ] Tests (Vitest) for filters, pagination, and error cases (unknown codes, bad years).
- [ ] Deploy to the workers.dev URL.
- [ ] Document the `/v1/` endpoints in the README.

## 4. Serve the legacy URLs

- [ ] Generate a list of every URL currently served (the 2,510 JSON files and the CSV in `docs/`) to use as a regression test. `AUX.json` and `CON.json` are new, so the live site currently returns 404 for them.
- [ ] Decide how to serve them. The recommended option is to keep generating the legacy JSON with the R pipeline and serve it as Workers static assets; the alternative is to rebuild each response from D1.
- [ ] Decide whether legacy URLs serve the 2026 data or stay frozen on the 2018 data (see Open questions).
- [ ] Serve every legacy path from the Worker, including `/api.json` and `/subsidies/*`, with the same JSON shape and CORS headers.
- [ ] On the workers.dev URL, request every legacy path and diff it against the current files.
- [ ] Check whether the old `http://openfisheries.org/api/...` URLs still resolve, and keep them working if they do.
- [ ] Test the rOpenSci `rfisheries` package against the workers.dev URL.

## 5. Add the MCP server

- [ ] Add an `/mcp` route to the same Worker (a remote MCP server, so users do not have to install anything).
- [ ] Tools:
  - [ ] Look up country and species codes by name.
  - [ ] Get landings for a country or species over a year range.
  - [ ] Get global totals by year.
- [ ] Return compact, labelled results (units, source, FAO release version) so answers can cite the data.
- [ ] Test with the MCP Inspector and by adding it to Claude as a custom connector.
- [ ] Add "How to connect" instructions to the README.

## 6. Cut over DNS

- [x] Find out which DNS provider hosts openfisheries.org: Cloudflare (it is registered with Cloudflare Registrar). So the Worker can take api.openfisheries.org as a custom domain, and Cloudflare issues its HTTPS certificate.
- [ ] Lower the DNS TTL a day beforehand.
- [ ] Point the api subdomain at the Worker by adding api.openfisheries.org as a Worker custom domain. This replaces the current `api` CNAME to GitHub Pages.
- [ ] Check the legacy URL list, `/v1/`, and `/mcp` on api.openfisheries.org.
- [ ] Rollback plan: remove the Worker custom domain and restore the `api` CNAME to `andrewjdyck.github.io` as "DNS only" (grey cloud). GitHub Pages keeps serving `docs/` from `main` in the meantime.
- [ ] Turn on request analytics to learn who uses the API.
- [ ] If any URL changed, open an issue or PR on `rfisheries`.

## After the MVP

- API documentation website and OpenAPI spec.
- Merge the website repo into this one.
  - Move the old API output out of `docs/`.
  - In a copy of the website repo, run `git filter-repo --to-subdirectory-filter docs`, then merge it in with `--allow-unrelated-histories`.
  - Set www.openfisheries.org on the merged repo's `/docs` folder and archive the old repo.
  - Target layout: `pipeline/`, `worker/`, `data/`, `docs/`.
  - Decide whether to keep the existing Hugo output or rebuild the site.
- Slim the repo: keep only the latest FAO data in `data/`, stop committing generated JSON, add `.DS_Store` to `.gitignore`.
- Automate updates: check for a stable "latest" FAO download URL, then add a scheduled GitHub Action that fetches the data, runs the pipeline, and loads D1.
- Subsidies under `/v1/` and in the MCP server.
- DFO Canada data as a second source.
- Open analytics and algorithms for MEY versus MSY estimation.

## Open questions

- Should the legacy URLs serve the 2026 data in the old shape, or stay frozen on the 2018 data?
- Does anyone outside this project depend on the current URLs?
