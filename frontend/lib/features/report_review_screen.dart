import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// M-06 — Verifikasi laporan bahaya.
///
/// HSE receives, verifies, and writes the corrective action. Management sees
/// the same register read-only; its decision gate lives in the management
/// evaluation console. HSE can never close a report, and a report can never
/// leave `IN_REVIEW` without a typed action description, PIC, severity and due
/// date. That server-enforced rule is what fixes the old disappearing-report
/// bug.
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
    final role = UserSession.instance.currentUser.value?.role ?? AppRole.hse;
    final decision = await showModalBottomSheet<ReviewDecision>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(report: report, role: role),
    );
    if (decision == null || !mounted) return;

    final result = await ApiService.instance.reviewReport(
      id: report['id'].toString(),
      status: decision.status,
      notes: decision.notes,
      action: decision.action,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            result.isSuccess ? AppTheme.online : AppTheme.riskCritical,
        content: Text(result.message ?? result.error ?? ''),
      ),
    );
    if (result.isSuccess) _load();
  }

  @override
  Widget build(BuildContext context) {
    final role = UserSession.instance.currentUser.value?.role ?? AppRole.hse;

    return AdaptivePage(
      onRefresh: _load,
      slivers: [
        RoleWorkspaceBanner(role: role),
        const SizedBox(height: AppTheme.lg),
        SectionHeader(
          title: role == AppRole.management
              ? 'Register Laporan K3'
              : 'Verifikasi Laporan',
          icon: Icons.fact_check_rounded,
          subtitle: role == AppRole.management
              ? 'Pantau laporan dan tindakan korektif. Keputusan persetujuan/evaluasi dilakukan di Konsol Evaluasi.'
              : 'Terima laporan lapangan, verifikasi, lalu susun tindakan korektif untuk disetujui Manajemen.',
        ),
        _StatusSummary(
          counts: _counts,
          filter: _filter,
          onChanged: (value) {
            setState(() => _filter = value);
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
                ? 'Semua laporan telah diverifikasi HSE.'
                : 'Ganti filter untuk melihat status lain.',
            compact: true,
          )
        else
          for (final report in _reports)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: _ReportCard(
                report: report,
                role: role,
                onReview: () => _openReview(report),
              ),
            ),
      ],
    );
  }
}

// ===========================================================================
class ReviewDecision {
  const ReviewDecision(this.status, this.notes, {this.action});
  final String status;
  final String? notes;
  final Map<String, dynamic>? action;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.report, required this.role});
  final Map<String, dynamic> report;
  final AppRole role;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final TextEditingController _notes =
      TextEditingController(text: (widget.report['hse_notes'] ?? '').toString());
  final TextEditingController _description = TextEditingController();
  final TextEditingController _pic = TextEditingController();

  String _severity = 'high';
  late DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    _description.dispose();
    _pic.dispose();
    super.dispose();
  }

  String get _status =>
      (widget.report['hse_status'] ?? 'SUBMITTED').toString().toUpperCase();

  bool get _isHse => widget.role == AppRole.hse;

  bool get _canVerify => _isHse && _status == 'SUBMITTED';
  bool get _canIssueAction => _isHse && _status == 'IN_REVIEW';

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Tenggat tindakan korektif',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _reject() {
    final notes = _notes.text.trim();
    if (notes.isEmpty) {
      setState(() => _error =
          'Alasan penolakan wajib diisi agar pelapor memahami keputusan HSE.');
      return;
    }
    Navigator.pop(context, ReviewDecision('REJECTED', notes));
  }

  void _verify() {
    Navigator.pop(context, ReviewDecision('IN_REVIEW', _notes.text.trim()));
  }

  void _sendAction() {
    final notes = _notes.text.trim();
    final description = _description.text.trim();
    final pic = _pic.text.trim();

    if (notes.isEmpty) {
      setState(() => _error =
          'Catatan verifikasi HSE wajib diisi sebelum mengirim tindakan.');
      return;
    }
    if (description.isEmpty) {
      setState(() => _error =
          'Uraian tindakan korektif wajib diketik. Laporan tidak akan berubah status sebelum tindakan diisi.');
      return;
    }
    if (pic.isEmpty) {
      setState(() => _error = 'Nama penanggung jawab (PIC) wajib diisi.');
      return;
    }
    if (_dueDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      setState(() => _error = 'Tenggat tindakan tidak boleh di masa lalu.');
      return;
    }

    final rawDescription =
        (widget.report['description'] ?? 'Temuan lapangan').toString();
    final actionTitle = rawDescription.length > 60
        ? 'Tindakan: ${rawDescription.substring(0, 60)}…'
        : 'Tindakan: $rawDescription';

    Navigator.pop(
      context,
      ReviewDecision(
        'PENDING_APPROVAL',
        notes,
        action: {
          'title': actionTitle,
          'description': description,
          'assigned_pic_name': pic,
          'target_due_date': _dueDate.toIso8601String().split('T').first,
          'severity': _severity,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final type = r['report_type'] == 'near_miss' ? 'Near Miss' : 'Bahaya';
    final timestamp =
        DateTime.tryParse((r['incident_timestamp'] ?? '').toString());
    final action = r['latest_action'] is Map
        ? (r['latest_action'] as Map).cast<String, dynamic>()
        : null;

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
                      _canIssueAction
                          ? 'Susun Tindakan Korektif'
                          : 'Tinjau Laporan',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  SbPill(
                    label: _statusLabel(_status),
                    color: _statusColor(_status),
                    dense: true,
                  ),
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
                    _Line(
                      label: 'Kategori',
                      value: (r['category'] ?? '—').toString(),
                    ),
                    _Line(
                      label: 'Pelapor',
                      value: (r['reporter_name'] ?? '—').toString(),
                    ),
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

              // -----------------------------------------------------------
              // Read-only workflow state for Management / already-decided rows
              // -----------------------------------------------------------
              if (!_isHse || (!_canVerify && !_canIssueAction)) ...[
                const SizedBox(height: 16),
                _WorkflowStatus(
                  status: _status,
                  notes: (r['hse_notes'] ?? '').toString(),
                  action: action,
                  role: widget.role,
                ),
              ],

              // -----------------------------------------------------------
              // HSE: verify a fresh report
              // -----------------------------------------------------------
              if (_canVerify) ...[
                const SizedBox(height: 18),
                Text('CATATAN VERIFIKASI HSE', style: AppTheme.eyebrow()),
                const SizedBox(height: 7),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  maxLength: 400,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: const InputDecoration(
                    hintText:
                        'Kondisi saat verifikasi, saksi, atau catatan awal HSE…',
                  ),
                ),
                if (_error != null) _ErrorText(_error!),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SbButton(
                        label: 'Tolak',
                        icon: Icons.close_rounded,
                        variant: SbButtonVariant.ghost,
                        tone: AppTheme.riskCritical,
                        onPressed: _reject,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      flex: 2,
                      child: SbButton(
                        label: 'Verifikasi & Terima',
                        icon: Icons.check_rounded,
                        tone: AppTheme.online,
                        onPressed: _verify,
                      ),
                    ),
                  ],
                ),
              ],

              // -----------------------------------------------------------
              // HSE: mandatory corrective action form
              // -----------------------------------------------------------
              if (_canIssueAction) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.riskHighBg.withValues(alpha: 0.45),
                    borderRadius: AppTheme.brSm,
                    border: Border.all(
                      color: AppTheme.riskHigh.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 18,
                        color: AppTheme.riskHigh,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tindakan wajib diisi sebelum laporan dikirim. Status laporan tidak akan berubah jika uraian tindakan kosong.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.riskHigh,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('URAIAN TINDAKAN KOREKTIF', style: AppTheme.eyebrow()),
                const SizedBox(height: 7),
                TextField(
                  controller: _description,
                  maxLines: 3,
                  maxLength: 600,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: const InputDecoration(
                    hintText:
                        'Contoh: Pasang safety berm setinggi 3/4 diameter roda dan rambu batas kecepatan di tikungan KM 4…',
                  ),
                ),
                const SizedBox(height: 8),
                Text('PENANGGUNG JAWAB (PIC)', style: AppTheme.eyebrow()),
                const SizedBox(height: 7),
                TextField(
                  controller: _pic,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Nama supervisor/PIC pelaksana',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
                  ),
                ),
                const SizedBox(height: 14),
                Text('TINGKAT KEPARAHAN', style: AppTheme.eyebrow()),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final item in const [
                      ('low', 'Rendah'),
                      ('medium', 'Sedang'),
                      ('high', 'Tinggi'),
                      ('critical', 'Kritis'),
                    ])
                      _ChoiceChip(
                        label: item.$2,
                        selected: _severity == item.$1,
                        color: AppTheme.riskColor(item.$1),
                        onTap: () => setState(() => _severity = item.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('TENGGAT PENYELESAIAN', style: AppTheme.eyebrow()),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: _pickDueDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: AppTheme.brMd,
                      border: Border.all(color: AppTheme.hairline),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          size: 19,
                          color: AppTheme.brand,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, d MMMM yyyy').format(_dueDate),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.edit_calendar_rounded,
                          size: 18,
                          color: AppTheme.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('CATATAN VERIFIKASI HSE', style: AppTheme.eyebrow()),
                const SizedBox(height: 7),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  maxLength: 400,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: const InputDecoration(
                    hintText:
                        'Dasar verifikasi, regulasi yang dilanggar, atau instruksi tambahan…',
                  ),
                ),
                if (_error != null) _ErrorText(_error!),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SbButton(
                        label: 'Tolak',
                        icon: Icons.close_rounded,
                        variant: SbButtonVariant.ghost,
                        tone: AppTheme.riskCritical,
                        onPressed: _reject,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      flex: 2,
                      child: SbButton(
                        label: 'Kirim ke Manajemen',
                        icon: Icons.send_rounded,
                        tone: const Color(0xFF12805C),
                        onPressed: _sendAction,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.sm),
                const Text(
                  'Setelah dikirim, tindakan masuk ke akun Manajemen untuk disetujui. Pekerja dan Supervisor otomatis menerima notifikasi.',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: AppTheme.inkFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'IN_REVIEW':
        return 'DIVERIFIKASI';
      case 'PENDING_APPROVAL':
        return 'MENUNGGU PERSETUJUAN';
      case 'ACTION_REQUIRED':
        return 'DILAKSANAKAN';
      case 'CLOSED':
        return 'DITUTUP';
      case 'REJECTED':
        return 'DITOLAK';
      default:
        return 'BARU';
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'IN_REVIEW':
        return AppTheme.brand;
      case 'PENDING_APPROVAL':
        return const Color(0xFF6D28D9);
      case 'ACTION_REQUIRED':
        return AppTheme.riskHigh;
      case 'CLOSED':
        return AppTheme.riskLow;
      case 'REJECTED':
        return AppTheme.riskCritical;
      default:
        return AppTheme.inkMuted;
    }
  }
}

class _WorkflowStatus extends StatelessWidget {
  const _WorkflowStatus({
    required this.status,
    required this.notes,
    required this.action,
    required this.role,
  });

  final String status;
  final String notes;
  final Map<String, dynamic>? action;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final managementStatus =
        (action?['management_status'] ?? '').toString().toUpperCase();
    final actionStage = action?['stage_number'] is num
        ? (action!['stage_number'] as num).toInt()
        : 0;

    final message = switch (status) {
      'IN_REVIEW' => role == AppRole.management
          ? 'Laporan sedang diverifikasi HSE. Rencana tindakan akan muncul di Konsol Evaluasi setelah HSE mengirimkannya.'
          : 'Laporan sudah diverifikasi HSE.',
      'PENDING_APPROVAL' =>
        'Tindakan korektif sudah disusun HSE dan sedang menunggu persetujuan Manajemen. Pekerja dan Supervisor menerima notifikasi.',
      'ACTION_REQUIRED' =>
        'Tindakan sudah disetujui Manajemen. Supervisor melaksanakan perbaikan; hasilnya akan dievaluasi Manajemen.',
      'CLOSED' =>
        'Laporan sudah dievaluasi dan ditutup Manajemen.',
      'REJECTED' => 'Laporan ditolak HSE atau dikembalikan Manajemen.',
      _ => 'Laporan baru menunggu verifikasi HSE.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _ReviewSheetState._statusColor(status).withValues(alpha: 0.06),
            borderRadius: AppTheme.brSm,
            border: Border.all(
              color:
                  _ReviewSheetState._statusColor(status).withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                role == AppRole.management
                    ? Icons.business_center_rounded
                    : Icons.info_outline_rounded,
                size: 17,
                color: _ReviewSheetState._statusColor(status),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
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
                      Icons.build_circle_rounded,
                      size: 15,
                      color: AppTheme.brand,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (action!['title'] ?? 'Tindakan korektif').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SbPill(
                      label: _actionLabel(managementStatus, actionStage),
                      dense: true,
                      color: _actionColor(managementStatus),
                    ),
                  ],
                ),
                if ((action!['management_notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Catatan Manajemen: ${action!['management_notes']}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (notes.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: AppTheme.brSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CATATAN HSE', style: AppTheme.eyebrow()),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _actionLabel(String status, int stage) {
    switch (status) {
      case 'PENDING':
        return 'MENUNGGU MANAJEMEN';
      case 'REJECTED':
        return 'DIKEMBALIKAN';
      case 'EVALUATED':
        return 'DIEVALUASI';
      case 'APPROVED':
        return stage >= 6 ? 'SELESAI' : 'BERJALAN';
      default:
        return 'TINDAKAN';
    }
  }

  static Color _actionColor(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFF6D28D9);
      case 'REJECTED':
        return AppTheme.riskCritical;
      case 'EVALUATED':
        return AppTheme.online;
      case 'APPROVED':
        return AppTheme.brand;
      default:
        return AppTheme.inkMuted;
    }
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : AppTheme.surface,
          borderRadius: AppTheme.brSm,
          border: Border.all(color: selected ? color : AppTheme.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: AppTheme.riskCritical,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppTheme.riskCritical,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.role,
    required this.onReview,
  });

  final Map<String, dynamic> report;
  final AppRole role;
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
    final timestamp =
        DateTime.tryParse((report['incident_timestamp'] ?? '').toString());
    final action = report['latest_action'] is Map
        ? (report['latest_action'] as Map).cast<String, dynamic>()
        : null;

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
                color: _ReviewSheetState._statusColor(status),
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
          if (action != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.build_circle_rounded,
                  size: 14,
                  color: AppTheme.brand,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    (action['title'] ?? 'Tindakan korektif').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                ),
                SbPill(
                  label: _WorkflowStatus._actionLabel(
                    (action['management_status'] ?? '').toString().toUpperCase(),
                    action['stage_number'] is num
                        ? (action['stage_number'] as num).toInt()
                        : 0,
                  ),
                  color: _WorkflowStatus._actionColor(
                    (action['management_status'] ?? '').toString().toUpperCase(),
                  ),
                  dense: true,
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SbButton(
            label: _buttonLabel(status),
            icon: role == AppRole.management
                ? Icons.visibility_rounded
                : Icons.rate_review_rounded,
            height: 46,
            variant: SbButtonVariant.ghost,
            tone: AppTheme.brand,
            onPressed: onReview,
          ),
        ],
      ),
    );
  }

  String _buttonLabel(String status) {
    if (role == AppRole.management) return 'Lihat Detail';
    if (status == 'SUBMITTED') return 'Verifikasi Laporan';
    if (status == 'IN_REVIEW') return 'Beri Tindakan Korektif';
    return 'Lihat Detail';
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

  int _n(String key) {
    final value = counts[key];
    return value is num ? value.toInt() : 0;
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      ('SUBMITTED', 'Baru', _n('submitted')),
      ('IN_REVIEW', 'Diverifikasi', _n('in_review')),
      ('PENDING_APPROVAL', 'Persetujuan', _n('pending_approval')),
      ('ACTION_REQUIRED', 'Tindak Lanjut', _n('action_required')),
      ('CLOSED', 'Ditutup', _n('closed')),
      ('REJECTED', 'Ditolak', _n('rejected')),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Menunggu',
                value: _n('submitted'),
                color: AppTheme.brand,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: _Stat(
                label: 'Persetujuan',
                value: _n('pending_approval'),
                color: const Color(0xFF6D28D9),
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: _Stat(
                label: 'Tindak Lanjut',
                value: _n('action_required'),
                color: AppTheme.riskHigh,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: _Stat(
                label: 'Ditutup',
                value: _n('closed'),
                color: AppTheme.riskLow,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.md),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: options.map((option) {
            final selected = option.$1 == filter;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(option.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                constraints: const BoxConstraints(minHeight: 42),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.brand : AppTheme.surface,
                  borderRadius: AppTheme.brSm,
                  border: Border.all(
                    color: selected ? AppTheme.brand : AppTheme.hairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppTheme.inkMuted,
                      ),
                    ),
                    if (option.$3 > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.22)
                              : AppTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${option.$3}',
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
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
                size: 21,
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
              fontSize: 9.5,
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
                  ? AppTheme.mono(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: AppTheme.ink,
                    )
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
