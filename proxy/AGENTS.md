# AGENTS.md — flight proxy

A ~30-line Express service. It exists so the SerpApi key isn't shipped inside
the Flutter app. One route: `GET /flights` → SerpApi Google Flights, returning
the `best_flights` / `other_flights` array as JSON. Run commands from this
directory (`proxy/`).

## Setup / run

```bash
npm install          # rarely needed — see below
node server.js       # listens on http://localhost:3000
```

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

- **Known issue:** `server.js` contains a hardcoded live `SERPAPI_KEY`. Don't
  copy that pattern and don't add more secrets to source — read them from
  `process.env` (e.g. `node --env-file=.env server.js`, Node 20.6+). Moving the
  existing key to an env var and rotating it is its own task.
- Never forward the SerpApi key to the client, and don't log full upstream
  responses that may carry it.
