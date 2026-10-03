'use strict';

/**
 * FR-104: recommendations must vary across user profiles and correspond to
 * each profile's own preferences, budget, and search history (#47).
 *
 * The deterministic tests below always run (no network, no API key) and
 * prove the pipeline builds a distinct, correctly targeted request per
 * profile and routes each profile's reply back correctly. They cannot prove
 * the model's *output* is good -- that's the live test at the bottom, which
 * only runs when a real GEMINI_API_KEY is explicitly opted into (see
 * proxy/README.md). CI has no such key, so it always skips there.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const { buildRecommendationPayload } = require('./llmDataFilter');
const { buildRecommendationPrompt, parseRecommendationResponse } = require('./recommendationPrompt');
const { createGeminiClient } = require('./geminiClient');

const AVAILABLE_DATES = { start: '2026-11-06', end: '2026-11-09' };

// llmDataFilter.js scopes budget/history to the *group*, not the user, so
// each profile is modeled as the sole member of its own group.
const PROFILES = [
  {
    key: 'p1',
    label: 'budget outdoors',
    userId: 'user-p1',
    groupId: 'group-p1',
    activities: ['backcountry hiking', 'camping'],
    preferredDestinations: ['Denver'],
    budget: { min: 200, max: 600 },
    previousSearches: [{ destination: 'Miami', query: 'beach resorts' }],
  },
  {
    key: 'p2',
    label: 'luxury beach',
    userId: 'user-p2',
    groupId: 'group-p2',
    activities: ['snorkeling', 'spa day'],
    preferredDestinations: ['Miami'],
    budget: { min: 2000, max: 5000 },
    previousSearches: [{ destination: 'Denver', query: 'mountain cabins' }],
  },
  {
    key: 'p3',
    label: 'mid-range culture',
    userId: 'user-p3',
    groupId: 'group-p3',
    activities: ['art museums', 'food tours'],
    preferredDestinations: ['New York City'],
    budget: { min: 800, max: 1500 },
    previousSearches: [
      { destination: 'Denver', query: 'hiking trips' },
      { destination: 'Miami', query: 'beach resorts' },
    ],
  },
];

// The same three candidate destinations offered to every profile -- only
// `groupId` differs per copy, and llmDataFilter.pickTravelResult strips that,
// so every profile sees an identical travelResults list.
function travelResultsFor(groupId) {
  return [
    { groupId, type: 'hotel', price: 90, location: 'Denver', name: 'Mountain Lodge' },
    { groupId, type: 'activity', price: 40, location: 'Denver', name: 'Rocky Mountain Trailhead' },
    { groupId, type: 'hotel', price: 480, location: 'Miami', name: 'Ocean Breeze Resort' },
    { groupId, type: 'activity', price: 150, location: 'Miami', name: 'Reef Snorkeling Tour' },
    { groupId, type: 'hotel', price: 260, location: 'New York City', name: 'Midtown Arts Hotel' },
    { groupId, type: 'activity', price: 60, location: 'New York City', name: 'MoMA Guided Tour' },
  ];
}

/** One shared rawData holding all three profiles' users/groups/searches. */
function buildRawData() {
  const rawData = { users: {}, groups: {}, previousSearches: [], travelResults: [] };
  for (const profile of PROFILES) {
    rawData.users[profile.userId] = {
      preferences: { activities: profile.activities, preferredDestinations: profile.preferredDestinations },
    };
    rawData.groups[profile.groupId] = {
      memberIds: [profile.userId],
      budget: profile.budget,
      availableDates: AVAILABLE_DATES,
    };
    for (const search of profile.previousSearches) {
      rawData.previousSearches.push({ ...search, groupId: profile.groupId });
    }
    rawData.travelResults.push(...travelResultsFor(profile.groupId));
  }
  return rawData;
}

const requestContextFor = (profile) => ({ requestingUserId: profile.userId, groupId: profile.groupId });

/** A canned, schema-valid Gemini reply tailored to `profile`. */
function cannedReplyFor(profile) {
  const destination = profile.preferredDestinations[0];
  const activity = profile.activities[0];
  const perPerson = Math.round((profile.budget.min + profile.budget.max) / 2);
  return {
    summary: `A ${profile.label} trip built around ${destination}.`,
    destinations: [
      {
        id: `${profile.key}-dest`,
        name: destination,
        region: null,
        rationale: `Matches your interest in ${activity}.`,
        matchedPreferences: [activity],
        estimatedCostPerPerson: { amount: perPerson, currency: 'USD' },
      },
    ],
    activities: [
      {
        id: `${profile.key}-act`,
        destinationId: `${profile.key}-dest`,
        name: activity,
        category: 'recreation',
        description: `Enjoy ${activity} in ${destination}.`,
        estimatedCostPerPerson: { amount: Math.min(perPerson, profile.budget.max), currency: 'USD' },
        durationHours: 3,
      },
    ],
    itinerary: [
      {
        day: 1,
        date: AVAILABLE_DATES.start,
        destinationId: `${profile.key}-dest`,
        items: [{ timeOfDay: 'morning', activityId: `${profile.key}-act`, title: activity, notes: null }],
      },
    ],
    assumptions: [],
    warnings: [],
  };
}

/**
 * Checks a parsed Gemini `data` object against `profile`'s budget, the
 * shared date range, and its preferences. Returns a list of violation
 * strings; `[]` means it fits.
 */
function checkFitsProfile(data, profile) {
  const violations = [];
  const startDate = new Date(AVAILABLE_DATES.start);
  const endDate = new Date(AVAILABLE_DATES.end);

  for (const item of [...data.destinations, ...data.activities]) {
    const cost = item.estimatedCostPerPerson;
    if (cost.currency !== 'USD') violations.push(`cost currency ${cost.currency} !== USD`);
    if (cost.amount > profile.budget.max) {
      violations.push(`cost ${cost.amount} exceeds budget max ${profile.budget.max}`);
    }
  }

  for (const day of data.itinerary) {
    if (!day.date) {
      violations.push('itinerary day has no date');
      continue;
    }
    const date = new Date(day.date);
    if (date < startDate || date > endDate) {
      violations.push(`itinerary date ${day.date} outside [${AVAILABLE_DATES.start}, ${AVAILABLE_DATES.end}]`);
    }
  }

  const rangeDays = Math.round((endDate - startDate) / 86400000) + 1;
  if (data.itinerary.length > rangeDays) {
    violations.push(`itinerary has ${data.itinerary.length} days, more than the ${rangeDays}-day range`);
  }

  const wanted = [...profile.preferredDestinations, ...profile.activities].map((s) => s.toLowerCase());
  const mentioned = [
    ...data.destinations.map((d) => d.name),
    ...data.destinations.flatMap((d) => d.matchedPreferences),
  ].map((s) => s.toLowerCase());
  if (!mentioned.some((value) => wanted.includes(value))) {
    violations.push('no destination or matchedPreferences entry matches a preferred destination/activity');
  }

  return violations;
}

// --- Deterministic: payload isolation and targeting ---

test("each profile's payload carries only its own preferences, budget, and search history", () => {
  const rawData = buildRawData();
  for (const profile of PROFILES) {
    const result = buildRecommendationPayload(requestContextFor(profile), rawData);
    assert.equal(result.allowed, true, `profile ${profile.key} was rejected: ${result.reason}`);
    assert.deepEqual(result.payload.requestingUserPreferences, {
      activities: profile.activities,
      preferredDestinations: profile.preferredDestinations,
    });
    assert.deepEqual(result.payload.budgetConstraints, profile.budget);
    assert.equal(result.payload.previousSearches.length, profile.previousSearches.length);
  }
});

test('shared dates and travel results are identical across profiles', () => {
  const rawData = buildRawData();
  const payloads = PROFILES.map((p) => buildRecommendationPayload(requestContextFor(p), rawData).payload);
  for (const payload of payloads.slice(1)) {
    assert.deepEqual(payload.availableDates, payloads[0].availableDates);
    assert.deepEqual(payload.travelResults, payloads[0].travelResults);
  }
});

test('payloads are pairwise distinct in exactly the profile-specific sections', () => {
  const rawData = buildRawData();
  const payloads = PROFILES.map((p) => buildRecommendationPayload(requestContextFor(p), rawData).payload);
  for (let i = 0; i < payloads.length; i++) {
    for (let j = i + 1; j < payloads.length; j++) {
      assert.notDeepEqual(payloads[i], payloads[j]);
      assert.notDeepEqual(payloads[i].requestingUserPreferences, payloads[j].requestingUserPreferences);
      assert.notDeepEqual(payloads[i].budgetConstraints, payloads[j].budgetConstraints);
      assert.notDeepEqual(payloads[i].previousSearches, payloads[j].previousSearches);
    }
  }
});

test("no profile's payload leaks another profile's activities or member list", () => {
  const rawData = buildRawData();
  for (const profile of PROFILES) {
    const { payload } = buildRecommendationPayload(requestContextFor(profile), rawData);
    const serialized = JSON.stringify(payload);
    for (const other of PROFILES) {
      if (other.key === profile.key) continue;
      for (const activity of other.activities) {
        assert.ok(!serialized.includes(activity), `${profile.key}'s payload leaked "${activity}" from ${other.key}`);
      }
    }
    assert.deepEqual(Object.keys(payload.memberPreferences), [profile.userId]);
  }
});

test('prompts are identical text across profiles -- payload values never appear there', () => {
  const rawData = buildRawData();
  const prompts = PROFILES.map((profile) => {
    const { payload } = buildRecommendationPayload(requestContextFor(profile), rawData);
    const result = buildRecommendationPrompt(payload);
    assert.equal(result.ok, true);
    return result.prompt;
  });
  for (const prompt of prompts.slice(1)) assert.equal(prompt, prompts[0]);

  for (const profile of PROFILES) {
    for (const activity of profile.activities) {
      assert.ok(!prompts[0].includes(activity), `prompt leaked activity "${activity}"`);
    }
  }
});

// --- Deterministic: request/response routing through geminiClient ---

test("each profile gets its own reply back through the Gemini client, and request bodies differ", async () => {
  const rawData = buildRawData();
  const sentTexts = [];

  for (const profile of PROFILES) {
    const { payload } = buildRecommendationPayload(requestContextFor(profile), rawData);
    const { prompt } = buildRecommendationPrompt(payload);
    const calls = [];
    const fetchImpl = async (url, init) => {
      calls.push(init);
      return {
        status: 200,
        ok: true,
        headers: { get: () => null },
        async json() {
          return { candidates: [{ content: { parts: [{ text: JSON.stringify(cannedReplyFor(profile)) }] } }] };
        },
      };
    };
    const client = createGeminiClient({ apiKey: 'test-key', fetchImpl });
    const geminiResult = await client.generateRecommendation({ payload, prompt });
    assert.equal(geminiResult.ok, true);

    const sentText = JSON.parse(calls[0].body).contents[0].parts[0].text;
    assert.equal(sentText, `${prompt}\n\n${JSON.stringify(payload)}`);
    sentTexts.push(sentText);

    const parsed = parseRecommendationResponse(geminiResult.text);
    assert.equal(parsed.ok, true, JSON.stringify(parsed));
    assert.equal(parsed.data.destinations[0].name, profile.preferredDestinations[0]);
  }

  for (let i = 0; i < sentTexts.length; i++) {
    for (let j = i + 1; j < sentTexts.length; j++) {
      assert.notEqual(sentTexts[i], sentTexts[j]);
    }
  }
});

// --- Deterministic: self-test the output checker before the live test trusts it ---

test("checkFitsProfile passes each profile's own canned reply", () => {
  for (const profile of PROFILES) {
    const violations = checkFitsProfile(cannedReplyFor(profile), profile);
    assert.deepEqual(violations, [], `profile ${profile.key}: ${violations.join('; ')}`);
  }
});

test('checkFitsProfile catches a reply that violates budget, dates, or preferences', () => {
  const [p1, p2] = PROFILES;

  const overBudget = cannedReplyFor(p2); // priced for p2's $2000-5000 budget
  assert.ok(
    checkFitsProfile(overBudget, p1).some((v) => v.includes('exceeds budget max')),
    'expected a budget violation'
  );

  const wrongDate = cannedReplyFor(p1);
  wrongDate.itinerary[0].date = '2099-01-01';
  assert.ok(checkFitsProfile(wrongDate, p1).some((v) => v.includes('outside')), 'expected a date violation');

  const noMatch = cannedReplyFor(p1);
  noMatch.destinations[0].name = 'Antarctica';
  noMatch.destinations[0].matchedPreferences = ['skiing'];
  assert.ok(checkFitsProfile(noMatch, p1).some((v) => v.includes('matches')), 'expected a preference-match violation');
});

// --- Live: the only test that checks Gemini's actual output ---

const LIVE_ENABLED = Boolean(process.env.GEMINI_API_KEY) && process.env.RUN_GEMINI_LIVE_TESTS === '1';

test(
  'live: Gemini recommendations vary across profiles and fit each one (FR-104)',
  {
    skip: LIVE_ENABLED ? false : 'set GEMINI_API_KEY and RUN_GEMINI_LIVE_TESTS=1 to run this against real Gemini',
    timeout: 90_000,
  },
  async (t) => {
    const rawData = buildRawData();
    const client = createGeminiClient();
    const destinationSets = [];

    for (const profile of PROFILES) {
      const filterResult = buildRecommendationPayload(requestContextFor(profile), rawData);
      assert.equal(filterResult.allowed, true);
      const promptResult = buildRecommendationPrompt(filterResult.payload);
      assert.equal(promptResult.ok, true);

      const geminiResult = await client.generateRecommendation({
        payload: filterResult.payload,
        prompt: promptResult.prompt,
      });
      if (geminiResult.error === 'rate_limited') {
        t.skip(`rate limited for profile ${profile.key}`);
        return;
      }
      assert.equal(geminiResult.ok, true, JSON.stringify(geminiResult));
      t.diagnostic(`${profile.key} latencyMs=${geminiResult.latencyMs} usage=${JSON.stringify(geminiResult.usage)}`);

      const parsed = parseRecommendationResponse(geminiResult.text);
      assert.equal(parsed.ok, true, JSON.stringify(parsed));

      const violations = checkFitsProfile(parsed.data, profile);
      assert.deepEqual(violations, [], `profile ${profile.key} violations: ${violations.join('; ')}`);

      const destinationNames = parsed.data.destinations.map((d) => d.name).sort();
      destinationSets.push(JSON.stringify(destinationNames));

      const searchedBefore = profile.previousSearches.map((s) => s.destination.toLowerCase());
      const allPreviouslySearched = destinationNames.every((name) => searchedBefore.includes(name.toLowerCase()));
      if (allPreviouslySearched) {
        t.diagnostic(`profile ${profile.key}: every suggested destination was already searched`);
      }
    }

    assert.ok(new Set(destinationSets).size > 1, 'all three profiles got the identical set of destinations');
  }
);
