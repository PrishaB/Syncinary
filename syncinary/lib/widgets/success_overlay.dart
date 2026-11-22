import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A brief success confirmation that dismisses itself.
Future<void> showSuccessOverlay(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogContext) {
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
          Navigator.of(dialogContext).pop();
        }
      });
      return Dialog(
        backgroundColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 480),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            decoration: AppDecorations.glassCard(radius: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
