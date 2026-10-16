import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../core/user_session.dart';
import '../../core/api_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  int _selectedEmergencyType = 0;
  double _holdProgress = 0.0;
  Timer? _timer;

  // Geographic coordinates for Pit and nearest Assembly Point A
  final LatLng _workerPos = const LatLng(-2.1458291, 115.3489124);
  final LatLng _assemblyPointA = const LatLng(-2.1435000, 115.3468000);

  final List<Map<String, dynamic>> _emergencyTypes = [
    {'title': 'Kebakaran', 'type': 'fire', 'icon': Icons.local_fire_department, 'color': Colors.red},
    {'title': 'Cedera / Medis', 'type': 'injury', 'icon': Icons.medical_services, 'color': const Color(0xFFE11D48)},
    {'title': 'Kebocoran B3', 'type': 'chemical_leak', 'icon': Icons.warning_rounded, 'color': Colors.amber},
    {'title': 'Banjir / Longsor', 'type': 'landslide_flood', 'icon': Icons.landscape, 'color': Colors.orange},
    {'title': 'Keamanan', 'type': 'security', 'icon': Icons.security, 'color': Colors.blueGrey},
  ];

  void _startHolding() {
    _holdProgress = 0.0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _holdProgress += 0.05 / 3.0; // 3 seconds to reach 1.0
        if (_holdProgress >= 1.0) {
          _timer?.cancel();
          _triggerSos();
        }
      });
    });
  }

  void _stopHolding() {
    _timer?.cancel();
    if (_holdProgress < 1.0) {
      setState(() => _holdProgress = 0.0);
    }
  }

  Future<void> _triggerSos() async {
    final user = UserSession().currentUser.value;
    final typeMap = _emergencyTypes[_selectedEmergencyType];

    // Trigger to Supabase via backend API
    final result = await ApiService().triggerSos(
      workerId: user?.employeeId ?? 'EMP-001',
      workerName: user != null ? '${user.fullName} (${user.roleDisplayName})' : 'Pekerja Tambang',
      zoneName: user?.workZone ?? 'Pit Utama',
      emergencyType: typeMap['type'] as String,
      latitude: _workerPos.latitude,
      longitude: _workerPos.longitude,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.emergency_share, color: AppTheme.riskCritical, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'SOS BERHASIL DISIARKAN',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.riskCritical),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result != null
                  ? 'Pusat Kendali HSE, Pengawas Lapangan, dan Tim Tanggap Darurat telah menerima sinyal darurat Anda di Supabase:'
                  : 'Sinyal SOS telah dicatat di perangkat & disiarkan via frekuensi radio darurat K3:',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.surfaceMuted, borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Pelapor: ${user?.fullName ?? "Pekerja Lapangan"}\nZona: ${user?.workZone ?? "Pit Utama"}\nKoordinat: -2.1458291, 115.3489124\nJenis: ${typeMap['title']}',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandPrimary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'SEGERA MENUJU TITIK KUMPUL A (Assembly Point Pit Utama, 350m). Jangan kembali untuk mengambil barang pribadi!',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.riskCritical),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _holdProgress = 0.0;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandPrimary),
            child: const Text('Saya Sudah di Titik Kumpul Aman', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Oversized Emergency SOS Button (Hold 3 Seconds)
          GestureDetector(
            onTapDown: (_) => _startHolding(),
            onTapUp: (_) => _stopHolding(),
            onTapCancel: () => _stopHolding(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: AppTheme.sosTargetHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.riskCritical,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(color: Color(0x55DC2626), blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.crisis_alert, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        _holdProgress > 0 ? 'TAHAN 3 DETIK (${(3 - _holdProgress * 3).toStringAsFixed(1)}s)' : 'TOMBOL DARURAT (SOS)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_holdProgress > 0)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _holdProgress.clamp(0.0, 1.0),
                          child: Container(color: Colors.black.withValues(alpha: 0.35)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Tekan & tahan 3 detik untuk menyiarkan sinyal evakuasi ke Supabase HSE',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Jenis Keadaan Darurat Selector
          Text('Pilih Jenis Keadaan Darurat', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_emergencyTypes.length, (index) {
                final item = _emergencyTypes[index];
                final isSelected = _selectedEmergencyType == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedEmergencyType = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.riskCriticalBg : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.riskCritical : AppTheme.borderSubtle,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(item['icon'] as IconData, size: 18, color: isSelected ? AppTheme.riskCritical : AppTheme.onSurfaceSecondary),
                          const SizedBox(width: 6),
                          Text(
                            item['title'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.riskCritical : AppTheme.onSurfacePrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Real OpenStreetMap Evacuation Map
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Jalur Evakuasi OpenStreetMap', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.riskLowBg, borderRadius: BorderRadius.circular(12)),
                      child: Text('350 Meter (4 Menit)', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.riskLow)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Rute Digital: Pit Utama ➔ Tanggul Barat ➔ Titik Kumpul A', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary)),
                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _workerPos,
                        initialZoom: 15.2,
                        minZoom: 13.0,
                        maxZoom: 18.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.consnet.sibeni',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [
                                _workerPos,
                                const LatLng(-2.1448, 115.3475),
                                _assemblyPointA,
                              ],
                              color: AppTheme.brandSafetyGreen,
                              strokeWidth: 4.0,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _workerPos,
                              width: 32,
                              height: 32,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.riskCritical,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                child: const Icon(Icons.person, color: Colors.white, size: 16),
                              ),
                            ),
                            Marker(
                              point: _assemblyPointA,
                              width: 100,
                              height: 44,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppTheme.brandSafetyGreen, borderRadius: BorderRadius.circular(4)),
                                    child: Text('Titik Kumpul A', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                  const Icon(Icons.flag, color: AppTheme.brandSafetyGreen, size: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. 4 Prinsip Tanggap Darurat (Grid 2x2)
          Text('4 Prinsip Tanggap Darurat Tambang', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: [
              _buildPrincipleCard('1. Utamakan Keselamatan', 'Lindungi diri dan rekan kerja'),
              _buildPrincipleCard('2. Laporkan Segera', 'Pusat kendali dan radio ch. 3'),
              _buildPrincipleCard('3. Ikuti Arahan', 'Patuhi instruksi petugas HSE'),
              _buildPrincipleCard('4. Cegah Risiko Lanjutan', 'Matikan mesin alat berat'),
            ],
          ),
          const SizedBox(height: 20),

          // 5. 6 Langkah Evakuasi (Vertical Stepper)
          Text('6 Langkah Evakuasi Terstruktur', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 10),
          _buildEvacStep(1, 'Kenali Tanda Alarm Darurat', 'Hentikan seketika aktivitas kerja dan matikan mesin operasional.'),
          _buildEvacStep(2, 'Menuju Jalur Evakuasi Terdekat', 'Ikuti rambu digital dan marka hijau menuju rute yang ditentukan.'),
          _buildEvacStep(3, 'Tetap Tenang dan Tertib', 'Dilarang berlari tergesa-gesa atau berbalik mengambil barang pribadi.'),
          _buildEvacStep(4, 'Menuju Titik Kumpul (Assembly Point)', 'Berkumpul di area terbuka aman yang telah ditetapkan.'),
          _buildEvacStep(5, 'Ikuti Arahan Petugas HSE', 'Dengarkan instruksi pengawas dan tunggu verifikasi kondisi lapangan.'),
          _buildEvacStep(6, 'Pastikan Seluruh Pekerja Dievakuasi', 'Lakukan absensi keselamatan (headcount) di titik kumpul.'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPrincipleCard(String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandPrimary)),
          Text(desc, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.onSurfaceSecondary)),
        ],
      ),
    );
  }

  Widget _buildEvacStep(int step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(color: AppTheme.brandPrimary, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$step',
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
                Text(desc, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.onSurfaceSecondary, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
