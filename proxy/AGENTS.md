# AGENTS.md — flight proxy

A ~30-line Express service. It exists so the SerpApi key isn't shipped inside
the Flutter app. `GET /flights` → SerpApi Google Flights, returning the
`best_flights` / `other_flights` array as JSON; `POST /recommendations` → the
Gemini recommendation pipeline (see `README.md`). Run commands from this
directory (`proxy/`).

## Setup / run

```bash
npm ci                         # required — see below
cp .env.example .env           # fill in SERPAPI_KEY, once
node --env-file=.env server.js # listens on http://localhost:3000
```

`server.js` reads `SERPAPI_KEY` from the environment and exits immediately if
it's unset — get a key at https://serpapi.com. Node loads `.env` itself via
`--env-file`. `.env` is gitignored; never commit it.

Node 22+ (CommonJS, `require`) — `firebase-admin@14` requires it, and CI runs
Node 22. Dependencies: `express`, `cors`, `express-rate-limit`, `firebase-admin`
and `node-fetch@2` — v2 is deliberate, it's the last CommonJS release of the
package.
`firebase-admin` is used only through its modular entry points
(`firebase-admin/app`, `/auth`, `/firestore`; 14.x removed the legacy
`admin.*` namespace). It is only initialized lazily by `/recommendations`
(needs `GOOGLE_APPLICATION_CREDENTIALS`, see `.env.example`); `/flights` and
the tests never touch it.

Run `npm ci` before starting the server. Older runtime dependencies (`express`, `cors`,
`node-fetch`) are still vendored in `node_modules/` from before, but newer ones
(`firebase-admin`, `express-rate-limit`) are **not** committed, so `node server.js`
fails with `Cannot find module` until you install. Don't commit `node_modules`
changes: `package.json` + `package-lock.json` pin exact versions, and CI
(`.github/workflows/ci.yml`) and the `Dockerfile` both run `npm ci` themselves.
Dependabot npm PRs only need `package*.json`.

## Lint & test

CI runs `npm run lint` (ESLint 9, flat config in `eslint.config.cjs`),
`npm test` (`node --test`, e.g. `llmDataFilter.test.js`) and `npm audit
--omit=dev --audit-level=high` on every push/PR. The `osv` job also fails on
any known vulnerability in `package-lock.json`, dev dependencies included, and
`codeql` scans the JavaScript here. Add tests as `*.test.js`
beside the module; `node --test` picks them up automatically.

`recommendationVariance.test.js` (FR-104 / #47) has a live sub-test that calls
the real Gemini API — it's skipped unless **both** `GEMINI_API_KEY` and
`RUN_GEMINI_LIVE_TESTS=1` are set, so `npm test` never makes a billed network
call by accident, and CI (which has neither) always skips it. See
`README.md` for the command to run it deliberately.

## Conventions

- Keep runtime code CommonJS and dependency-light.
- The Flutter client calls
  `GET /flights?origin=&destination=&departureDate=&adults=` and expects a JSON
  array back. Don't change that contract without updating
  `syncinary/lib/pages/amadeus_service.dart` in the same change.

## Security

- `SERPAPI_KEY` is read from `process.env` (see Setup / run above) — never
  hardcode a key in source again. The key that used to be hardcoded here is
  still live in this repo's git history (removing it from `server.js` doesn't
  erase old commits) — **rotate it in the SerpApi dashboard** and use the new
  value locally / in deployment secrets (#20). CI's gitleaks job detects
  SerpApi keys with a custom `serpapi-key` rule and allowlists only that old
  commit's finding in `.gitleaksignore`.
- Never forward the SerpApi key to the client, and don't log full upstream
  responses that may carry it.
- `POST /recommendations` must verify the Firebase ID token before any
  Firestore or Gemini work and take the uid only from the verified token. Never
  forward upstream error text, `raw`, or tokens to the client or logs.
- Keep `/recommendations` rate-limited with `express-rate-limit` middleware in
  the route chain (per-IP first, per-uid after auth): each call spends Gemini
  quota, and CodeQL's `js/missing-rate-limiting` fails CI on an authorized
  route without it.
