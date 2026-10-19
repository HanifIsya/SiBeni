import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/user_session.dart';
import 'sb_card.dart';

/// A compact, unmistakable role header.
///
/// The four roles share a design language but not a visual identity: HSE is
/// green (verification), Supervisor is cyan (field execution), Management is
/// violet (decision/evaluation). This is the first thing a user sees on every
/// operational screen, so the difference is obvious without changing the
/// underlying report form.
class RoleWorkspaceBanner extends StatelessWidget {
  const RoleWorkspaceBanner({
    super.key,
    required this.role,
    this.dense = false,
    this.trailing,
  });

  final AppRole role;
  final bool dense;
  final Widget? trailing;

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
    final color = colorFor(role);
    final steps = role.workspaceSteps;

    return SbCard(
      accent: color,
      color: Color.alphaBlend(color.withValues(alpha: 0.055), AppTheme.surface),
      borderColor: color.withValues(alpha: 0.22),
      padding: EdgeInsets.all(dense ? AppTheme.md : AppTheme.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: dense ? 36 : 42,
                height: dense ? 36 : 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppTheme.brMd,
                ),
                child: Icon(iconFor(role), color: color, size: dense ? 19 : 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.workspaceTitle.toUpperCase(),
                      style: AppTheme.eyebrow(color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.workspaceSubtitle,
                      style: TextStyle(
                        fontSize: dense ? 12 : 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.ink,
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
          if (!dense) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < steps.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.09),
                      borderRadius: AppTheme.brPill,
                      border: Border.all(color: color.withValues(alpha: 0.16)),
                    ),
                    child: Text(
                      '${i + 1}  ${steps[i]}',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
