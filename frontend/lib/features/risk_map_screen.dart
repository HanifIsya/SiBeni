import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _warnings = [];
  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;

  // Real geographic center of mining concession
  final LatLng _workerPos = const LatLng(-2.1458291, 115.3489124);

  // 7 Defined Geographic Points in OpenStreetMap
  final Map<String, LatLng> _zoneCoordinates = {
    'ZONE_PIT': const LatLng(-2.1458291, 115.3489124),
    'ZONE_HAUL_ROAD': const LatLng(-2.1492000, 115.3524000),
    'ZONE_STOCKPILE': const LatLng(-2.1528000, 115.3561000),
    'ZONE_WORKSHOP': const LatLng(-2.1435000, 115.3468000),
    'ZONE_PROCESSING': const LatLng(-2.1550000, 115.3585000),
    'ZONE_WAREHOUSE': const LatLng(-2.1412000, 115.3435000),
    'ZONE_SUPPORT': const LatLng(-2.1425000, 115.3452000),
  };

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
        return 'SANGAT TINGGI (AWAS)';
      case 'high':
        return 'TINGGI (SIAGA)';
      case 'medium':
        return 'SEDANG (WASPADA)';
      default:
        return 'RENDAH (AMAN)';
    }
  }

  void _showZoneDetail(Map<String, dynamic> zone) {
    final riskLevel = zone['current_risk_level'] ?? 'low';
    final color = _getRiskColor(riskLevel);
    final hazards = List<String>.from(zone['active_hazards'] ?? []);

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
                  Expanded(
                    child: Text(
                      zone['name'] ?? 'Zona Tambang',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
                    child: Text(_getRiskLabel(riskLevel), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(zone['description'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.onSurfaceSecondary)),
              const SizedBox(height: 12),
              Text('Potensi Bahaya Teridentifikasi:', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (hazards.isEmpty)
                Text('• Tidak ada ancaman geoteknik atau cuaca aktif di zona ini.', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.brandSafetyGreen))
              else
                ...hazards.map((h) => Text('• $h', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.riskHigh, fontWeight: FontWeight.w600))),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.surfaceMuted, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: AppTheme.brandSafetyGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Titik Kumpul Evakuasi Terdekat:', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.onSurfaceSecondary)),
                          Text(zone['evacuation_assembly_point'] ?? 'Assembly Point A', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.brandSafetyGreen)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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
            // 1. Worker Identity & Shift Badge
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
                          Text('Lokasi Operasional Anda', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary)),
                          Text(
                            user != null ? user.workZone.split(' (')[0] : 'Pit Utama',
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

            // 2. Early Warning Alert Card (Live Supabase & BMKG)
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
              }),

            // 3. Real Interactive OpenStreetMap Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Peta Risiko Interaktif (OpenStreetMap)', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.surfaceMuted, borderRadius: BorderRadius.circular(6)),
                  child: Text('OSM Live Tiles', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.brandPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _workerPos,
                              initialZoom: 14.5,
                              minZoom: 12.0,
                              maxZoom: 18.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.consnet.sibeni',
                              ),
                              // Haul Road Arterial Polyline connecting pit to facilities
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: [
                                      const LatLng(-2.1412, 115.3435), // Warehouse
                                      const LatLng(-2.1435, 115.3468), // Workshop
                                      const LatLng(-2.1458, 115.3489), // Pit Utama
                                      const LatLng(-2.1492, 115.3524), // Haul Road KM 4
                                      const LatLng(-2.1528, 115.3561), // Stockpile
                                      const LatLng(-2.1550, 115.3585), // Crusher Plant
                                    ],
                                    color: const Color(0xFFEAB308),
                                    strokeWidth: 4.0,
                                  ),
                                  // Green evacuation route
                                  Polyline(
                                    points: [
                                      _workerPos,
                                      const LatLng(-2.1448, 115.3475),
                                      const LatLng(-2.1435, 115.3468),
                                    ],
                                    color: AppTheme.brandSafetyGreen,
                                    strokeWidth: 3.5,
                                  ),
                                ],
                              ),
                              // Mining Zones Markers
                              MarkerLayer(
                                markers: [
                                  // 7 Zones Markers
                                  ..._zones.map((zone) {
                                    final code = zone['code'] ?? 'ZONE_PIT';
                                    final pos = _zoneCoordinates[code] ?? _workerPos;
                                    final riskColor = _getRiskColor(zone['current_risk_level'] ?? 'low');
                                    final shortName = zone['name'].toString().split(' (')[0];

                                    return Marker(
                                      point: pos,
                                      width: 90,
                                      height: 50,
                                      child: GestureDetector(
                                        onTap: () => _showZoneDetail(zone),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: riskColor, width: 2),
                                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                              ),
                                              child: Text(
                                                shortName,
                                                style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(Icons.location_on, color: riskColor, size: 22),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),

                                  // Worker Live Position Marker
                                  Marker(
                                    point: _workerPos,
                                    width: 36,
                                    height: 36,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandSecondary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: const [BoxShadow(color: Color(0x6600B4D8), blurRadius: 8, spreadRadius: 2)],
                                      ),
                                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Map Controls (Zoom In/Out, Re-center)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Column(
                              children: [
                                FloatingActionButton.small(
                                  heroTag: 'btn_zoom_in',
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.brandPrimary,
                                  onPressed: () {
                                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                                  },
                                  child: const Icon(Icons.add),
                                ),
                                const SizedBox(height: 6),
                                FloatingActionButton.small(
                                  heroTag: 'btn_zoom_out',
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.brandPrimary,
                                  onPressed: () {
                                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                                  },
                                  child: const Icon(Icons.remove),
                                ),
                                const SizedBox(height: 6),
                                FloatingActionButton.small(
                                  heroTag: 'btn_recenter',
                                  backgroundColor: AppTheme.brandPrimary,
                                  foregroundColor: Colors.white,
                                  onPressed: () {
                                    _mapController.move(_workerPos, 15.0);
                                  },
                                  child: const Icon(Icons.my_location),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4-Tier Risk Taxonomy Legend
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLegendItem('Rendah', AppTheme.riskLow),
                        _buildLegendItem('Sedang', AppTheme.riskMedium),
                        _buildLegendItem('Tinggi', AppTheme.riskHigh),
                        _buildLegendItem('Kritis (SOS)', AppTheme.riskCritical),
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
