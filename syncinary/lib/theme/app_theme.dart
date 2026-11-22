import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────
/// Syncinary Design System — "Midnight Voyage"
/// A premium dark-mode palette inspired by dusk skies
/// and ocean-blue accents for a modern travel app.
/// ─────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ── Core palette ──────────────────────────────────────
  static const Color background = Color(0xFF101622); // deep navy
  static const Color surface = Color(0xFF192231); // card / panel
  static const Color surfaceLight = Color(0xFF222E40); // elevated surface
  static const Color border = Color(0xFF354359); // subtle borders

  // ── Brand accent (gradient endpoints) ─────────────────
  static const Color accentStart = Color(0xFF95B1FF); // readable blue accent
  static const Color accentEnd = Color(0xFFACC5FF); // light blue
  static const Color accentMid = Color(0xFF95B1FF); // companion accent

  // ── Semantic ──────────────────────────────────────────
  static const Color success = Color(0xFF75D6AE);
  static const Color warning = Color(0xFFEFC475);
  static const Color error = Color(0xFFFF949B);

  // ── Text ──────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF2F5FA);
  static const Color textSecondary = Color(0xFFB9C5D6);
  static const Color textMuted = Color(0xFF9CAEC5);

  // ── Misc ──────────────────────────────────────────────
  static const Color shimmer = Color(0x1AFFFFFF); // 10 % white
  static const Color shadow = Color(0x40000000); // 25 % black

  /// Branded gradient used on buttons, app-bars, etc.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF4059B5), Color(0xFF315B96)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle background gradient for scaffolds.
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF101622), Color(0xFF151E2D)],
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
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    height: 1.4,
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

  /// Solid card surface with a subtle border.
  static BoxDecoration glassCard({double radius = 16}) => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border, width: 1),
  );

  /// Field states and spacing come from the shared Material theme.
  static InputDecoration inputDecoration({
    required String label,
    IconData? prefixIcon,
    IconData? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
    suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 20),
  );
}

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
    final enabled = onPressed != null && !isLoading;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled || isLoading ? AppColors.brandGradient : null,
        color: enabled || isLoading ? null : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: AppColors.textMuted,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                  semanticsLabel: 'Loading',
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
  }
}

ThemeData buildAppTheme() {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  const scheme = ColorScheme.dark(
    primary: AppColors.accentStart,
    onPrimary: AppColors.background,
    primaryContainer: AppColors.surfaceLight,
    onPrimaryContainer: AppColors.textPrimary,
    secondary: AppColors.accentEnd,
    onSecondary: AppColors.background,
    secondaryContainer: AppColors.surfaceLight,
    onSecondaryContainer: AppColors.textPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerHighest: AppColors.surfaceLight,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.error,
    onError: AppColors.background,
  );
  final buttonStyle = ElevatedButton.styleFrom(
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: shape,
    elevation: 0,
    textStyle: AppTextStyles.button,
    foregroundColor: AppColors.background,
    backgroundColor: AppColors.accentStart,
    disabledBackgroundColor: AppColors.surfaceLight,
    disabledForegroundColor: AppColors.textMuted,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.title,
      iconTheme: IconThemeData(color: AppColors.textSecondary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: AppColors.accentEnd),
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,
      errorMaxLines: 3,
      border: inputBorder(AppColors.border),
      enabledBorder: inputBorder(AppColors.border),
      disabledBorder: inputBorder(AppColors.border),
      focusedBorder: inputBorder(AppColors.accentStart, 2),
      errorBorder: inputBorder(AppColors.error),
      focusedErrorBorder: inputBorder(AppColors.error, 2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: shape,
        textStyle: AppTextStyles.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.accentEnd,
        shape: shape,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 520),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: AppTextStyles.title,
      contentTextStyle: AppTextStyles.body,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      constraints: BoxConstraints(maxWidth: 640),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      contentTextStyle: AppTextStyles.body,
      actionTextColor: AppColors.accentEnd,
      shape: shape,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedColor: AppColors.accentStart.withValues(alpha: 0.18),
      labelStyle: AppTextStyles.body,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.surfaceLight,
      headerForegroundColor: AppColors.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: ThemeData.dark().textTheme
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          headlineLarge: AppTextStyles.headline,
          titleLarge: AppTextStyles.title,
          titleMedium: AppTextStyles.subtitle,
          bodyMedium: AppTextStyles.body,
          bodySmall: AppTextStyles.caption,
          labelSmall: AppTextStyles.caption,
        ),
  );
}
