import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A brief brand-gradient confirmation panel — mirrors the wireframe's
/// "[Trip name] successfully deleted" / "[User name] successfully deleted"
/// full-panel success states. Auto-dismisses itself.
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentStart.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    },
  );
}
