import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _kpiData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await ApiService().getKpis();
    if (mounted) {
      setState(() {
        _kpiData = data;
        _isLoading = false;
      });
    }
  }

  String _formatNumber(dynamic val) {
    if (val == null) return '0';
    if (val is num) {
      return NumberFormat('#,###', 'id_ID').format(val);
    }
    return val.toString();
  }

  @override
  Widget build(BuildContext context) {
    final liveData = _kpiData?['data'] as Map<String, dynamic>?;
    final fallbackKpis = _kpiData?['kpis'] as Map<String, dynamic>?;

    final safeHours = liveData?['safe_man_hours'] ?? fallbackKpis?['safe_man_hours']?['value'] ?? 1247652;
    final trir = liveData?['calculated_trir'] ?? fallbackKpis?['trir']?['value'] ?? 0.48;
    final totalEnergy = liveData?['total_energy_gj'] ?? fallbackKpis?['total_energy']?['value'] ?? 24785;
    final intensity = liveData?['energy_intensity_gj_per_ton'] ?? fallbackKpis?['energy_intensity']?['value'] ?? 2.41;
    final co2e = liveData?['total_co2e_emissions_ton'] ?? fallbackKpis?['total_co2e']?['value'] ?? 12456;

    final electricityGj = liveData?['energy_electricity_gj'] ?? 11153;
    final naturalGasGj = liveData?['energy_natural_gas_gj'] ?? 6196;
    final dieselGj = liveData?['energy_diesel_fuel_gj'] ?? 3718;
    final otherGj = liveData?['energy_other_gj'] ?? 3718;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('K3, Energi & Emisi', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
                    Text('Data Terintegrasi Supabase & ESG', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppTheme.surfaceMuted, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.borderSubtle)),
                  child: Row(
                    children: [
                      const Icon(Icons.sync, size: 12, color: AppTheme.brandSafetyGreen),
                      const SizedBox(width: 4),
                      Text('1 - 31 Okt 2026', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_isLoading && _kpiData == null)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else ...[
              // 5 KPI Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  _buildKpiCard('Total Jam Selamat', _formatNumber(safeHours), 'jam', '+12,4%', Icons.verified_user, AppTheme.brandPrimary),
                  _buildKpiCard('TRIR (Insiden Rate)', trir.toString(), '', '-20,0% (Target <0.5)', Icons.speed, AppTheme.brandSafetyGreen),
                  _buildKpiCard('Energi Total', _formatNumber(totalEnergy), 'GJ', '-3,1% efisiensi', Icons.bolt, Colors.amber.shade800),
                  _buildKpiCard('Intensitas Energi', intensity.toString(), 'GJ/t', '-5,5% vs target', Icons.analytics, Colors.blue.shade700),
                ],
              ),
              const SizedBox(height: 10),

              // 5th KPI Card (Full Width): Total Emisi CO2e
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emisi Total Karbon (CO₂e)', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.onSurfaceSecondary)),
                        const SizedBox(height: 4),
                        Text('${_formatNumber(co2e)} Ton', style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.brandSafetyGreen)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.riskLowBg, borderRadius: BorderRadius.circular(20)),
                      child: Text('-6,8% Dekarbonisasi', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandSafetyGreen)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Energy Source Breakdown
              Text('Konsumsi Energi per Sumber (GJ)', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildEnergyBar('Listrik PLN & Site Genset', 0.45, '45% (${_formatNumber(electricityGj)} GJ)', AppTheme.brandPrimary),
                    const SizedBox(height: 10),
                    _buildEnergyBar('Gas Alam Operasional', 0.25, '25% (${_formatNumber(naturalGasGj)} GJ)', AppTheme.brandSecondary),
                    const SizedBox(height: 10),
                    _buildEnergyBar('BBM Solar Industri (Hauler)', 0.15, '15% (${_formatNumber(dieselGj)} GJ)', Colors.amber.shade700),
                    const SizedBox(height: 10),
                    _buildEnergyBar('Lainnya & Pelumas', 0.15, '15% (${_formatNumber(otherGj)} GJ)', const Color(0xFF94A3B8)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, String unit, String trend, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary), overflow: TextOverflow.ellipsis)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.onSurfacePrimary)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(unit, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary)),
              ],
            ],
          ),
          Text(trend, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.brandSafetyGreen)),
        ],
      ),
    );
  }

  Widget _buildEnergyBar(String label, double ratio, String desc, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600)),
            Text(desc, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.onSurfaceSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: ratio,
          backgroundColor: AppTheme.surfaceMuted,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
      ],
    );
  }
}
