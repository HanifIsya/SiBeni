import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_service.dart';
import '../core/theme.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/sb_card.dart';
import '../widgets/states.dart';

/// Executive view of K3, energy and carbon performance.
///
/// Every figure is read from the metrics table. When a value is missing the
/// card renders an em dash — it never substitutes a plausible-looking default,
/// because a safety report must never contain invented numbers.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// Indonesian number formatting: `.` for thousands, `,` for decimals.
String formatNumber(num? value, {int decimals = 0}) {
  if (value == null) return '—';
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  final head = '${negative ? '-' : ''}$buffer';
  return parts.length > 1 ? '$head,${parts[1]}' : head;
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  DateTime? _period;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.instance.getKpis();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      if (data != null) {
        final raw = data['data']?['record_date'] ?? data['record_date'];
        _period = raw is String ? DateTime.tryParse(raw) : null;
      }
    });
  }

  // ------------------------------------------------------------------ helpers
  num? _live(String key) {
    final v = _data?['data']?[key];
    return v is num ? v : null;
  }

  num? _kpi(String key) {
    final v = _data?['kpis']?[key]?['value'];
    return v is num ? v : null;
  }

  num? _metric(String key) => _live(key) ?? _kpi(key);

  String _fmt(num? value, {int decimals = 0}) => formatNumber(value, decimals: decimals);

  @override
  Widget build(BuildContext context) {
    final energySources = <({String label, num? value, Color color})>[
      (label: 'Listrik & genset', value: _metric('energy_electricity_gj'), color: AppTheme.brand),
      (label: 'Gas alam', value: _metric('energy_natural_gas_gj'), color: AppTheme.accentDeep),
      (label: 'BBM solar', value: _metric('energy_diesel_fuel_gj'), color: const Color(0xFFB45309)),
      (label: 'Lainnya', value: _metric('energy_other_gj'), color: AppTheme.inkFaint),
    ];

    return AdaptivePage(
      onRefresh: _load,
      slivers: [
        SectionHeader(
          title: 'K3 & ESG',
          icon: Icons.insights_rounded,
          subtitle: _period == null
              ? 'Metrik operasional'
              : 'Periode ${DateFormat('MMMM yyyy').format(_period!)}',
        ),

        if (_loading && _data == null)
          const _KpiSkeleton()
        else if (_data == null)
          const EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Metrik belum tersedia',
            message: 'Hubungkan ke server untuk melihat data K3 dan ESG.',
          )
        else ...[
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 620 ? 4 : 2;
              const spacing = AppTheme.md;
              final width = (c.maxWidth - spacing * (columns - 1)) / columns;
              final cards = <Widget>[
                _MetricCard(
                  label: 'Jam kerja aman',
                  value: _fmt(_metric('safe_man_hours')),
                  unit: 'jam',
                  icon: Icons.verified_user_rounded,
                  tone: AppTheme.brand,
                ),
                _MetricCard(
                  label: 'TRIR',
                  value: _fmt(_metric('calculated_trir') ?? _kpi('trir'), decimals: 2),
                  unit: '',
                  icon: Icons.trending_down_rounded,
                  tone: AppTheme.riskLow,
                ),
                _MetricCard(
                  label: 'Energi total',
                  value: _fmt(_metric('total_energy_gj') ?? _kpi('total_energy')),
                  unit: 'GJ',
                  icon: Icons.bolt_rounded,
                  tone: const Color(0xFFB45309),
                ),
                _MetricCard(
                  label: 'Intensitas energi',
                  value: _fmt(
                    _metric('energy_intensity_gj_per_ton') ?? _kpi('energy_intensity'),
                    decimals: 2,
                  ),
                  unit: 'GJ/t',
                  icon: Icons.scale_rounded,
                  tone: AppTheme.accentDeep,
                ),
              ];

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: cards
                    .map((card) => SizedBox(width: width, child: card))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: AppTheme.md),

          _CarbonCard(
            value: _fmt(_metric('total_co2e_emissions_ton') ?? _kpi('total_co2e')),
          ),
          const SizedBox(height: AppTheme.lg),

          const SectionHeader(
            title: 'Komposisi Energi',
            icon: Icons.bar_chart_rounded,
            dense: true,
          ),
          SbCard(
            child: Column(
              children: [
                for (final src in energySources)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.md),
                    child: _EnergyBar(
                      label: src.label,
                      value: src.value,
                      color: src.color,
                      total: _metric('total_energy_gj'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ===========================================================================
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return SbCard(
      padding: const EdgeInsets.all(AppTheme.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: AppTheme.brSm,
                ),
                child: Icon(icon, size: 15, color: tone),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppTheme.mono(
                    size: 22,
                    weight: FontWeight.w800,
                    color: value == '—' ? AppTheme.inkFaint : AppTheme.ink,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarbonCard extends StatelessWidget {
  const _CarbonCard({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return SbHeroPanel(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: AppTheme.brMd,
            ),
            child: const Icon(Icons.eco_rounded, color: Color(0xFF6EE7B7), size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emisi karbon',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onDarkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: AppTheme.mono(
                          size: 24,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'ton CO₂e',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onDarkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyBar extends StatelessWidget {
  const _EnergyBar({
    required this.label,
    required this.value,
    required this.color,
    required this.total,
  });

  final String label;
  final num? value;
  final Color color;
  final num? total;

  @override
  Widget build(BuildContext context) {
    final ratio = (value != null && total != null && total! > 0)
        ? (value! / total!).clamp(0.0, 1.0)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value == null ? '—' : '${formatNumber(value)} GJ',
              style: AppTheme.mono(size: 11, weight: FontWeight.w700, color: AppTheme.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio ?? 0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => Stack(
              children: [
                Container(height: 6, color: AppTheme.surfaceSunken),
                FractionallySizedBox(
                  widthFactor: t,
                  child: Container(height: 6, color: color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: AppTheme.md,
          runSpacing: AppTheme.md,
          children: List.generate(
            4,
            (_) => const SizedBox(
              width: 160,
              child: SbCard(
                padding: EdgeInsets.all(AppTheme.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 28, width: 28, radius: 8),
                    SizedBox(height: 12),
                    SkeletonBox(height: 20, width: 90),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.md),
        const SbCard(
          child: SkeletonBox(height: 72, radius: 20),
        ),
      ],
    );
  }
}