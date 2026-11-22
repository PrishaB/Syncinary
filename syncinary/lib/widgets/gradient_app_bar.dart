import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'settings_panel.dart';

/// Shared app bar with a quiet surface and consistent account controls.
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
      centerTitle: false,
      leading: leading,
      actions: [...?actions, const SettingsButton()],
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      title: titleWidget ?? Text(title ?? '', style: AppTextStyles.title),
    );
  }
}
