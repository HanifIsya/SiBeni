import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_service.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/pills.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_card.dart';
import '../widgets/states.dart';

/// M-05 — K3, energy and carbon performance.
///
/// Every figure is read from `energy_emission_metrics`. Nothing is defaulted:
/// when the database has no row, the screen says so instead of inventing a
/// reassuring number.
///
/// Only **management** may write these values — they are the official K3/ESG
/// record. Supervisor and HSE see them read-only, which makes the permission
/// model visible rather than theoretical.
class InsightScreen extends StatefulWidget {
  const InsightScreen({super.key});

  @override
  State<InsightScreen> createState() => _InsightScreenState();
}

class _InsightScreenState extends State<InsightScreen> {
  Map<String, dynamic>? _payload;
  bool _loading = true;

  bool get _canEdit => UserSession.instance.currentUser.value?.role.canEditInsight ?? false;

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
      _payload = data;
      _loading = false;
    });
  }

  Map<String, dynamic>? get _latest {
    final raw = _payload?['data'];
    return raw is Map ? raw.cast<String, dynamic>() : null;
  }

  List<Map<String, dynamic>> get _history {
    final raw = _payload?['history'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  num? _value(String key) {
    final v = _latest?[key];
    return v is num ? v : null;
  }

  Future<void> _openEditor() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InsightEditorSheet(latest: _latest),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    final period = DateTime.tryParse((latest?['record_date'] ?? '').toString());

    return AdaptivePage(
      onRefresh: _load,
      slivers: [
        SectionHeader(
          title: 'K3 & ESG',
          icon: Icons.insights_rounded,
          subtitle: period == null
              ? 'Belum ada data pelaporan'
              : 'Periode ${DateFormat('MMMM yyyy').format(period)}',
          action: _canEdit
              ? SbButton(
                  label: 'Perbarui Data',
                  icon: Icons.edit_rounded,
                  height: 48,
                  expand: false,
                  variant: SbButtonVariant.ghost,
                  tone: AppTheme.brand,
                  onPressed: _openEditor,
                )
              : const SbPill(
                  label: 'Hanya baca',
                  icon: Icons.lock_rounded,
                  dense: true,
                  color: AppTheme.inkFaint,
                ),
        ),

        if (_loading && _payload == null)
          const _InsightSkeleton()
        else if (latest == null)
          EmptyState(
            icon: Icons.query_stats_rounded,
            title: 'Belum ada metrik tercatat',
            message: _canEdit
                ? 'Isi angka periode berjalan untuk mulai memantau kinerja K3 dan ESG.'
                : 'Manajemen belum memasukkan angka untuk periode ini.',
            action: _canEdit
                ? SbButton(
                    label: 'Isi Data Sekarang',
                    icon: Icons.add_rounded,
                    expand: false,
                    onPressed: _openEditor,
                  )
                : null,
          )
        else ...[
          if (!_canEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: SbPanel(
                color: AppTheme.surfaceMuted,
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 15, color: AppTheme.inkFaint),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Angka resmi dikelola Manajemen. Anda memiliki akses baca.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppTheme.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 620 ? 4 : 2;
              final width = (c.maxWidth - AppTheme.md * (columns - 1)) / columns;
              final cards = <Widget>[
                _MetricCard(
                  label: 'Jam kerja aman',
                  value: formatNumber(_value('safe_man_hours')),
                  unit: 'jam',
                  icon: Icons.verified_user_rounded,
                  tone: AppTheme.brand,
                ),
                _MetricCard(
                  label: 'TRIR',
                  value: formatNumber(_value('calculated_trir'), decimals: 2),
                  unit: '',
                  icon: Icons.trending_down_rounded,
                  tone: AppTheme.riskLow,
                ),
                _MetricCard(
                  label: 'Energi total',
                  value: formatNumber(_value('total_energy_gj')),
                  unit: 'GJ',
                  icon: Icons.bolt_rounded,
                  tone: const Color(0xFFB45309),
                ),
                _MetricCard(
                  label: 'Intensitas energi',
                  value: formatNumber(_value('energy_intensity_gj_per_ton'), decimals: 2),
                  unit: 'GJ/t',
                  icon: Icons.scale_rounded,
                  tone: AppTheme.accentDeep,
                ),
              ];
              return Wrap(
                spacing: AppTheme.md,
                runSpacing: AppTheme.md,
                children: cards.map((card) => SizedBox(width: width, child: card)).toList(),
              );
            },
          ),
          const SizedBox(height: AppTheme.md),

          _CarbonCard(value: formatNumber(_value('total_co2e_emissions_ton'))),
          const SizedBox(height: AppTheme.lg),

          const SectionHeader(
            title: 'Komposisi Energi',
            icon: Icons.bar_chart_rounded,
            dense: true,
          ),
          SbCard(
            child: Column(
              children: [
                for (final part in _energyParts())
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.md),
                    child: _EnergyBar(
                      label: part.$1,
                      value: part.$2,
                      share: part.$3,
                      color: part.$4,
                    ),
                  ),
              ],
            ),
          ),

          if (_history.length > 1) ...[
            const SizedBox(height: AppTheme.lg),
            const SectionHeader(
              title: 'Tren Periode',
              icon: Icons.show_chart_rounded,
              dense: true,
            ),
            SbCard(
              child: Column(
                children: List.generate(_history.length.clamp(0, 6), (i) {
                  final row = _history[i];
                  final date = DateTime.tryParse((row['record_date'] ?? '').toString());
                  return Padding(
                    padding:
                        EdgeInsets.only(bottom: i == _history.length - 1 ? 0 : AppTheme.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            date == null ? '—' : DateFormat('d MMM yyyy').format(date),
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.inkMuted),
                          ),
                        ),
                        Text(
                          '${formatNumber(row['safe_man_hours'])} jam',
                          style: AppTheme.mono(
                            size: 11.5,
                            weight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SbPill(
                          label: '${formatNumber(row['total_co2e_emissions_ton'])} CO₂e',
                          dense: true,
                          color: AppTheme.riskLow,
                          background: AppTheme.riskLowBg,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ],
    );
  }

  List<(String, num?, double, Color)> _energyParts() {
    final total = _value('total_energy_gj');
    const raw = <(String, String, Color)>[
      ('Listrik & genset', 'energy_electricity_gj', AppTheme.brand),
      ('Gas alam', 'energy_natural_gas_gj', AppTheme.accentDeep),
      ('BBM solar', 'energy_diesel_fuel_gj', Color(0xFFB45309)),
      ('Lainnya', 'energy_other_gj', AppTheme.inkFaint),
    ];

    return raw.map((r) {
      final value = _value(r.$2);
      final share = (value != null && total != null && total > 0)
          ? (value / total).clamp(0.0, 1.0)
          : 0.0;
      return (r.$1, value, share, r.$3);
    }).toList();
  }
}

// ===========================================================================
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
    required this.share,
    required this.color,
  });

  final String label;
  final num? value;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
              value == null
                  ? '—'
                  : '${formatNumber(value)} GJ · ${(share * 100).toStringAsFixed(0)}%',
              style: AppTheme.mono(size: 11, weight: FontWeight.w700, color: AppTheme.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: share),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => Stack(
              children: [
                Container(height: 6, color: AppTheme.surfaceSunken),
                FractionallySizedBox(widthFactor: t, child: Container(height: 6, color: color)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
/// Management-only editor for the official K3 / ESG record.
class _InsightEditorSheet extends StatefulWidget {
  const _InsightEditorSheet({required this.latest});
  final Map<String, dynamic>? latest;

  @override
  State<_InsightEditorSheet> createState() => _InsightEditorSheetState();
}

class _InsightEditorSheetState extends State<_InsightEditorSheet> {
  static const _schema = <String, (String, String)>{
    'safe_man_hours': ('Jam kerja aman', 'jam'),
    'total_recordable_incidents': ('Insiden tercatat', 'kejadian'),
    'calculated_trir': ('TRIR', ''),
    'energy_electricity_gj': ('Listrik & genset', 'GJ'),
    'energy_natural_gas_gj': ('Gas alam', 'GJ'),
    'energy_diesel_fuel_gj': ('BBM solar', 'GJ'),
    'energy_other_gj': ('Energi lainnya', 'GJ'),
    'total_energy_gj': ('Total energi', 'GJ'),
    'material_hauled_ton': ('Material terangkut', 'ton'),
    'energy_intensity_gj_per_ton': ('Intensitas energi', 'GJ/t'),
    'total_co2e_emissions_ton': ('Emisi CO₂e', 'ton'),
  };

  final _fields = <String, TextEditingController>{};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final key in _schema.keys) {
      final raw = widget.latest?[key];
      _fields[key] = TextEditingController(text: raw is num ? raw.toString() : '');
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final payload = <String, dynamic>{};

    for (final entry in _fields.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final parsed = num.tryParse(text.replaceAll(',', '.'));
      if (parsed == null) {
        setState(() => _error = 'Nilai "${_schema[entry.key]!.$1}" bukan angka yang valid.');
        return;
      }
      payload[entry.key] = parsed;
    }

    if (payload.isEmpty) {
      setState(() => _error = 'Isi minimal satu metrik.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ApiService.instance.saveKpis(payload);
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.online,
          content: Text(result.message ?? 'Metrik tersimpan.'),
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Perbarui Metrik',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Periode ${DateFormat('d MMMM yyyy').format(DateTime.now())}',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.inkMuted),
              ),
              const SizedBox(height: 14),

              SbCard(
                child: Column(
                  children: [
                    for (final entry in _schema.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                entry.value.$1,
                                style: const TextStyle(fontSize: 12.5, color: AppTheme.inkMuted),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _fields[entry.key],
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.right,
                                style: AppTheme.mono(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: AppTheme.ink,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  hintText: '0',
                                  suffixText: entry.value.$2.isEmpty ? null : entry.value.$2,
                                  suffixStyle:
                                      const TextStyle(fontSize: 11, color: AppTheme.inkFaint),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.riskCriticalBg,
                    borderRadius: AppTheme.brSm,
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.riskCritical,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              SbButton(
                label: 'Simpan Metrik',
                icon: Icons.save_rounded,
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightSkeleton extends StatelessWidget {
  const _InsightSkeleton();

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
        const SbCard(child: SkeletonBox(height: 72, radius: 20)),
      ],
    );
  }
}