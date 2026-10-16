import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Small capsule used for statuses, risk levels and metadata.
class SbPill extends StatelessWidget {
  const SbPill({
    super.key,
    required this.label,
    this.icon,
    this.color = AppTheme.brand,
    this.background,
    this.dense = false,
    this.mono = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color? background;
  final bool dense;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.10),
        borderRadius: AppTheme.brPill,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? AppTheme.mono(size: dense ? 10 : 11, weight: FontWeight.w700, color: color)
                  : TextStyle(
                      fontSize: dense ? 10 : 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: color,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Risk-level badge driven directly by the design-system taxonomy.
class RiskPill extends StatelessWidget {
  const RiskPill({super.key, required this.level, this.dense = false, this.icon = true});

  final String level;
  final bool dense;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(level);
    return SbPill(
      label: AppTheme.riskLabel(level),
      color: color,
      background: AppTheme.riskBg(level),
      dense: dense,
      icon: icon ? AppTheme.riskIcon(level) : null,
    );
  }
}

/// Neutral tag used for hazard taxonomies and list metadata.
class SbTag extends StatelessWidget {
  const SbTag({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: AppTheme.brPill,
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slowly breathing dot — used to signal a live connection.
class PulseDot extends StatefulWidget {
  const PulseDot({
    super.key,
    this.color = AppTheme.online,
    this.size = 8,
    this.animate = true,
  });

  final Color color;
  final double size;
  final bool animate;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat(reverse: true);
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
      builder: (context, _) {
        final t = widget.animate ? _controller.value : 0.5;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.18 + (0.32 * t)),
                blurRadius: 2 + (6 * t),
                spreadRadius: 1 + (3 * t),
              ),
            ],
          ),
        );
      },
    );
  }
}