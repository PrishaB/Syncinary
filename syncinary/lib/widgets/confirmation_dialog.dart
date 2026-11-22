import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A compact confirmation with a distinct destructive action.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
  bool isDestructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      icon: Icon(
        isDestructive
            ? Icons.warning_amber_rounded
            : Icons.help_outline_rounded,
        color: isDestructive ? AppColors.error : AppColors.accentEnd,
      ),
      title: Text(message, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          key: const Key('confirmation_dialog_confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive
                ? AppColors.error
                : AppColors.accentStart,
            foregroundColor: AppColors.background,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
