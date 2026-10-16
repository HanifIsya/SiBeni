import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'pressable.dart';

/// The single card primitive used across the product.
///
/// One elevation language, one radius language, one border language — that
/// restraint is what makes the interface read as a system rather than a pile
/// of widgets.
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;
  final Color? color;
  final bool elevated;
  final Color? borderColor;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent;

    final content = Container(
      decoration: BoxDecoration(
        color: color ?? AppTheme.surface,
        borderRadius: AppTheme.brLg,
        border: Border.all(color: borderColor ?? AppTheme.hairline),
        boxShadow: elevated ? AppTheme.shadowLift : AppTheme.shadowSoft,
      ),
      child: ClipRRect(
        borderRadius: AppTheme.brLg,
        child: Stack(
          children: [
            if (accentColor != null)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: accentColor),
              ),
            Padding(
              padding: accentColor != null
                  ? padding.add(const EdgeInsetsDirectional.only(start: 4))
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