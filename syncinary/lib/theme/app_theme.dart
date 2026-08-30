import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────
/// Syncinary Design System — "Midnight Voyage"
/// A premium dark-mode palette inspired by dusk skies
/// and ocean-blue accents for a modern travel app.
/// ─────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Core palette ──────────────────────────────────────
  static const Color background      = Color(0xFF0F1123);   // deep navy
  static const Color surface         = Color(0xFF1A1D36);   // card / panel
  static const Color surfaceLight    = Color(0xFF242849);   // elevated surface
  static const Color border          = Color(0xFF2E3358);   // subtle borders

  // ── Brand accent (gradient endpoints) ─────────────────
  static const Color accentStart     = Color(0xFF6C63FF);   // vivid indigo
  static const Color accentEnd       = Color(0xFF3DD6F5);   // cyan
  static const Color accentMid       = Color(0xFF8B5CF6);   // purple mid-tone

  // ── Semantic ──────────────────────────────────────────
  static const Color success         = Color(0xFF22C55E);
  static const Color warning         = Color(0xFFFBBF24);
  static const Color error           = Color(0xFFEF4444);

  // ── Text ──────────────────────────────────────────────
  static const Color textPrimary     = Color(0xFFF0F0FF);
  static const Color textSecondary   = Color(0xFF9CA3C5);
  static const Color textMuted       = Color(0xFF5C6299);

  // ── Misc ──────────────────────────────────────────────
  static const Color shimmer         = Color(0x1AFFFFFF);   // 10 % white
  static const Color shadow          = Color(0x40000000);   // 25 % black

  /// Branded gradient used on buttons, app-bars, etc.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [accentStart, accentEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle background gradient for scaffolds.
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0F1123), Color(0xFF161938)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ─────────────────────────────────────────────────────────
// Text styles
// ─────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'Roboto'; // ships with Flutter

  static const TextStyle headline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  static const TextStyle navLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );
}

// ─────────────────────────────────────────────────────────
// Reusable decorations / shapes
// ─────────────────────────────────────────────────────────
class AppDecorations {
  AppDecorations._();

  /// Glassmorphic card surface.
  static BoxDecoration glassCard({double radius = 16}) => BoxDecoration(
    color: AppColors.surface.withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: const [
      BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  /// Input field decoration (consistent across all text fields).
  static InputDecoration inputDecoration({
    required String label,
    IconData? prefixIcon,
    IconData? suffixIcon,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        floatingLabelStyle: AppTextStyles.caption.copyWith(color: AppColors.accentEnd),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.accentEnd, size: 20)
            : null,
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: AppColors.textMuted, size: 20)
            : null,
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentEnd, width: 1.5),
        ),
      );

  /// Primary gradient button style.
  static ButtonStyle primaryButton = ButtonStyle(
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    ),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevation: WidgetStateProperty.all(0),
    backgroundColor: WidgetStateProperty.all(Colors.transparent),
    foregroundColor: WidgetStateProperty.all(AppColors.textPrimary),
    textStyle: WidgetStateProperty.all(AppTextStyles.button),
  );

  /// Secondary (outline) button style.
  static ButtonStyle secondaryButton = ButtonStyle(
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    ),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    elevation: WidgetStateProperty.all(0),
    backgroundColor: WidgetStateProperty.all(Colors.transparent),
    foregroundColor: WidgetStateProperty.all(AppColors.textSecondary),
    textStyle: WidgetStateProperty.all(AppTextStyles.button),
  );
}

// ─────────────────────────────────────────────────────────
// Helper widget: Gradient-filled button
// ─────────────────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        gradient: onPressed != null ? AppColors.brandGradient : null,
        color: onPressed == null ? AppColors.surfaceLight : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.accentStart.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.textPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: AppColors.textPrimary, size: 20),
                        const SizedBox(width: 10),
                      ],
                      Text(label, style: AppTextStyles.button),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// MaterialApp ThemeData (plug into main.dart)
// ─────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.dark(
      primary: AppColors.accentStart,
      secondary: AppColors.accentEnd,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.title,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      labelStyle: AppTextStyles.caption,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      headerBackgroundColor: AppColors.surfaceLight,
      headerForegroundColor: AppColors.textPrimary,
      dayForegroundColor: WidgetStateProperty.all(AppColors.textPrimary),
      todayForegroundColor: WidgetStateProperty.all(AppColors.accentEnd),
      todayBorder: const BorderSide(color: AppColors.accentEnd),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      headlineLarge: AppTextStyles.headline,
      titleLarge: AppTextStyles.title,
      titleMedium: AppTextStyles.subtitle,
      bodyMedium: AppTextStyles.body,
      labelSmall: AppTextStyles.caption,
    ),
  );
}
