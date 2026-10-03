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

// Caps below bound how much adversarial text/data a single request can smuggle
// into the LLM payload (#91): a string field is truncated rather than rejected
// outright (a member's genuinely long activity name shouldn't 400 the whole
// request), but nothing gets through unbounded.
const MAX_STRING_LENGTH = 300;
const MAX_ARRAY_ITEMS = 15;
const MAX_MEMBERS = 25;
const MAX_PAYLOAD_BYTES = 20000;

const PREFERENCE_FIELD_TYPES = Object.freeze({
  activities: 'stringArray',
  preferredDestinations: 'stringArray',
});
const BUDGET_FIELD_TYPES = Object.freeze({ min: 'number', max: 'number' });
const DATE_RANGE_FIELD_TYPES = Object.freeze({ start: 'string', end: 'string' });
const SEARCH_FIELD_TYPES = Object.freeze({
  destination: 'string',
  startDate: 'string',
  endDate: 'string',
  query: 'string',
  timestamp: 'number',
});
const TRAVEL_RESULT_FIELD_TYPES = Object.freeze({
  type: 'string',
  price: 'number',
  carrier: 'string',
  departureTime: 'string',
  arrivalTime: 'string',
  location: 'string',
  name: 'string',
});

const ALLOWED_PREFERENCE_FIELDS = Object.keys(PREFERENCE_FIELD_TYPES);
const ALLOWED_BUDGET_FIELDS = Object.keys(BUDGET_FIELD_TYPES);
const ALLOWED_DATE_RANGE_FIELDS = Object.keys(DATE_RANGE_FIELD_TYPES);
const ALLOWED_SEARCH_FIELDS = Object.keys(SEARCH_FIELD_TYPES);
const ALLOWED_TRAVEL_RESULT_FIELDS = Object.keys(TRAVEL_RESULT_FIELD_TYPES);

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function sanitizeString(value) {
  return typeof value === 'string' ? value.slice(0, MAX_STRING_LENGTH) : undefined;
}

function sanitizeNumber(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function sanitizeStringArray(value) {
  if (!Array.isArray(value)) return undefined;
  return value
    .filter((item) => typeof item === 'string')
    .slice(0, MAX_ARRAY_ITEMS)
    .map((item) => item.slice(0, MAX_STRING_LENGTH));
}

/** Enforces `type` on `value`, returning `undefined` (drop the field) if it doesn't fit. */
function sanitizeByType(value, type) {
  if (type === 'string') return sanitizeString(value);
  if (type === 'number') return sanitizeNumber(value);
  if (type === 'stringArray') return sanitizeStringArray(value);
  return undefined;
}

/**
 * Copies only the fields named in `fieldTypes` from `raw` into a new object,
 * dropping any field whose value doesn't match its declared type (or is
 * missing) and truncating strings/arrays to the caps above. Never
 * spreads/clones wholesale, and never lets an unexpected shape (wrong type,
 * nested object, oversized string) reach the LLM payload.
 */
function pickAllowed(raw, fieldTypes) {
  const out = {};
  if (!isPlainObject(raw)) return out;
  for (const [field, type] of Object.entries(fieldTypes)) {
    if (!(field in raw)) continue;
    const sanitized = sanitizeByType(raw[field], type);
    if (sanitized !== undefined) out[field] = sanitized;
  }
  return out;
}

const pickPreferences = (raw) => pickAllowed(raw, PREFERENCE_FIELD_TYPES);
const pickBudget = (raw) => pickAllowed(raw, BUDGET_FIELD_TYPES);
const pickDateRange = (raw) => pickAllowed(raw, DATE_RANGE_FIELD_TYPES);
const pickSearch = (raw) => pickAllowed(raw, SEARCH_FIELD_TYPES);
const pickTravelResult = (raw) => pickAllowed(raw, TRAVEL_RESULT_FIELD_TYPES);

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
  for (const memberId of memberIds.slice(0, MAX_MEMBERS)) {
    const member = users[memberId];
    if (!isPlainObject(member)) continue; // member has no record on file — skip silently
    memberPreferences[memberId] = pickPreferences(member.preferences);
  }

  const previousSearches = Array.isArray(rawData.previousSearches) ? rawData.previousSearches : [];
  const groupSearches = previousSearches
    .filter((search) => isPlainObject(search) && search.groupId === groupId)
    .slice(0, MAX_ARRAY_ITEMS)
    .map(pickSearch);

  const travelResults = Array.isArray(rawData.travelResults) ? rawData.travelResults : [];
  const groupTravelResults = travelResults
    .filter((result) => isPlainObject(result) && result.groupId === groupId)
    .slice(0, MAX_ARRAY_ITEMS)
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

  // Defense in depth on top of the per-field caps above: even fully-capped
  // fields can add up across enough members/searches/results, so refuse to
  // hand Gemini an oversized request rather than let it grow unbounded.
  if (Buffer.byteLength(JSON.stringify(payload), 'utf8') > MAX_PAYLOAD_BYTES) {
    return { allowed: false, reason: 'payload_too_large' };
  }

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
  MAX_STRING_LENGTH,
  MAX_ARRAY_ITEMS,
  MAX_MEMBERS,
  MAX_PAYLOAD_BYTES,
};
