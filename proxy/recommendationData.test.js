'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRecommendationDataLoader } = require('./recommendationData');
const { MAX_MEMBERS } = require('./llmDataFilter');

function fakeFirestore(docs) {
  const snap = (path) => ({ id: path.split('/')[1], exists: path in docs, data: () => docs[path] });
  const calls = { getAll: [] };
  return {
    calls,
    collection: (c) => ({ doc: (id) => ({ path: `${c}/${id}`, get: async () => snap(`${c}/${id}`) }) }),
    getAll: async (...refs) => {
      calls.getAll.push(refs.length);
      return refs.map((r) => snap(r.path));
    },
  };
}

test('loads the group, member users and stamped travel results', async () => {
  const group = { memberIds: ['a', 'b'], name: 'Trip' };
  const fs = fakeFirestore({ 'groups/g': group, 'users/a': { preferences: {} }, 'users/b': { email: 'x' } });
  const raw = await createRecommendationDataLoader(fs).loadRawData({
    uid: 'a',
    groupId: 'g',
    travelResults: [{ type: 'flight', groupId: 'spoofed' }],
  });
  assert.deepEqual(raw.groups, { g: group });
  assert.deepEqual(Object.keys(raw.users), ['a', 'b']);
  assert.deepEqual(raw.previousSearches, []);
  assert.deepEqual(raw.travelResults, [{ type: 'flight', groupId: 'g' }]);
});

test('skips member docs that do not exist', async () => {
  const fs = fakeFirestore({ 'groups/g': { memberIds: ['a', 'gone'] }, 'users/a': {} });
  const raw = await createRecommendationDataLoader(fs).loadRawData({ uid: 'a', groupId: 'g', travelResults: [] });
  assert.deepEqual(Object.keys(raw.users), ['a']);
});

test('a missing group yields empty groups', async () => {
  const raw = await createRecommendationDataLoader(fakeFirestore({})).loadRawData({ uid: 'a', groupId: 'g', travelResults: [] });
  assert.deepEqual(raw.groups, {});
});

test('caps member reads at MAX_MEMBERS in a single getAll', async () => {
  const memberIds = Array.from({ length: MAX_MEMBERS + 10 }, (_, i) => `m${i}`);
  memberIds[0] = 'a';
  const fs = fakeFirestore({ 'groups/g': { memberIds } });
  await createRecommendationDataLoader(fs).loadRawData({ uid: 'a', groupId: 'g', travelResults: [] });
  assert.deepEqual(fs.calls.getAll, [MAX_MEMBERS]);
});

test('does not read member docs for a non-member', async () => {
  const fs = fakeFirestore({ 'groups/g': { memberIds: ['b'] } });
  const raw = await createRecommendationDataLoader(fs).loadRawData({ uid: 'a', groupId: 'g', travelResults: [] });
  assert.deepEqual(fs.calls.getAll, []);
  assert.deepEqual(raw.users, {});
});
