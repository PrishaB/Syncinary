import 'package:flutter/material.dart';

import '../models/recommendation.dart';
import '../services/recommendation_service.dart';
import '../theme/app_theme.dart';

/// FR-104 suggestions panel: fetches once in [initState] and renders one of
/// four states — loading, success, empty, or error with retry. It owns its
/// future independently of whatever page embeds it, so a slow or failed
/// recommendation never blocks the rest of that page's content.
class SuggestionsSection extends StatefulWidget {
  const SuggestionsSection({
    super.key,
    required this.service,
    required this.searchContext,
  });

  final RecommendationService service;
  final SearchContext searchContext;

  @override
  State<SuggestionsSection> createState() => _SuggestionsSectionState();
}

class _SuggestionsSectionState extends State<SuggestionsSection> {
  late Future<RecommendationResult> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchRecommendations(widget.searchContext);
  }

  void _retry() {
    setState(() {
      _future = widget.service.fetchRecommendations(widget.searchContext);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecommendationResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _loadingCard();
        }
        final result = snapshot.data;
        if (result is RecommendationSuccess) {
          return result.data.destinations.isEmpty ? _emptyCard() : _successCard(result.data);
        }
        if (result is RecommendationFailure) {
          // empty_payload means "not enough data to recommend from", not a
          // failure worth alarming the user about.
          return result.error == RecommendationError.emptyPayload
              ? _emptyCard()
              : _errorCard();
        }
        return _emptyCard();
      },
    );
  }

  Widget _card({required Key key, required Widget child}) => Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.glassCard(),
        child: child,
      );

  Widget _loadingCard() => _card(
        key: const Key('suggestions-loading'),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accentEnd),
            ),
            const SizedBox(width: 14),
            Text('Finding suggestions…',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _emptyCard() => _card(
        key: const Key('suggestions-empty'),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'No suggestions yet — add preferences to your group to get personalized ideas.',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );

  Widget _errorCard() => _card(
        key: const Key('suggestions-error'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 14),
                // A generic message, not the raw failure `message` — that can
                // carry backend/upstream detail (e.g. an HTTP status and
                // truncated body) that shouldn't be shown to end users.
                Expanded(
                  child: Text("Couldn't load suggestions.", style: AppTextStyles.body),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('suggestions-retry'),
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.accentEnd),
                label: Text('Retry', style: AppTextStyles.body.copyWith(color: AppColors.accentEnd)),
              ),
            ),
          ],
        ),
      );

  Widget _successCard(Recommendation data) => _card(
        key: const Key('suggestions-success'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.accentEnd, size: 20),
                const SizedBox(width: 10),
                Text('Suggestions for you', style: AppTextStyles.title.copyWith(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            Text(data.summary, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            for (final destination in data.destinations)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _destinationTile(destination, data),
              ),
            if (data.warnings.isNotEmpty)
              Text(data.warnings.join(' '), style: AppTextStyles.caption),
          ],
        ),
      );

  Widget _destinationTile(Destination destination, Recommendation data) {
    final activityCount = data.activitiesFor(destination.id).length;
    final dayCount = data.dayCountFor(destination.id);
    final subtitle = [
      if (activityCount > 0) '$activityCount ${activityCount == 1 ? 'activity' : 'activities'}',
      if (dayCount > 0) '$dayCount-day itinerary',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  destination.region != null
                      ? '${destination.name}, ${destination.region}'
                      : destination.name,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '~\$${destination.estimatedCostPerPerson.amount.round()}/person',
                style: AppTextStyles.caption.copyWith(color: AppColors.accentEnd),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(destination.rationale, style: AppTextStyles.caption),
          if (destination.matchedPreferences.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final pref in destination.matchedPreferences) _chip(pref)],
            ),
          ],
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentStart.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.accentEnd)),
      );
}
