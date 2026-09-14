# Syncinary proxy

Small Express backend. `server.js` proxies flight search to SerpApi.

## `llmDataFilter.js`

Filters and assembles the payload sent to the LLM recommendation agent
(FR-104 / SYS 109). Given a requesting user + an optional group id and a raw
data bundle (user records, group records, previous searches, travel results),
it:

- Enforces that the requester is a member of the target group, when a group
  id is given. Without one, it returns a personal payload built solely from
  the requester's own preferences, with every group-derived field empty.
- Returns only allowlisted fields — preferences, budget, dates, previous
  searches, and travel results — never credentials, tokens, payment info, or
  data belonging to other users/groups.

It's a pure function: no Firebase, no network. `requestingUserId` is assumed
to already be verified (e.g. from a checked session token) by the caller — this
module checks group *membership*, not identity. Wiring it to real Firebase
reads and an authenticated route is a follow-up issue.

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
string reaches Gemini solely inside the appended JSON. `RECOMMENDATION_OUTPUT_SCHEMA`
is exported as the single source of truth for the response shape, for a
future response-parsing module to validate against.

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
