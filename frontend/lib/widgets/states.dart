import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Section title with an optional trailing action and a soft leading rule.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    // On very narrow canvases the action moves under the title rather than
    // competing for horizontal space and pushing itself off-screen.
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = action != null && constraints.maxWidth < 360;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppTheme.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppTheme.inkMuted,
                ),
              ),
            ],
          ],
        );

        if (stacked) {
          return Padding(
            padding: EdgeInsets.only(bottom: dense ? AppTheme.sm : AppTheme.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: AppTheme.brand),
                      const SizedBox(width: 9),
                    ],
                    Expanded(child: titleBlock),
                  ],
                ),
                const SizedBox(height: AppTheme.sm),
                Align(alignment: Alignment.centerLeft, child: action!),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: dense ? AppTheme.sm : AppTheme.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppTheme.brand),
                const SizedBox(width: 9),
              ],
              Expanded(child: titleBlock),
              if (action != null) ...[const SizedBox(width: 8), action!],
            ],
          ),
        );
      },
    );
  }
}

/// Neutral, informative empty state — never invent placeholder content.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: compact ? 22 : 34, horizontal: AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.brLg,
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 40 : 52,
            height: compact ? 40 : 52,
            decoration: const BoxDecoration(color: AppTheme.surfaceMuted, shape: BoxShape.circle),
            child: Icon(icon, size: compact ? 20 : 24, color: AppTheme.inkFaint),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 5),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.inkMuted),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

/// Lightweight shimmering placeholder used while the first payload loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius,
  });

  final double height;
  final double? width;
  final double? radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(AppTheme.surfaceMuted, AppTheme.surfaceSunken, _controller.value),
            borderRadius: BorderRadius.circular(widget.radius ?? 8),
          ),
        );
      },
    );
  }
}

/// Standard fade + slide entrance. Stagger by [index] for list-like content.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 420),
    this.offset = 14,
  });

  final Widget child;
  final int index;
  final Duration duration;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: (widget.index.clamp(0, 8) * 55));
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        return Opacity(
          opacity: curve.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - curve.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}