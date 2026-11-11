# Open Fisheries: Technical Tasks

Working task list for modernizing the API and website. Intended as the starting brief for Claude Code.

## Current state

- `api.openfisheries.org` repo: 2,511 generated JSON files in `docs/`, served via GitHub Pages at the api.openfisheries.org subdomain. R scripts in `_bin/`. Old FAO CSV exports tracked in `data/`.
- `openfisheries.github.io` repo: built Hugo output (Hugo 0.54.0) with no source, served at www.openfisheries.org. Contains a stale copy of the API output. The site does not call the API.
- `ropenfisheries` R package does not call the API.
- Only one Pages custom domain is allowed per repo, so the API must move off GitHub Pages before the website can be served from `docs/` in the merged repo.

## 1. Fix known bugs

- [ ] Subsidies filter bug in `_bin/subsidies.R`: `filter(iso3c == iso3c)` compares the column to itself, so every per-country file contains all countries' data. All files in `docs/subsidies/` are currently identical. Rename the loop variable and regenerate.
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
- [ ] Load the cleaned FAO landings data into the database from the pipeline.
- [ ] Add versioned endpoints under `/v1/` with filtering by country, species, year range, and inland or marine, plus pagination.
- [ ] Add an OpenAPI spec and docs page.
- [ ] Serve the legacy paths from the same Worker.
- [ ] Test on the workers.dev URL and diff every legacy path against the current files before changing DNS.

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

- [ ] Check whether FAO offers a bulk capture-production download at a stable URL, to replace the manual FishStatJ export.
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
