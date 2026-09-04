'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  buildRecommendationPayload,
  ALLOWED_PREFERENCE_FIELDS,
  ALLOWED_BUDGET_FIELDS,
  ALLOWED_DATE_RANGE_FIELDS,
  ALLOWED_TRAVEL_RESULT_FIELDS,
} = require('./llmDataFilter');

// Sentinel values that must never appear anywhere in a serialized payload.
const LEAKS = {
  passwordHash: 'LEAK_passwordHash_a1',
  authToken: 'LEAK_authToken_b2',
  refreshToken: 'LEAK_refreshToken_c3',
  idToken: 'LEAK_idToken_d4',
  apiKey: 'LEAK_apiKey_e5',
  creditCard: 'LEAK_creditCard_f6',
  billingAddress: 'LEAK_billingAddress_g7',
  paymentMethods: 'LEAK_paymentMethods_h8',
  firebaseRef: 'LEAK_firebaseRef_i9',
  email: 'LEAK_email_j10',
};

function baseUser(overrides = {}) {
  return {
    displayName: 'Alice',
    email: LEAKS.email,
    passwordHash: LEAKS.passwordHash,
    authToken: LEAKS.authToken,
    refreshToken: LEAKS.refreshToken,
    idToken: LEAKS.idToken,
    apiKey: LEAKS.apiKey,
    creditCard: LEAKS.creditCard,
    billingAddress: LEAKS.billingAddress,
    paymentMethods: [LEAKS.paymentMethods],
    firebase: { _ref: LEAKS.firebaseRef },
    preferences: {
      activities: ['hiking', 'museums'],
      preferredDestinations: ['Japan'],
    },
    ...overrides,
  };
}

function baseGroup(overrides = {}) {
  return {
    memberIds: ['u1', 'u2'],
    sharedPreferences: { activities: ['beach'], preferredDestinations: ['Portugal'] },
    budget: { min: 500, max: 2000 },
    availableDates: { start: '2026-06-01', end: '2026-06-10' },
    ownerId: 'u1',
    firebase: { _ref: LEAKS.firebaseRef },
    ...overrides,
  };
}

function baseRawData(overrides = {}) {
  return {
    users: { u1: baseUser(), u2: baseUser({ displayName: 'Bob' }) },
    groups: { g1: baseGroup() },
    previousSearches: [
      { groupId: 'g1', destination: 'Lisbon', startDate: '2026-06-01', endDate: '2026-06-05', query: 'beach trip', timestamp: 100, searchedBy: 'u1' },
    ],
    travelResults: [
      { groupId: 'g1', type: 'flight', price: 300, carrier: 'AA', departureTime: '08:00', arrivalTime: '12:00', bookingToken: 'LEAK_bookingToken_k11' },
    ],
    ...overrides,
  };
}

const ctx = { requestingUserId: 'u1', groupId: 'g1' };

function serialized(payload) {
  return JSON.stringify(payload);
}

// --- Permission ---

test('denies a requester who is not a group member', () => {
  const result = buildRecommendationPayload({ requestingUserId: 'stranger', groupId: 'g1' }, baseRawData());
  assert.equal(result.allowed, false);
  assert.equal(result.reason, 'not_a_member');
  assert.equal('payload' in result, false);
});

test('denies an unknown group id', () => {
  const result = buildRecommendationPayload({ requestingUserId: 'u1', groupId: 'missing' }, baseRawData());
  assert.equal(result.allowed, false);
  assert.equal(result.reason, 'unknown_group');
});

test('allows a requester who is a group member', () => {
  const result = buildRecommendationPayload(ctx, baseRawData());
  assert.equal(result.allowed, true);
  assert.ok(result.payload);
});

// --- Allowlist / pass-through ---

test('payload includes every allowed category with correct values', () => {
  const { payload } = buildRecommendationPayload(ctx, baseRawData());
  assert.deepEqual(payload.requestingUserPreferences, {
    activities: ['hiking', 'museums'],
    preferredDestinations: ['Japan'],
  });
  assert.deepEqual(payload.groupPreferences, {
    activities: ['beach'],
    preferredDestinations: ['Portugal'],
  });
  assert.deepEqual(payload.budgetConstraints, { min: 500, max: 2000 });
  assert.deepEqual(payload.availableDates, { start: '2026-06-01', end: '2026-06-10' });
  assert.deepEqual(payload.previousSearches, [
    { destination: 'Lisbon', startDate: '2026-06-01', endDate: '2026-06-05', query: 'beach trip', timestamp: 100 },
  ]);
  assert.deepEqual(payload.travelResults, [
    { type: 'flight', price: 300, carrier: 'AA', departureTime: '08:00', arrivalTime: '12:00' },
  ]);
});

test('travel result entries drop raw-provider extras and keep only allowlisted fields', () => {
  const { payload } = buildRecommendationPayload(ctx, baseRawData());
  const [result] = payload.travelResults;
  assert.deepEqual(Object.keys(result).sort(), ALLOWED_TRAVEL_RESULT_FIELDS.filter((f) => f in result).sort());
});

// --- Leak prevention ---

for (const [label, sentinel] of Object.entries(LEAKS)) {
  test(`never leaks ${label} into the serialized payload`, () => {
    const { payload } = buildRecommendationPayload(ctx, baseRawData());
    assert.ok(!serialized(payload).includes(sentinel), `${label} leaked into payload`);
  });
}

test('allowlist field constants stay narrow (no PII beyond preferences)', () => {
  for (const field of ['email', 'displayName', 'passwordHash', 'authToken']) {
    assert.ok(!ALLOWED_PREFERENCE_FIELDS.includes(field));
  }
});

// --- Scoping ---

test('excludes an unrelated user who is not a member of the target group', () => {
  const rawData = baseRawData({
    users: { ...baseRawData().users, u3: baseUser({ displayName: 'Eve', preferences: { activities: ['LEAK_unrelated_activity'] } }) },
  });
  const { payload } = buildRecommendationPayload(ctx, rawData);
  assert.ok(!serialized(payload).includes('LEAK_unrelated_activity'));
  assert.ok(!('u3' in payload.memberPreferences));
});

test('excludes an unrelated group entirely', () => {
  const rawData = baseRawData({
    groups: {
      ...baseRawData().groups,
      g2: baseGroup({ memberIds: ['u1'], sharedPreferences: { activities: ['LEAK_other_group_activity'] } }),
    },
  });
  const { payload } = buildRecommendationPayload(ctx, rawData);
  assert.ok(!serialized(payload).includes('LEAK_other_group_activity'));
});

test('excludes previous searches belonging to a different group', () => {
  const rawData = baseRawData({
    previousSearches: [
      ...baseRawData().previousSearches,
      { groupId: 'g2', destination: 'LEAK_other_group_destination' },
    ],
  });
  const { payload } = buildRecommendationPayload(ctx, rawData);
  assert.ok(!serialized(payload).includes('LEAK_other_group_destination'));
});

// --- Robustness ---

test('handles rawData missing previousSearches and travelResults', () => {
  const rawData = baseRawData();
  delete rawData.previousSearches;
  delete rawData.travelResults;
  const { payload } = buildRecommendationPayload(ctx, rawData);
  assert.deepEqual(payload.previousSearches, []);
  assert.deepEqual(payload.travelResults, []);
});

test('handles a group with empty memberIds without throwing', () => {
  const rawData = baseRawData({ groups: { g1: baseGroup({ memberIds: [] }) } });
  const result = buildRecommendationPayload(ctx, rawData);
  assert.equal(result.allowed, false);
  assert.equal(result.reason, 'not_a_member');
});

test('rejects non-object requestContext and rawData without throwing', () => {
  assert.deepEqual(buildRecommendationPayload(null, baseRawData()), { allowed: false, reason: 'invalid_input' });
  assert.deepEqual(buildRecommendationPayload(ctx, undefined), { allowed: false, reason: 'invalid_input' });
  assert.deepEqual(buildRecommendationPayload('nope', baseRawData()), { allowed: false, reason: 'invalid_input' });
  assert.deepEqual(buildRecommendationPayload(ctx, 42), { allowed: false, reason: 'invalid_input' });
});

test('skips a member id with no corresponding user record', () => {
  const rawData = baseRawData({ groups: { g1: baseGroup({ memberIds: ['u1', 'ghost'] }) } });
  const { payload } = buildRecommendationPayload(ctx, rawData);
  assert.ok(!('ghost' in payload.memberPreferences));
  assert.ok('u1' in payload.memberPreferences);
});

test('does not mutate its inputs', () => {
  const rawData = baseRawData();
  const snapshot = JSON.parse(JSON.stringify(rawData));
  buildRecommendationPayload(ctx, rawData);
  assert.deepEqual(rawData, snapshot);
});
