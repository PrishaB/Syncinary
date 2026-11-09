'use strict';

const { MAX_MEMBERS } = require('./llmDataFilter');

/**
 * Builds the `rawData` bundle for `llmDataFilter.buildRecommendationPayload`
 * from Firestore (`groups/{id}`, `users/{uid}`). `firestore` is injected so
 * tests need no Firebase.
 *
 * Only the group doc is read for a non-member; the filter still makes the
 * final membership decision.
 */
function createRecommendationDataLoader(firestore) {
  /**
   * @param {{uid: string, groupId: string, travelResults: object[]}} args
   * @returns {Promise<object>} rawData for the filter
   */
  async function loadRawData({ uid, groupId, travelResults }) {
    const groupSnap = await firestore.collection('groups').doc(groupId).get();
    if (!groupSnap.exists) return { groups: {}, users: {}, previousSearches: [], travelResults: [] };

    const group = groupSnap.data();
    const memberIds = Array.isArray(group.memberIds) ? group.memberIds : [];

    const users = {};
    if (memberIds.includes(uid)) {
      const refs = memberIds.slice(0, MAX_MEMBERS).map((id) => firestore.collection('users').doc(id));
      for (const snap of refs.length ? await firestore.getAll(...refs) : []) {
        if (snap.exists) users[snap.id] = snap.data();
      }
    }

    return {
      groups: { [groupId]: group },
      users,
      // No searches collection exists yet; read groups/{groupId}/searches here once it does.
      previousSearches: [],
      // The client's own fresh results; the filter drops any not stamped with this groupId.
      travelResults: travelResults.map((result) => ({ ...result, groupId })),
    };
  }

  return { loadRawData };
}

module.exports = { createRecommendationDataLoader };
