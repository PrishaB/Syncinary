# AGENTS.md

Guidance for coding agents working in the Syncinary repository. This root file
covers repo-wide layout and process; each subproject has its own `AGENTS.md`
with the details that matter there. **The closest `AGENTS.md` to the file you
are editing takes precedence.**

## What this is

Syncinary is a group travel-planning app (Purdue team project — Team 05: Ethan
Bar, Prisha Boreddy, Jack Burky, Shubhi Agarwal). Two parts:

- **`syncinary/`** — the Flutter app (Dart, Firebase Auth + Cloud Firestore).
  Everything users see: auth, groups, itinerary, flight search.
- **`proxy/`** — a small Node/Express service. Its only job today is to proxy
  Google Flights requests to SerpApi so the SerpApi key stays off the client.

`syncinary/lib/pages/amadeus_service.dart` calls the proxy at a hardcoded
`http://localhost:3000`; the proxy must be running locally for flight search to
work.

## Repository layout

| Path | What |
|------|------|
| `syncinary/` | Flutter app — see `syncinary/AGENTS.md` |
| `proxy/` | Express/SerpApi proxy — see `proxy/AGENTS.md` |
| `Doc/` | Course deliverables (`DevProcesses.md`, `Final SDP.md`, Design Document PDF). Not engineering docs — don't edit them to record implementation notes, and don't auto-generate summary files here. |
| `.github/workflows/ci.yml` | CI (see below) |

Which file to read next: editing `.dart` → `syncinary/AGENTS.md`; editing
`proxy/*.js` → `proxy/AGENTS.md`.

## Branching & pull requests

Full policy is in `Doc/DevProcesses.md`. Essentials:

- **`main` is locked** — never commit to it directly. One branch per feature.
- Documented branch convention is `MAINFEATURE_SUBFEATURE` (e.g. `auth_login`).
  Recent issue-driven work also uses `work-issue-<n>-<slug>`.
- A PR needs both before it can merge: (1) review by a teammate who did not
  write the branch, with every review comment addressed; (2) green CI.
- PR title: short summary of the change. Description: the details, with
  `Closes #<id>` at the bottom.

## CI

`.github/workflows/ci.yml` runs two jobs on every push (any branch) and every
PR targeting `main` or `dev`:

- **`flutter`** — `flutter pub get` + `flutter test` in `syncinary/` on
  Flutter 3.47.2 (stable). It does **not** run `flutter analyze`: `lib/main.dart`
  imports the gitignored `lib/firebase_options.dart` (contains API keys, never
  committed), so `flutter analyze` fails outside a machine that has run
  `flutterfire configure`. Run `flutter analyze` yourself before pushing.
- **`proxy`** — `npm install`, `npm run lint` (ESLint, flat config in
  `proxy/eslint.config.cjs`), then `npm test` (`node --test`; currently a
  no-op since `proxy/` has no `*.test.js` files yet — see `proxy/AGENTS.md`).
