import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter/foundation.dart' show kReleaseMode;

import 'core/app_config.dart';
import 'core/auth_service.dart';
import 'core/brand.dart';
import 'core/location_service.dart';
import 'core/network_service.dart';
import 'core/notification_service.dart';
import 'core/offline_sync_manager.dart';
import 'core/theme.dart';
import 'core/user_session.dart';
import 'features/auth_screen.dart';
import 'features/emergency_screen.dart';
import 'features/inspection_screen.dart';
import 'features/insight_screen.dart';
import 'features/management_evaluation_screen.dart';
import 'features/notification_center.dart';
import 'features/profile_edit_screen.dart';
import 'features/quick_report_screen.dart';
import 'features/report_review_screen.dart';
import 'features/risk_map_screen.dart';
import 'features/supervisor_coordination_screen.dart';
import 'features/warning_manage_screen.dart';
import 'features/settings_sheet.dart';
import 'widgets/network_pill.dart';
import 'widgets/role_workspace.dart';
import 'widgets/states.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A rendering error must never look like an empty page. In release the
  // default error widget paints nothing, so the user would simply see a blank
  // screen with no explanation. Debug builds keep Flutter's red error box.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => SbErrorFallback(error: details.exception);
  }

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
    // Warm the GPS and the notification badge in the background so the first
    // screen is already live after login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(LocationService.instance.ensureFix());
      unawaited(NotificationService.instance.refresh());
    });
  }

  /// Build the destination list for a role.
  ///
  /// Worker    : Peta, Lapor, Darurat.
  /// Supervisor: Peta, Lapor, Inspeksi, Koordinasi, Dashboard K3/ESG.
  /// HSE       : Peta, Laporan, Inspeksi, Koordinasi, Dashboard K3/ESG.
  /// Management: Peta, Laporan, Evaluasi, Koordinasi, Dashboard K3/ESG.
  ///
  /// HSE has no "Lapor" tab because HSE receives reports. Management has an
  /// explicit evaluation console for approvals and closure. SOS remains one
  /// tap away in the app-bar overflow and on the map for every role.
  static List<_Destination> _destinationsFor(AppRole role) {
    final items = <_Destination>[
      _Destination(
        'Peta',
        Icons.explore_outlined,
        Icons.explore_rounded,
        (_) => RiskMapScreen(
          onNavigateToReport: () => _AppShellBus.instance.report(),
          onNavigateToEmergency: () => _AppShellBus.instance.emergency(),
        ),
      ),
    ];

    if (role.canFileReport) {
      items.add(_Destination(
        'Lapor',
        Icons.add_circle_outline_rounded,
        Icons.add_circle_rounded,
        (_) => const QuickReportScreen(),
      ));
    }

    if (role == AppRole.worker) {
      items.add(_Destination(
        'Darurat',
        Icons.crisis_alert_rounded,
        Icons.crisis_alert_rounded,
        (_) => const EmergencyScreen(),
      ));
    }

    if (role.canInspect) {
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

    if (role.canApproveActions) {
      items.add(_Destination(
        'Evaluasi',
        Icons.approval_outlined,
        Icons.approval_rounded,
        (_) => const ManagementEvaluationScreen(),
      ));
    }

    if (role.canCoordinate) {
      items.add(_Destination(
        'Koordinasi',
        Icons.forum_outlined,
        Icons.forum_rounded,
        (_) => const SupervisorCoordinationScreen(),
      ));
    }

    if (role.canViewInsight) {
      items.add(_Destination(
        'Dashboard',
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

  void _openEmergency() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: AppTheme.brandDeep,
            foregroundColor: Colors.white,
            title: const Text(
              'Tanggap Darurat',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: const EmergencyScreen(),
        ),
      ),
    );
  }

  AppRole get _currentRole =>
      UserSession.instance.currentUser.value?.role ?? AppRole.worker;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: UserSession.instance.currentUser,
      builder: (context, user, _) {
        final role = user?.role ?? AppRole.worker;
        final items = _destinationsFor(role);
        final primary = items.where((d) => d.isPrimary).toList();

        // Keep the tab bar within a comfortable thumb span.
        final safeIndex = _index.clamp(0, primary.length - 1);
        _AppShellBus.instance.go = _goTo;
        _AppShellBus.instance.emergency = _openEmergency;
        _AppShellBus.instance.report = () {
          if (_currentRole.canFileReport) {
            _goTo('Lapor');
          } else if (_currentRole.canReviewReports) {
            _goTo('Laporan');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Menu laporan tidak tersedia untuk peran ini.')),
            );
          }
        };

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
                role: role,
                onProfile: () => _goTo('Profil'),
                onSettings: () => showSettingsSheet(context),
                onEmergency: _openEmergency,
                onNotifications: () => showNotificationCenter(context),
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
      },
    );
  }
}

/// Lets a screen request navigation without holding a reference to the shell.
class _AppShellBus {
  static final instance = _AppShellBus._();
  _AppShellBus._();
  late void Function(String label) go;
  late void Function() emergency;
  late void Function() report;
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------
class _BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _BrandAppBar({
    required this.user,
    required this.role,
    required this.onProfile,
    required this.onSettings,
    required this.onEmergency,
    required this.onNotifications,
  });

  final UserProfile? user;
  final AppRole role;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onEmergency;
  final VoidCallback onNotifications;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  /// A tinted dark app bar makes the signed-in role recognisable at a glance
  /// without breaking the industrial palette. Worker keeps the original navy.
  static Color _tintFor(AppRole role) {
    switch (role) {
      case AppRole.worker:
        return AppTheme.brandDeep;
      case AppRole.supervisor:
        return Color.alphaBlend(
          const Color(0xFF0E7490).withValues(alpha: 0.34),
          AppTheme.brandDeep,
        );
      case AppRole.hse:
        return Color.alphaBlend(
          const Color(0xFF12805C).withValues(alpha: 0.34),
          AppTheme.brandDeep,
        );
      case AppRole.management:
        return Color.alphaBlend(
          const Color(0xFF6D28D9).withValues(alpha: 0.34),
          AppTheme.brandDeep,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 58,
      titleSpacing: 14,
      backgroundColor: _tintFor(role),
      foregroundColor: Colors.white,
      title: _IdentityBlock(user: user),
      actions: [
        _NotificationBell(onTap: onNotifications),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(
            child: NetworkPill(compact: true, onTap: () => showNetworkSheet(context)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Center(child: _AvatarButton(user: user, onTap: onProfile)),
        ),
        PopupMenuButton<String>(
          tooltip: 'Menu lainnya',
          icon: const Icon(
            Icons.more_vert_rounded,
            size: 21,
            color: AppTheme.onDarkMuted,
          ),
          color: AppTheme.surface,
          onSelected: (value) {
            if (value == 'emergency') {
              onEmergency();
            } else if (value == 'settings') {
              onSettings();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'emergency',
              child: Row(
                children: [
                  Icon(Icons.crisis_alert_rounded, size: 18, color: AppTheme.riskCritical),
                  SizedBox(width: 9),
                  Text(
                    'Tanggap Darurat',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.riskCritical,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: AppTheme.inkMuted),
                  SizedBox(width: 9),
                  Text(
                    'Pengaturan & Akun',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.instance.unread,
      builder: (context, unread, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                size: 21,
                color: AppTheme.onDarkMuted,
              ),
              tooltip: 'Notifikasi',
              onPressed: onTap,
            ),
            if (unread > 0)
              Positioned(
                top: 9,
                right: 9,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.riskCritical,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.brandDeep, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        fontSize: 8,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Wordmark + identity line for the app bar.
///
/// Deliberately minimal: the mark, the product name, the role, and the name of
/// the person signed in. The employee number used to sit here as a third chip
/// and pushed the name off-screen on narrow phones; it belongs on the account
/// screen, not in the chrome.
class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.user});
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The mark is the one element that must never be dropped — unless the
        // slot is narrower than the mark itself.
        const markSize = 32.0;
        const gap = 9.0;
        if (constraints.maxWidth < markSize + gap) return const SizedBox.shrink();

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
                  Text(
                    AppConfig.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.white,
                      height: 1.15,
                    ),
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
    // The avatar carries the role colour, so the signed-in role is readable
    // from the chrome alone.
    final roleColor = RoleWorkspaceBanner.colorFor(user?.role ?? AppRole.worker);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            roleColor.withValues(alpha: 0.45),
            Colors.white.withValues(alpha: 0.10),
          ),
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
