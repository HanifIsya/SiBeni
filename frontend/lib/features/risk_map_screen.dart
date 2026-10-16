import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class RiskMapScreen extends StatelessWidget {
  final VoidCallback onNavigateToReport;
  final VoidCallback onNavigateToEmergency;

  const RiskMapScreen({
    super.key,
    required this.onNavigateToReport,
    required this.onNavigateToEmergency,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Worker Zone Pill & Active Shift
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.brandPrimary, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Zona Anda Saat Ini', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary)),
                        Text('Pit Utama (Aktif)', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.riskHighBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.riskHigh),
                  ),
                  child: Text(
                    'SIAGA (TINGGI)',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.riskHigh),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Early Warning Banner (BMKG Official)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.riskHighBg,
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: AppTheme.riskHigh, width: 4),
                top: BorderSide(color: AppTheme.borderSubtle, width: 1),
                right: BorderSide(color: AppTheme.borderSubtle, width: 1),
                bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.riskHigh, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PERINGATAN DINI RESMI BMKG',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.riskHigh, letterSpacing: 0.5),
                      ),
                    ),
                    Text(
                      '07.00 - 19.00 WIB',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Waspada Hujan Lebat & Angin Kencang di Konsesi Tambang',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.onSurfacePrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Zona Terancam: Pit Utama, Haul Road KM 4, Stockpile. Potensi longsor lereng barat dan jalan licin.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.onSurfaceSecondary, height: 1.4),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildHazardChip('Tanah Longsor'),
                    _buildHazardChip('Banjir Tambang'),
                    _buildHazardChip('Jalan Angkut Licin'),
                    _buildHazardChip('Petir'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Mining Risk Map Card (7 Operational Zones)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Peta Risiko 7 Zona Tambang', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
              Text('PT Consnet Mining', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.brandPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                // Simulated Vector Mining Map
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Stack(
                    children: [
                      // Grid background pattern
                      Positioned.fill(
                        child: CustomPaint(painter: MapGridPainter()),
                      ),
                      // Zone Overlays
                      Positioned(
                        top: 20,
                        left: 20,
                        child: _buildMapZoneNode('Pit Utama', AppTheme.riskHigh, 'Tinggi (Siaga)'),
                      ),
                      Positioned(
                        top: 60,
                        right: 30,
                        child: _buildMapZoneNode('Jalan Angkut KM 0-15', AppTheme.riskMedium, 'Sedang (Waspada)'),
                      ),
                      Positioned(
                        bottom: 30,
                        left: 30,
                        child: _buildMapZoneNode('Workshop & Bengkel', AppTheme.riskMedium, 'Sedang'),
                      ),
                      Positioned(
                        bottom: 40,
                        right: 40,
                        child: _buildMapZoneNode('Stockpile & ROM', AppTheme.riskLow, 'Rendah (Aman)'),
                      ),
                      // Worker Position Marker
                      Positioned(
                        top: 45,
                        left: 80,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_pin_circle, color: Colors.cyanAccent, size: 16),
                              const SizedBox(width: 4),
                              Text('Posisi Anda', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4-Tier Risk Taxonomy Legend
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegendItem('Rendah', AppTheme.riskLow),
                      _buildLegendItem('Sedang', AppTheme.riskMedium),
                      _buildLegendItem('Tinggi', AppTheme.riskHigh),
                      _buildLegendItem('Sangat Tinggi', AppTheme.riskCritical),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Quick Action Cards (Lapor Cepat & Tombol SOS)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppTheme.minTouchTarget,
                  child: ElevatedButton.icon(
                    onPressed: onNavigateToReport,
                    icon: const Icon(Icons.edit_note, size: 20),
                    label: const Text('Lapor Cepat', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: AppTheme.minTouchTarget,
                  child: ElevatedButton.icon(
                    onPressed: onNavigateToEmergency,
                    icon: const Icon(Icons.sos, size: 24),
                    label: const Text('DARURAT', style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.riskCritical,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHazardChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.riskHigh.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.riskHigh),
      ),
    );
  }

  Widget _buildMapZoneNode(String name, Color color, String status) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(status, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceSecondary)),
      ],
    );
  }
}

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 0.5;

    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
