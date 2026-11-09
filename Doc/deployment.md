# Deployment: Syncinary

Syncinary is deployed as a web app, so there's nothing to install. Open **<https://syncinary.com>** in any modern browser, then follow the [Getting Started tutorial](tutorial.md) to sign up and create or join a group.

## What is deployed

| Part | Where it runs | Address |
|------|---------------|---------|
| Web app (Flutter, release build) | Firebase Hosting, project `syncinary-48881` | <https://syncinary.com> (also <https://syncinary-48881.web.app>) |
| Backend proxy (Node 22 / Express, Docker) | Google Cloud Run, service `syncinary-proxy`, region `us-central1` | Called by the web app; not used directly |
| Accounts and data | Firebase Authentication and Cloud Firestore | Accessed through the Firebase SDK |

Each GitHub release is a deployed version. For example, **v0.6.0** ("Map View and Admin Release", Nov 6, 2026) is live now. The AI Advisor in the Schedule Builder ships with the next release.

Syncinary is a browser application, not a mobile app, so it isn't published to the Google Play Store or the Apple App Store. Flutter can build mobile versions from the same code, but the supported product is the web app.

## How a release is deployed

Publishing a full (non-prerelease) GitHub release starts the release workflow, `.github/workflows/firebase-hosting-pull-request.yml`. Nothing is deployed by hand.

```mermaid
flowchart LR
    rel[GitHub release published] --> checks[Proxy: lint, tests, audit<br/>Flutter: analyze, tests]
    checks --> run[Deploy proxy to Cloud Run<br/>as a tagged revision with no traffic]
    run --> smoke{Smoke checks<br/>pass?}
    smoke -- no --> stop[Stop: production unchanged]
    smoke -- yes --> promote[Send 100% of traffic<br/>to the new revision]
    promote --> build[Build the web app with<br/>PROXY_URL = Cloud Run URL]
    build --> host[Deploy to Firebase Hosting<br/>live channel]
```

1. **Checks.** The proxy is linted, tested and audited (`npm audit`). The Flutter app is analyzed and tested. A failure stops the release.
2. **Proxy deploy.** Cloud Build builds the proxy's Docker image from source, and Cloud Run deploys it as a new revision that receives no traffic yet. It runs on 0 to 3 instances, so it scales to zero when idle.
3. **Smoke checks** run against that revision. None of them uses a billed API:
    - `/hotels` with no parameters must return 400.
    - `/airports?q=IND` must find the IND airport.
    - `/recommendations` without a login must return 401.
4. **Promote.** Only a revision that passes all checks receives production traffic. A failed check leaves the previous version serving users.
5. **Web deploy.** The Flutter web app is built with the proxy's URL compiled in (`--dart-define=PROXY_URL=...`) and published to Firebase Hosting's live channel.

## Configuration and secrets

No API key is stored in the source code, the Docker image or the web build.

| Secret | Stored in | Used for |
|--------|-----------|----------|
| `SERPAPI_KEY` | Google Secret Manager | Flight, hotel and place search |
| `GOOGLE_MAPS_API_KEY` | Google Secret Manager | Airport name search (Places API) |
| `GEMINI_API_KEY` | Google Secret Manager | AI recommendations |
| `FIREBASE_OPTIONS_DART` | GitHub Actions secret | Firebase client config for the web build |
| `FIREBASE_SERVICE_ACCOUNT_SYNCINARY_48881` | GitHub Actions secret | Lets the workflow deploy to Cloud Run and Hosting |

The proxy runs as its own service account. That account can read only its three secrets and Firestore; it reads Firestore to build recommendations. The release workflow also sets two settings on Cloud Run:

- `FIREBASE_PROJECT_ID`, used to verify users' login tokens.
- `TRUST_PROXY_HOPS=1`, so rate limits see each user's real IP address.

The one-time Google Cloud setup (service accounts, roles and secrets) is in [`proxy/README.md`](../proxy/README.md#production-releases-cloud-run).

## Checking a deployment

After a release:

- [ ] Open <https://syncinary.com>, sign in, and open a group.
- [ ] Search flights and hotels, and an airport by city name (for example, Indianapolis).
- [ ] Open the Schedule Builder and confirm the AI Advisor shows suggestions.
- [ ] Open the trip map and confirm items with locations appear.

To run Syncinary locally for development:

1. Start the proxy as described in [`proxy/README.md`](../proxy/README.md). It runs at `http://localhost:3000`.
2. In `syncinary/`, generate `lib/firebase_options.dart` with `flutterfire configure --project=syncinary-48881`. The file is gitignored.
3. Run `flutter run -d chrome`.
