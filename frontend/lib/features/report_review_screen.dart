import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api_service.dart';
import '../core/theme.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/pills.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_card.dart';
import '../widgets/states.dart';

/// M-06 — Hazard report review.
///
/// The missing half of the reporting loop: a filed report is not "done". It has
/// to be picked up by HSE, assessed, and closed with a decision. Every
/// transition here is enforced twice — the button hides itself for roles that
/// lack the capability, and the API re-checks it under Row Level Security.
class ReportReviewScreen extends StatefulWidget {
  const ReportReviewScreen({super.key});

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic> _counts = const {};
  bool _loading = true;
  String _filter = 'SUBMITTED';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.instance.getReports(status: _filter);
    if (!mounted) return;
    setState(() {
      _reports = result.reports;
      _counts = result.counts;
      _loading = false;
    });
  }

  Future<void> _openReview(Map<String, dynamic> report) async {
    final decision = await showModalBottomSheet<ReviewDecision>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(report: report),
    );
    if (decision == null || !mounted) return;

    final result = await ApiService.instance.reviewReport(
      id: report['id'].toString(),
      status: decision.status,
      notes: decision.notes,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.isSuccess ? AppTheme.online : AppTheme.riskCritical,
        content: Text(result.message ?? result.error ?? ''),
      ),
    );
    if (result.isSuccess) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptivePage(
      onRefresh: _load,
      slivers: [
        const SectionHeader(
          title: 'Tinjauan Laporan',
          icon: Icons.fact_check_rounded,
          subtitle: 'Periksa dan putuskan laporan yang masuk dari lapangan',
        ),

        _StatusSummary(
          counts: _counts,
          filter: _filter,
          onChanged: (v) {
            setState(() => _filter = v);
            _load();
          },
        ),
        const SizedBox(height: AppTheme.lg),

        if (_loading)
          const _ReviewSkeleton()
        else if (_reports.isEmpty)
          EmptyState(
            icon: _filter == 'SUBMITTED'
                ? Icons.inbox_rounded
                : Icons.assignment_turned_in_rounded,
            title: _filter == 'SUBMITTED'
                ? 'Tidak ada laporan baru'
                : 'Tidak ada laporan pada status ini',
            message: _filter == 'SUBMITTED'
                ? 'Semua laporan telah ditinjau.'
                : 'Ganti filter untuk melihat status lain.',
            compact: true,
          )
        else
          for (final report in _reports)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: _ReportCard(
                report: report,
                onReview: () => _openReview(report),
              ),
            ),
      ],
    );
  }
}

// ===========================================================================
class ReviewDecision {
  const ReviewDecision(this.status, this.notes);
  final String status;
  final String? notes;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.report});
  final Map<String, dynamic> report;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final TextEditingController _notes =
      TextEditingController(text: (widget.report['hse_notes'] ?? '').toString());

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _decide(String status) {
    Navigator.pop(context, ReviewDecision(status, _notes.text));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final status = (r['hse_status'] ?? 'SUBMITTED').toString();
    final type = r['report_type'] == 'near_miss' ? 'Near Miss' : 'Bahaya';
    final timestamp = DateTime.tryParse((r['incident_timestamp'] ?? '').toString());

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tinjau Laporan',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  SbPill(label: _statusLabel(status), dense: true),
                ],
              ),
              const SizedBox(height: 16),

              SbCard(
                padding: const EdgeInsets.all(AppTheme.md),
                child: Column(
                  children: [
                    _Line(label: 'Jenis', value: type),
                    _Line(
                      label: 'Zona',
                      value: (r['zone_name'] ?? '—').toString(),
                    ),
                    _Line(label: 'Kategori', value: (r['category'] ?? '—').toString()),
                    _Line(label: 'Pelapor', value: (r['reporter_name'] ?? '—').toString()),
                    if (timestamp != null)
                      _Line(
                        label: 'Waktu',
                        value: DateFormat('d MMM yyyy, HH:mm').format(timestamp),
                      ),
                    if (r['gps_latitude'] != null)
                      _Line(
                        label: 'Koordinat',
                        value:
                            '${(r['gps_latitude'] as num).toStringAsFixed(5)}, ${(r['gps_longitude'] as num).toStringAsFixed(5)}',
                        mono: true,
                      ),
                  ],
                ),
              ),

              if ((r['description'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('DESKRIPSI', style: AppTheme.eyebrow()),
                const SizedBox(height: 7),
                Text(
                  r['description'].toString(),
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.55,
                    color: AppTheme.ink,
                  ),
                ),
              ],

              const SizedBox(height: 18),
              Text('CATATAN PENINJAUAN', style: AppTheme.eyebrow()),
              const SizedBox(height: 7),
              TextField(
                controller: _notes,
                maxLines: 3,
                maxLength: 400,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
                decoration: const InputDecoration(
                  hintText: 'Temuan, instruksi, atau tindak lanjut HSE…',
                ),
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  Expanded(
                    child: SbButton(
                      label: 'Tolak',
                      icon: Icons.close_rounded,
                      variant: SbButtonVariant.ghost,
                      tone: AppTheme.inkFaint,
                      onPressed: () => _decide('ACTION_REQUIRED'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  Expanded(
                    child: SbButton(
                      label: 'Terima',
                      icon: Icons.check_rounded,
                      variant: SbButtonVariant.ghost,
                      tone: AppTheme.brand,
                      onPressed: () => _decide('IN_REVIEW'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.sm),
              SbButton(
                label: 'Tutup Laporan',
                icon: Icons.verified_rounded,
                onPressed: () => _decide('CLOSED'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'IN_REVIEW':
        return 'DITINJAU';
      case 'ACTION_REQUIRED':
        return 'PERLU TINDAKAN';
      case 'CLOSED':
        return 'DITUTUP';
      default:
        return 'BARU';
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onReview});
  final Map<String, dynamic> report;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final status = (report['hse_status'] ?? 'SUBMITTED').toString();
    final isEmergency = report['is_emergency'] == true;
    final isNearMiss = report['report_type'] == 'near_miss';
    final color = isEmergency
        ? AppTheme.riskCritical
        : isNearMiss
            ? AppTheme.riskMedium
            : AppTheme.riskHigh;
    final timestamp = DateTime.tryParse((report['incident_timestamp'] ?? '').toString());

    return SbCard(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  (report['description'] ?? 'Laporan lapangan').toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SbPill(
                label: _ReviewSheetState._statusLabel(status),
                color: _statusColor(status),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (isEmergency)
                const SbPill(
                  label: 'DARURAT',
                  icon: Icons.crisis_alert_rounded,
                  color: AppTheme.riskCritical,
                  dense: true,
                ),
              SbTag(
                label: (report['zone_name'] ?? '').toString().split(' (').first,
                icon: Icons.place_rounded,
              ),
              SbTag(label: (report['category'] ?? '—').toString()),
              SbTag(
                label: (report['reporter_name'] ?? '—').toString(),
                icon: Icons.person_rounded,
              ),
              if (timestamp != null)
                SbTag(
                  label: DateFormat('d MMM, HH:mm').format(timestamp),
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
          const SizedBox(height: 14),
          SbButton(
            label: status == 'CLOSED' ? 'Lihat Detail' : 'Tinjau Sekarang',
            icon: Icons.rate_review_rounded,
            height: 46,
            variant: SbButtonVariant.ghost,
            tone: AppTheme.brand,
            onPressed: onReview,
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'IN_REVIEW':
        return AppTheme.brand;
      case 'ACTION_REQUIRED':
        return AppTheme.riskHigh;
      case 'CLOSED':
        return AppTheme.riskLow;
      default:
        return AppTheme.inkMuted;
    }
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.counts,
    required this.filter,
    required this.onChanged,
  });

  final Map<String, dynamic> counts;
  final String filter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    int n(String key) {
      final v = counts[key];
      return v is num ? v.toInt() : 0;
    }

    const options = [
      ('SUBMITTED', 'Baru'),
      ('IN_REVIEW', 'Ditinjau'),
      ('ACTION_REQUIRED', 'Tindak Lanjut'),
      ('CLOSED', 'Ditutup'),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Menunggu',
                value: n('submitted'),
                color: AppTheme.brand,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: _Stat(
                label: 'Tindak Lanjut',
                value: n('action_required'),
                color: AppTheme.riskHigh,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: _Stat(
                label: 'Ditutup',
                value: n('closed'),
                color: AppTheme.riskLow,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: options.map((o) {
            final selected = o.$1 == filter;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(o.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.brand : AppTheme.surface,
                  borderRadius: AppTheme.brSm,
                  border: Border.all(color: selected ? AppTheme.brand : AppTheme.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      o.$2,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppTheme.inkMuted,
                      ),
                    ),
                    if (n(o.$1.toLowerCase()) > 0) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.22)
                              : AppTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${n(o.$1.toLowerCase())}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : AppTheme.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.brMd,
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$value',
              style: AppTheme.mono(
                size: 22,
                weight: FontWeight.w800,
                color: value > 0 ? color : AppTheme.inkFaint,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.inkFaint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? AppTheme.mono(size: 11.5, weight: FontWeight.w700, color: AppTheme.ink)
                  : const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppTheme.md),
          child: SbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14),
                SizedBox(height: 12),
                SkeletonBox(height: 11, width: 200),
                SizedBox(height: 14),
                SkeletonBox(height: 44, radius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}