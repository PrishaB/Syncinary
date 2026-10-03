# Syncinary proxy

Small Express backend. `server.js` proxies flight search to SerpApi.

## Production releases (Cloud Run)

The release workflow deploys `syncinary-proxy` to Cloud Run in
`syncinary-48881`, region `us-central1`, then builds Flutter with the service's
HTTPS URL (`--dart-define=PROXY_URL=...`) and deploys Firebase Hosting.
Only published, non-prerelease GitHub releases deploy. The release tag must
include the workflow and these deployment files. Local Flutter builds still
default to `http://localhost:3000`.

### One-time setup

Enable billing for the Firebase/Google Cloud project (Firebase Blaze plan).
Run the following in **Google Cloud Shell (Bash)** as a project administrator.
The deployer is the service account whose JSON is already saved in the GitHub
secret `FIREBASE_SERVICE_ACCOUNT_SYNCINARY_48881`. Confirm its email in IAM
and replace the example `DEPLOYER` value if necessary.

```bash
PROJECT=syncinary-48881
DEPLOYER=github-action-1200702692@syncinary-48881.iam.gserviceaccount.com
RUNTIME=syncinary-proxy-runtime@$PROJECT.iam.gserviceaccount.com
BUILDER=syncinary-proxy-build@$PROJECT.iam.gserviceaccount.com

gcloud services enable run.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com secretmanager.googleapis.com \
  --project="$PROJECT"

gcloud iam service-accounts create syncinary-proxy-runtime --project="$PROJECT"
gcloud iam service-accounts create syncinary-proxy-build --project="$PROJECT"

for ROLE in roles/run.sourceDeveloper roles/serviceusage.serviceUsageConsumer roles/run.admin; do
  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:$DEPLOYER" --role="$ROLE"
done

for ACCOUNT in "$RUNTIME" "$BUILDER"; do
  gcloud iam service-accounts add-iam-policy-binding "$ACCOUNT" \
    --project="$PROJECT" --member="serviceAccount:$DEPLOYER" \
    --role=roles/iam.serviceAccountUser
done

gcloud projects add-iam-policy-binding "$PROJECT" \
  --member="serviceAccount:$BUILDER" --role=roles/run.builder
```

In **Google Cloud Console → Secret Manager**, create a secret named
`SERPAPI_KEY` in this project and paste the current SerpApi key as its value.
Then grant only the runtime account access to that secret:

```bash
gcloud secrets add-iam-policy-binding SERPAPI_KEY --project="$PROJECT" \
  --member="serviceAccount:$RUNTIME" --role=roles/secretmanager.secretAccessor
```

Airport name/city search also requires **Places API (New)** enabled in the
Google Cloud project that owns the Maps key. Create a Secret Manager secret
named `GOOGLE_MAPS_API_KEY` in `syncinary-48881` containing that key, then run:

```bash
gcloud services enable places.googleapis.com --project="$PROJECT"
gcloud secrets add-iam-policy-binding GOOGLE_MAPS_API_KEY --project="$PROJECT" \
  --member="serviceAccount:$RUNTIME" --role=roles/secretmanager.secretAccessor
```

Use a server-side key restricted to Places API (New); browser HTTP-referrer
restrictions do not work for these server requests. For local development,
set `GOOGLE_MAPS_API_KEY` in `proxy/.env` and start the proxy with
`node --env-file=.env server.js`. Cloud Run reads Secret Manager, not `.env`.
See Google's [Places setup guide](https://developers.google.com/maps/documentation/places/web-service/get-api-key).

The workflow injects the latest secret version into the running container.
After rotating it, deploy a new release to replace running instances.
Keep the existing `FIREBASE_OPTIONS_DART` GitHub secret configured for Flutter.
No SerpApi key belongs in GitHub source, the Docker image, or the Flutter build.
The upload and Docker contexts allow only the files needed by `server.js`;
extend both allowlists and the Dockerfile if new runtime modules are added.

These permissions follow Google's [source deployment](https://docs.cloud.google.com/run/docs/deploying-source-code),
[build service account](https://docs.cloud.google.com/run/docs/configuring/services/build-service-account),
and [runtime secret](https://docs.cloud.google.com/run/docs/configuring/services/secrets)
documentation. `roles/run.admin` additionally allows the deployer to make the
service publicly invokable for browser requests.

### Verification and behavior

The workflow runs proxy lint, tests, and a dependency audit plus Flutter
analysis and tests before deployment. After deploying Cloud Run it requests
`/hotels` without parameters and expects HTTP 400; this checks reachability
without making a billed SerpApi call. It then builds and publishes the web app.
It also checks `/airports?q=IND` to verify the packaged airport router and
catalog without calling Google. This does not verify the Maps key: check a
city such as Indianapolis in the deployed app to exercise Google Places.
Check flights and hotels in the deployed app after publishing a release.

Cloud Run and Hosting updates are sequential, not atomic: if the web build or
Hosting deployment fails, the new proxy revision remains live. Keep proxy
routes compatible with the previous frontend release.

The current proxy has public, unauthenticated search routes. Anyone who knows
the URL can consume the SerpApi quota; the three-instance limit is not a
request quota. Authentication and rate limiting are separate backend work.
The `/recommendations` route is not implemented yet; deploying does not add it.

## `llmDataFilter.js`

Filters and assembles the payload sent to the LLM recommendation agent
(FR-104 / SYS 109). Given a requesting user + group id and a raw data bundle
(user records, group records, previous searches, travel results), it:

- Enforces that the requester is a member of the target group.
- Returns only allowlisted fields — preferences, budget, dates, previous
  searches, and travel results — never credentials, tokens, payment info, or
  data belonging to other users/groups.

It's a pure function: no Firebase, no network. `requestingUserId` is assumed
to already be verified (e.g. from a checked session token) by the caller — this
module checks group *membership*, not identity (see #86). Wiring it to real
Firebase reads and an authenticated route is a follow-up issue.

Every allowlisted field also has a declared type (string, number, or array of
strings) — a value of the wrong shape (a nested object, a number where a
string is expected, a non-string array item) is dropped rather than forwarded,
and strings/arrays are truncated to `MAX_STRING_LENGTH`/`MAX_ARRAY_ITEMS`. If
the sanitized payload is still over `MAX_PAYLOAD_BYTES` overall (e.g. a large
group), `buildRecommendationPayload` returns `{allowed: false, reason:
'payload_too_large'}` instead of sending it. This bounds how much adversarial
or oversized text a request can smuggle to Gemini (#91) — it does not attempt
to detect or strip instruction-like *content*, which is `recommendationPrompt.js`'s
untrusted-data framing and `parseRecommendationResponse()`'s job.

## `geminiClient.js`

Backend client for the Gemini Generative Language API (FR-104 / SYS 109).
Talks to Gemini only — it doesn't decide what data is safe to send (that's
`llmDataFilter.js`) or build prompt text (a later issue).

```js
const { createGeminiClient } = require('./geminiClient');
const client = createGeminiClient(); // reads GEMINI_API_KEY etc. from process.env
const result = await client.generateRecommendation({ payload, prompt: 'Suggest a trip.' });
if (result.ok) {
  console.log(result.text);
} else {
  console.error(result.error, result.message); // e.g. 'rate_limited', 'timeout'
}
```

Like `llmDataFilter.js`, every call returns a plain `{ok, ...}` result instead
of throwing. Error codes: `missing_api_key`, `invalid_input`, `timeout`,
`rate_limited`, `upstream_error`, `network_error`, `invalid_response`. The API
key is sent as an `x-goog-api-key` header (never in the URL) and is redacted
out of every error message — it's never logged or thrown. See
[`GEMINI_METRICS.md`](./GEMINI_METRICS.md) for the `latencyMs`/`usage` fields
every result carries.

## `recommendationPrompt.js`

Builds the instruction text that goes ahead of the JSON payload in a Gemini
request (FR-104 / SYS 109). Sits between the other two modules: it turns the
payload from `llmDataFilter.js` into the `prompt` string `geminiClient.js`
expects, and asks Gemini to return recommendations in a fixed JSON shape the
UI can render as destination / activity / itinerary cards.

```js
const { buildRecommendationPayload } = require('./llmDataFilter');
const { buildRecommendationPrompt } = require('./recommendationPrompt');
const { createGeminiClient } = require('./geminiClient');

const filterResult = buildRecommendationPayload(requestContext, rawData);
if (!filterResult.allowed) throw new Error(filterResult.reason);

const promptResult = buildRecommendationPrompt(filterResult.payload);
if (!promptResult.ok) throw new Error(promptResult.error); // 'invalid_input' | 'empty_payload'

const client = createGeminiClient();
const result = await client.generateRecommendation({ payload: filterResult.payload, prompt: promptResult.prompt });
```

Like the other two modules, it never throws — it returns `{ok: false, error, message}`
for a malformed or all-empty payload. It also never writes a payload *value*
into the prompt text: the prompt only names which top-level sections (budget,
dates, preferences, etc.) are present or absent, and every user-controlled
string reaches Gemini solely inside the appended JSON.

`RECOMMENDATION_OUTPUT_SCHEMA` is the single source of truth for the response
shape, and `parseRecommendationResponse(text)` validates a Gemini reply's
`text` against it (#91 / #81):

```js
const geminiResult = await client.generateRecommendation({ payload: filterResult.payload, prompt: promptResult.prompt });
if (!geminiResult.ok) throw new Error(geminiResult.error);

const parsed = parseRecommendationResponse(geminiResult.text);
if (!parsed.ok) throw new Error(parsed.error); // 'invalid_json' | 'schema_mismatch'
// parsed.data is now safe to render — never show geminiResult.text directly.
```

A reply that isn't valid JSON, is missing a required key, has the wrong type
for a field, or uses a value outside a fixed enum (e.g. `timeOfDay`) comes back
as `{ok: false, error: 'schema_mismatch' | 'invalid_json'}` rather than being
passed through — this is what actually closes the gap `geminiClient.js`'s
`generationConfig.responseMimeType` only makes less likely, since a model
reply is never trusted just because Gemini returned `ok: true`.

### Local setup

Copy `.env.example` to `.env` and fill in `GEMINI_API_KEY`, then run:

```
node --env-file=.env server.js
```

There's no `dotenv` dependency — `proxy/node_modules/` is committed to this
repo, so native env-file loading (Node 20.6+) avoids growing that further.
Without `--env-file`, `GEMINI_API_KEY` is simply unset and calls return
`missing_api_key`.

Run tests with `npm test` (uses Node's built-in `node --test`, no extra deps).

### FR-104 variance test

`recommendationVariance.test.js` (#47) builds three synthetic user profiles
with different preferences, budgets, and search history, and checks that
`llmDataFilter.js`/`recommendationPrompt.js`/`geminiClient.js` build a
distinct, correctly targeted request per profile — this part always runs, no
key needed. It also has one live sub-test that calls the real Gemini API and
checks the *actual* recommendations vary and fit each profile's budget/dates/
preferences; that one is skipped by default and only runs with both of:

```
GEMINI_API_KEY=<your key> RUN_GEMINI_LIVE_TESTS=1 node --env-file=.env --test recommendationVariance.test.js
```

It makes three billed Gemini calls, so run it deliberately, not as part of
routine `npm test`.
