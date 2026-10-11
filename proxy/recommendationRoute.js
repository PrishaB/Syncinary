'use strict';

const { buildRecommendationPayload } = require('./llmDataFilter');
const { buildRecommendationPrompt, parseRecommendationResponse } = require('./recommendationPrompt');

// error code -> HTTP status. The code itself is passed to the client unchanged.
const STATUS_BY_ERROR = Object.freeze({
  unauthenticated: 401,
  invalid_input: 400,
  not_a_member: 403,
  unknown_group: 404,
  payload_too_large: 413,
  empty_payload: 422,
  rate_limited: 429,
  invalid_json: 502,
  schema_mismatch: 502,
  invalid_response: 502,
  upstream_error: 502,
  network_error: 502,
  missing_api_key: 503,
  timeout: 504,
});

// Fixed strings only: upstream (Gemini/Firestore) messages can echo secrets or user data.
const MESSAGES = Object.freeze({
  unauthenticated: 'Sign in to get recommendations.',
  invalid_input: 'The recommendation request was malformed.',
  not_a_member: 'You are not a member of this group.',
  unknown_group: 'That group does not exist.',
  payload_too_large: 'The recommendation request was too large.',
  empty_payload: 'There is not enough information to make recommendations yet.',
  rate_limited: 'Recommendations are busy right now. Try again shortly.',
  invalid_json: 'The recommendation service returned an unreadable answer.',
  schema_mismatch: 'The recommendation service returned an unexpected answer.',
  invalid_response: 'The recommendation service returned no answer.',
  upstream_error: 'The recommendation service is unavailable.',
  network_error: 'Could not reach the recommendation service.',
  missing_api_key: 'Recommendations are not configured on the server.',
  timeout: 'The recommendation service took too long to respond.',
});

const MAX_GROUP_ID_LENGTH = 128;

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Returns the validated `{groupId, search, travelResults}` or `null`. Any `uid` in the body is ignored. */
function parseBody(body) {
  if (!isPlainObject(body)) return null;
  const { groupId, search = {}, travelResults = [] } = body;
  // '/' would make Firestore's doc() throw instead of just not finding a group.
  if (typeof groupId !== 'string' || !groupId || groupId.length > MAX_GROUP_ID_LENGTH || groupId.includes('/')) {
    return null;
  }
  if (!isPlainObject(search) || !Array.isArray(travelResults) || !travelResults.every(isPlainObject)) return null;
  return { groupId, search, travelResults };
}

/**
 * @param {{
 *   verifyIdToken: (authorizationHeader?: string) => Promise<{uid: string}>,
 *   loadRawData: (args: {uid: string, groupId: string, travelResults: object[]}) => Promise<object>,
 *   geminiClient: {generateRecommendation: Function},
 *   log?: (line: string) => void,
 * }} deps
 */
function createRecommendationsHandler({ verifyIdToken, loadRawData, geminiClient, log = console.error }) {
  return async function recommendationsHandler(req, res) {
    const startedAt = Date.now();
    const fail = (error, { status = STATUS_BY_ERROR[error], retryAfterSeconds } = {}) => {
      log(`recommendations failed: ${error} (${Date.now() - startedAt}ms)`);
      if (Number.isFinite(retryAfterSeconds)) res.set('Retry-After', String(retryAfterSeconds));
      return res.status(status).json({ ok: false, error, message: MESSAGES[error] });
    };

    try {
      let uid;
      try {
        ({ uid } = await verifyIdToken(req.get('Authorization')));
      } catch {
        return fail('unauthenticated');
      }

      const body = parseBody(req.body);
      if (!body) return fail('invalid_input');

      let rawData;
      try {
        rawData = await loadRawData({ uid, groupId: body.groupId, travelResults: body.travelResults });
      } catch {
        return fail('upstream_error', { status: 503 });
      }

      const filtered = buildRecommendationPayload(
        { requestingUserId: uid, groupId: body.groupId, currentSearch: body.search },
        rawData
      );
      if (!filtered.allowed) return fail(filtered.reason);

      const prompt = buildRecommendationPrompt(filtered.payload);
      if (!prompt.ok) {
        return fail(prompt.error, prompt.error === 'empty_payload' ? {} : { status: 500 });
      }

      const generated = await geminiClient.generateRecommendation({ payload: filtered.payload, prompt: prompt.prompt });
      if (!generated.ok) {
        // Gemini's own invalid_input can only come from a bug here, not from the caller.
        if (generated.error === 'invalid_input') return fail('upstream_error', { status: 500 });
        return fail(generated.error, { retryAfterSeconds: generated.retryAfterSeconds });
      }

      const parsed = parseRecommendationResponse(generated.text);
      if (!parsed.ok) return fail(parsed.error);

      return res.json({ ok: true, data: parsed.data });
    } catch {
      return fail('upstream_error', { status: 500 });
    }
  };
}

/** Express error middleware for the route's `express.json()` body parser. */
function bodyErrorHandler(err, req, res, next) {
  const tooLarge = err && err.type === 'entity.too.large';
  if (!tooLarge && !(err && err.type === 'entity.parse.failed')) return next(err);
  const error = tooLarge ? 'payload_too_large' : 'invalid_input';
  return res.status(STATUS_BY_ERROR[error]).json({ ok: false, error, message: MESSAGES[error] });
}

module.exports = { createRecommendationsHandler, bodyErrorHandler, STATUS_BY_ERROR };
