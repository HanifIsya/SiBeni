import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_config.dart';
import 'core/auth_service.dart';
import 'core/brand.dart';
import 'core/location_service.dart';
import 'core/network_service.dart';
import 'core/offline_sync_manager.dart';
import 'core/theme.dart';
import 'core/user_session.dart';
import 'features/auth_screen.dart';
import 'features/emergency_screen.dart';
import 'features/inspection_screen.dart';
import 'features/insight_screen.dart';
import 'features/profile_edit_screen.dart';
import 'features/quick_report_screen.dart';
import 'features/report_review_screen.dart';
import 'features/risk_map_screen.dart';
import 'features/warning_manage_screen.dart';
import 'features/settings_sheet.dart';
import 'widgets/network_pill.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.initialize();
  await NetworkService.instance.initialize();
  OfflineSyncManager.instance.initialize();
  await UserSession.instance.initialize();
  runApp(const SiBeniApp());
}

class SiBeniApp extends StatelessWidget {
  const SiBeniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConfig.appName} — ${AppConfig.appTagline}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        // Keep layouts intact when the OS font scale is large. Beyond 1.3 the
        // safety taxonomy stops being scannable; below 0.9 it is unreadable
        // in direct sunlight.
        final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(0.9, 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: ValueListenableBuilder<UserProfile?>(
        valueListenable: UserSession.instance.currentUser,
        builder: (context, user, _) {
          if (user == null) return const AuthScreen();
          return const AppShell();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation model
// ---------------------------------------------------------------------------

/// One primary navigation destination.
///
/// The set is derived from the signed-in role, which is what makes the four
/// roles genuinely different products rather than the same app with a
/// different name on the profile card.
class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon, this.builder, {this.isPrimary = true});

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;

  /// Secondary destinations live in the overflow sheet, not the tab bar.
  final bool isPrimary;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final Set<String> _unlocked = {};

  @override
  void initState() {
    super.initState();
    // Warm the GPS in the background so the first map/report is already live.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(LocationService.instance.ensureFix());
    });
  }

  /// Build the destination list for a role.
  ///
  /// Worker: report + SOS only. Supervisor: verification + read-only insight.
  /// HSE: report review + early warnings. Management: review + official metrics.
  static List<_Destination> _destinationsFor(AppRole role) {
    final items = <_Destination>[
      _Destination(
        'Peta',
        Icons.explore_outlined,
        Icons.explore_rounded,
        (_) => RiskMapScreen(
          onNavigateToReport: () => _AppShellBus.instance.go('Lapor'),
          onNavigateToEmergency: () => _AppShellBus.instance.go('Darurat'),
        ),
      ),
      _Destination(
        'Lapor',
        Icons.add_circle_outline_rounded,
        Icons.add_circle_rounded,
        (_) => const QuickReportScreen(),
      ),
      _Destination(
        'Darurat',
        Icons.sos_rounded,
        Icons.sos_rounded,
        (_) => const EmergencyScreen(),
      ),
    ];

    if (role.canVerifyTickets) {
      items.add(_Destination(
        'Inspeksi',
        Icons.fact_check_outlined,
        Icons.fact_check_rounded,
        (_) => const InspectionScreen(),
      ));
    }

    if (role.canReviewReports) {
      items.add(_Destination(
        'Laporan',
        Icons.assignment_turned_in_outlined,
        Icons.assignment_turned_in_rounded,
        (_) => const ReportReviewScreen(),
      ));
    }

    if (role.canViewInsight) {
      items.add(_Destination(
        'Insight',
        Icons.insights_outlined,
        Icons.insights_rounded,
        (_) => const InsightScreen(),
      ));
    }

    // Secondary modules for roles that own them.
    if (role.canManageWarnings) {
      items.add(_Destination(
        'Peringatan',
        Icons.campaign_outlined,
        Icons.campaign_rounded,
        (_) => const WarningManageScreen(),
        isPrimary: false,
      ));
    }

    items.add(_Destination(
      'Profil',
      Icons.person_outline_rounded,
      Icons.person_rounded,
      (_) => const ProfileEditScreen(),
      isPrimary: false,
    ));

    return items;
  }

  void _goTo(String label) {
    final items = _destinationsFor(_currentRole);
    final target = items.indexWhere((d) => d.label == label);
    if (target < 0) return;

    if (items[target].isPrimary) {
      setState(() => _index = target);
    } else {
      // Secondary destinations open as a sheet rather than hijacking a tab.
      _unlocked.add(label);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => items[target].builder(context),
      );
    }
  }

  AppRole get _currentRole =>
      UserSession.instance.currentUser.value?.role ?? AppRole.worker;

  @override
  Widget build(BuildContext context) {
    final user = UserSession.instance.currentUser.value;
    final items = _destinationsFor(_currentRole);
    final primary = items.where((d) => d.isPrimary).toList();

    // Keep the tab bar within a comfortable thumb span.
    final safeIndex = _index.clamp(0, primary.length - 1);
    _AppShellBus.instance.go = _goTo;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= AppTheme.railBreakpoint;
        final body = IndexedStack(
          index: safeIndex,
          children: primary.map((d) => d.builder(context)).toList(),
        );

        return Scaffold(
          appBar: _BrandAppBar(
            user: user,
            secondary: items.where((d) => !d.isPrimary).toList(),
            onSecondary: _goTo,
            onProfile: () => _goTo('Profil'),
            onSettings: () => showSettingsSheet(context),
          ),
          body: Row(
            children: [
              if (useRail)
                _SideRail(
                  index: safeIndex,
                  items: primary,
                  onSelected: (i) => setState(() => _index = i),
                ),
              Expanded(child: SafeArea(top: false, child: body)),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : _BottomBar(
                  index: safeIndex,
                  items: primary,
                  onSelected: (i) => setState(() => _index = i),
                ),
        );
      },
    );
  }
}

/// Lets a screen request navigation without holding a reference to the shell.
class _AppShellBus {
  static final instance = _AppShellBus._();
  _AppShellBus._();
  late void Function(String label) go;
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------
class _BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _BrandAppBar({
    required this.user,
    required this.secondary,
    required this.onSecondary,
    required this.onProfile,
    required this.onSettings,
  });

  final UserProfile? user;
  final List<_Destination> secondary;
  final ValueChanged<String> onSecondary;
  final VoidCallback onProfile;
  final VoidCallback onSettings;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final hasOverflow = secondary.any((d) => d.label != 'Profil');

    // AppBar's own layout decides how much width the actions take, so measuring
    // the title budget from the full screen width is only an approximation.
    // Instead the title is built with every part shrinkable: the wordmark and
    // the employee chip ellipsize, and the subtitle drops below 360 dp. On a
    // very tight viewport only the brand mark remains, which is preferable to
    // pushing the wordmark off screen.
    return AppBar(
      toolbarHeight: 58,
      titleSpacing: 14,
      backgroundColor: AppTheme.brandDeep,
      foregroundColor: Colors.white,
      // AppBar lays the title into a fixed middle slot. Feeding it a Row of a fixed
      // mark plus an Expanded block overflows that slot, because the Expanded
      // child's minimum is still the mark's width plus the gap. The identity
      // block therefore owns the whole slot and draws the mark itself.
      title: _IdentityBlock(user: user),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Center(
            child: NetworkPill(compact: true, onTap: () => showNetworkSheet(context)),
          ),
        ),
        if (hasOverflow)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.grid_view_rounded, size: 20, color: AppTheme.onDarkMuted),
                tooltip: 'Modul lainnya',
                onPressed: () => _showOverflow(context),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Center(child: _AvatarButton(user: user, onTap: onProfile)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: IconButton(
              icon: const Icon(Icons.tune_rounded, size: 20, color: AppTheme.onDarkMuted),
              tooltip: 'Pengaturan',
              onPressed: onSettings,
            ),
          ),
        ),
      ],
    );
  }

  void _showOverflow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'MODUL TAMBAHAN',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppTheme.inkFaint,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final d in secondary.where((d) => d.label != 'Profil'))
              ListTile(
                leading: Icon(d.icon, color: AppTheme.brand),
                title: Text(
                  d.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.inkFaint),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSecondary(d.label);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Wordmark + identity line for the app bar.
class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.user});
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The mark is the one element that must never be dropped — unless the
        // slot is narrower than the mark itself, which happens on a very narrow
        // device where the actions (status capsule, overflow, avatar, settings)
        // consume the toolbar. Rendering nothing is the only correct answer
        // there; the avatar still carries the identity.
        const markSize = 34.0;
        const gap = 10.0;
        if (constraints.maxWidth < markSize + gap) return const SizedBox.shrink();

        final budget = constraints.maxWidth - markSize - gap;

        // Below these budgets the chip and subtitle cost more than they
        // explain, so they are dropped and the wordmark gets the room.
        final showChip = user != null && budget >= 120;
        final showSubtitle = budget >= 84;

        return Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            const BrandMark(size: markSize),
            const SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: Text(
                          AppConfig.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                      if (showChip) ...[
                        const SizedBox(width: 7),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user!.employeeId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.mono(
                                size: 9.5,
                                weight: FontWeight.w700,
                                color: const Color(0xFFD6E6F2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (showSubtitle) ...[
                    const SizedBox(height: 1),
                    Text(
                      user == null
                          ? AppConfig.organisation
                          : '${user!.fullName} · ${user!.roleDisplayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.onDarkMuted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.user, required this.onTap});
  final UserProfile? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = user?.avatarUrl;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: avatar != null
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _initials(),
              )
            : _initials(),
      ),
    );
  }

  Widget _initials() => Center(
        child: Text(
          user?.initials ?? '?',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.items,
    required this.onSelected,
  });

  final int index;
  final List<_Destination> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.hairline)),
        color: AppTheme.surface,
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            onSelected(i);
          },
          destinations: items
              .map(
                (d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.activeIcon),
                  label: d.label,
                  tooltip: d.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.index,
    required this.items,
    required this.onSelected,
  });

  final int index;
  final List<_Destination> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppTheme.hairline)),
        color: AppTheme.surface,
      ),
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        selectedIndex: index,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          onSelected(i);
        },
        labelType: NavigationRailLabelType.all,
        groupAlignment: -0.9,
        destinations: items
            .map(
              (d) => NavigationRailDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.activeIcon),
                label: Text(d.label),
              ),
            )
            .toList(),
      ),
    );
  }
}
