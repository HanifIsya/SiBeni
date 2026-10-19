import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_service.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/pills.dart';
import '../widgets/role_workspace.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_card.dart';
import '../widgets/states.dart';

/// Konsol Evaluasi Manajemen.
///
/// Management is the decision gate in the revised workflow:
///   PENDING  → setujui / tolak rencana tindakan yang disusun HSE
///   APPROVED + tahap 6 → nilai efektivitas dan tutup laporan
/// The screen deliberately does not expose stage advancement: field execution
/// belongs to the Supervisor, verification belongs to HSE.
class ManagementEvaluationScreen extends StatefulWidget {
  const ManagementEvaluationScreen({super.key});

  @override
  State<ManagementEvaluationScreen> createState() =>
      _ManagementEvaluationScreenState();
}

class _ManagementEvaluationScreenState extends State<ManagementEvaluationScreen> {
  List<Map<String, dynamic>> _actions = [];
  Map<String, dynamic> _counts = const {};
  bool _loading = true;
  String _filter = 'pending';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ApiService.instance.getInspections();
    if (!mounted) return;
    final raw = data['corrective_actions'];
    setState(() {
      _actions = raw is List
          ? raw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final counts = data['counts'];
      _counts = counts is Map
          ? counts.map((k, v) => MapEntry(k.toString(), v))
          : const {};
      _loading = false;
    });
  }

  static String _managementStatus(Map<String, dynamic> action) =>
      (action['management_status'] ?? 'PENDING').toString().toUpperCase();

  static int _stage(Map<String, dynamic> action) {
    final raw = action['stage_number'];
    return raw is num ? raw.toInt().clamp(1, 6) : 1;
  }

  static bool _waitingEvaluation(Map<String, dynamic> action) =>
      _managementStatus(action) == 'APPROVED' &&
      _stage(action) >= 6 &&
      action['evaluated_at'] == null;

  List<Map<String, dynamic>> get _visible {
    switch (_filter) {
      case 'pending':
        return _actions.where((a) => _managementStatus(a) == 'PENDING').toList();
      case 'waiting':
        return _actions.where(_waitingEvaluation).toList();
      case 'approved':
        return _actions
            .where((a) => _managementStatus(a) == 'APPROVED')
            .toList();
      case 'evaluated':
        return _actions
            .where((a) => _managementStatus(a) == 'EVALUATED')
            .toList();
      default:
        return _actions;
    }
  }

  Future<void> _decide(
    Map<String, dynamic> action,
    String decision, {
    required String title,
    required String hint,
    required String confirmLabel,
    required Color tone,
    bool requireNotes = true,
    bool requireRating = false,
  }) async {
    final id = (action['id'] ?? '').toString();
    if (id.isEmpty) return;

    final result = await showModalBottomSheet<_DecisionResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DecisionSheet(
        title: title,
        hint: hint,
        confirmLabel: confirmLabel,
        tone: tone,
        requireNotes: requireNotes,
        requireRating: requireRating,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _busyId = id);
    final apiResult = await ApiService.instance.decideCorrectiveAction(
      id: id,
      decision: decision,
      notes: result.notes,
      effectivenessRating: result.rating,
    );
    if (!mounted) return;
    setState(() => _busyId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            apiResult.isSuccess ? AppTheme.online : AppTheme.riskCritical,
        content: Text(apiResult.message ?? apiResult.error ?? ''),
      ),
    );
    if (apiResult.isSuccess) {
      setState(() => _filter = decision == 'EVALUATED' ? 'evaluated' : 'pending');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = UserSession.instance.currentUser.value?.role ?? AppRole.management;

    return AdaptivePage(
      onRefresh: _load,
      slivers: [
        RoleWorkspaceBanner(
          role: role,
          variant: RoleBannerVariant.compact,
          note: _counts.isEmpty
              ? null
              : '${_counts['pending_approval'] ?? 0} menunggu persetujuan · '
                  '${_counts['waiting_evaluation'] ?? 0} siap dievaluasi',
        ),
        const SizedBox(height: AppTheme.lg),
        const SectionHeader(
          title: 'Konsol Evaluasi Manajemen',
          icon: Icons.business_center_rounded,
          subtitle:
              'Setujui rencana tindakan HSE, awasi pelaksanaan, lalu nilai efektivitas dan tutup laporan.',
        ),
        _StatGrid(counts: _counts),
        const SizedBox(height: AppTheme.md),
        _FilterBar(
          value: _filter,
          counts: _counts,
          onChanged: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: AppTheme.lg),
        if (_loading)
          const _EvaluationSkeleton()
        else if (_visible.isEmpty)
          EmptyState(
            icon: Icons.task_alt_rounded,
            title: _emptyTitle,
            message: _emptyMessage,
            compact: true,
          )
        else
          for (final action in _visible)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: _ManagementActionCard(
                action: action,
                busy: _busyId == (action['id'] ?? '').toString(),
                role: role,
                onApprove: () => _decide(
                  action,
                  'APPROVED',
                  title: 'Setujui rencana tindakan',
                  hint:
                      'Catatan persetujuan (opsional), misalnya target waktu atau prioritas anggaran.',
                  confirmLabel: 'Setujui Tindakan',
                  tone: AppTheme.online,
                  requireNotes: false,
                ),
                onReject: () => _decide(
                  action,
                  'REJECTED',
                  title: 'Kembalikan rencana ke HSE',
                  hint:
                      'Tuliskan alasan penolakan agar HSE dapat memperbaiki rencana tindakan.',
                  confirmLabel: 'Tolak Rencana',
                  tone: AppTheme.riskCritical,
                ),
                onEvaluate: () => _decide(
                  action,
                  'EVALUATED',
                  title: 'Evaluasi hasil & tutup laporan',
                  hint:
                      'Jelaskan bukti hasil, kondisi akhir di lapangan, dan pelajaran yang dapat diambil.',
                  confirmLabel: 'Simpan Evaluasi',
                  tone: const Color(0xFF6D28D9),
                  requireRating: true,
                ),
              ),
            ),
      ],
    );
  }

  String get _emptyTitle {
    switch (_filter) {
      case 'pending':
        return 'Tidak ada tindakan menunggu persetujuan';
      case 'waiting':
        return 'Belum ada tindakan selesai untuk dievaluasi';
      case 'evaluated':
        return 'Belum ada tindakan yang dievaluasi';
      default:
        return 'Belum ada tindakan korektif';
    }
  }

  String get _emptyMessage {
    switch (_filter) {
      case 'pending':
        return 'HSE belum mengirim rencana tindakan baru. Tarik untuk memuat ulang.';
      case 'waiting':
        return 'Tindakan akan muncul di sini setelah Supervisor menyelesaikan seluruh tahap.';
      case 'evaluated':
        return 'Hasil evaluasi Manajemen akan tersimpan di sini sebagai riwayat K3.';
      default:
        return 'Tindakan dari laporan HSE dan temuan inspeksi akan tampil di konsol ini.';
    }
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.counts});
  final Map<String, dynamic> counts;

  int _n(String key) {
    final raw = counts[key];
    return raw is num ? raw.toInt() : 0;
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Menunggu persetujuan', _n('pending_approval'), const Color(0xFF6D28D9)),
      ('Siap dievaluasi', _n('waiting_evaluation'), AppTheme.brand),
      ('Terlambat', _n('overdue'), AppTheme.riskCritical),
      ('Sudah dievaluasi', _n('evaluated'), AppTheme.online),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 620 ? 4 : 2;
        final width = (c.maxWidth - AppTheme.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppTheme.md,
          runSpacing: AppTheme.md,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: AppTheme.brMd,
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${card.$2}',
                        style: AppTheme.mono(
                          size: 24,
                          weight: FontWeight.w800,
                          color: card.$2 > 0 ? card.$3 : AppTheme.inkFaint,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        card.$1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.value,
    required this.counts,
    required this.onChanged,
  });

  final String value;
  final Map<String, dynamic> counts;
  final ValueChanged<String> onChanged;

  int _n(String key) {
    final raw = counts[key];
    return raw is num ? raw.toInt() : 0;
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      ('pending', 'Persetujuan', _n('pending_approval')),
      ('waiting', 'Evaluasi', _n('waiting_evaluation')),
      ('approved', 'Berjalan', _n('approved')),
      ('evaluated', 'Selesai', _n('evaluated')),
      ('all', 'Semua', _n('total')),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _FilterChip(
              label: options[i].$2,
              count: options[i].$3,
              selected: value == options[i].$1,
              onTap: () => onChanged(options[i].$1),
            ),
            if (i != options.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brand : AppTheme.surface,
          borderRadius: AppTheme.brSm,
          border: Border.all(color: selected ? AppTheme.brand : AppTheme.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.inkMuted,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
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
  }
}

class _ManagementActionCard extends StatelessWidget {
  const _ManagementActionCard({
    required this.action,
    required this.busy,
    required this.role,
    required this.onApprove,
    required this.onReject,
    required this.onEvaluate,
  });

  final Map<String, dynamic> action;
  final bool busy;
  final AppRole role;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEvaluate;

  @override
  Widget build(BuildContext context) {
    final status = _ManagementEvaluationScreenState._managementStatus(action);
    final stage = _ManagementEvaluationScreenState._stage(action);
    final waitingEval =
        _ManagementEvaluationScreenState._waitingEvaluation(action);
    final severity = (action['severity'] ?? 'medium').toString();
    final report = action['hazard_report'] is Map
        ? (action['hazard_report'] as Map).cast<String, dynamic>()
        : null;
    final due = DateTime.tryParse((action['target_due_date'] ?? '').toString());
    final overdue = due != null &&
        due.isBefore(DateTime.now()) &&
        stage < 6 &&
        status != 'EVALUATED';

    final color = status == 'EVALUATED'
        ? AppTheme.online
        : status == 'REJECTED'
            ? AppTheme.riskCritical
            : waitingEval
                ? AppTheme.brand
                : const Color(0xFF6D28D9);

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
                  (action['title'] ?? 'Tindakan korektif').toString(),
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
                label: _statusLabel(status, waitingEval),
                color: color,
                dense: true,
                icon: _statusIcon(status, waitingEval),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              RiskPill(level: severity, dense: true),
              if (action['assigned_pic_name'] != null)
                SbTag(
                  label: 'PIC ${action['assigned_pic_name']}',
                  icon: Icons.person_rounded,
                ),
              if (due != null)
                SbTag(
                  label: 'Tenggat ${DateFormat('d MMM yyyy').format(due)}',
                  icon: Icons.event_rounded,
                  color: overdue ? AppTheme.riskCritical : null,
                ),
              SbTag(
                label: 'Tahap $stage/6',
                icon: Icons.timeline_rounded,
              ),
            ],
          ),
          if ((action['description'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              action['description'].toString(),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppTheme.inkMuted,
              ),
            ),
          ],
          if (report != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.canvas,
                borderRadius: AppTheme.brSm,
                border: Border.all(color: AppTheme.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.assignment_rounded,
                        size: 14,
                        color: AppTheme.brand,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LAPORAN TERKAIT',
                        style: AppTheme.eyebrow(color: AppTheme.brand),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (report['description'] ?? 'Laporan bahaya').toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (report['reporter_name'] != null)
                        report['reporter_name'].toString(),
                      if (report['zone_name'] != null)
                        report['zone_name'].toString().split(' (').first,
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (status == 'PENDING') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SbButton(
                    label: 'Tolak',
                    icon: Icons.close_rounded,
                    height: 46,
                    variant: SbButtonVariant.ghost,
                    tone: AppTheme.riskCritical,
                    onPressed: busy ? null : onReject,
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  flex: 2,
                  child: SbButton(
                    label: 'Setujui Rencana',
                    icon: Icons.check_rounded,
                    height: 46,
                    loading: busy,
                    tone: AppTheme.online,
                    onPressed: busy ? null : onApprove,
                  ),
                ),
              ],
            ),
          ] else if (waitingEval) ...[
            const SizedBox(height: 14),
            SbButton(
              label: 'Evaluasi Hasil & Tutup Laporan',
              icon: Icons.fact_check_rounded,
              height: 48,
              loading: busy,
              tone: const Color(0xFF6D28D9),
              onPressed: busy ? null : onEvaluate,
            ),
          ] else if (status == 'APPROVED') ...[
            const SizedBox(height: 12),
            _ProgressNote(stage: stage),
          ] else if (status == 'REJECTED' &&
              (action['management_notes'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _Note(
              label: 'CATATAN PENOLAKAN',
              text: action['management_notes'].toString(),
              color: AppTheme.riskCritical,
            ),
          ] else if (status == 'EVALUATED') ...[
            const SizedBox(height: 12),
            _EvaluationSummary(action: action),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(String status, bool waitingEval) {
    switch (status) {
      case 'APPROVED':
        return waitingEval ? 'SIAP DIEVALUASI' : 'BERJALAN';
      case 'REJECTED':
        return 'DIKEMBALIKAN';
      case 'EVALUATED':
        return 'DIEVALUASI';
      default:
        return 'MENUNGGU PERSETUJUAN';
    }
  }

  static IconData _statusIcon(String status, bool waitingEval) {
    switch (status) {
      case 'APPROVED':
        return waitingEval ? Icons.fact_check_rounded : Icons.play_circle_rounded;
      case 'REJECTED':
        return Icons.undo_rounded;
      case 'EVALUATED':
        return Icons.verified_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }
}

class _ProgressNote extends StatelessWidget {
  const _ProgressNote({required this.stage});
  final int stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.brand.withValues(alpha: 0.055),
        borderRadius: AppTheme.brSm,
        border: Border.all(color: AppTheme.brand.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.engineering_rounded, size: 17, color: AppTheme.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tindakan disetujui. Supervisor sedang melaksanakan perbaikan '
              '(tahap $stage dari 6). Evaluasi terbuka otomatis setelah tahap 6 selesai.',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppTheme.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.label, required this.text, required this.color});
  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppTheme.brSm,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.eyebrow(color: color)),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvaluationSummary extends StatelessWidget {
  const _EvaluationSummary({required this.action});
  final Map<String, dynamic> action;

  @override
  Widget build(BuildContext context) {
    final ratingRaw = action['effectiveness_rating'];
    final rating = ratingRaw is num ? ratingRaw.toInt().clamp(1, 5) : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFB7791F)),
            const SizedBox(width: 5),
            Text(
              'Efektivitas $rating/5',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(width: 6),
            for (var i = 0; i < 5; i++)
              Icon(
                i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                size: 15,
                color: const Color(0xFFB7791F),
              ),
          ],
        ),
        if ((action['management_notes'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          _Note(
            label: 'CATATAN EVALUASI',
            text: action['management_notes'].toString(),
            color: AppTheme.online,
          ),
        ],
      ],
    );
  }
}

class _DecisionResult {
  const _DecisionResult({required this.notes, this.rating});
  final String notes;
  final int? rating;
}

class _DecisionSheet extends StatefulWidget {
  const _DecisionSheet({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.tone,
    required this.requireNotes,
    required this.requireRating,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final Color tone;
  final bool requireNotes;
  final bool requireRating;

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  final TextEditingController _notes = TextEditingController();
  int _rating = 4;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final notes = _notes.text.trim();
    if (widget.requireNotes && notes.isEmpty) {
      setState(() => _error = 'Catatan wajib diisi sebelum keputusan dikirim.');
      return;
    }
    if (widget.requireRating && (_rating < 1 || _rating > 5)) {
      setState(() => _error = 'Pilih nilai efektivitas 1–5.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    Navigator.pop(
      context,
      _DecisionResult(notes: notes, rating: widget.requireRating ? _rating : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.tone.withValues(alpha: 0.11),
                      borderRadius: AppTheme.brSm,
                    ),
                    child: Icon(
                      Icons.business_center_rounded,
                      size: 20,
                      color: widget.tone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.requireRating) ...[
                Text('EFEKTIVITAS TINDAKAN', style: AppTheme.eyebrow()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      GestureDetector(
                        onTap: () => setState(() => _rating = i),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: i <= _rating
                                  ? const Color(0xFFB7791F).withValues(alpha: 0.13)
                                  : AppTheme.surface,
                              borderRadius: AppTheme.brSm,
                              border: Border.all(
                                color: i <= _rating
                                    ? const Color(0xFFB7791F)
                                    : AppTheme.hairline,
                              ),
                            ),
                            child: Icon(
                              i <= _rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 24,
                              color: const Color(0xFFB7791F),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$_rating/5 — ${_ratingLabel(_rating)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkMuted,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('CATATAN', style: AppTheme.eyebrow()),
              const SizedBox(height: 7),
              TextField(
                controller: _notes,
                maxLines: 4,
                maxLength: 600,
                autofocus: false,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(hintText: widget.hint),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.riskCritical,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SbButton(
                label: widget.confirmLabel,
                icon: Icons.send_rounded,
                loading: _submitting,
                tone: widget.tone,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Tidak efektif';
      case 2:
        return 'Kurang efektif';
      case 3:
        return 'Cukup efektif';
      case 5:
        return 'Sangat efektif';
      default:
        return 'Efektif';
    }
  }
}

class _EvaluationSkeleton extends StatelessWidget {
  const _EvaluationSkeleton();

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
                SkeletonBox(height: 15, width: 240),
                SizedBox(height: 12),
                SkeletonBox(height: 11, width: 180),
                SizedBox(height: 14),
                SkeletonBox(height: 46, radius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
