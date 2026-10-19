import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api_service.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/network_aware.dart';
import '../widgets/pills.dart';
import '../widgets/role_workspace.dart';
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

class _InspectionScreenState extends State<InspectionScreen>
    with NetworkAwareState {
  static const _stages = ['Inspeksi', 'Temuan', 'Verifikasi', 'Tugaskan', 'Perbaikan', 'Selesai'];

  List<Map<String, dynamic>> _actions = [];
  List<Map<String, dynamic>> _inspections = [];
  bool _loading = true;
  String _filter = 'all';

  /// Set when the last load could not reach the server, so the screen can say
  /// so instead of pretending the site has no findings.
  String? _loadError;

  /// True when the payload came from the on-device cache.
  bool _fromCache = false;

  /// Ticket currently being advanced, so only that button shows a spinner.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    final read = await ApiService.instance.getInspectionsRead();
    if (!mounted) return;
    setState(() {
      _actions = _listOf(read.data?['corrective_actions']);
      _inspections = _listOf(read.data?['inspections']);
      _loadError = read.error;
      _fromCache = read.fromCache;
      _loading = false;
    });
  }

  static List<Map<String, dynamic>> _listOf(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// The link came back: pull the register again instead of leaving the user
  /// on a failed screen.
  @override
  void onNetworkRestored() {
    if (_loadError != null) _load();
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

  static String _managementStatus(Map<String, dynamic> a) =>
      (a['management_status'] ?? 'APPROVED').toString().toUpperCase();

  static bool _canAdvance(Map<String, dynamic> ticket, AppRole role) {
    final stage = _stage(ticket);
    final management = _managementStatus(ticket);
    if (stage >= 6) return false;
    if (management == 'PENDING' ||
        management == 'REJECTED' ||
        management == 'EVALUATED') {
      return false;
    }
    if (role == AppRole.hse) return stage < 3;
    if (role == AppRole.supervisor) return stage >= 4;
    return false;
  }

  static String _advanceLabel(Map<String, dynamic> ticket, AppRole role) {
    final stage = _stage(ticket);
    if (role == AppRole.hse) {
      return stage == 2 ? 'Verifikasi Temuan' : 'Verifikasi → ${_stages[stage]}';
    }
    if (stage == 4) return 'Mulai Perbaikan';
    if (stage == 5) return 'Tandai Selesai';
    return 'Lanjutkan Tahap';
  }

  Future<void> _advance(Map<String, dynamic> ticket) async {
    final role = UserSession.instance.currentUser.value?.role ?? AppRole.supervisor;
    final current = _stage(ticket);
    if (!_canAdvance(ticket, role)) {
      final management = _managementStatus(ticket);
      _toast(
        current >= 6
            ? 'Tindakan sudah selesai. Menunggu evaluasi Manajemen.'
            : management == 'PENDING'
                ? 'Tindakan masih menunggu persetujuan Manajemen.'
                : management == 'REJECTED'
                    ? 'Tindakan dikembalikan Manajemen. HSE harus merevisi rencana.'
                    : role == AppRole.hse
                        ? 'HSE hanya memverifikasi sampai tahap 3. Pelaksanaan dilakukan Supervisor.'
                        : 'Tahap ini belum dapat dijalankan oleh peran Anda.',
        AppTheme.riskHigh,
      );
      return;
    }

    final id = (ticket['id'] ?? '').toString();
    if (id.isEmpty) {
      _toast('Tiket ini tidak memiliki ID server.', AppTheme.riskCritical);
      return;
    }

    setState(() => _busyId = id);

    final actor = UserSession.instance.currentUser.value?.fullName ?? 'Petugas';
    final note = role == AppRole.hse
        ? 'Diverifikasi $actor pada ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}'
        : 'Dilaksanakan $actor pada ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}';
    final result = await ApiService.instance.advanceCorrectiveActionStage(
      id: id,
      nextStage: current + 1,
      note: note,
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

  Future<void> _openNewInspectionSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewInspectionSheet(),
    );
    if (created == true && mounted) {
      _load();
    }
  }

  // ------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final user = UserSession.instance.currentUser.value;
    final role = user?.role ?? AppRole.supervisor;
    final canInspect = role.canInspect;

    return AdaptivePage(
      onRefresh: _load,
      slivers: [
        RoleWorkspaceBanner(
          role: role,
          variant: RoleBannerVariant.compact,
          note: _actions.isEmpty
              ? null
              : '${_actions.where((a) => _stage(a) < 6).length} temuan aktif',
        ),
        const SizedBox(height: AppTheme.lg),
        SectionHeader(
          title: role == AppRole.hse ? 'Inspeksi & Verifikasi' : 'Inspeksi K3',
          icon: Icons.fact_check_rounded,
          subtitle: role == AppRole.hse
              ? 'Verifikasi temuan sampai tahap 3, lalu awasi pelaksanaan Supervisor.'
              : 'Jalankan inspeksi lapangan dan selesaikan tindakan yang sudah disetujui Manajemen.',
          action: canInspect
              ? SbButton(
                  label: 'Inspeksi Baru',
                  icon: Icons.add_task_rounded,
                  height: 48,
                  expand: false,
                  onPressed: _openNewInspectionSheet,
                )
              : null,
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

        if (_loadError != null && _actions.isEmpty)
          _LoadErrorCard(
            message: _loadError!,
            onRetry: _load,
          )
        else ...[
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: _OfflineNotice(
                message: _fromCache
                    ? 'Data terakhir yang tersimpan di perangkat ini.'
                    : _loadError!,
              ),
            ),
          if (_actions.isNotEmpty) ...[
            _StatStrip(
              active: _actions.where((a) => _stage(a) < 6).length,
              pending: _actions
                  .where((a) => _managementStatus(a) == 'PENDING')
                  .length,
              evaluation: _actions
                  .where(
                    (a) =>
                        _stage(a) >= 6 && _managementStatus(a) == 'APPROVED',
                  )
                  .length,
              done: _actions
                  .where((a) => _managementStatus(a) == 'EVALUATED')
                  .length,
            ),
            const SizedBox(height: AppTheme.md),
          ],
          if (_loading)
            const _TicketSkeleton()
          else if (_visible.isEmpty)
            EmptyState(
              icon: Icons.fact_check_outlined,
              title: role == AppRole.hse
                  ? 'Belum ada temuan yang perlu diverifikasi'
                  : 'Belum ada tiket tindakan korektif',
              message: role == AppRole.hse
                  ? 'Temuan inspeksi yang dibuat Supervisor akan muncul di sini untuk diverifikasi, lalu disusunkan sebagai tindakan korektif.'
                  : 'Temuan inspeksi otomatis menjadi tiket tindakan korektif setelah inspection lapangan dikirim.',
              action: canInspect
                  ? SbButton(
                      label: 'Mulai Inspeksi',
                      icon: Icons.add_task_rounded,
                      height: 46,
                      expand: false,
                      onPressed: _openNewInspectionSheet,
                    )
                  : null,
            )
          else
            for (final ticket in _visible)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.md),
                child: _TicketCard(
                  ticket: ticket,
                  stage: _stage(ticket),
                  stages: _stages,
                  role: role,
                  managementStatus: _managementStatus(ticket),
                  canAdvance: _canAdvance(ticket, role),
                  advanceLabel: _advanceLabel(ticket, role),
                  busy: _busyId == (ticket['id'] ?? '').toString(),
                  onAdvance: () => _advance(ticket),
                ),
              ),
        ],

        const SizedBox(height: AppTheme.sm),
        const SectionHeader(
          title: 'Riwayat Inspeksi',
          icon: Icons.history_rounded,
          dense: true,
        ),

        if (_loading)
          const _TicketSkeleton()
        else if (_inspections.isEmpty)
          const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Belum ada riwayat inspeksi',
            message:
                'Setiap inspeksi lapangan yang dikirim akan tercatat di sini beserta jumlah butir yang lulus.',
            compact: true,
          )
        else
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
    );
  }
}

/// Four counters that answer "where does the K3 work stand right now?".
class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.active,
    required this.pending,
    required this.evaluation,
    required this.done,
  });

  final int active;
  final int pending;
  final int evaluation;
  final int done;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, int value, Color color})>[
      (label: 'Temuan aktif', value: active, color: AppTheme.brand),
      (label: 'Menunggu persetujuan', value: pending, color: const Color(0xFF6D28D9)),
      (label: 'Menunggu evaluasi', value: evaluation, color: AppTheme.riskMedium),
      (label: 'Selesai', value: done, color: AppTheme.online),
    ];

    return SbCard(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 380;
          final stats = items
              .map(
                (i) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${i.value}',
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: i.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      i.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              )
              .toList();

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var row = 0; row < 2; row++)
                  Padding(
                    padding: EdgeInsets.only(bottom: row == 0 ? 12 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: stats[row * 2]),
                        const SizedBox(width: 12),
                        Expanded(child: stats[row * 2 + 1]),
                      ],
                    ),
                  ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppTheme.hairline,
                  ),
                Expanded(child: stats[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Shown when the register could not be loaded at all.
class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SbCard(
      accent: AppTheme.riskMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 18, color: AppTheme.riskMedium),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DATA BELUM TERSINKRON',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.eyebrow(color: AppTheme.riskMedium),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          SbButton(
            label: 'Coba Lagi',
            icon: Icons.refresh_rounded,
            height: 46,
            expand: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Thin notice that the numbers on screen come from the device cache.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.riskMediumBg,
        borderRadius: AppTheme.brSm,
        border: Border.all(color: AppTheme.riskMedium.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 15, color: AppTheme.riskMedium),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Menampilkan data tersimpan di perangkat. $message',
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppTheme.riskMedium,
              ),
            ),
          ),
        ],
      ),
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
    required this.role,
    required this.managementStatus,
    required this.canAdvance,
    required this.advanceLabel,
    required this.busy,
    required this.onAdvance,
  });

  final Map<String, dynamic> ticket;
  final int stage;
  final List<String> stages;
  final AppRole role;
  final String managementStatus;
  final bool canAdvance;
  final String advanceLabel;
  final bool busy;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final severity = (ticket['severity'] ?? 'medium').toString();
    final done = stage >= 6;
    final evaluated = managementStatus == 'EVALUATED';
    final waitingApproval = managementStatus == 'PENDING';
    final rejected = managementStatus == 'REJECTED';
    final color = evaluated
        ? AppTheme.online
        : rejected
            ? AppTheme.riskCritical
            : waitingApproval
                ? const Color(0xFF6D28D9)
                : done
                    ? AppTheme.riskLow
                    : AppTheme.riskColor(severity);

    final due = ticket['target_due_date'];
    final dueDate = due is String ? DateTime.tryParse(due) : null;
    final report = ticket['hazard_report'] is Map
        ? (ticket['hazard_report'] as Map).cast<String, dynamic>()
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
                label: evaluated
                    ? 'DIEVALUASI'
                    : rejected
                        ? 'DIKEMBALIKAN'
                        : waitingApproval
                            ? 'MENUNGGU MANAJEMEN'
                            : done
                                ? (managementStatus == 'APPROVED'
                                    ? 'MENUNGGU EVALUASI'
                                    : 'SELESAI')
                                : stages[stage - 1].toUpperCase(),
                icon: evaluated
                    ? Icons.verified_rounded
                    : rejected
                        ? Icons.undo_rounded
                        : waitingApproval
                            ? Icons.hourglass_top_rounded
                            : done
                                ? Icons.fact_check_rounded
                                : Icons.timelapse_rounded,
                color: color,
                background: color.withValues(alpha: 0.10),
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
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppTheme.inkMuted,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (report != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
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
                        size: 13,
                        color: AppTheme.brand,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'LAPORAN TERKAIT',
                        style: AppTheme.eyebrow(color: AppTheme.brand),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (report['description'] ?? '-').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (report['reporter_name'] != null)
                        report['reporter_name'].toString(),
                      if (report['zone_name'] != null)
                        report['zone_name'].toString().split(' (').first,
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
          if (waitingApproval) ...[
            const SizedBox(height: 12),
            _StatusNote(
              color: const Color(0xFF6D28D9),
              icon: Icons.business_center_rounded,
              text:
                  'Rencana tindakan menunggu persetujuan Manajemen. Supervisor belum dapat memulai pelaksanaan.',
            ),
          ] else if (rejected) ...[
            const SizedBox(height: 12),
            _StatusNote(
              color: AppTheme.riskCritical,
              icon: Icons.undo_rounded,
              text:
                  'Dikembalikan Manajemen. HSE perlu merevisi rencana tindakan sebelum dilanjutkan.',
            ),
          ] else if (done && managementStatus == 'APPROVED') ...[
            const SizedBox(height: 12),
            _StatusNote(
              color: AppTheme.brand,
              icon: Icons.fact_check_rounded,
              text:
                  'Pelaksanaan selesai. Menunggu evaluasi efektivitas dan penutupan oleh Manajemen.',
            ),
          ] else if (done && evaluated) ...[
            const SizedBox(height: 12),
            _StatusNote(
              color: AppTheme.online,
              icon: Icons.verified_rounded,
              text: 'Tindakan selesai dan sudah dievaluasi Manajemen.',
            ),
          ],
          if (canAdvance) ...[
            const SizedBox(height: 14),
            SbButton(
              label: advanceLabel,
              icon: role == AppRole.hse
                  ? Icons.verified_rounded
                  : Icons.arrow_forward_rounded,
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

class _StatusNote extends StatelessWidget {
  const _StatusNote({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppTheme.brSm,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
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

// ===========================================================================
// Conduct New K3 Inspection Sheet
// ===========================================================================
class _NewInspectionSheet extends StatefulWidget {
  const _NewInspectionSheet();

  @override
  State<_NewInspectionSheet> createState() => _NewInspectionSheetState();
}

class _NewInspectionSheetState extends State<_NewInspectionSheet> {
  static const _categories = [
    'Penggunaan APD',
    'Alat Berat',
    'Jalan Angkut',
    'APAR',
    'Housekeeping',
    'Lingkungan',
  ];

  static const Map<String, List<String>> _standardChecklists = {
    'Penggunaan APD': [
      'Helm keselamatan (Hard Hat) & tali dagu terpasang kencang',
      'Sepatu safety boots standar SNI tanpa sobekan/cacat',
      'Rompi reflektif visibilitas tinggi bersih dan menyala',
      'Kacamata safety anti debu & radiasi UV saat bekerja',
      'Masker respirator / partikulat debu P100 di area kerja',
    ],
    'Alat Berat': [
      'Pemeriksaan harian P2H unit dump truck & excavator tuntas',
      'Klakson, alarm mundur, dan rotary lamp berfungsi normal',
      'Kaca kabin bersih tanpa retak, wiper berfungsi baik',
      'Sistem rem darurat (emergency brake) berfungsi pakem',
      'Tidak ada kebocoran oli hidrolik atau solar di kolong unit',
    ],
    'Jalan Angkut': [
      'Lebar jalan hauling memenuhi standar keselamatan unit',
      'Tanggul pengaman (safety berm) setinggi 3/4 diameter roda',
      'Rambu batas kecepatan 25 km/jam terpasang jelas',
      'Penyiraman debu (water truck) aktif terjadwal',
      'Drainase jalan bebas genangan air dan lumpur tebal',
    ],
    'APAR': [
      'Tabung APAR tersedia pada setiap kabin alat berat & bengkel',
      'Jarum indikator tekanan berada di area hijau (aman)',
      'Segel pin pengaman utuh dan label masa berlaku valid',
      'Penempatan APAR mudah dijangkau tanpa halangan barang',
    ],
    'Housekeeping': [
      'Penataan perkakas rapi pada tool board / rak bengkel',
      'Lantai kerja bebas dari ceceran oli dan limbah B3',
      'Jalur evakuasi dan pintu darurat tidak terhalang barang',
      'Penyortiran tempat sampah organik, anorganik, dan limbah B3',
    ],
    'Lingkungan': [
      'Kolam pengendapan sedimen (settling pond) terpantau jernih',
      'Pengelolaan ceceran oli dengan oil spill kit tersedia',
      'Kadar debu jalan hauling dalam batas baku mutu',
      'Tingkat kebisingan area crusher di bawah 85 dBA',
    ],
  };

  late String _selectedCategory = _categories.first;
  String _selectedZone = 'Pit Utama (Area Penambangan Aktif)';
  List<String> _zones = [
    'Pit Utama (Area Penambangan Aktif)',
    'Jalan Angkut (Haul Road KM 0 - 15)',
    'Stockpile & ROM Timbunan',
    'Workshop & Maintenance Alat Berat',
    'Fasilitas Pengolahan (Crusher Plant)',
    'Gudang Logistik & Handak',
    'Fasilitas Pendukung (Mess & Site Office)',
  ];

  late final TextEditingController _titleController;
  final TextEditingController _notesController = TextEditingController();

  // Item pass state: index -> bool (true: Lulus, false: Temuan)
  final Map<int, bool> _passStates = {};
  // Finding notes: index -> controller
  final Map<int, TextEditingController> _findingNotes = {};

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final userZone = UserSession.instance.currentUser.value?.workZone;
    if (userZone != null && userZone.isNotEmpty) {
      _selectedZone = userZone;
    }
    _titleController = TextEditingController(
      text: 'Inspeksi K3 $_selectedCategory - ${_selectedZone.split(' (').first}',
    );
    _initChecklist();
    _loadZones();
  }

  Future<void> _loadZones() async {
    final zones = await ApiService.instance.getMiningZones();
    if (!mounted || zones.isEmpty) return;
    setState(() {
      _zones = zones.map((z) => (z['name'] ?? '').toString()).where((n) => n.isNotEmpty).toList();
      if (!_zones.contains(_selectedZone) && _zones.isNotEmpty) {
        _selectedZone = _zones.first;
        _updateDefaultTitle();
      }
    });
  }

  void _initChecklist() {
    _passStates.clear();
    for (final c in _findingNotes.values) {
      c.dispose();
    }
    _findingNotes.clear();

    final items = _standardChecklists[_selectedCategory] ?? const [];
    for (var i = 0; i < items.length; i++) {
      _passStates[i] = true; // default all pass
      _findingNotes[i] = TextEditingController();
    }
  }

  void _updateDefaultTitle() {
    _titleController.text =
        'Inspeksi K3 $_selectedCategory - ${_selectedZone.split(' (').first}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    for (final c in _findingNotes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Judul inspeksi wajib diisi.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final items = _standardChecklists[_selectedCategory] ?? const [];
    var passedCount = 0;
    var failedCount = 0;
    final findings = <Map<String, dynamic>>[];

    for (var i = 0; i < items.length; i++) {
      final passed = _passStates[i] ?? true;
      if (passed) {
        passedCount++;
      } else {
        failedCount++;
        final note = _findingNotes[i]?.text.trim() ?? '';
        findings.add({
          'item': items[i],
          'note': note.isNotEmpty ? note : 'Ditemukan ketidakpatuhan standar pada item ini.',
          'severity': 'medium',
        });
      }
    }

    final result = await ApiService.instance.createInspection(
      category: _selectedCategory,
      zoneName: _selectedZone,
      title: title,
      notes: _notesController.text.trim(),
      passedItems: passedCount,
      failedItems: failedCount,
      findings: findings,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.online,
          content: Text(
            failedCount > 0
                ? 'Inspeksi tersimpan. $failedCount tiket tindakan perbaikan otomatis diterbitkan!'
                : 'Inspeksi tersimpan. Semua butir dinyatakan LULUS.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _error = result.error ?? 'Gagal menyimpan inspeksi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserSession.instance.currentUser.value;
    final items = _standardChecklists[_selectedCategory] ?? const [];
    final failedCount = _passStates.values.where((p) => !p).length;

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
              // Sheet Handle
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
              const SizedBox(height: 14),

              // Title Header with Close Button
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.brand.withValues(alpha: 0.1),
                      borderRadius: AppTheme.brSm,
                    ),
                    child: const Icon(Icons.fact_check_rounded, color: AppTheme.brand, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Laporan Inspeksi K3 Baru',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: AppTheme.ink,
                          ),
                        ),
                        Text(
                          'Inspektur: ${user?.fullName ?? "Pengawas"} (${user?.roleDisplayName ?? "HSE"})',
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.ink),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.riskCriticalBg,
                    borderRadius: AppTheme.brMd,
                    border: Border.all(color: AppTheme.riskCritical.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.riskCritical, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
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
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 1. Kategori Inspeksi
              Text('KATEGORI INSPEKSI', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _categories.map((cat) {
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedCategory = cat;
                        _updateDefaultTitle();
                        _initChecklist();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.brand : AppTheme.surface,
                        borderRadius: AppTheme.brSm,
                        border: Border.all(
                          color: selected ? AppTheme.brand : AppTheme.hairline,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? Colors.white : AppTheme.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 2. Zona Kerja
              Text('ZONA OPERASIONAL TAMBANG', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _zones.map((zone) {
                  final shortName = zone.split(' (').first;
                  final selected = zone == _selectedZone;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedZone = zone;
                        _updateDefaultTitle();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.brand.withValues(alpha: 0.12) : AppTheme.canvas,
                        borderRadius: AppTheme.brSm,
                        border: Border.all(
                          color: selected ? AppTheme.brand : AppTheme.hairline,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Text(
                        shortName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? AppTheme.brand : AppTheme.inkMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 3. Judul / Fokus Inspeksi
              Text('FOKUS / JUDUL INSPEKSI', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: 'Contoh: Inspeksi Kelayakan APD & Rambu Jalur Hauling',
                  prefixIcon: Icon(Icons.assignment_outlined, size: 19),
                ),
              ),
              const SizedBox(height: 18),

              // 4. Checklist Items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('BUTIR PEMERIKSAAN K3', style: AppTheme.eyebrow()),
                  SbPill(
                    label: failedCount > 0 ? '$failedCount TEMUAN' : 'SEMUA LULUS',
                    color: failedCount > 0 ? AppTheme.riskHigh : AppTheme.riskLow,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SbCard(
                padding: const EdgeInsets.all(AppTheme.sm),
                child: Column(
                  children: List.generate(items.length, (idx) {
                    final itemText = items[idx];
                    final isPassed = _passStates[idx] ?? true;

                    return Padding(
                      padding: EdgeInsets.only(bottom: idx == items.length - 1 ? 0 : 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPassed ? AppTheme.surface : AppTheme.riskHighBg.withValues(alpha: 0.5),
                          borderRadius: AppTheme.brSm,
                          border: Border.all(
                            color: isPassed ? AppTheme.hairline : AppTheme.riskHigh.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isPassed ? AppTheme.brand : AppTheme.riskHigh,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${idx + 1}',
                                    style: AppTheme.mono(
                                      size: 10,
                                      weight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    itemText,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      color: AppTheme.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // PASS TOGGLE
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _passStates[idx] = true);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isPassed ? AppTheme.riskLow : Colors.transparent,
                                      borderRadius: AppTheme.brPill,
                                      border: Border.all(color: AppTheme.riskLow),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: isPassed ? Colors.white : AppTheme.riskLow,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'LULUS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isPassed ? Colors.white : AppTheme.riskLow,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // FINDING TOGGLE
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _passStates[idx] = false);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: !isPassed ? AppTheme.riskHigh : Colors.transparent,
                                      borderRadius: AppTheme.brPill,
                                      border: Border.all(color: AppTheme.riskHigh),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 14,
                                          color: !isPassed ? Colors.white : AppTheme.riskHigh,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'TEMUAN',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: !isPassed ? Colors.white : AppTheme.riskHigh,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!isPassed) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _findingNotes[idx],
                                maxLines: 2,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Deskripsi temuan ketidakpatuhan...',
                                  hintStyle: const TextStyle(fontSize: 11.5, color: AppTheme.inkFaint),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.all(10),
                                  border: OutlineInputBorder(
                                    borderRadius: AppTheme.brSm,
                                    borderSide: const BorderSide(color: AppTheme.riskHigh),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Catatan Tambahan
              Text('CATATAN UMUM LAPANGAN (OPSIONAL)', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Kondisi cuaca saat inspeksi, tim pendamping, dll...',
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SbButton(
                label: failedCount > 0
                    ? 'Kirim Inspeksi & Terbitkan $failedCount Tindak Lanjut'
                    : 'Kirim Laporan Inspeksi K3',
                icon: Icons.send_rounded,
                loading: _submitting,
                tone: failedCount > 0 ? AppTheme.riskHigh : AppTheme.brand,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}