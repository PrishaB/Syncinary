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

`.github/workflows/ci.yml` runs on every push (any branch), every PR (any
base) and manual `workflow_dispatch`. Jobs:

- **`flutter`** — in `syncinary/` on Flutter 3.47.2: writes a placeholder
  `lib/firebase_options.dart` (the real one is gitignored), then `flutter pub
  get`, `flutter analyze` (any issue, info included, fails), and `flutter test
  --coverage`. `coverage/lcov.info` is uploaded as the `flutter-coverage`
  artifact (no threshold).
- **`proxy`** — `npm ci`, `npm run lint`, `npm test`, and `npm audit --omit=dev
  --audit-level=high` (see `proxy/AGENTS.md`).
- **`security`** (`Security - gitleaks`) — gitleaks CLI over the commits new in
  the push or PR. A manual dispatch scans the full history. Known finding:
  the old SerpApi key (#20), allowlisted by fingerprint in `.gitleaksignore`.
  On a finding, remove the secret and **rotate it**; don't allowlist it.
- **`osv`** (`Security - OSV-Scanner`) — checks `syncinary/pubspec.lock` and
  `proxy/package-lock.json` (dev dependencies included) against OSV.dev and
  fails on any known vulnerability. Fix by upgrading the package.
- **`codeql`** (`Security - CodeQL`) — CodeQL default security queries for the
  proxy's JavaScript and for the workflow files (`actions`); Dart isn't
  supported. Fails on any finding; results also appear in the Security tab.

`security` is never cancelled by newer pushes; the other jobs are, except on
`main`.

Dependabot (`.github/dependabot.yml`) opens weekly grouped updates for npm,
pub and GitHub Actions.

Name new tests with their `Doc/Verification_Test_Inventory.md` ID as a prefix,
e.g. `'[501-6] joinByCode trims the code'`.
