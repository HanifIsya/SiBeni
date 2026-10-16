import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api_service.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/pills.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_card.dart';
import '../widgets/states.dart';

/// K3 inspection and corrective-action tracking.
///
/// The six-stage pipeline is the heart of the module: every ticket shows
/// exactly where it sits in the corrective-action lifecycle and can be pushed
/// forward by an authorised role.
class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  static const _stages = ['Inspeksi', 'Temuan', 'Verifikasi', 'Tugaskan', 'Perbaikan', 'Selesai'];

  List<Map<String, dynamic>> _actions = [];
  List<Map<String, dynamic>> _inspections = [];
  bool _loading = true;
  String _filter = 'all';

  /// Ticket currently being advanced, so only that button shows a spinner.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.instance.getInspections();
    if (!mounted) return;
    setState(() {
      _actions = _listOf(data['corrective_actions']);
      _inspections = _listOf(data['inspections']);
      _loading = false;
    });
  }

  static List<Map<String, dynamic>> _listOf(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> get _visible {
    if (_filter == 'open') {
      return _actions.where((a) => _stage(a) < 6).toList();
    }
    if (_filter == 'done') {
      return _actions.where((a) => _stage(a) >= 6).toList();
    }
    return _actions;
  }

  static int _stage(Map<String, dynamic> a) {
    final v = a['stage_number'];
    return v is num ? v.toInt().clamp(1, 6) : 2;
  }

  Future<void> _advance(Map<String, dynamic> ticket) async {
    final current = _stage(ticket);
    if (current >= 6) return;

    final id = (ticket['id'] ?? '').toString();
    if (id.isEmpty) {
      _toast('Tiket ini tidak memiliki ID server.', AppTheme.riskCritical);
      return;
    }

    setState(() => _busyId = id);

    final verifier = UserSession.instance.currentUser.value?.fullName ?? 'Petugas HSE';
    final result = await ApiService.instance.advanceCorrectiveActionStage(
      id: id,
      nextStage: current + 1,
      note: 'Diverifikasi $verifier pada ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}',
    );

    if (!mounted) return;
    setState(() => _busyId = null);

    // Show exactly what happened. The previous version reported a device-local
    // save that never existed, so a failed verification looked like a no-op.
    _toast(
      result.message ?? result.error ?? 'Gagal memperbarui.',
      result.isSuccess ? AppTheme.online : AppTheme.riskCritical,
    );

    if (result.isSuccess) _load();
  }

  void _toast(String message, Color tone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: tone, content: Text(message)),
    );
  }

  // ------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final user = UserSession.instance.currentUser.value;
    final canVerify = user?.role.canVerifyTickets ?? false;

    return AdaptivePage(
      onRefresh: _load,
      slivers: [
        const SectionHeader(
          title: 'Inspeksi K3',
          icon: Icons.fact_check_rounded,
          subtitle: 'Alur tindakan korektif enam tahap',
        ),

        const _PipelineCard(),
        const SizedBox(height: AppTheme.lg),

        SectionHeader(
          title: 'Tindak Lanjut',
          icon: Icons.assignment_turned_in_rounded,
          dense: true,
          action: _FilterToggle(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),

        if (_loading)
          const _TicketSkeleton()
        else if (_visible.isEmpty)
          const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Tidak ada tiket aktif',
            message: 'Semua tindakan korektif sudah ditutup.',
          )
        else
          for (final ticket in _visible)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: _TicketCard(
                ticket: ticket,
                stage: _stage(ticket),
                stages: _stages,
                canVerify: canVerify,
                busy: _busyId == (ticket['id'] ?? '').toString(),
                onAdvance: () => _advance(ticket),
              ),
            ),

        if (_inspections.isNotEmpty) ...[
          const SizedBox(height: AppTheme.sm),
          const SectionHeader(
            title: 'Riwayat Inspeksi',
            icon: Icons.history_rounded,
            dense: true,
          ),
          SbCard(
            child: Column(
              children: List.generate(_inspections.length, (i) {
                final row = _inspections[i];
                final date = row['inspection_date'];
                final parsed = date is String ? DateTime.tryParse(date) : null;
                return Padding(
                  padding: EdgeInsets.only(bottom: i == _inspections.length - 1 ? 0 : AppTheme.md),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceMuted,
                          borderRadius: AppTheme.brSm,
                        ),
                        child: const Icon(Icons.assignment_outlined,
                            size: 17, color: AppTheme.inkFaint),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (row['title'] ?? 'Inspeksi').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            Text(
                              [
                                if (row['zone_name'] != null) row['zone_name'].toString(),
                                if (parsed != null) DateFormat('d MMM yyyy').format(parsed),
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      SbPill(
                        label: '${row['passed_items'] ?? 0}/${(row['passed_items'] ?? 0) + (row['failed_items'] ?? 0)}',
                        dense: true,
                        color: (row['failed_items'] ?? 0) > 0
                            ? AppTheme.riskHigh
                            : AppTheme.riskLow,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

// ===========================================================================
class _PipelineCard extends StatelessWidget {
  const _PipelineCard();

  static const _labels = ['1', '2', '3', '4', '5', '6'];
  static const _names = ['Inspeksi', 'Temuan', 'Verifikasi', 'Tugaskan', 'Perbaikan', 'Selesai'];

  @override
  Widget build(BuildContext context) {
    return SbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, size: 16, color: AppTheme.brand),
              const SizedBox(width: 8),
              Text('ALUR 6 TAHAP', style: AppTheme.eyebrow(color: AppTheme.brand)),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 420;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(_names.length, (i) {
                  return Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (i > 0)
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: AppTheme.hairline,
                                ),
                              ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: AppTheme.brand,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _labels[i],
                                style: AppTheme.mono(
                                  size: 10.5,
                                  weight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (i < _names.length - 1)
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: AppTheme.hairline,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            _names[i],
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 8.5 : 9.5,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('all', 'Semua'),
    ('open', 'Aktif'),
    ('done', 'Selesai'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSunken,
        borderRadius: AppTheme.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _options.map((o) {
          final selected = o.$1 == value;
          return Flexible(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(o.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.surface : Colors.transparent,
                  borderRadius: AppTheme.brPill,
                  boxShadow: selected ? AppTheme.shadowSoft : null,
                ),
                child: Text(
                  o.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppTheme.brand : AppTheme.inkMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.stage,
    required this.stages,
    required this.canVerify,
    required this.busy,
    required this.onAdvance,
  });

  final Map<String, dynamic> ticket;
  final int stage;
  final List<String> stages;
  final bool canVerify;
  final bool busy;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final severity = (ticket['severity'] ?? 'medium').toString();
    final done = stage >= 6;
    final color = done ? AppTheme.riskLow : AppTheme.riskColor(severity);

    final due = ticket['target_due_date'];
    final dueDate = due is String ? DateTime.tryParse(due) : null;

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
                  (ticket['title'] ?? 'Tindakan korektif').toString(),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    letterSpacing: -0.2,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SbPill(
                label: done ? 'SELESAI' : stages[stage - 1].toUpperCase(),
                icon: done ? Icons.check_circle_rounded : Icons.timelapse_rounded,
                color: color,
                background: AppTheme.riskBg(done ? 'low' : severity),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StageBar(current: stage, total: stages.length, color: color),
          const SizedBox(height: 14),
          if ((ticket['description'] ?? '').toString().trim().isNotEmpty) ...[
            Text(
              ticket['description'].toString(),
              style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.inkMuted),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (ticket['assigned_pic_name'] != null)
                SbTag(
                  label: ticket['assigned_pic_name'].toString(),
                  icon: Icons.person_rounded,
                ),
              if (dueDate != null)
                SbTag(
                  label: 'Target ${DateFormat('d MMM').format(dueDate)}',
                  icon: Icons.event_rounded,
                  color: dueDate.isBefore(DateTime.now()) && !done
                      ? AppTheme.riskCritical
                      : AppTheme.inkMuted,
                ),
              RiskPill(level: severity, icon: false),
            ],
          ),
          if (!done && canVerify) ...[
            const SizedBox(height: 14),
            SbButton(
              label: 'Verifikasi → ${stages[stage]}',
              icon: Icons.arrow_forward_rounded,
              height: 46,
              tone: color,
              loading: busy,
              onPressed: busy ? null : onAdvance,
            ),
          ],
        ],
      ),
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.current, required this.total, required this.color});
  final int current;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Row(
        children: List.generate(total, (i) {
          final active = i < current;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              height: 5,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 3),
              color: active ? color : AppTheme.surfaceSunken,
            ),
          );
        }),
      ),
    );
  }
}

class _TicketSkeleton extends StatelessWidget {
  const _TicketSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppTheme.md),
          child: SbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 15, width: 210),
                SizedBox(height: 14),
                SkeletonBox(height: 5),
                SizedBox(height: 14),
                SkeletonBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}