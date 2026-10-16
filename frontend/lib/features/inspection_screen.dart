import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/user_session.dart';
import '../../core/api_service.dart';

class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  int _selectedCategoryIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _correctiveActions = [];

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
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getInspectionsAndCorrectiveActions();
    if (mounted) {
      setState(() {
        if (data['corrective_actions'] != null) {
          _correctiveActions = List<Map<String, dynamic>>.from(data['corrective_actions']);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _advanceStage(String id, int currentStage) async {
    final nextStage = (currentStage < 6) ? currentStage + 1 : 6;
    final user = UserSession().currentUser.value;
    final note = 'Diverifikasi oleh ${user?.fullName ?? "Supervisor"} pada ${DateTime.now().toString().split('.')[0]}';

    final success = await ApiService().advanceCorrectiveActionStage(id, nextStage, note);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.brandSafetyGreen,
            content: Text('Tahap berhasil diperbarui ke Tahap $nextStage di database Supabase!'),
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembaruan disimpan lokal (offline).')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession().currentUser.value;
    final canVerify = user?.role == AppRole.supervisor || user?.role == AppRole.hse || user?.role == AppRole.management;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Role Notification
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.brandSafetyGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.brandSafetyGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, size: 16, color: AppTheme.brandSafetyGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Modul Inspeksi Aktif: ${user?.roleDisplayName ?? "Pengawas"}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandSafetyGreen),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

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
            Text('Checklist Inspeksi Lapangan — ${_categories[_selectedCategoryIndex]}', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
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

            // 4. Live Corrective Action Tickets from Database
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tiket Tindak Lanjut Aktif (Supabase)', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
                Text('${_correctiveActions.length} Tiket', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandPrimary)),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoading && _correctiveActions.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_correctiveActions.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderSubtle)),
                child: Center(
                  child: Text('Tidak ada tiket perbaikan aktif saat ini.', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.onSurfaceSecondary)),
                ),
              )
            else
              ..._correctiveActions.map((ca) {
                final int stage = ca['stage_number'] ?? 4;
                final isCompleted = stage >= 6 || ca['status'] == 'completed';
                final severity = ca['severity'] ?? 'medium';
                final isHigh = severity == 'high' || severity == 'critical';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(color: isCompleted ? AppTheme.riskLow : (isHigh ? AppTheme.riskHigh : AppTheme.riskMedium), width: 4),
                        top: const BorderSide(color: AppTheme.borderSubtle),
                        right: const BorderSide(color: AppTheme.borderSubtle),
                        bottom: const BorderSide(color: AppTheme.borderSubtle),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ca['id'] != null ? 'CA-${ca['id'].toString().substring(0, 8)}' : 'CA-TICKET',
                              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.brandPrimary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCompleted ? AppTheme.riskLowBg : AppTheme.riskHighBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isCompleted ? 'SELESAI (TAHAP 6)' : 'TAHAP $stage: ${stage == 4 ? "PENUGASAN" : stage == 5 ? "PERBAIKAN FISIK" : "INSPEKSI"}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isCompleted ? AppTheme.riskLow : AppTheme.riskHigh,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(ca['title'] ?? 'Tindakan Perbaikan', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          ca['description'] ?? '',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.onSurfaceSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'PIC: ${ca['assigned_pic_name'] ?? "Tim Lapangan"}\nTarget Selesai: ${ca['target_due_date'] ?? "Segera"}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.brandPrimary, fontWeight: FontWeight.w600),
                        ),
                        if (ca['hse_verification_notes'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Catatan: ${ca['hse_verification_notes']}', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 12),
                        if (!isCompleted && canVerify)
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: () => _advanceStage(ca['id'], stage),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: Text('Verifikasi & Lanjutkan ke Tahap ${stage + 1}'),
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
                );
              }),
            const SizedBox(height: 20),
          ],
        ),
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
