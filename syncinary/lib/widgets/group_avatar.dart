import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A group's round photo, or the gradient group icon when it has none or the
/// photo fails to load.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.photoUrl,
    required this.size,
    this.glow = false,
  });

  final String? photoUrl;
  final double size;

  /// Adds the soft accent shadow used on the group page header.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.group_rounded, color: Colors.white, size: size * 0.43);
    final url = photoUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.accentStart.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? fallback
          : Image.network(
              url,
              key: ValueKey(url),
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Firebase Storage download URLs don't send CORS headers unless
              // the bucket is configured for it; falling back to an <img>
              // element lets web show the photo either way.
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
