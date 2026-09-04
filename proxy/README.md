# Syncinary proxy

Small Express backend. `server.js` proxies flight search to SerpApi.

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
module checks group *membership*, not identity. Wiring it to real Firebase
reads and an authenticated route is a follow-up issue.

Run tests with `npm test` (uses Node's built-in `node --test`, no extra deps).
