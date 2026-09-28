'use strict';

/**
 * Builds the data payload sent to the LLM for a travel recommendation request.
 *
 * This module is a pure, synchronous filter: it takes already-fetched plain
 * objects (not live Firebase documents) and an already-authenticated
 * `requestingUserId`, and returns only the fields the LLM is allowed to see
 * (FR-104 / SYS 109 — LLM Role and Data Access). It does not call Firebase,
 * Gemini, or any network API — a later issue supplies the loader that
 * produces the `rawData` shape this module consumes from real data, and the
 * route/session layer that authenticates `requestContext.requestingUserId`
 * before calling in. Until then, treat `requestingUserId` as already
 * verified — this module checks group *membership*, not identity.
 */

const ALLOWED_PREFERENCE_FIELDS = ['activities', 'preferredDestinations'];
const ALLOWED_BUDGET_FIELDS = ['min', 'max'];
const ALLOWED_DATE_RANGE_FIELDS = ['start', 'end'];
const ALLOWED_SEARCH_FIELDS = ['destination', 'startDate', 'endDate', 'query', 'timestamp'];
const ALLOWED_TRAVEL_RESULT_FIELDS = [
  'type',
  'price',
  'carrier',
  'departureTime',
  'arrivalTime',
  'location',
  'name',
];

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Copies only `fields` from `raw` into a new object. Never spreads/clones wholesale. */
function pickAllowed(raw, fields) {
  const out = {};
  if (!isPlainObject(raw)) return out;
  for (const field of fields) {
    if (!(field in raw)) continue;
    const value = raw[field];
    out[field] = Array.isArray(value) ? [...value] : value;
  }
  return out;
}

const pickPreferences = (raw) => pickAllowed(raw, ALLOWED_PREFERENCE_FIELDS);
const pickBudget = (raw) => pickAllowed(raw, ALLOWED_BUDGET_FIELDS);
const pickDateRange = (raw) => pickAllowed(raw, ALLOWED_DATE_RANGE_FIELDS);
const pickSearch = (raw) => pickAllowed(raw, ALLOWED_SEARCH_FIELDS);
const pickTravelResult = (raw) => pickAllowed(raw, ALLOWED_TRAVEL_RESULT_FIELDS);

/**
 * @param {{requestingUserId: string, groupId: string}} requestContext
 * @param {{
 *   users?: Record<string, {preferences?: object}>,
 *   groups?: Record<string, {memberIds?: string[], sharedPreferences?: object, budget?: object, availableDates?: object}>,
 *   previousSearches?: Array<{groupId?: string} & object>,
 *   travelResults?: Array<{groupId?: string} & object>,
 * }} rawData
 * @returns {{allowed: true, payload: object} | {allowed: false, reason: string}}
 */
function buildRecommendationPayload(requestContext, rawData) {
  if (!isPlainObject(requestContext) || !isPlainObject(rawData)) {
    return { allowed: false, reason: 'invalid_input' };
  }

  const { requestingUserId, groupId } = requestContext;
  if (!requestingUserId || !groupId) {
    return { allowed: false, reason: 'invalid_input' };
  }

  const groups = isPlainObject(rawData.groups) ? rawData.groups : {};
  const group = groups[groupId];
  if (!isPlainObject(group)) {
    return { allowed: false, reason: 'unknown_group' };
  }

  const memberIds = Array.isArray(group.memberIds) ? group.memberIds : [];
  if (!memberIds.includes(requestingUserId)) {
    return { allowed: false, reason: 'not_a_member' };
  }

  const users = isPlainObject(rawData.users) ? rawData.users : {};

  const memberPreferences = {};
  for (const memberId of memberIds) {
    const member = users[memberId];
    if (!isPlainObject(member)) continue; // member has no record on file — skip silently
    memberPreferences[memberId] = pickPreferences(member.preferences);
  }

  const previousSearches = Array.isArray(rawData.previousSearches) ? rawData.previousSearches : [];
  const groupSearches = previousSearches
    .filter((search) => isPlainObject(search) && search.groupId === groupId)
    .map(pickSearch);

  const travelResults = Array.isArray(rawData.travelResults) ? rawData.travelResults : [];
  const groupTravelResults = travelResults
    .filter((result) => isPlainObject(result) && result.groupId === groupId)
    .map(pickTravelResult);

  const requestingUser = users[requestingUserId];

  const payload = {
    requestingUserPreferences: pickPreferences(requestingUser && requestingUser.preferences),
    groupPreferences: pickPreferences(group.sharedPreferences),
    memberPreferences,
    budgetConstraints: pickBudget(group.budget),
    availableDates: pickDateRange(group.availableDates),
    previousSearches: groupSearches,
    travelResults: groupTravelResults,
  };

  return { allowed: true, payload };
}

module.exports = {
  buildRecommendationPayload,
  pickPreferences,
  pickBudget,
  pickDateRange,
  pickSearch,
  pickTravelResult,
  ALLOWED_PREFERENCE_FIELDS,
  ALLOWED_BUDGET_FIELDS,
  ALLOWED_DATE_RANGE_FIELDS,
  ALLOWED_SEARCH_FIELDS,
  ALLOWED_TRAVEL_RESULT_FIELDS,
};
