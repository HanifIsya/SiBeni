import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme.dart';
import 'core/user_session.dart';
import 'core/offline_sync_manager.dart';
import 'features/login_screen.dart';
import 'features/risk_map_screen.dart';
import 'features/quick_report_screen.dart';
import 'features/emergency_screen.dart';
import 'features/inspection_screen.dart';
import 'features/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineSyncManager().initialize();
  await UserSession().initialize();
  runApp(const SiBeniApp());
}

class SiBeniApp extends StatelessWidget {
  const SiBeniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SI BENI - Siaga Bencana Dini',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ValueListenableBuilder<UserProfile?>(
        valueListenable: UserSession().currentUser,
        builder: (context, user, _) {
          if (user == null) {
            return LoginScreen(onLoginSuccess: () {});
          }
          return const MainNavigationScreen();
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _showRoleSwitchDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ganti Peran / Akun Pengguna', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 10),
              ...UserSession.demoPersonas.map((persona) {
                final isCurrent = UserSession().currentUser.value?.employeeId == persona.employeeId;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isCurrent ? AppTheme.brandPrimary : AppTheme.surfaceMuted,
                    child: Icon(
                      persona.role == AppRole.worker
                          ? Icons.construction
                          : persona.role == AppRole.supervisor
                              ? Icons.supervised_user_circle
                              : persona.role == AppRole.hse
                                  ? Icons.health_and_safety
                                  : Icons.business_center,
                      color: isCurrent ? Colors.white : AppTheme.onSurfaceSecondary,
                      size: 20,
                    ),
                  ),
                  title: Text(persona.fullName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                  subtitle: Text('${persona.roleDisplayName} • ${persona.workZone.split(" (")[0]}'),
                  trailing: isCurrent ? const Icon(Icons.check, color: AppTheme.brandSafetyGreen) : null,
                  onTap: () {
                    UserSession().login(persona);
                    Navigator.pop(context);
                    setState(() => _currentIndex = 0);
                  },
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    UserSession().logout();
                  },
                  icon: const Icon(Icons.logout, color: AppTheme.riskCritical),
                  label: const Text('Keluar (Ganti Akun Manual)', style: TextStyle(color: AppTheme.riskCritical, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.riskCritical)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession().currentUser.value;
    final role = user?.role ?? AppRole.worker;

    // Dynamic tabs based on user role
    final List<Widget> screens = [];
    final List<BottomNavigationBarItem> navItems = [];

    // All roles have Risk Map
    screens.add(RiskMapScreen(
      onNavigateToReport: () => setState(() => _currentIndex = 1),
      onNavigateToEmergency: () => setState(() => _currentIndex = 2),
    ));
    navItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.map_outlined),
      activeIcon: Icon(Icons.map),
      label: 'Peta Risiko',
    ));

    // Worker, Supervisor, HSE have Quick Report
    screens.add(const QuickReportScreen());
    navItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.edit_note_outlined),
      activeIcon: Icon(Icons.edit_note),
      label: 'Lapor Cepat',
    ));

    // Worker, Supervisor, HSE have Emergency SOS
    screens.add(const EmergencyScreen());
    navItems.add(const BottomNavigationBarItem(
      icon: Icon(Icons.sos_outlined, color: AppTheme.riskCritical),
      activeIcon: Icon(Icons.sos, color: AppTheme.riskCritical),
      label: 'Darurat SOS',
    ));

    // Supervisor, HSE, Management have Inspections
    if (role == AppRole.supervisor || role == AppRole.hse || role == AppRole.management) {
      screens.add(const InspectionScreen());
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.fact_check_outlined),
        activeIcon: Icon(Icons.fact_check),
        label: 'Inspeksi K3',
      ));
    }

    // HSE and Management have Executive Dashboard
    if (role == AppRole.hse || role == AppRole.management) {
      screens.add(const DashboardScreen());
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart_outlined),
        activeIcon: Icon(Icons.bar_chart),
        label: 'Dashboard',
      ));
    }

    // Guard index bounds if role changes
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.brandSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'SI BENI',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user?.employeeId ?? 'K3',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    user != null ? '${user.fullName} (${user.roleDisplayName})' : 'PT Consnet Mining',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.switch_account),
            tooltip: 'Ganti Peran / Akun',
            onPressed: _showRoleSwitchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Peringatan Dini BMKG & Tanggap Darurat aktif.')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Persistent Connectivity & Offline Sync Bar
          ValueListenableBuilder<bool>(
            valueListenable: OfflineSyncManager().isOnline,
            builder: (context, online, _) {
              return ValueListenableBuilder<int>(
                valueListenable: OfflineSyncManager().queueCount,
                builder: (context, count, _) {
                  if (online && count == 0) {
                    return Container(
                      width: double.infinity,
                      color: const Color(0xFFF0FDF4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.statusOnline,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Terhubung • Data BMKG/BNPB Aktif (Live Render & Supabase)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.brandSafetyGreen,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Container(
                      width: double.infinity,
                      color: AppTheme.statusOfflineBg,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, size: 16, color: AppTheme.statusOfflineText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              online
                                  ? 'Menyinkronkan $count laporan ke server HSE...'
                                  : 'Mode Offline Aktif • $count Laporan Disimpan Lokal (Kirim Otomatis Saat Online)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.statusOfflineText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              );
            },
          ),

          // Active Screen
          Expanded(child: screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.brandPrimary,
        unselectedItemColor: AppTheme.onSurfaceSecondary,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
        items: navItems,
      ),
    );
  }
}
