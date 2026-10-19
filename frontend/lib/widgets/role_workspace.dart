import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/user_session.dart';
import 'chamfer.dart';
import 'sb_card.dart';

/// How much of the role context a screen shows.
enum RoleBannerVariant {
  /// Full workspace panel: role, mission and the workflow steps. Reserved for
  /// the role's home screen, where it is the point of the screen.
  full,

  /// One-line context strip. Used on working screens so the role stays
  /// visible without a permanent card pushing the real content down.
  compact,
}

/// A compact, unmistakable role header.
///
/// The four roles share a design language but not a visual identity: HSE is
/// green (verification), Supervisor is cyan (field execution), Management is
/// violet (decision/evaluation).
///
/// The panel is deliberately not repeated on every screen. A permanent card
/// above the content reads as decoration and hides what the screen is for, so
/// working screens use the compact strip and only the home screen shows the
/// full workspace panel.
class RoleWorkspaceBanner extends StatelessWidget {
  const RoleWorkspaceBanner({
    super.key,
    required this.role,
    this.dense = false,
    this.trailing,
    this.variant = RoleBannerVariant.full,
    this.note,
  });

  final AppRole role;
  final bool dense;
  final Widget? trailing;

  /// Panel style for this screen.
  final RoleBannerVariant variant;

  /// Live, role-specific status line shown on the compact strip.
  final String? note;

  static Color colorFor(AppRole role) {
    switch (role) {
      case AppRole.worker:
        return AppTheme.accentDeep;
      case AppRole.supervisor:
        return const Color(0xFF0E7490);
      case AppRole.hse:
        return const Color(0xFF12805C);
      case AppRole.management:
        return const Color(0xFF6D28D9);
    }
  }

  static IconData iconFor(AppRole role) {
    switch (role) {
      case AppRole.worker:
        return Icons.construction_rounded;
      case AppRole.supervisor:
        return Icons.supervised_user_circle_rounded;
      case AppRole.hse:
        return Icons.health_and_safety_rounded;
      case AppRole.management:
        return Icons.business_center_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return variant == RoleBannerVariant.compact
        ? _compact(context)
        : _full(context);
  }

  // ------------------------------------------------------------------ compact
  Widget _compact(BuildContext context) {
    final color = colorFor(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppTheme.brSm,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          ClipPath(
            clipper: ChamferClipper(radius: 7, cut: 4),
            child: Container(
              width: 22,
              height: 22,
              color: color.withValues(alpha: 0.16),
              alignment: Alignment.center,
              child: Icon(iconFor(role), color: color, size: 13),
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              role.workspaceTitle.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: color,
              ),
            ),
          ),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(width: 1, height: 14, color: color.withValues(alpha: 0.25)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.inkMuted,
                ),
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------- full
  Widget _full(BuildContext context) {
    final color = colorFor(role);
    final steps = role.workspaceSteps;

    return SbCard(
      accent: color,
      cut: 12,
      color: Color.alphaBlend(color.withValues(alpha: 0.04), AppTheme.surface),
      borderColor: color.withValues(alpha: 0.20),
      padding: EdgeInsets.all(dense ? AppTheme.md : AppTheme.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cut-corner tile: same silhouette as the card, so the header
              // reads as one machined part instead of an icon in a bubble.
              ClipPath(
                clipper: ChamferClipper(radius: 10, cut: 6),
                child: Container(
                  width: dense ? 34 : 38,
                  height: dense ? 34 : 38,
                  color: color.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  child: Icon(iconFor(role), color: color, size: dense ? 18 : 20),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.workspaceTitle,
                      style: TextStyle(
                        fontSize: dense ? 13.5 : 14.5,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      role.workspaceSubtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          if (!dense && steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: color.withValues(alpha: 0.16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < steps.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: AppTheme.mono(
                            size: 9.5,
                            weight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
