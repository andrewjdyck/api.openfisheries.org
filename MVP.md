# Open Fisheries MVP

## Goal

A modern, queryable Open Fisheries API that serves the latest FAO capture data, does not break existing users, and can be used directly by AI tools.

## Done means

The new API is live at api.openfisheries.org with the FAO Global Production 2026.1.0 data, and every existing URL still works.

## In scope

1. **New `/v1/` REST API** for FAO landings data, filterable by country, species, year range, and inland or marine, with pagination.
2. **Legacy URLs keep working.** Every existing path (for example `/landings/countries/USA.json` and `/subsidies/USA.json`) returns the same JSON shape, with CORS headers.
3. **MCP server** so Claude and other AI tools can query the data.
4. **Latest data.** FAO Global Production 2026.1.0.
5. **Hosting** on Cloudflare Workers with D1 (SQLite) and Hono, on the free tier.
6. **Minimal docs.** The README lists the `/v1/` endpoints and how to connect the MCP server.

## Out of scope

- A documentation website, OpenAPI spec, or merging the website repo
- Subsidies under `/v1/` (they stay available at the legacy paths)
- Automated data updates
- Slimming the repository
- DFO Canada data
- MEY and MSY analytics

These are listed under "After the MVP" in [TASKS.md](TASKS.md).
