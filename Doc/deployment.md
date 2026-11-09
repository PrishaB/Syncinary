# Deployment: Syncinary

## Access

Syncinary is a web app, so there's nothing to install. Open **<https://syncinary.com>** in any modern browser. The [Getting Started tutorial](tutorial.md) is the quick-start guide: it covers signing up, verifying your email, and creating or joining a group.

Syncinary isn't a mobile app, so it isn't published to the Google Play Store or the Apple App Store.

## Deployed version

The live version is **v0.6.0**, the "Map View and Admin Release", published Nov 6, 2026.

**Available in the live deployment:**
- Accounts with email verification.
- Groups, invites and admin roles.
- Travel preferences.
- The shared Schedule Builder, with suggest and approve.
- The trip map.
- Expense tracking with equal splits.
- Flight, hotel and airport search.

**Not in the live deployment:**
- **AI recommendations.** The deployed proxy has no `/recommendations` route. The Schedule Builder's AI Advisor is a placeholder, and the suggestions card on Flight Search shows "Couldn't load suggestions." The recommendation pipeline is on `main` but hasn't been released yet.
- **Custom percentage expense splits.** These are also on `main`, but not released.

## How it is deployed

| Part | Platform |
|------|----------|
| Web app (Flutter release build) | Firebase Hosting, project `syncinary-48881`, at syncinary.com |
| Backend proxy (Node 22 / Express in Docker) | Google Cloud Run, service `syncinary-proxy`, `us-central1`, 0–3 instances |
| Accounts and data | Firebase Authentication and Cloud Firestore |

Publishing a GitHub release deploys automatically through `.github/workflows/firebase-hosting-pull-request.yml`:

1. The proxy and the Flutter app must pass lint, analysis, tests and a dependency audit.
2. The proxy is deployed to Cloud Run as a new revision that receives no traffic yet.
3. Smoke checks run against that revision: `/hotels` with no parameters must return 400, and `/airports?q=IND` must find IND.
4. The revision receives traffic only if both checks pass. Otherwise the previous version keeps running.
5. The web app is built with the proxy's URL compiled in, then published to Firebase Hosting.

API keys (`SERPAPI_KEY`, `GOOGLE_MAPS_API_KEY`) are kept in Google Secret Manager and read only by the proxy. No key is in the source code, the Docker image or the web build.

## Documentation

- [README](../README.md): the live link and links to every document.
- [Tutorial](tutorial.md): getting started.
- [Explanation](explanation.md): architecture and design decisions.
- [Reference](Reference.md): APIs, data model and configuration.
- [`proxy/README.md`](../proxy/README.md): proxy setup and the one-time Cloud Run configuration.
