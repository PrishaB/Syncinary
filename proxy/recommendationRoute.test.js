'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.SERPAPI_KEY = 'test-serpapi-key';

const {
  app,
  setRecommendationDeps,
  resetRecommendationDeps,
  resetRecommendationRateLimits,
  RECOMMENDATION_IP_LIMIT,
  RECOMMENDATION_USER_LIMIT,
} = require('./server');
const { createGeminiClient } = require('./geminiClient');
const { createRecommendationDataLoader } = require('./recommendationData');

const UID = 'u1';
const GEMINI_KEY = 'test-gemini-key-do-not-leak';

const VALID_REPLY = {
  summary: 'A trip',
  destinations: [
    {
      id: 'd1',
      name: 'Lisbon',
      region: null,
      rationale: 'Sunny',
      matchedPreferences: [],
      estimatedCostPerPerson: { amount: 900, currency: 'USD' },
    },
  ],
  activities: [],
  itinerary: [],
  assumptions: [],
  warnings: [],
};

// In-memory stand-in for the slice of Firestore that recommendationData.js uses.
function fakeFirestore(docs) {
  const snap = (path) => ({ id: path.split('/')[1], exists: path in docs, data: () => docs[path] });
  const calls = { getAll: 0 };
  return {
    calls,
    collection: (c) => ({ doc: (id) => ({ path: `${c}/${id}`, get: async () => snap(`${c}/${id}`) }) }),
    getAll: async (...refs) => {
      calls.getAll += 1;
      return refs.map((r) => snap(r.path));
    },
  };
}

const DOCS = {
  'groups/g1': {
    name: 'Trip',
    inviteCode: 'LEAK_invite',
    memberIds: [UID, 'u2'],
    members: { [UID]: { username: 'LEAK_name', email: 'LEAK_email', role: 'owner' } },
  },
  'groups/g2': { memberIds: ['other'] },
  'users/u1': { username: 'LEAK_name', email: 'LEAK_email', preferences: { activities: ['hiking'] } },
  'users/u2': { username: 'LEAK_name2', email: 'LEAK_email2' },
};

const BODY = {
  groupId: 'g1',
  search: { destination: 'Lisbon', startDate: '2026-06-01', query: 'JFK to LIS' },
  travelResults: [{ type: 'flight', price: 300, carrier: 'TAP' }],
};

const geminiReply = (text) => async () => ({
  ok: true,
  status: 200,
  json: async () => ({ candidates: [{ content: { parts: [{ text }] } }] }),
});

function setup({ geminiFetch, loadRawData, geminiClient } = {}) {
  resetRecommendationRateLimits();
  const geminiRequests = [];
  const calls = { verify: 0, load: 0 };
  const firestore = fakeFirestore(DOCS);
  const loader = createRecommendationDataLoader(firestore);
  setRecommendationDeps({
    log: () => {},
    verifyIdToken: async (header) => {
      calls.verify += 1;
      if (header !== 'Bearer good-token') throw new Error('bad token');
      return { uid: UID };
    },
    loadRawData:
      loadRawData ||
      ((args) => {
        calls.load += 1;
        return loader.loadRawData(args);
      }),
    geminiClient:
      geminiClient ||
      createGeminiClient({
        apiKey: GEMINI_KEY,
        fetchImpl:
          geminiFetch ||
          ((url, init) => {
            geminiRequests.push(init.body);
            return geminiReply(JSON.stringify(VALID_REPLY))();
          }),
      }),
  });
  return { geminiRequests, calls, firestore };
}

async function post(body, { token = 'good-token', raw } = {}) {
  const server = app.listen(0);
  try {
    await new Promise((resolve) => (server.listening ? resolve() : server.once('listening', resolve)));
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    const response = await fetch(`http://127.0.0.1:${server.address().port}/recommendations`, {
      method: 'POST',
      headers,
      body: raw !== undefined ? raw : JSON.stringify(body),
    });
    return { status: response.status, headers: response.headers, body: await response.json() };
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test.afterEach(() => resetRecommendationDeps());

test('POST /recommendations with a valid token returns the parsed recommendation', async () => {
  const { geminiRequests } = setup();
  const res = await post(BODY);
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { ok: true, data: VALID_REPLY });
  assert.equal(geminiRequests.length, 1);
});

test('the Gemini request carries the search and results but no identity data, and ignores a body uid', async () => {
  const { geminiRequests } = setup();
  await post({ ...BODY, uid: 'attacker', requestingUserId: 'attacker' });
  const sent = geminiRequests[0];
  assert.match(sent, /hiking/);
  assert.match(sent, /JFK to LIS/);
  assert.match(sent, /TAP/);
  for (const leak of ['LEAK_', 'attacker', 'good-token', 'username', 'email', 'inviteCode']) {
    assert.ok(!sent.includes(leak), `request leaked ${leak}`);
  }
});

test('a missing or rejected token returns 401 without touching Firestore or Gemini', async () => {
  const { calls, geminiRequests } = setup();
  for (const token of [null, 'bad-token']) {
    const res = await post(BODY, { token });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthenticated');
  }
  assert.equal(calls.load, 0);
  assert.equal(geminiRequests.length, 0);
});

test('a malformed body returns 400 invalid_input', async () => {
  setup();
  const bodies = [
    {},
    { ...BODY, groupId: 5 },
    { ...BODY, groupId: 'a/b' },
    { ...BODY, search: 'x' },
    { ...BODY, travelResults: {} },
    { ...BODY, travelResults: ['x'] },
  ];
  for (const body of bodies) {
    const res = await post(body);
    assert.equal(res.status, 400, JSON.stringify(body));
    assert.equal(res.body.error, 'invalid_input');
  }
  assert.equal((await post(null, { raw: '{not json' })).status, 400);
});

test('an oversized body returns 413', async () => {
  const { calls } = setup();
  const res = await post({ ...BODY, search: { query: 'x'.repeat(40000) } });
  assert.equal(res.status, 413);
  assert.equal(res.body.error, 'payload_too_large');
  assert.equal(calls.load, 0);
});

test('an unknown group returns 404', async () => {
  setup();
  const res = await post({ ...BODY, groupId: 'missing' });
  assert.equal(res.status, 404);
  assert.equal(res.body.error, 'unknown_group');
});

test('a non-member gets 403 and member user docs are never read', async () => {
  const { firestore, geminiRequests } = setup();
  const res = await post({ ...BODY, groupId: 'g2' });
  assert.equal(res.status, 403);
  assert.equal(res.body.error, 'not_a_member');
  assert.equal(firestore.calls.getAll, 0);
  assert.equal(geminiRequests.length, 0);
});

test('no preferences, search or results returns 422 empty_payload', async () => {
  setup({ loadRawData: async () => ({ groups: { g1: { memberIds: [UID] } }, users: {} }) });
  const res = await post({ groupId: 'g1' });
  assert.equal(res.status, 422);
  assert.equal(res.body.error, 'empty_payload');
});

test('a search with no results is still enough to recommend from', async () => {
  setup();
  const res = await post({ groupId: 'g1', search: BODY.search });
  assert.equal(res.status, 200);
});

test('Gemini failures map to their status and never echo upstream text', async () => {
  const cases = [
    [{ ok: false, status: 429, headers: { get: () => '7' } }, 429, 'rate_limited'],
    [{ ok: false, status: 500, text: async () => 'boom upstream', headers: { get: () => null } }, 502, 'upstream_error'],
    [{ ok: true, status: 200, json: async () => ({ candidates: [] }) }, 502, 'invalid_response'],
  ];
  for (const [response, status, error] of cases) {
    setup({ geminiFetch: async () => response });
    const res = await post(BODY);
    assert.equal(res.status, status);
    assert.equal(res.body.error, error);
    assert.ok(!JSON.stringify(res.body).includes('boom'));
    if (error === 'rate_limited') assert.equal(res.headers.get('retry-after'), '7');
  }

  setup({
    geminiFetch: async () => {
      throw Object.assign(new Error('aborted'), { name: 'AbortError' });
    },
  });
  const timeout = await post(BODY);
  assert.equal(timeout.status, 504);
  assert.equal(timeout.body.error, 'timeout');

  setup({
    geminiFetch: async () => {
      throw new Error(`connect failed ${GEMINI_KEY}`);
    },
  });
  const net = await post(BODY);
  assert.equal(net.status, 502);
  assert.equal(net.body.error, 'network_error');
  assert.ok(!JSON.stringify(net.body).includes(GEMINI_KEY));
});

test('a missing Gemini key returns 503 missing_api_key', async () => {
  const saved = process.env.GEMINI_API_KEY;
  delete process.env.GEMINI_API_KEY;
  try {
    setup({ geminiClient: createGeminiClient({ fetchImpl: async () => {} }) });
    const res = await post(BODY);
    assert.equal(res.status, 503);
    assert.equal(res.body.error, 'missing_api_key');
  } finally {
    if (saved !== undefined) process.env.GEMINI_API_KEY = saved;
  }
});

test('Gemini replies that are not valid JSON or the wrong shape return 502', async () => {
  setup({ geminiFetch: geminiReply('not json') });
  const notJson = await post(BODY);
  assert.equal(notJson.status, 502);
  assert.equal(notJson.body.error, 'invalid_json');

  setup({ geminiFetch: geminiReply('{"summary":1}') });
  const wrong = await post(BODY);
  assert.equal(wrong.status, 502);
  assert.equal(wrong.body.error, 'schema_mismatch');
});

test('a loader failure returns 503 upstream_error with a fixed message', async () => {
  setup({
    loadRawData: async () => {
      throw new Error('firestore secret detail');
    },
  });
  const res = await post(BODY);
  assert.equal(res.status, 503);
  assert.equal(res.body.error, 'upstream_error');
  assert.ok(!res.body.message.includes('secret'));
});

test('an unexpected throw returns 500 upstream_error', async () => {
  setup({
    geminiClient: {
      generateRecommendation: async () => {
        throw new Error('bug');
      },
    },
  });
  const res = await post(BODY);
  assert.equal(res.status, 500);
  assert.equal(res.body.error, 'upstream_error');
});

test('a user over the per-user limit gets 429 rate_limited without another Gemini call', async () => {
  const { geminiRequests } = setup();
  for (let i = 0; i < RECOMMENDATION_USER_LIMIT; i += 1) {
    assert.equal((await post(BODY)).status, 200);
  }
  const res = await post(BODY);
  assert.equal(res.status, 429);
  assert.equal(res.body.ok, false);
  assert.equal(res.body.error, 'rate_limited');
  assert.equal(typeof res.body.message, 'string');
  assert.match(res.headers.get('retry-after'), /^\d+$/);
  assert.equal(geminiRequests.length, RECOMMENDATION_USER_LIMIT);
});

test('a client IP over the per-IP limit gets 429 before its token is checked', async () => {
  const { calls } = setup();
  for (let i = 0; i < RECOMMENDATION_IP_LIMIT; i += 1) {
    assert.equal((await post(BODY, { token: 'bad-token' })).status, 401);
  }
  const res = await post(BODY);
  assert.equal(res.status, 429);
  assert.equal(res.body.error, 'rate_limited');
  assert.equal(calls.verify, RECOMMENDATION_IP_LIMIT);
});
