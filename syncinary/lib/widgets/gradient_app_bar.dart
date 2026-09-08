import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared translucent gradient app bar used across the app's screens.
/// Extracted from the duplicated `flexibleSpace` blocks in
/// `itinerary_builder.dart` / `flight_search.dart` so new screens
/// (and those two, eventually) share one definition.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      leading: leading,
      actions: actions,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withValues(alpha: 0.95),
              AppColors.surface.withValues(alpha: 0.80),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      title: titleWidget ?? Text(title ?? '', style: AppTextStyles.title),
    );
  }
}
