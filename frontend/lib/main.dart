import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme.dart';
import 'core/offline_sync_manager.dart';
import 'features/risk_map_screen.dart';
import 'features/quick_report_screen.dart';
import 'features/emergency_screen.dart';
import 'features/inspection_screen.dart';
import 'features/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineSyncManager().initialize();
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
      home: const MainNavigationScreen(),
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      RiskMapScreen(
        onNavigateToReport: () => setState(() => _currentIndex = 1),
        onNavigateToEmergency: () => setState(() => _currentIndex = 2),
      ),
      const QuickReportScreen(),
      const EmergencyScreen(),
      const InspectionScreen(),
      const DashboardScreen(),
    ];

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SI BENI',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'PT Consnet Mining • K3 Mobile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
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
                            'Terhubung • Data BMKG/BNPB Aktif',
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

          // Main Screen View
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Peta Risiko',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note_outlined),
            activeIcon: Icon(Icons.edit_note),
            label: 'Lapor Cepat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sos_outlined, color: AppTheme.riskCritical),
            activeIcon: Icon(Icons.sos, color: AppTheme.riskCritical),
            label: 'Darurat SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            activeIcon: Icon(Icons.fact_check),
            label: 'Inspeksi K3',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}
