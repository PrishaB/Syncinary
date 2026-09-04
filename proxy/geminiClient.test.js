'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createGeminiClient, GEMINI_ERRORS } = require('./geminiClient');

const API_KEY = 'test-key-abc123';
const LEAK_KEY = 'LEAK_geminiKey_z9';

function makeHeaders(map = {}) {
  return { get: (name) => (name in map ? map[name] : null) };
}

function makeResponse({ status = 200, jsonBody, jsonError, textBody = '', headers } = {}) {
  return {
    status,
    ok: status >= 200 && status < 300,
    headers: makeHeaders(headers),
    async json() {
      if (jsonError) throw jsonError;
      return jsonBody;
    },
    async text() {
      return textBody;
    },
  };
}

/** Records every call and delegates to `impl(url, init)` for the result. */
function recordingFetch(impl) {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, init });
    return impl(url, init);
  };
  return { fetchImpl, calls };
}

function okPayload(text = 'a recommendation') {
  return { candidates: [{ content: { parts: [{ text }] }, finishReason: 'STOP' }] };
}

const payload = { requestingUserPreferences: { activities: ['hiking'] } };
const prompt = 'Suggest a trip.';

// --- Input / config validation ---

test('missing API key returns a typed error and never calls fetch', async () => {
  const { fetchImpl, calls } = recordingFetch(() => {
    throw new Error('should not be called');
  });
  const client = createGeminiClient({ apiKey: '', fetchImpl });
  const result = await client.generateRecommendation({ payload, prompt });
  assert.equal(result.ok, false);
  assert.equal(result.error, GEMINI_ERRORS.MISSING_API_KEY);
  assert.equal(calls.length, 0);
});

test('invalid payload/prompt returns invalid_input without calling fetch', async () => {
  const { fetchImpl, calls } = recordingFetch(() => {
    throw new Error('should not be called');
  });
  const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });

  for (const badArgs of [{ payload: 'not an object', prompt }, { payload, prompt: '' }, { payload, prompt: 42 }, {}]) {
    const result = await client.generateRecommendation(badArgs);
    assert.equal(result.ok, false);
    assert.equal(result.error, GEMINI_ERRORS.INVALID_INPUT);
  }
  assert.equal(calls.length, 0);
});

// --- Successful request/response ---

test('successful request sends the key as a header, not in the URL, and returns the candidate text', async () => {
  const { fetchImpl, calls } = recordingFetch(() => makeResponse({ jsonBody: okPayload('go to Lisbon') }));
  const client = createGeminiClient({ apiKey: API_KEY, model: 'gemini-2.0-flash', fetchImpl });
  const result = await client.generateRecommendation({ payload, prompt });

  assert.equal(result.ok, true);
  assert.equal(result.text, 'go to Lisbon');
  assert.equal(result.model, 'gemini-2.0-flash');
  assert.equal(result.finishReason, 'STOP');
  assert.ok(result.raw);

  assert.equal(calls.length, 1);
  const { url, init } = calls[0];
  assert.equal(init.method, 'POST');
  assert.ok(url.includes('gemini-2.0-flash'));
  assert.ok(url.includes(':generateContent'));
  assert.ok(!url.includes(API_KEY));
  assert.equal(init.headers['x-goog-api-key'], API_KEY);
  const sentBody = JSON.parse(init.body);
  const sentText = sentBody.contents[0].parts[0].text;
  assert.ok(sentText.includes(prompt));
  assert.ok(sentText.includes('hiking'));
});

test('multiple response parts are concatenated in order', async () => {
  const { fetchImpl } = recordingFetch(() =>
    makeResponse({ jsonBody: { candidates: [{ content: { parts: [{ text: 'part one, ' }, { text: 'part two' }] } }] } })
  );
  const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });
  const result = await client.generateRecommendation({ payload, prompt });
  assert.equal(result.ok, true);
  assert.equal(result.text, 'part one, part two');
});

// --- Timeout ---

test('timeout produces a typed error, not a throw', async () => {
  const fetchImpl = (url, init) =>
    new Promise((resolve, reject) => {
      const onAbort = () => {
        const err = new Error('aborted');
        err.name = 'AbortError';
        reject(err);
      };
      if (init.signal.aborted) onAbort();
      else init.signal.addEventListener('abort', onAbort, { once: true });
    });
  const client = createGeminiClient({ apiKey: API_KEY, fetchImpl, timeoutMs: 10 });
  const result = await client.generateRecommendation({ payload, prompt });
  assert.equal(result.ok, false);
  assert.equal(result.error, GEMINI_ERRORS.TIMEOUT);
  assert.ok(typeof result.latencyMs === 'number' && result.latencyMs >= 0);
});

// --- Rate limiting ---

test('429 with Retry-After maps to rate_limited with retryAfterSeconds', async () => {
  const { fetchImpl } = recordingFetch(() => makeResponse({ status: 429, headers: { 'Retry-After': '30' } }));
  const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });
  const result = await client.generateRecommendation({ payload, prompt });
  assert.equal(result.ok, false);
  assert.equal(result.error, GEMINI_ERRORS.RATE_LIMITED);
  assert.equal(result.status, 429);
  assert.equal(result.retryAfterSeconds, 30);
});

test('429 without Retry-After omits retryAfterSeconds rather than NaN', async () => {
  const { fetchImpl } = recordingFetch(() => makeResponse({ status: 429 }));
  const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });
  const result = await client.generateRecommendation({ payload, prompt });
  assert.equal(result.error, GEMINI_ERRORS.RATE_LIMITED);
  assert.equal('retryAfterSeconds' in result, false);
});

// --- Other upstream errors ---

test('non-2xx statuses other than 429 map to upstream_error with the status', async () => {
  for (const status of [400, 401, 403, 500, 503]) {
    const { fetchImpl } = recordingFetch(() => makeResponse({ status, textBody: 'upstream said no' }));
    const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });
    const result = await client.generateRecommendation({ payload, prompt });
    assert.equal(result.ok, false);
    assert.equal(result.error, GEMINI_ERRORS.UPSTREAM_ERROR);
    assert.equal(result.status, status);
  }
});

// --- Network failure ---

test('a rejected fetch maps to network_error without rethrowing', async () => {
  const fetchImpl = async () => {
    throw new TypeError('fetch failed');
  };
  const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });
  const result = await client.generateRecommendation({ payload, prompt });
  assert.equal(result.ok, false);
  assert.equal(result.error, GEMINI_ERRORS.NETWORK_ERROR);
});

// --- Malformed responses ---

test('malformed or blocked response shapes all map to invalid_response, never throw', async () => {
  const badBodies = [
    { jsonError: new Error('not json') },
    { jsonBody: {} },
    { jsonBody: { candidates: [] } },
    { jsonBody: { candidates: [{}] } },
    { jsonBody: { candidates: [{ content: { parts: [{}] } }] } },
    { jsonBody: { promptFeedback: { blockReason: 'SAFETY' } } },
  ];
  for (const spec of badBodies) {
    const { fetchImpl } = recordingFetch(() => makeResponse(spec));
    const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });
    const result = await client.generateRecommendation({ payload, prompt });
    assert.equal(result.ok, false, JSON.stringify(spec));
    assert.equal(result.error, GEMINI_ERRORS.INVALID_RESPONSE, JSON.stringify(spec));
  }
});

// --- Key never leaks ---

test('the API key never appears in a result, even when errors echo it back', async () => {
  const scenarios = [
    // network error whose message contains the key
    recordingFetch(async () => {
      throw new Error(`connection failed for key=${LEAK_KEY}`);
    }),
    // upstream error body echoing the key
    recordingFetch(() => makeResponse({ status: 400, textBody: `invalid request, key was ${LEAK_KEY}` })),
  ];
  for (const { fetchImpl } of scenarios) {
    const client = createGeminiClient({ apiKey: LEAK_KEY, fetchImpl });
    const result = await client.generateRecommendation({ payload, prompt });
    assert.ok(!JSON.stringify(result).includes(LEAK_KEY), `key leaked: ${JSON.stringify(result)}`);
  }
});

test('nothing is logged to the console', async (t) => {
  const logCalls = [];
  for (const method of ['log', 'error', 'warn', 'info']) {
    t.mock.method(console, method, (...args) => logCalls.push(args));
  }
  const { fetchImpl } = recordingFetch(() => makeResponse({ status: 500, textBody: 'boom' }));
  const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });
  await client.generateRecommendation({ payload, prompt });
  assert.equal(logCalls.length, 0);
});

// --- Caller-supplied signal ---

test('an already-aborted caller signal short-circuits to a timeout result', async () => {
  const controller = new AbortController();
  controller.abort();
  const fetchImpl = () =>
    new Promise((resolve, reject) => {
      const err = new Error('aborted');
      err.name = 'AbortError';
      reject(err);
    });
  const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });
  const result = await client.generateRecommendation({ payload, prompt, signal: controller.signal });
  assert.equal(result.ok, false);
  assert.equal(result.error, GEMINI_ERRORS.TIMEOUT);
});

// --- Metrics fields ---

test('a successful result reports latencyMs and usage parsed from usageMetadata', async () => {
  const { fetchImpl } = recordingFetch(() =>
    makeResponse({
      jsonBody: {
        ...okPayload(),
        usageMetadata: { promptTokenCount: 12, candidatesTokenCount: 34, totalTokenCount: 46 },
      },
    })
  );
  const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });
  const result = await client.generateRecommendation({ payload, prompt });
  assert.equal(result.ok, true);
  assert.ok(typeof result.latencyMs === 'number' && result.latencyMs >= 0);
  assert.deepEqual(result.usage, { promptTokens: 12, candidatesTokens: 34, totalTokens: 46 });
});

test('a response with no usageMetadata omits usage entirely', async () => {
  const { fetchImpl } = recordingFetch(() => makeResponse({ jsonBody: okPayload() }));
  const client = createGeminiClient({ apiKey: API_KEY, fetchImpl });
  const result = await client.generateRecommendation({ payload, prompt });
  assert.equal('usage' in result, false);
});
