'use strict';

/**
 * Backend client for the Gemini Generative Language API (FR-104 / SYS 109).
 *
 * Talks to Gemini only — it does not decide what data is safe to send (see
 * `llmDataFilter.js` for that) and does not build prompt text (a later issue
 * owns prompt design). Every call returns a plain discriminated result object
 * instead of throwing, mirroring `llmDataFilter.js`'s `{allowed, ...}` style,
 * so callers handle success/failure uniformly.
 *
 * The API key is read from `process.env.GEMINI_API_KEY` (or passed directly
 * for tests) and is never logged or included in an error message — see
 * `redact()`. Run the server with `node --env-file=proxy/.env server.js` to
 * load it locally (see `proxy/README.md`); there is no `dotenv` dependency.
 */

const DEFAULT_MODEL = 'gemini-2.0-flash';
const DEFAULT_TIMEOUT_MS = 20000;
const DEFAULT_BASE_URL = 'https://generativelanguage.googleapis.com';

const GEMINI_ERRORS = Object.freeze({
  MISSING_API_KEY: 'missing_api_key',
  INVALID_INPUT: 'invalid_input',
  TIMEOUT: 'timeout',
  RATE_LIMITED: 'rate_limited',
  UPSTREAM_ERROR: 'upstream_error',
  NETWORK_ERROR: 'network_error',
  INVALID_RESPONSE: 'invalid_response',
});

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Strips the API key out of any string before it can reach a caller/log. */
function redact(text, apiKey) {
  if (typeof text !== 'string' || !apiKey) return text;
  return text.split(apiKey).join('[REDACTED]');
}

/** Maps Gemini's `usageMetadata` to the result's camelCase `usage` field, omitting it if empty. */
function pickUsage(usageMetadata) {
  if (!isPlainObject(usageMetadata)) return undefined;
  const usage = {};
  if (typeof usageMetadata.promptTokenCount === 'number') usage.promptTokens = usageMetadata.promptTokenCount;
  if (typeof usageMetadata.candidatesTokenCount === 'number') usage.candidatesTokens = usageMetadata.candidatesTokenCount;
  if (typeof usageMetadata.totalTokenCount === 'number') usage.totalTokens = usageMetadata.totalTokenCount;
  return Object.keys(usage).length ? usage : undefined;
}

function resolveConfig(options) {
  const opts = isPlainObject(options) ? options : {};
  return {
    apiKey: opts.apiKey || process.env.GEMINI_API_KEY || '',
    model: opts.model || process.env.GEMINI_MODEL || DEFAULT_MODEL,
    timeoutMs: opts.timeoutMs || Number(process.env.GEMINI_TIMEOUT_MS) || DEFAULT_TIMEOUT_MS,
    baseUrl: opts.baseUrl || process.env.GEMINI_BASE_URL || DEFAULT_BASE_URL,
    fetchImpl: opts.fetchImpl || globalThis.fetch,
  };
}

/**
 * @param {{apiKey?: string, model?: string, timeoutMs?: number, baseUrl?: string, fetchImpl?: Function}} [options]
 */
function createGeminiClient(options) {
  const { apiKey, model, timeoutMs, baseUrl, fetchImpl } = resolveConfig(options);

  /**
   * @param {{payload: object, prompt: string, timeoutMs?: number, signal?: AbortSignal}} args
   * @returns {Promise<
   *   {ok: true, text: string, model: string, finishReason?: string, raw: object, latencyMs: number, usage?: object} |
   *   {ok: false, error: string, message: string, status?: number, retryAfterSeconds?: number, latencyMs: number}
   * >}
   */
  async function generateRecommendation(args) {
    const startedAt = Date.now();
    const latency = () => Date.now() - startedAt;
    const { payload, prompt, timeoutMs: callTimeoutMs, signal: callerSignal } = isPlainObject(args) ? args : {};

    if (!isPlainObject(payload) || typeof prompt !== 'string' || prompt.trim() === '') {
      return { ok: false, error: GEMINI_ERRORS.INVALID_INPUT, message: 'payload must be an object and prompt must be a non-empty string', latencyMs: latency() };
    }

    if (!apiKey) {
      return {
        ok: false,
        error: GEMINI_ERRORS.MISSING_API_KEY,
        message: 'GEMINI_API_KEY is not set. Pass apiKey to createGeminiClient(), or run with `node --env-file=.env`.',
        latencyMs: latency(),
      };
    }

    const url = `${baseUrl}/v1beta/models/${model}:generateContent`;
    const text = `${prompt}\n\n${JSON.stringify(payload)}`;
    const body = JSON.stringify({ contents: [{ role: 'user', parts: [{ text }] }] });
    const signal = callerSignal || AbortSignal.timeout(callTimeoutMs || timeoutMs);

    let response;
    try {
      response = await fetchImpl(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
        body,
        signal,
      });
    } catch (err) {
      const name = err && err.name;
      if (name === 'AbortError' || name === 'TimeoutError') {
        return { ok: false, error: GEMINI_ERRORS.TIMEOUT, message: 'Gemini request timed out', latencyMs: latency() };
      }
      return {
        ok: false,
        error: GEMINI_ERRORS.NETWORK_ERROR,
        message: redact(String((err && err.message) || err), apiKey),
        latencyMs: latency(),
      };
    }

    if (response.status === 429) {
      const retryAfterHeader = response.headers && typeof response.headers.get === 'function' ? response.headers.get('Retry-After') : null;
      const retryAfterSeconds = retryAfterHeader === null ? undefined : Number(retryAfterHeader);
      const result = { ok: false, error: GEMINI_ERRORS.RATE_LIMITED, message: 'Gemini rate limit exceeded', status: 429, latencyMs: latency() };
      if (Number.isFinite(retryAfterSeconds)) result.retryAfterSeconds = retryAfterSeconds;
      return result;
    }

    if (!response.ok) {
      let bodyText = '';
      try {
        bodyText = await response.text();
      } catch {
        // best-effort — an unreadable error body is still reported via status alone
      }
      return {
        ok: false,
        error: GEMINI_ERRORS.UPSTREAM_ERROR,
        message: redact(`Gemini returned status ${response.status}: ${bodyText}`.slice(0, 500), apiKey),
        status: response.status,
        latencyMs: latency(),
      };
    }

    let json;
    try {
      json = await response.json();
    } catch {
      return { ok: false, error: GEMINI_ERRORS.INVALID_RESPONSE, message: 'Gemini response was not valid JSON', latencyMs: latency() };
    }

    const candidate = isPlainObject(json) && Array.isArray(json.candidates) ? json.candidates[0] : undefined;
    const parts = candidate && isPlainObject(candidate.content) && Array.isArray(candidate.content.parts) ? candidate.content.parts : undefined;
    const combinedText = parts ? parts.map((part) => (part && typeof part.text === 'string' ? part.text : '')).join('') : '';

    if (!parts || combinedText === '') {
      const blockReason = isPlainObject(json) && isPlainObject(json.promptFeedback) ? json.promptFeedback.blockReason : undefined;
      return {
        ok: false,
        error: GEMINI_ERRORS.INVALID_RESPONSE,
        message: blockReason ? `Gemini blocked the request: ${blockReason}` : 'Gemini response had no usable candidate text',
        latencyMs: latency(),
      };
    }

    const result = { ok: true, text: combinedText, model, raw: json, latencyMs: latency() };
    if (typeof candidate.finishReason === 'string') result.finishReason = candidate.finishReason;
    const usage = pickUsage(json.usageMetadata);
    if (usage) result.usage = usage;
    return result;
  }

  return { generateRecommendation };
}

module.exports = { createGeminiClient, GEMINI_ERRORS };
