# AGENTS.md — flight proxy

A ~30-line Express service. It exists so the SerpApi key isn't shipped inside
the Flutter app. One route: `GET /flights` → SerpApi Google Flights, returning
the `best_flights` / `other_flights` array as JSON. Run commands from this
directory (`proxy/`).

## Setup / run

```bash
npm install                    # rarely needed — see below
cp .env.example .env           # fill in SERPAPI_KEY, once
node --env-file=.env server.js # listens on http://localhost:3000
```

`server.js` reads `SERPAPI_KEY` from the environment and exits immediately if
it's unset — get a key at https://serpapi.com. Node 20.6+ can load `.env`
itself via `--env-file`; on older Node 18, export the var another way
(`export SERPAPI_KEY=...` or a tool like `dotenv-cli`). `.env` is gitignored;
never commit it.

Node 18+ (CommonJS, `require`). Dependencies: `express`, `cors`, and
`node-fetch@2` — v2 is deliberate, it's the last CommonJS release of the
package.

`node_modules/` is **committed** (~650 files) on purpose: there's no build step
and CI doesn't install here. Adding a dependency means committing it too, so
add one only if you genuinely need it.

## Test

There is no test suite and no `test` script yet. If you add logic worth
testing, use Node's built-in runner: files named `*.test.js` beside the module,
`node --test` to run them, and add `"scripts": { "test": "node --test" }` to
`package.json` so CI can pick it up later.

## Conventions

- Keep it CommonJS and dependency-light.
- The Flutter client calls
  `GET /flights?origin=&destination=&departureDate=&adults=` and expects a JSON
  array back. Don't change that contract without updating
  `syncinary/lib/pages/amadeus_service.dart` in the same change.

## Security

- `SERPAPI_KEY` is read from `process.env` (see Setup / run above) — never
  hardcode a key in source again. The key that used to be hardcoded here is
  still live in this repo's git history (removing it from `server.js` doesn't
  erase old commits) — **rotate it in the SerpApi dashboard** and use the new
  value locally / in deployment secrets.
- Never forward the SerpApi key to the client, and don't log full upstream
  responses that may carry it.
