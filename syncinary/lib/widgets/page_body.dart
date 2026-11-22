import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Keeps page backgrounds full-bleed while giving content a readable width.
/// The child owns scrolling, so lists remain lazy and forms keep their focus.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.maxWidth = 1120});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
    child: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    ),
  );
}
