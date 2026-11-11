# Open Fisheries: Technical Tasks

Working task list for modernizing the API and website. Intended as the starting brief for Claude Code.

## Next up

Work is moving to a local Claude Code session on the laptop, where R and other tools are installed. Run `git pull` on `main` first. Work through these in order:

1. **Fix the subsidies bug** (section 1, first item). Confirmed: 152 of 155 files in `docs/subsidies/` are byte-for-byte identical; only the three `subsidy_*_totals.json` files differ. Do this on a new branch off `main`.
2. **Modernize the API** (sections 2 to 4), using the FAO Global Production 2026.1.0 release as the launch dataset (see section 3).
3. **Build an MCP server** (section 3b) on top of the new `/v1/` endpoints.

## Done

- [x] Added `MVP.md` (mission and roadmap) and `TASKS.md` (this file).
- [x] Renamed the default branch from `master` to `main` on GitHub. GitHub Pages now publishes `docs/` from `main`.

## Current state

- `api.openfisheries.org` repo: 2,511 generated JSON files in `docs/`, served via GitHub Pages (from `main` / `docs`) at the api.openfisheries.org subdomain. R scripts in `_bin/`. Old FAO CSV exports tracked in `data/`; the newest is `fishstat_export_s_capture2020.csv`.
- `openfisheries.github.io` repo: built Hugo output (Hugo 0.54.0) with no source, served at www.openfisheries.org. Contains a stale copy of the API output. The site does not call the API.
- `ropenfisheries` R package does not call the API.
- Only one Pages custom domain is allowed per repo, so the API must move off GitHub Pages before the website can be served from `docs/` in the merged repo.

## 1. Fix known bugs

- [ ] Subsidies filter bug in `_bin/subsidies.R`: in `output_subsidies_json()`, the loop `for (iso3c in countries)` is followed by `filter(iso3c == iso3c)`, which compares the column to itself, so every per-country file contains all countries' data. All 152 per-country files in `docs/subsidies/` are currently identical. Rename the loop variable (e.g. `for (code in countries)` and `filter(iso3c == code)`), rerun the script from the repo root, and check that each file contains only its own country's rows. Note: `read_csv` may no longer produce an `X1` column in newer readr versions (it is now `...1`), so `select(-X1)` may need updating.
- [ ] Pipeline uses global variables (`out_data`, `country_list`, and others) and hardcoded years. Refactor into functions with explicit inputs and outputs, and parameterize the year range.
- [ ] `build_landings_api_data.R` calls `output_global_json` twice and has the cleanup step commented out. Tidy up.
- [ ] Fix `api.json` and README to advertise https rather than http, if HTTPS is enforced.

## 2. Protect existing users

- [ ] Generate a list of every URL currently served (all 2,511 files) to use as a regression test.
- [ ] Preserve legacy paths and JSON shape exactly, for example `/landings.json`, `/landings/countries/USA.json`, `/landings/species/SKJ.json`, `/landings/countries.json`, `/landings/species.json`, `/subsidies/<ISO3>.json`.
- [ ] Keep `Access-Control-Allow-Origin: *` on all responses.
- [ ] Check whether `http://openfisheries.org/api/...` URLs from the old README still resolve, and keep them working.
- [ ] Known consumer: the rOpenSci `rfisheries` R package wraps this API. Test it against the new API before the DNS cutover, and consider opening an issue or PR there if any URL changes.

## 3. Build the new API

- [ ] Stand up a free-tier host. Leading candidate is Cloudflare Workers with D1 (SQLite) and Hono. Alternatives are Vercel functions with Turso, or static JSON on Cloudflare Pages.
- [ ] Launch dataset: FAO Global Production 2026.1.0, downloadable at https://www.fao.org/fishery/static/Data/GlobalProduction_2026.1.0.zip. Download it, inspect its structure (it is likely a normalized CSV with separate code lists for countries, species, and areas, rather than the old FishStatJ export format), and adapt the R pipeline to read it. Keep the zip out of git, or keep only the extracted CSVs the pipeline needs.
- [ ] Compare the new data's output against the current `docs/landings/` files for overlapping years, to check that the new pipeline reproduces the existing numbers.
- [ ] Load the cleaned FAO landings data into the database from the pipeline.
- [ ] Add versioned endpoints under `/v1/` with filtering by country, species, year range, and inland or marine, plus pagination.
- [ ] Add an OpenAPI spec and docs page.
- [ ] Serve the legacy paths from the same Worker.
- [ ] Test on the workers.dev URL and diff every legacy path against the current files before changing DNS.

## 3b. MCP server

Expose the API to Claude and other AI tools through a Model Context Protocol (MCP) server, built on the `/v1/` endpoints.

- [ ] Decide on hosting: a remote MCP server on the same Cloudflare Worker (an `/mcp` route, no install needed by users) or a small local server package. Remote is preferred.
- [ ] Define tools, for example: look up a country or species code, get landings for a country or species over a year range, get global totals, and get subsidies by country.
- [ ] Return compact, well-labelled results (units, source, FAO release version) so answers can cite the data.
- [ ] Document how to connect it in Claude and other clients, and add it to the website docs.

## 4. DNS cutover

- [ ] Lower the DNS TTL a day beforehand.
- [ ] Repoint the api subdomain. A Worker custom domain needs the zone on Cloudflare, while Cloudflare Pages works with a plain CNAME. Confirm which applies.
- [ ] Keep the rollback plan: point the CNAME back to GitHub Pages.
- [ ] Turn on request analytics to learn who uses the API.

## 5. Merge the repositories

- [ ] Move the old API output out of `docs/` first.
- [ ] In a copy of the website repo, run `git filter-repo --to-subdirectory-filter docs`, then merge it into the API repo with `--allow-unrelated-histories` so both histories are preserved.
- [ ] Remove the custom domain from the old website repo, set www.openfisheries.org on the merged repo's `/docs` folder, and archive the old repo.
- [ ] Target layout: `pipeline/`, `worker/`, `data/`, `docs/`.

## 6. Slim the repo

- [ ] Keep only the latest FAO CSV in `data/`. Older exports remain in git history.
- [ ] Stop committing generated JSON once the new API is live.
- [ ] Add `.DS_Store` to `.gitignore`.

## 7. Automate updates

- [ ] Check whether FAO offers a bulk capture-production download at a stable URL, to replace the manual FishStatJ export. The versioned zip at `https://www.fao.org/fishery/static/Data/GlobalProduction_<version>.zip` looks promising; check whether there is a "latest" URL or a predictable release pattern.
- [ ] If so, add a scheduled GitHub Action that fetches the data, runs the R pipeline, and loads the database.

## 8. Website

- [ ] Decide whether to keep the existing Hugo output as static files or rebuild the site.
- [ ] Add API documentation and examples.

## 9. Later

- [ ] Add DFO Canada data as a second source.
- [ ] Open analytics and algorithms for MEY versus MSY estimation.

## Open questions

- Is HTTPS currently enforced on api.openfisheries.org?
- Which DNS provider hosts openfisheries.org?
- Does anyone outside this project depend on the current URLs?
