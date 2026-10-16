import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('K3, Energi & Emisi', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.surfaceMuted, borderRadius: BorderRadius.circular(8)),
                child: Text('1 - 31 Okt 2026', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5 KPI Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _buildKpiCard('Total Jam Selamat', '1.247.652', 'jam', '+12,4%', Icons.verified_user, AppTheme.brandPrimary, true),
              _buildKpiCard('TRIR (Tingkat Insiden)', '0,48', '', '-20,0%', Icons.speed, AppTheme.brandSafetyGreen, false),
              _buildKpiCard('Energi Total', '24.785', 'GJ', '-3,1%', Icons.bolt, Colors.amber.shade800, false),
              _buildKpiCard('Intensitas Energi', '2,41', 'GJ/t', '-5,5%', Icons.analytics, Colors.blue.shade700, false),
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
                    Text('12.456 Ton', style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.brandSafetyGreen)),
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
          Text('Konsumsi Energi per Sumber', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary)),
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
                _buildEnergyBar('Listrik PLN & Site Genset', 0.45, '45% (11.153 GJ)', AppTheme.brandPrimary),
                const SizedBox(height: 10),
                _buildEnergyBar('Gas Alam Operasional', 0.25, '25% (6.196 GJ)', AppTheme.brandSecondary),
                const SizedBox(height: 10),
                _buildEnergyBar('BBM Solar Industri (Hauler)', 0.15, '15% (3.718 GJ)', Colors.amber.shade700),
                const SizedBox(height: 10),
                _buildEnergyBar('Lainnya & Pelumas', 0.15, '15% (3.718 GJ)', const Color(0xFF94A3B8)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, String unit, String trend, IconData icon, Color color, bool isPositiveGood) {
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
