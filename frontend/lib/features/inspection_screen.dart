import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  int _selectedCategoryIndex = 0;

  final List<String> _categories = [
    'Penggunaan APD',
    'Alat Berat',
    'Jalan Angkut',
    'APAR',
    'Housekeeping',
    'Lingkungan',
  ];

  final List<Map<String, dynamic>> _checklistItems = [
    {'item': 'Helm Keselamatan (Hard Hat) & Tali Dagu', 'passed': true},
    {'item': 'Sepatu Safety Boots Berkualitas Standar SNI', 'passed': true},
    {'item': 'Rompi Reflektif Visibilitas Tinggi', 'passed': true},
    {'item': 'Kacamata Safety (Anti Debu & UV)', 'passed': false, 'note': '2 pekerja tidak memakai kacamata di area stockpile berdebu.'},
    {'item': 'Masker Respirator / Partikulat Debu P100', 'passed': true},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Pipeline Bar (6-Stage Alur Inspeksi & Corrective Action)
          Text('Alur 6 Tahap Corrective Action', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStagePill(1, 'Inspeksi', true),
                _buildStagePill(2, 'Temuan', true),
                _buildStagePill(3, 'Verifikasi', true),
                _buildStagePill(4, 'Tugaskan', true),
                _buildStagePill(5, 'Perbaikan', false),
                _buildStagePill(6, 'Selesai', false),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Kategori Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_categories.length, (index) {
                final isSelected = _selectedCategoryIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(_categories[index]),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedCategoryIndex = index),
                    selectedColor: AppTheme.brandSafetyGreen,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppTheme.onSurfacePrimary,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Checklist Items List
          Text('Checklist Inspeksi Lapangan — Shift Pagi', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _checklistItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.borderSubtle),
              itemBuilder: (context, idx) {
                final item = _checklistItems[idx];
                final bool passed = item['passed'] as bool;
                return ListTile(
                  dense: true,
                  title: Text(item['item'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: item['note'] != null
                      ? Text(item['note'] as String, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.riskCritical))
                      : null,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: passed ? AppTheme.riskLowBg : AppTheme.riskCriticalBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      passed ? 'LULUS' : 'TEMUAN',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: passed ? AppTheme.riskLow : AppTheme.riskCritical,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // 4. Active Corrective Action Card
          Text('Tiket Tindak Lanjut Aktif', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: AppTheme.riskHigh, width: 4),
                top: BorderSide(color: AppTheme.borderSubtle),
                right: BorderSide(color: AppTheme.borderSubtle),
                bottom: BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CA-2026-089', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.brandPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.riskHighBg, borderRadius: BorderRadius.circular(10)),
                      child: Text('TAHAP 4: PENUGASAN', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.riskHigh)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Perataan & Pemadatan Retakan Haul Road KM 4.2', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('PIC: Hendro Wijaya (Supervisor Road Maintenance)\nBatas Waktu: 17 Oktober 2026', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tindakan verifikasi telah diteruskan ke Supervisor HSE.')),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Verifikasi & Lanjutkan Tahap 5'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandSafetyGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStagePill(int stage, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: active ? AppTheme.brandSafetyGreen : AppTheme.borderSubtle,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$stage',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
