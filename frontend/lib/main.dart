import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_config.dart';
import 'core/auth_service.dart';
import 'core/location_service.dart';
import 'core/network_service.dart';
import 'core/offline_sync_manager.dart';
import 'core/theme.dart';
import 'core/user_session.dart';
import 'features/auth_screen.dart';
import 'features/dashboard_screen.dart';
import 'features/emergency_screen.dart';
import 'features/inspection_screen.dart';
import 'features/quick_report_screen.dart';
import 'features/risk_map_screen.dart';
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
        // Keep layouts intact when the OS font scale is large.
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
class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon, this.builder);
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Warm the GPS in the background so the first map/report is already live.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(LocationService.instance.ensureFix());
    });
  }

  List<_Destination> _destinations(AppRole role) {
    final list = <_Destination>[
      _Destination(
        'Peta',
        Icons.explore_outlined,
        Icons.explore_rounded,
        (_) => RiskMapScreen(
          onNavigateToReport: () => _selectByLabel('Lapor'),
          onNavigateToEmergency: () => _selectByLabel('Darurat'),
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

    if (role == AppRole.supervisor || role == AppRole.hse || role == AppRole.management) {
      list.add(_Destination(
        'Inspeksi',
        Icons.fact_check_outlined,
        Icons.fact_check_rounded,
        (_) => const InspectionScreen(),
      ));
    }

    if (role == AppRole.hse || role == AppRole.management) {
      list.add(_Destination(
        'Insight',
        Icons.insights_outlined,
        Icons.insights_rounded,
        (_) => const DashboardScreen(),
      ));
    }

    return list;
  }

  void _selectByLabel(String label) {
    final items = _destinations(UserSession.instance.currentUser.value?.role ?? AppRole.worker);
    final target = items.indexWhere((d) => d.label == label);
    if (target >= 0 && mounted) setState(() => _index = target);
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession.instance.currentUser.value;
    final role = user?.role ?? AppRole.worker;
    final items = _destinations(role);
    final safeIndex = _index.clamp(0, items.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= AppTheme.railBreakpoint;
        final body = IndexedStack(
          index: safeIndex,
          children: items.map((d) => d.builder(context)).toList(),
        );

        return Scaffold(
          extendBodyBehindAppBar: false,
          appBar: _BrandAppBar(
            user: user,
            onProfile: () => showProfileSheet(context),
            onSettings: () => showSettingsSheet(context),
          ),
          body: Row(
            children: [
              if (useRail)
                _SideRail(
                  index: safeIndex,
                  items: items,
                  onSelected: (i) => setState(() => _index = i),
                ),
              Expanded(child: SafeArea(top: false, child: body)),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : _BottomBar(
                  index: safeIndex,
                  items: items,
                  onSelected: (i) => setState(() => _index = i),
                ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------
class _BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _BrandAppBar({
    required this.user,
    required this.onProfile,
    required this.onSettings,
  });

  final UserProfile? user;
  final VoidCallback onProfile;
  final VoidCallback onSettings;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 58,
      titleSpacing: 16,
      backgroundColor: AppTheme.brandDeep,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: AppTheme.brSm,
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                    if (user != null) ...[
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
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: NetworkPill(
              compact: true,
              onTap: () => showNetworkSheet(context),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Center(
            child: _AvatarButton(user: user, onTap: onProfile),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
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
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.user, required this.onTap});
  final UserProfile? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = (user?.fullName.isNotEmpty == true)
        ? user!.fullName.trim()[0].toUpperCase()
        : '?';
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
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
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