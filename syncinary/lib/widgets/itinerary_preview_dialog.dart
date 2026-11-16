import 'package:flutter/material.dart';

import '../services/recommendation_to_schedule.dart';
import '../theme/app_theme.dart';

/// Lists [items] by day and asks to add them, or to suggest them when
/// [suggest]. [skipped] items already in the itinerary are only counted.
/// Returns true on confirm.
Future<bool> showItineraryPreview(
  BuildContext context, {
  required List<PendingScheduleItem> items,
  required int skipped,
  required bool suggest,
  required String Function(DateTime) formatDay,
}) async {
  final byDay = <String, List<PendingScheduleItem>>{};
  for (final item in items) {
    byDay.putIfAbsent(item.dayKey, () => []).add(item);
  }
  final verb = suggest ? 'Suggest' : 'Add';
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('$verb ${items.length} ${items.length == 1 ? 'item' : 'items'}?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final day in byDay.values) ...[
                Text(formatDay(day.first.date),
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                for (final item in day)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• ${item.title}', style: AppTextStyles.caption),
                  ),
                const SizedBox(height: 12),
              ],
              if (skipped > 0)
                Text('$skipped already in the itinerary will be skipped.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('$verb ${items.length} ${items.length == 1 ? 'item' : 'items'}'),
        ),
      ],
    ),
  );
  return result ?? false;
}
