# Gemini client metrics

Every `generateRecommendation()` result — success or failure — carries a few
fields specifically so usage can be measured later without redesigning the
client. Nothing is logged automatically; a caller that wants numbers over
time collects these fields itself (e.g. append each result to a file or
array) and aggregates them.

| Field | Present on | Meaning |
| --- | --- | --- |
| `latencyMs` | every result | Wall-clock time from just before the request to just after the response (or failure). Use it for typical/typical-worst-case response time. |
| `error` | failure only | One of `missing_api_key`, `invalid_input`, `timeout`, `rate_limited`, `upstream_error`, `network_error`, `invalid_response`. Tally by this to see failure-mode breakdown. |
| `usage.promptTokens` | success, if Gemini reports it | Input token count for the request (payload + prompt). |
| `usage.candidatesTokens` | success, if Gemini reports it | Output token count for the generated recommendation. |
| `usage.totalTokens` | success, if Gemini reports it | Sum of the two above; the number Gemini bills against. |

## Pulling numbers for a presentation

There's no built-in aggregator (out of scope for this issue) — accumulate
results from real calls, e.g.:

```js
const results = [];
// ...call generateRecommendation(...) repeatedly, push each result...

const successRate = results.filter(r => r.ok).length / results.length;
const avgLatencyMs = results.reduce((sum, r) => sum + r.latencyMs, 0) / results.length;
const totalTokens = results.filter(r => r.ok && r.usage).reduce((sum, r) => sum + (r.usage.totalTokens || 0), 0);
const errorsByCode = results.filter(r => !r.ok).reduce((acc, r) => {
  acc[r.error] = (acc[r.error] || 0) + 1;
  return acc;
}, {});
```

`usage` is only present when Gemini's response includes `usageMetadata` —
don't assume it's always there.
