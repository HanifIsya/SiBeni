import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import 'chamfer.dart';
import 'pressable.dart';

enum SbButtonVariant { primary, secondary, danger, ghost }

/// The one button in the system.
///
/// Handles: min touch target, disabled + busy states, icon, and a press
/// animation large enough to read through gloves and dust.
class SbButton extends StatelessWidget {
  const SbButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = SbButtonVariant.primary,
    this.height = AppTheme.touchTarget,
    this.expand = true,
    this.loading = false,
    this.tone,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SbButtonVariant variant;
  final double height;
  final bool expand;
  final bool loading;

  /// Overrides the variant colour (used for risk-coloured actions).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final base = tone ??
        switch (variant) {
          SbButtonVariant.primary => AppTheme.brand,
          SbButtonVariant.secondary => AppTheme.surface,
          SbButtonVariant.danger => AppTheme.riskCritical,
          SbButtonVariant.ghost => AppTheme.surfaceMuted,
        };

    final fg = switch (variant) {
      SbButtonVariant.primary => Colors.white,
      SbButtonVariant.secondary => AppTheme.brand,
      SbButtonVariant.danger => Colors.white,
      SbButtonVariant.ghost => AppTheme.ink,
    };

    final bordered = variant == SbButtonVariant.secondary ||
        (tone != null && variant == SbButtonVariant.ghost);

    final enabled = onPressed != null && !loading;

    final child = Container(
      height: height,
      width: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 22),
      decoration: ShapeDecoration(
        color: bordered ? AppTheme.surface : base,
        shape: ChamferBorder(
          color: bordered ? base.withValues(alpha: 0.5) : base,
          width: bordered ? 1.4 : 1,
          radius: 12,
          cut: 6,
        ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
            ),
            const SizedBox(width: 10),
          ] else if (icon != null) ...[
            Icon(icon, size: 19, color: fg),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Pressable(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed?.call();
              }
            : null,
        scale: 0.97,
        child: child,
      ),
    );
  }
}

/// Round icon button used in app bars and map overlays.
class SbIconButton extends StatelessWidget {
  const SbIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 40,
    this.color = AppTheme.surface,
    this.foreground = AppTheme.ink,
    this.bordered = true,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color color;
  final Color foreground;
  final bool bordered;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: bordered ? Border.all(color: AppTheme.hairline) : null,
        boxShadow: bordered ? AppTheme.shadowSoft : null,
      ),
      child: Icon(icon, size: size * 0.48, color: foreground),
    );

    if (badge != null) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(right: -2, top: -2, child: badge!),
        ],
      );
    }

    return Pressable(
      onTap: onPressed,
      scale: 0.92,
      child: Semantics(button: true, label: tooltip, child: button),
    );
  }
}

/// Selectable segmented control — replaces the ad-hoc chip rows.
class SbSegmented<T> extends StatelessWidget {
  const SbSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.iconBuilder,
    this.background,
  });

  final T value;
  final List<T> options;
  final ValueChanged<T> onChanged;
  final IconData Function(T)? iconBuilder;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background ?? AppTheme.surfaceSunken,
        borderRadius: AppTheme.brMd,
      ),
      child: Row(
        children: options.map((option) {
          final selected = option == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!selected) {
                  HapticFeedback.selectionClick();
                  onChanged(option);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.surface : Colors.transparent,
                  borderRadius: AppTheme.brSm,
                  boxShadow: selected ? AppTheme.shadowSoft : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconBuilder != null) ...[
                      Icon(
                        iconBuilder!(option),
                        size: 16,
                        color: selected ? AppTheme.brand : AppTheme.inkFaint,
                      ),
                      const SizedBox(width: 7),
                    ],
                    Flexible(
                      child: Text(
                        '$option',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? AppTheme.brand : AppTheme.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}