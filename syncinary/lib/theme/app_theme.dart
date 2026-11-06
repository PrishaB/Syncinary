import 'package:flutter/material.dart';

/// Syncinary's Midnight Voyage palette and its daylight counterpart.
/// Resolve through the widget context so existing routes rebuild on a change.
class AppColors {
  const AppColors._(this.brightness);

  final Brightness brightness;
  bool get _dark => brightness == Brightness.dark;

  static const dark = AppColors._(Brightness.dark);
  static const light = AppColors._(Brightness.light);

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  Color get background =>
      _dark ? const Color(0xFF0F1123) : const Color(0xFFF4F6FC);
  Color get surface =>
      _dark ? const Color(0xFF1A1D36) : const Color(0xFFFFFFFF);
  Color get surfaceLight =>
      _dark ? const Color(0xFF242849) : const Color(0xFFEAF0FA);
  Color get border => _dark ? const Color(0xFF2E3358) : const Color(0xFFCDD3E6);

  Color get accentStart =>
      _dark ? const Color(0xFF6C63FF) : const Color(0xFF574BD8);
  Color get accentEnd =>
      _dark ? const Color(0xFF3DD6F5) : const Color(0xFF007F9C);
  Color get accentMid =>
      _dark ? const Color(0xFF8B5CF6) : const Color(0xFF7040C5);

  Color get success =>
      _dark ? const Color(0xFF22C55E) : const Color(0xFF16713A);
  Color get warning =>
      _dark ? const Color(0xFFFBBF24) : const Color(0xFF8A5A00);
  Color get error => _dark ? const Color(0xFFEF4444) : const Color(0xFFB42332);

  Color get textPrimary =>
      _dark ? const Color(0xFFF0F0FF) : const Color(0xFF18213D);
  Color get textSecondary =>
      _dark ? const Color(0xFF9CA3C5) : const Color(0xFF4E5875);
  Color get textMuted =>
      _dark ? const Color(0xFF929ABC) : const Color(0xFF5C6484);
  Color get shimmer =>
      _dark ? const Color(0x1AFFFFFF) : const Color(0x0D18213D);
  Color get shadow => _dark ? const Color(0x40000000) : const Color(0x1418213D);

  LinearGradient get brandGradient => LinearGradient(
    colors: [accentStart, accentEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get backgroundGradient => LinearGradient(
    colors: [
      background,
      _dark ? const Color(0xFF161938) : const Color(0xFFE8EEFA),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ─────────────────────────────────────────────────────────
// Text styles
// ─────────────────────────────────────────────────────────
class AppTextStyles {
  const AppTextStyles._(this._colors);

  final AppColors _colors;

  static AppTextStyles of(BuildContext context) =>
      AppTextStyles._(AppColors.of(context));

  static const String _fontFamily = 'Roboto'; // ships with Flutter

  TextStyle get headline => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: _colors.textPrimary,
    letterSpacing: -0.5,
  );

  TextStyle get title => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: _colors.textPrimary,
  );

  TextStyle get subtitle => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: _colors.textSecondary,
  );

  TextStyle get body => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: _colors.textPrimary,
  );

  TextStyle get caption => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: _colors.textMuted,
  );

  TextStyle get button => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: _colors.textPrimary,
    letterSpacing: 0.5,
  );

  TextStyle get navLabel => TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: _colors.textSecondary,
  );
}

// ─────────────────────────────────────────────────────────
// Reusable decorations / shapes
// ─────────────────────────────────────────────────────────
class AppDecorations {
  AppDecorations._();

  /// Glassmorphic card surface.
  static BoxDecoration glassCard(BuildContext context, {double radius = 16}) =>
      BoxDecoration(
        color: AppColors.of(context).surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.of(context).border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).shadow,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      );

  /// Input field decoration (consistent across all text fields).
  static InputDecoration inputDecoration(
    BuildContext context, {
    required String label,
    IconData? prefixIcon,
    IconData? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    labelStyle: AppTextStyles.of(
      context,
    ).caption.copyWith(color: AppColors.of(context).textMuted),
    floatingLabelStyle: AppTextStyles.of(
      context,
    ).caption.copyWith(color: AppColors.of(context).accentEnd),
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, color: AppColors.of(context).accentEnd, size: 20)
        : null,
    suffixIcon: suffixIcon != null
        ? Icon(suffixIcon, color: AppColors.of(context).textMuted, size: 20)
        : null,
    filled: true,
    fillColor: AppColors.of(context).surfaceLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.of(context).border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: AppColors.of(context).accentEnd,
        width: 1.5,
      ),
    ),
  );

  /// Primary gradient button style.
  static ButtonStyle primaryButton(BuildContext context) => ButtonStyle(
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    ),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    elevation: WidgetStateProperty.all(0),
    backgroundColor: WidgetStateProperty.all(Colors.transparent),
    foregroundColor: WidgetStateProperty.all(Colors.white),
    textStyle: WidgetStateProperty.all(
      AppTextStyles.of(context).button.copyWith(color: Colors.white),
    ),
  );

  /// Secondary (outline) button style.
  static ButtonStyle secondaryButton(BuildContext context) => ButtonStyle(
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    ),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.of(context).border),
      ),
    ),
    elevation: WidgetStateProperty.all(0),
    backgroundColor: WidgetStateProperty.all(Colors.transparent),
    foregroundColor: WidgetStateProperty.all(
      AppColors.of(context).textSecondary,
    ),
    textStyle: WidgetStateProperty.all(AppTextStyles.of(context).button),
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
        gradient: onPressed != null
            ? AppColors.of(context).brandGradient
            : null,
        color: onPressed == null ? AppColors.of(context).surfaceLight : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.of(
                    context,
                  ).accentStart.withValues(alpha: 0.35),
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
                ? const SizedBox(height: 22, child: _ThreeDotsLoading())
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          style: AppTextStyles.of(
                            context,
                          ).button.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Animated three-dot loading indicator
// ─────────────────────────────────────────────────────────
class _ThreeDotsLoading extends StatefulWidget {
  const _ThreeDotsLoading();

  @override
  State<_ThreeDotsLoading> createState() => _ThreeDotsLoadingState();
}

class _ThreeDotsLoadingState extends State<_ThreeDotsLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            // Stagger each dot by ~0.2 of the animation cycle
            final delay = index * 0.2;
            final t = (_controller.value - delay) % 1.0;
            // Bounce: scale up then back down in the first half of each dot's cycle
            final scale = t < 0.5
                ? 0.5 +
                      (t * 2.0) *
                          0.5 // 0.5 → 1.0
                : 0.5 + ((1.0 - t) * 2.0) * 0.5; // 1.0 → 0.5
            final opacity = scale; // tie opacity to scale for a pulsing effect

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// MaterialApp ThemeData (plug into main.dart)
// ─────────────────────────────────────────────────────────
ThemeData buildAppTheme({Brightness brightness = Brightness.dark}) {
  final colors = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  final textStyles = AppTextStyles._(colors);
  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.accentStart,
    brightness: brightness,
    primary: colors.accentStart,
    onPrimary: Colors.white,
    secondary: colors.accentEnd,
    onSecondary: Colors.white,
    surface: colors.surface,
    onSurface: colors.textPrimary,
    onSurfaceVariant: colors.textSecondary,
    error: colors.error,
    outline: colors.border,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: colors.background,
    colorScheme: colorScheme,
    dividerColor: colors.border,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: textStyles.title,
      iconTheme: IconThemeData(color: colors.textMuted),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceLight,
      labelStyle: textStyles.caption,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.border),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colors.surface,
      headerBackgroundColor: colors.surfaceLight,
      headerForegroundColor: colors.textPrimary,
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.textPrimary.withValues(alpha: 0.38);
        }
        return states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colors.accentEnd;
      }),
      todayBorder: BorderSide(color: colors.accentEnd),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: TextTheme(
      headlineLarge: textStyles.headline,
      titleLarge: textStyles.title,
      titleMedium: textStyles.subtitle,
      bodyMedium: textStyles.body,
      labelSmall: textStyles.caption,
    ),
  );
}
