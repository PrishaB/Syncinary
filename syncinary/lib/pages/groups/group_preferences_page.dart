import 'package:flutter/material.dart';

import '../../models/group_preferences_summary.dart';
import '../../models/user_preferences.dart';
import '../../services/group_preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_app_bar.dart';

class GroupPreferencesPage extends StatefulWidget {
  const GroupPreferencesPage({
    super.key,
    required this.groupId,
    required this.groupName,
    this.service,
  });

  final String groupId;
  final String groupName;
  final GroupPreferencesService? service;

  @override
  State<GroupPreferencesPage> createState() => _GroupPreferencesPageState();
}

class _GroupPreferencesPageState extends State<GroupPreferencesPage> {
  late final _service = widget.service ?? GroupPreferencesService();
  late Stream<GroupPreferencesSummary?> _summary = _service.watchSummary(
    widget.groupId,
  );

  void _refresh() => setState(() {
    _summary = _service.watchSummary(widget.groupId);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Group Preferences',
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Refresh preferences',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: StreamBuilder<GroupPreferencesSummary?>(
            key: ObjectKey(_summary),
            stream: _summary,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final denied =
                    snapshot.error is GroupPreferencesAccessException;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          denied
                              ? 'Sign in with a verified account that belongs to this group to view its summary.'
                              : 'Could not load group preferences. Please try again.',
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        GradientButton(onPressed: _refresh, label: 'Retry'),
                      ],
                    ),
                  ),
                );
              }
              final summary = snapshot.data;
              if (summary == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(widget.groupName, style: AppTextStyles.headline),
                        const SizedBox(height: 8),
                        Text(
                          'Plan around what your group enjoys.',
                          style: AppTextStyles.subtitle,
                        ),
                        const SizedBox(height: 24),
                        _SummaryCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.groups_outlined,
                                color: AppColors.accentEnd,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${summary.respondentCount} of ${summary.memberCount} members have shared preferences',
                                style: AppTextStyles.title,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Only combined responses are shown, without names or individual answers. '
                                'Each category needs at least ${GroupPreferencesSummary.minimumResponses} responses before results appear.',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (summary.respondentCount == 0) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'No preferences shared yet. Members can add theirs using Set Preferences on the group page.',
                                  style: AppTextStyles.body,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 760) {
                              return _PreferenceColumn(fields: summary.fields);
                            }
                            // Each column flows independently so a long chart
                            // doesn't leave a gap beneath its shorter neighbor.
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _PreferenceColumn(
                                    fields: [
                                      for (
                                        var i = 0;
                                        i < summary.fields.length;
                                        i += 2
                                      )
                                        summary.fields[i],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _PreferenceColumn(
                                    fields: [
                                      for (
                                        var i = 1;
                                        i < summary.fields.length;
                                        i += 2
                                      )
                                        summary.fields[i],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PreferenceColumn extends StatelessWidget {
  const _PreferenceColumn({required this.fields});
  final List<PreferenceSummary> fields;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < fields.length; i++) ...[
        if (i > 0) const SizedBox(height: 20),
        _PreferenceCard(summary: fields[i]),
      ],
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: AppDecorations.glassCard(),
    child: child,
  );
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.summary});
  final PreferenceSummary summary;

  @override
  Widget build(BuildContext context) {
    final options = summary.counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return _SummaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.field.title, style: AppTextStyles.title),
          const SizedBox(height: 4),
          Text(
            '${summary.responseCount} ${summary.responseCount == 1 ? 'response' : 'responses'}',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (!summary.isVisible)
            Text(
              summary.responseCount == 0
                  ? 'No responses yet.'
                  : 'Summary appears after at least ${GroupPreferencesSummary.minimumResponses} members answer this category.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else if (summary.field.input == PreferenceInput.amount) ...[
            Text(
              '${summary.field.id == 'budgetPerPersonUsd' ? '\$' : ''}${summary.average!.toStringAsFixed(0)}',
              style: AppTextStyles.headline.copyWith(
                color: AppColors.accentEnd,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summary.field.id == 'budgetPerPersonUsd'
                  ? 'Average total trip budget per person (USD)'
                  : 'Average ${summary.field.amountLabel.toLowerCase()}',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 8),
            const Text(
              'Blank budgets are excluded from the average.',
              style: AppTextStyles.body,
            ),
          ] else ...[
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                  label:
                      '${option.key}: ${option.value} of ${summary.responseCount} responses',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(option.key, style: AppTextStyles.body),
                              Text(
                                '${option.value} of ${summary.responseCount} (${(option.value / summary.responseCount * 100).round()}%)',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: option.value / summary.responseCount,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: AppColors.surfaceLight,
                          color: AppColors.accentEnd,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          if (summary.field.input == PreferenceInput.multipleChoice) ...[
            const SizedBox(height: 8),
            Text(
              'Only selected options count as responses. Members may choose more than one.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
