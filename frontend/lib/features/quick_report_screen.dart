import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/offline_sync_manager.dart';

class QuickReportScreen extends StatefulWidget {
  const QuickReportScreen({super.key});

  @override
  State<QuickReportScreen> createState() => _QuickReportScreenState();
}

class _QuickReportScreenState extends State<QuickReportScreen> {
  String _selectedReportType = 'hazard'; // 'hazard' or 'near_miss'
  String _selectedZone = 'Pit Utama';
  String _selectedCategory = 'Alat Berat';
  final TextEditingController _descController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _zones = [
    'Pit Utama',
    'Jalan Angkut KM 0-15',
    'Stockpile & ROM',
    'Workshop',
    'Fasilitas Pengolahan',
    'Gudang Handak',
    'Fasilitas Pendukung',
  ];

  final List<String> _categories = [
    'Alat Berat',
    'Longsor / Geoteknik',
    'Kebakaran',
    'Debu & Lingkungan',
    'Cuaca Ekstrem',
    'Kepatuhan APD',
  ];

  Future<void> _submitReport() async {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan deskripsi singkat kondisi.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final reportData = {
      'local_id': 'rep-${DateTime.now().millisecondsSinceEpoch}',
      'report_type': _selectedReportType,
      'zone_name': _selectedZone,
      'category': _selectedCategory,
      'incident_timestamp': DateTime.now().toIso8601String(),
      'gps_latitude': -2.1458291,
      'gps_longitude': 115.3489124,
      'description': _descController.text.trim(),
      'photo_urls': ['https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?auto=format&fit=crop&w=800&q=80'],
      'is_emergency': false,
    };

    await OfflineSyncManager().enqueueReport(reportData);

    setState(() {
      _isSubmitting = false;
      _descController.clear();
    });

    if (mounted) {
      final isOnline = OfflineSyncManager().isOnline.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isOnline ? AppTheme.brandSafetyGreen : AppTheme.statusOffline,
          content: Text(
            isOnline
                ? 'Laporan berhasil dikirim langsung ke HSE!'
                : 'Mode Offline: Laporan tersimpan di perangkat & otomatis terkirim saat online.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slogan Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.brandPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.brandPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"Lapor Hari Ini, Cegah Kecelakaan Esok Hari"',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Segmented Type Selector (Bahaya vs Near Miss)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedReportType = 'hazard'),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: _selectedReportType == 'hazard' ? AppTheme.riskHighBg : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedReportType == 'hazard' ? AppTheme.riskHigh : AppTheme.borderSubtle,
                        width: _selectedReportType == 'hazard' ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.riskHigh, size: 22),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BAHAYA', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.riskHigh)),
                            Text('Kondisi / Tindakan', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.onSurfaceSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedReportType = 'near_miss'),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: _selectedReportType == 'near_miss' ? AppTheme.riskMediumBg : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedReportType == 'near_miss' ? AppTheme.riskMedium : AppTheme.borderSubtle,
                        width: _selectedReportType == 'near_miss' ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flash_on, color: AppTheme.riskMedium, size: 22),
                        const SizedBox(width: 6),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NEAR MISS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFB45309))),
                            Text('Hampir Celaka', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.onSurfaceSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 2. Lokasi Area Kerja & GPS
          Text('Lokasi Area Kerja', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.my_location, size: 14, color: AppTheme.brandPrimary),
              const SizedBox(width: 4),
              Text('GPS Terdeteksi: -2.1458291, 115.3489124', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.onSurfaceSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _zones.map((zone) {
                final isSelected = _selectedZone == zone;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(zone),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedZone = zone),
                    selectedColor: AppTheme.brandPrimary,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.onSurfacePrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // 3. Kategori Bahaya
          Text('Kategori Bahaya', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (val) => setState(() => _selectedCategory = cat),
                selectedColor: AppTheme.brandSecondary.withValues(alpha: 0.2),
                side: BorderSide(color: isSelected ? AppTheme.brandSecondary : AppTheme.borderSubtle),
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.brandPrimary : AppTheme.onSurfaceSecondary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // 4. Dokumentasi Foto Box
          Text('Dokumentasi Foto Bukti', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 8),
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.4), style: BorderStyle.solid, width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_a_photo, size: 36, color: AppTheme.brandPrimary),
                const SizedBox(height: 6),
                Text('Ambil Foto Kamera / Galeri', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.brandPrimary)),
                Text('Format otomatis dikompresi (< 1 MB)', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 5. Deskripsi Kondisi
          Text('Deskripsi Kondisi Bahaya', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Contoh: Retakan badan jalan angkut KM 4.2 melebar 15cm...',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic, color: AppTheme.brandPrimary),
                onPressed: () {
                  _descController.text = 'Retakan lereng aktif di dekat area pemuatan excavator #08.';
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 6. Dual-State Submit Button
          ValueListenableBuilder<bool>(
            valueListenable: OfflineSyncManager().isOnline,
            builder: (context, online, child) {
              return SizedBox(
                width: double.infinity,
                height: AppTheme.minTouchTarget,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReport,
                  icon: Icon(online ? Icons.send : Icons.save_alt, color: Colors.white),
                  label: Text(
                    online ? 'KIRIM LAPORAN KE HSE' : 'SIMPAN LAPORAN OFFLINE',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: online ? AppTheme.brandPrimary : AppTheme.statusOffline,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
