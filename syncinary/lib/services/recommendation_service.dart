import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/recommendation.dart';

/// Error codes a `/recommendations` call can fail with. Mirrors the `reason`
/// values from `proxy/llmDataFilter.js` (`allowed:false`), the codes from
/// `proxy/recommendationPrompt.js` (`PROMPT_ERRORS`/`RESPONSE_ERRORS`) and
/// `proxy/geminiClient.js` (`GEMINI_ERRORS`), plus two client-only codes for
/// failures the proxy never gets a chance to report.
abstract final class RecommendationError {
  // llmDataFilter.js `reason`
  static const invalidInput = 'invalid_input';
  static const unknownGroup = 'unknown_group';
  static const notAMember = 'not_a_member';
  static const payloadTooLarge = 'payload_too_large';
  // recommendationPrompt.js
  static const emptyPayload = 'empty_payload';
  static const invalidJson = 'invalid_json';
  static const schemaMismatch = 'schema_mismatch';
  // geminiClient.js
  static const missingApiKey = 'missing_api_key';
  static const timeout = 'timeout';
  static const rateLimited = 'rate_limited';
  static const upstreamError = 'upstream_error';
  static const networkError = 'network_error';
  static const invalidResponse = 'invalid_response';
  // Client-only: the request never came back as the proxy's `{ok}` shape.
  static const unreachable = 'unreachable';
  static const malformedResponse = 'malformed_response';
}

sealed class RecommendationResult {
  const RecommendationResult();
}

class RecommendationSuccess extends RecommendationResult {
  const RecommendationSuccess(this.data);
  final Recommendation data;
}

class RecommendationFailure extends RecommendationResult {
  const RecommendationFailure(this.error, this.message);
  final String error;
  final String message;
}

/// What an FR-104 suggestion request is grounded in for one search: the
/// travel results already fetched, plus the trip's group (optional — see
/// [RecommendationService] doc).
class SearchContext {
  const SearchContext({
    required this.origin,
    required this.destination,
    required this.departureDate,
    this.groupId,
    this.travelResults = const [],
  });

  final String origin;
  final String destination;
  final String departureDate;
  final String? groupId;
  final List<dynamic> travelResults;
}

/// Calls the proxy's `/recommendations` endpoint for FR-104 travel
/// suggestions. That route doesn't exist yet (#46) — every call fails with
/// [RecommendationError.unreachable] until a follow-up issue wires it up to
/// `llmDataFilter.js` -> `recommendationPrompt.js` -> `geminiClient.js`. This
/// class exists so the UI has a stable, testable contract to build against
/// in the meantime.
///
/// Preferences, budget, available dates and search history are never sent
/// from the client — `llmDataFilter.buildRecommendationPayload` is designed
/// to load those server-side for the verified caller, identified by a
/// Firebase ID token sent as `Authorization: Bearer <token>`. The client only
/// supplies the current search and its own travel results, matching the
/// `search`/`travelResults` fields `llmDataFilter.js` allows through.
///
/// [SearchContext.groupId] is sent through as-is, including `null` for a
/// personal (groupless) request. Note: on this branch, `buildRecommendationPayload`
/// still requires a group (the groupless path from issue #87 / PR #88 hasn't
/// merged into this stack yet), so a `null` groupId will come back as
/// `invalid_input` until #88 lands — that's a forward-looking contract on the
/// client side, not a bug here.
///
/// `client`, `baseUrl` and `idTokenProvider` are all injectable so tests can
/// supply a `MockClient` and a fake token without touching Firebase.
class RecommendationService {
  RecommendationService({
    http.Client? client,
    this.baseUrl = 'http://localhost:3000',
    Future<String?> Function()? idTokenProvider,
    this.timeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _idTokenProvider = idTokenProvider ?? _defaultIdTokenProvider;

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;
  final Future<String?> Function() _idTokenProvider;

  static Future<String?> _defaultIdTokenProvider() =>
      FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null);

  // Mirrors llmDataFilter.js's ALLOWED_TRAVEL_RESULT_FIELDS / MAX_ARRAY_ITEMS —
  // the server re-enforces these caps itself, but there's no reason to send a
  // raw SerpApi blob (or more than it will use) over the wire in the first place.
  static const int _maxTravelResults = 15;
  static const _allowedTravelResultFields = {
    'type',
    'price',
    'carrier',
    'departureTime',
    'arrivalTime',
    'location',
    'name',
  };

  Future<RecommendationResult> fetchRecommendations(SearchContext context) async {
    final token = await _idTokenProvider();
    final body = jsonEncode({
      'groupId': context.groupId,
      'search': {
        'destination': context.destination,
        'startDate': context.departureDate,
        'query': '${context.origin} to ${context.destination}',
      },
      'travelResults': _reduceTravelResults(context.travelResults),
    });

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/recommendations'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(timeout);
    } on Exception {
      return const RecommendationFailure(
        RecommendationError.unreachable,
        'Could not reach the recommendations service.',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      return const RecommendationFailure(
        RecommendationError.malformedResponse,
        'The recommendations service returned an unreadable response.',
      );
    } on TypeError {
      return const RecommendationFailure(
        RecommendationError.malformedResponse,
        'The recommendations service returned an unreadable response.',
      );
    }

    if (json['ok'] != true) {
      return RecommendationFailure(
        (json['error'] as String?) ?? RecommendationError.malformedResponse,
        (json['message'] as String?) ?? 'The recommendations service returned an error.',
      );
    }

    try {
      final data = json['data'] as Map<String, dynamic>;
      return RecommendationSuccess(Recommendation.fromJson(data));
    } on TypeError {
      return const RecommendationFailure(
        RecommendationError.malformedResponse,
        'The recommendations service returned data in an unexpected shape.',
      );
    }
  }

  List<Map<String, dynamic>> _reduceTravelResults(List<dynamic> raw) {
    return raw.whereType<Map>().take(_maxTravelResults).map((item) {
      final out = <String, dynamic>{};
      for (final field in _allowedTravelResultFields) {
        if (item.containsKey(field)) out[field] = item[field];
      }
      return out;
    }).toList();
  }
}
