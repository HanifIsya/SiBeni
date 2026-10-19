import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'chamfer.dart';
import 'pressable.dart';

/// The single card primitive used across the product.
///
/// One elevation language, one radius language, one border language — that
/// restraint is what makes the interface read as a system rather than a pile
/// of widgets.
///
/// The silhouette is deliberately angular: a 10 px chamfer on the trailing-top
/// corner instead of a fully rounded pill. Flat cards with soft shadows read as
/// "template"; a cut corner reads as equipment panel.
class SbCard extends StatelessWidget {
  const SbCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.lg),
    this.onTap,
    this.accent,
    this.color,
    this.elevated = false,
    this.borderColor,
    this.clip = false,
    this.cut = 10,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;
  final Color? color;
  final bool elevated;
  final Color? borderColor;
  final bool clip;

  /// Size of the cut corner. Set to 0 for a plain rectangle.
  final double cut;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent;
    final border = ChamferBorder(
      color: borderColor ?? AppTheme.hairline,
      width: 1,
      radius: 16,
      cut: cut,
    );

    final content = DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? AppTheme.surface,
        shape: border,
        shadows: elevated
            ? AppTheme.shadowLift
            : const [
                BoxShadow(
                  color: Color(0x0D0B1622),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: ClipPath(
        clipper: ChamferClipper(radius: 16, cut: cut),
        child: Stack(
          children: [
            if (accentColor != null)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: accentColor),
              ),
            Padding(
              padding: accentColor != null
                  ? padding.add(const EdgeInsetsDirectional.only(start: 3))
                  : padding,
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return content;
    return Pressable(onTap: onTap, child: content);
  }
}

/// A compact glass-like surface for dense metadata blocks.
class SbPanel extends StatelessWidget {
  const SbPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.md),
    this.color = AppTheme.surfaceMuted,
    this.borderRadius,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BorderRadius? borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? AppTheme.brMd,
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: child,
    );
  }
}

/// Dark, high-contrast panel used for the primary "situation" readout.
class SbHeroPanel extends StatelessWidget {
  const SbHeroPanel({super.key, required this.child, this.padding = const EdgeInsets.all(AppTheme.xl)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: AppTheme.brXl,
        boxShadow: AppTheme.shadowLift,
      ),
      child: child,
    );
  }
}