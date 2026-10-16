import 'package:flutter/material.dart';

import '../core/network_service.dart';
import '../core/offline_sync_manager.dart';
import '../core/theme.dart';
import 'pills.dart';

/// Live connectivity capsule.
///
/// One glance answers three operational questions: am I online, over what
/// transport, and how many reports are still waiting to be delivered.
class NetworkPill extends StatelessWidget {
  const NetworkPill({
    super.key,
    this.onTap,
    this.onDark = true,
    this.compact = false,
  });

  final VoidCallback? onTap;
  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OnlineState>(
      valueListenable: NetworkService.instance.state,
      builder: (context, state, _) {
        return ValueListenableBuilder<int>(
          valueListenable: OfflineSyncManager.instance.queueCount,
          builder: (context, queue, _) {
            final spec = _spec(state, queue);
            final fg = onDark ? spec.onDark : spec.color;

            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 11,
                  vertical: compact ? 6 : 7,
                ),
                decoration: BoxDecoration(
                  color: onDark
                      ? Colors.white.withValues(alpha: spec.solid ? 0.16 : 0.08)
                      : spec.color.withValues(alpha: 0.10),
                  borderRadius: AppTheme.brPill,
                  border: Border.all(color: fg.withValues(alpha: 0.32)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulseDot(color: fg, size: 7, animate: state == OnlineState.online),
                    const SizedBox(width: 7),
                    Text(
                      spec.label,
                      style: TextStyle(
                        fontSize: compact ? 10.5 : 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  ({String label, Color color, Color onDark, bool solid}) _spec(OnlineState state, int queue) {
    switch (state) {
      case OnlineState.online:
        final cellular = NetworkService.instance.link.value == LinkType.cellular;
        return (
          label: queue > 0 ? 'Sinkron $queue' : (cellular ? 'Seluler' : 'Online'),
          color: AppTheme.online,
          onDark: const Color(0xFF6EE7B7),
          solid: false,
        );
      case OnlineState.mobileBlocked:
        return (
          label: 'Wi-Fi Saja',
          color: AppTheme.offline,
          onDark: const Color(0xFFFCD34D),
          solid: false,
        );
      case OnlineState.unreachable:
        return (
          label: queue > 0 ? 'Antrean $queue' : 'Terputus',
          color: AppTheme.offline,
          onDark: const Color(0xFFFCD34D),
          solid: false,
        );
      case OnlineState.offline:
        return (
          label: queue > 0 ? 'Offline · $queue' : 'Offline',
          color: AppTheme.inkFaint,
          onDark: const Color(0xFFB9C7D4),
          solid: false,
        );
    }
  }
}