# Open Fisheries: Tasks

Plan and task list for the MVP described in [MVP.md](MVP.md).

## Plan

1. **Fix the existing pipeline**: bugs in the R scripts that build today's API files. *(Done.)*
2. **Prepare the 2026 data**: read the FAO Global Production 2026.1.0 release with the R pipeline. *(Done.)*
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

- [x] Download and inspect the release. `Rscript _bin/download_fao_data.R 2026.1.0` saves it to `data/fao/` (6.4 MB zip, ignored by git).
  - [x] Main data file: `Global_production_quantity.csv`, one row per country, species, fishing area, production source, measure, and year (1950 to 2024). Capture in tonnes is `PRODUCTION_SOURCE_DET.CODE == "CAPTURE"` and `MEASURE == "Q_tlw"`. Code lists: `CL_FI_COUNTRY_GROUPS.csv`, `CL_FI_SPECIES_GROUPS.csv`, `CL_FI_WATERAREA_GROUPS.csv` (which also flags inland or marine), `CL_FI_PRODUCTION_SOURCE_DET.csv`, `CL_FI_SYMBOL_SDMX.csv`, `FSJ_UNIT.csv`.
  - [x] Countries are UN M49 numeric codes, mapped to ISO3 with the country code list. Three entities have no ISO3 code (former Ethiopia PDR, former Sudan, "Other nei") and are dropped, as before. The code list gives the former Netherlands Antilles (`ANT`) two UN codes; only one is used in the data.
  - [x] Status symbols are now SDMX codes (A official, I imputed, N not significant (under 0.5 t), E estimated, and others) rather than the old blank, F, -, and 0 symbols. They are kept as they are.
- [x] Add a reader: `read_fao_release()` and `clean_fao_release()` in `_bin/fao_data_utils.r` produce the same long format as `clean_fao_data()`, plus a `un_code` column. `build_landings_api_data.R` accepts either a release zip or an old CSV export. Unit tests are in `tests/testthat/test-fao-release.R`. The old CSV still builds the current `docs/` byte for byte.
- [x] Compare against the current `docs/landings/` files for 1950 to 2018, using `_bin/compare_landings.R`. Global totals differ by 0.01% (at most 0.14% in any year). The country and species differences are FAO revisions (USSR reporting for 1988 to 1991, merged sardine and anchovy species, new territories). See `reports/fao_2026.1.0_vs_current_api.md`.
- [x] Write D1 load files: `Rscript _bin/export_d1_data.R` writes CSVs and SQL to `data/d1/` (ignored by git): a schema, lookup tables (245 countries, 3,768 species, 29 areas), 616,490 landings rows split into 7 files of at most 100,000 rows, and an index file. Official zeros are dropped; not-significant rows (status N) are kept. Checked by loading into SQLite: no orphan codes, and yearly totals match the 2026 legacy build.
- [x] Keep the zip out of git: `data/fao/*.zip` and `data/d1/` are in `.gitignore`. The extracted data file is 56 MB, too big to commit comfortably, so the pipeline reads straight from the zip.
- [ ] Decide whether the legacy `countries.json` and `species.json` code lists should be regenerated from the 2026 code lists (259 countries with ISO3 codes, 13,772 species) in their current shape. They are still copied from `data/`. Part of the step 4 decision on legacy URLs.

## 3. Build the `/v1/` API

- [ ] Set up Cloudflare.
  - [ ] Create a Cloudflare account and install `wrangler`.
  - [ ] Create a `worker/` folder with a Hono app in TypeScript.
- [ ] Database.
  - [ ] Review the draft D1 schema in `_bin/d1_utils.R` (`d1_schema_sql()`): `landings` (iso3c, a3_code, area, year, catch, status; primary key on the first four), `countries`, `species`, `areas` (with the inland flag), and `metadata` (source, release, unit). Indexes on (a3_code, year) and year.
  - [ ] Load `data/d1/sql/*.sql` into D1 with `wrangler d1 execute --file`, local first, then remote. D1's free plan limits rows written per day (100,000 at the time of writing, and index entries may count too), so the remote load takes about a week on the free plan, or one go on the Workers paid plan. Check Cloudflare's current limits first.
- [ ] Endpoints.
  - [ ] `GET /v1/landings` with filters `country`, `species`, `year_from`, `year_to`, `inland`, and pagination (`limit`, `offset` or a cursor).
  - [ ] Totals by year, optionally grouped by country or species, so callers do not have to sum rows themselves.
  - [ ] `GET /v1/countries` and `GET /v1/species` for code lookups.
  - [ ] Include the data source and FAO release version in responses. FAO licenses the data under CC BY 4.0, so this attribution is required.
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
