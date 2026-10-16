import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/user_session.dart';
import '../../core/api_service.dart';

class RiskMapScreen extends StatefulWidget {
  final VoidCallback onNavigateToReport;
  final VoidCallback onNavigateToEmergency;

  const RiskMapScreen({
    super.key,
    required this.onNavigateToReport,
    required this.onNavigateToEmergency,
  });

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> {
  List<Map<String, dynamic>> _warnings = [];
  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final warnings = await ApiService().getEarlyWarnings();
    final zones = await ApiService().getMiningZones();
    if (mounted) {
      setState(() {
        _warnings = warnings;
        _zones = zones;
        _isLoading = false;
      });
    }
  }

  Color _getRiskColor(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return AppTheme.riskCritical;
      case 'high':
        return AppTheme.riskHigh;
      case 'medium':
        return AppTheme.riskMedium;
      default:
        return AppTheme.riskLow;
    }
  }

  String _getRiskLabel(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return 'Sangat Tinggi (Awas)';
      case 'high':
        return 'Tinggi (Siaga)';
      case 'medium':
        return 'Sedang (Waspada)';
      default:
        return 'Rendah (Aman)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession().currentUser.value;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Worker Zone Pill & Active Shift
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.brandPrimary, size: 22),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Zona & Peran Anda', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary)),
                          Text(
                            user != null ? '${user.workZone.split(' (')[0]} • ${user.roleDisplayName}' : 'Pit Utama',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary),
                          ),
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
                      'STATUS: SIAGA',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.riskHigh),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Early Warning Banner (BMKG & BNPB Live from Database)
            if (_isLoading && _warnings.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_warnings.isNotEmpty)
              ..._warnings.map((w) {
                final severity = w['severity'] ?? 'medium';
                final isHigh = severity == 'high' || severity == 'critical';
                final tags = List<String>.from(w['hazard_tags'] ?? ['Cuaca Ekstrem', 'Longsor']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isHigh ? AppTheme.riskHighBg : AppTheme.riskMediumBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(color: isHigh ? AppTheme.riskHigh : AppTheme.riskMedium, width: 4),
                        top: const BorderSide(color: AppTheme.borderSubtle, width: 1),
                        right: const BorderSide(color: AppTheme.borderSubtle, width: 1),
                        bottom: const BorderSide(color: AppTheme.borderSubtle, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: isHigh ? AppTheme.riskHigh : const Color(0xFFB45309), size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PERINGATAN DINI RESMI ${w['source'] ?? 'BMKG'}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isHigh ? AppTheme.riskHigh : const Color(0xFFB45309),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                severity.toString().toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          w['title'] ?? 'Waspada Potensi Bahaya',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.onSurfacePrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          w['description'] ?? '',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.onSurfaceSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: tags.map((t) => _buildHazardChip(t, isHigh ? AppTheme.riskHigh : const Color(0xFFB45309))).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              })
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.riskLowBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.riskLow),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.riskLow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tidak ada peringatan dini darurat aktif. Kondisi operasional normal.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.brandSafetyGreen),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            // 3. Mining Risk Map Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Peta Risiko 7 Zona Tambang', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
                Text('Live Database', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.brandSafetyGreen, fontWeight: FontWeight.bold)),
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
                  // Vector Mining Map Layout with Dynamic Zone Statuses
                  Container(
                    height: 230,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: MapGridPainter()),
                        ),
                        // Dynamic Zone 1: Pit
                        Positioned(
                          top: 15,
                          left: 15,
                          child: _buildMapZoneNode(
                            _zones.isNotEmpty ? _zones[0]['name'].toString().split(' (')[0] : 'Pit Utama',
                            _zones.isNotEmpty ? _getRiskColor(_zones[0]['current_risk_level'] ?? 'high') : AppTheme.riskHigh,
                            _zones.isNotEmpty ? _getRiskLabel(_zones[0]['current_risk_level'] ?? 'high') : 'Tinggi',
                          ),
                        ),
                        // Dynamic Zone 2: Haul Road
                        Positioned(
                          top: 55,
                          right: 20,
                          child: _buildMapZoneNode(
                            _zones.length > 1 ? _zones[1]['name'].toString().split(' (')[0] : 'Haul Road',
                            _zones.length > 1 ? _getRiskColor(_zones[1]['current_risk_level'] ?? 'medium') : AppTheme.riskMedium,
                            _zones.length > 1 ? _getRiskLabel(_zones[1]['current_risk_level'] ?? 'medium') : 'Sedang',
                          ),
                        ),
                        // Dynamic Zone 3: Workshop
                        Positioned(
                          bottom: 25,
                          left: 20,
                          child: _buildMapZoneNode(
                            _zones.length > 3 ? _zones[3]['name'].toString().split(' (')[0] : 'Workshop',
                            _zones.length > 3 ? _getRiskColor(_zones[3]['current_risk_level'] ?? 'medium') : AppTheme.riskMedium,
                            _zones.length > 3 ? _getRiskLabel(_zones[3]['current_risk_level'] ?? 'medium') : 'Sedang',
                          ),
                        ),
                        // Dynamic Zone 4: Stockpile
                        Positioned(
                          bottom: 35,
                          right: 25,
                          child: _buildMapZoneNode(
                            _zones.length > 2 ? _zones[2]['name'].toString().split(' (')[0] : 'Stockpile',
                            _zones.length > 2 ? _getRiskColor(_zones[2]['current_risk_level'] ?? 'low') : AppTheme.riskLow,
                            _zones.length > 2 ? _getRiskLabel(_zones[2]['current_risk_level'] ?? 'low') : 'Rendah',
                          ),
                        ),
                        // Worker Position Badge
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
                                Text(
                                  user != null ? user.fullName : 'Posisi Anda',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
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

            // 4. Quick Action Cards
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppTheme.minTouchTarget,
                    child: ElevatedButton.icon(
                      onPressed: widget.onNavigateToReport,
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
                      onPressed: widget.onNavigateToEmergency,
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
      ),
    );
  }

  Widget _buildHazardChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: color),
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
