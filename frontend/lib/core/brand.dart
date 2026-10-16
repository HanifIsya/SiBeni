import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/theme.dart';

/// The SI BENI brand mark.
///
/// One artwork source (`assets/images/logo_launcher.png`) feeds the Android
/// launcher, the app bar, and the auth hero, so the identity can never drift
/// between the home screen and the app.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 34,
    this.rounded = true,
    this.showShadow = false,
  });

  final double size;
  final bool rounded;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final radius = rounded ? size * 0.28 : 0.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.30),
                  blurRadius: size * 0.55,
                  offset: Offset(0, size * 0.22),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/logo_mark.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          // The asset already carries the brand background.
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

/// The hero lockup shown on the auth screen.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 96});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BrandMark(size: markSize, rounded: true, showShadow: true),
        const SizedBox(height: 18),
        const Text(
          AppConfig.appName,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppConfig.appTagline.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }
}