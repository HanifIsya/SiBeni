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

/// Kanal koordinasi Supervisor ↔ HSE ↔ Manajemen.
///
/// Supervisor needs a formal channel to raise field constraints, HSE needs to
/// answer verification questions, and Management needs visibility for urgent
/// escalations. Every message is stored server-side and notifies the recipient
/// role automatically.
class SupervisorCoordinationScreen extends StatefulWidget {
  const SupervisorCoordinationScreen({super.key});

  @override
  State<SupervisorCoordinationScreen> createState() =>
      _SupervisorCoordinationScreenState();
}

class _SupervisorCoordinationScreenState
    extends State<SupervisorCoordinationScreen> {
  List<Map<String, dynamic>> _requests = [];
  Map<String, dynamic> _counts = const {};
  bool _loading = true;
  String _filter = 'open';
  String? _busyId;

  /// Set when the channel could not be loaded.
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final read = await ApiService.instance.getCoordinationRead();
    if (!mounted) return;
    final data = read.data;
    setState(() {
      if (data == null) {
        _requests = const [];
        _counts = const {};
      } else {
        _requests = (data['requests'] is List)
            ? (data['requests'] as List)
                .whereType<Map<String, dynamic>>()
                .toList()
            : const [];
        final counts = data['counts'];
        _counts = counts is Map
            ? counts.map((k, v) => MapEntry(k.toString(), v))
            : const {};
      }
      _loadError = read.error;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _visible {
    switch (_filter) {
      case 'open':
        return _requests
            .where(
              (r) =>
                  (r['status'] ?? '').toString().toUpperCase() != 'RESOLVED',
            )
            .toList();
      case 'mine':
        final me = UserSession.instance.currentUser.value;
        return _requests
            .where(
              (r) =>
                  (r['to_role'] ?? '').toString() == (me?.role.name ?? '') &&
                  (r['status'] ?? '').toString().toUpperCase() != 'RESOLVED',
            )
            .toList();
      case 'urgent':
        return _requests
            .where(
              (r) =>
                  (r['priority'] ?? '').toString().toUpperCase() == 'URGENT' &&
                  (r['status'] ?? '').toString().toUpperCase() != 'RESOLVED',
            )
            .toList();
      default:
        return _requests;
    }
  }

  Future<void> _newRequest() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewCoordinationSheet(),
    );
    if (sent == true) await _load();
  }

  Future<void> _respond(Map<String, dynamic> request) async {
    final id = (request['id'] ?? '').toString();
    if (id.isEmpty) return;

    final result = await showModalBottomSheet<_CoordinationReply>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReplySheet(request: request),
    );
    if (result == null || !mounted) return;

    setState(() => _busyId = id);
    final apiResult = await ApiService.instance.respondCoordination(
      id: id,
      response: result.response,
      status: result.status,
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
    if (apiResult.isSuccess) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = UserSession.instance.currentUser.value;
    final role = me?.role ?? AppRole.supervisor;
    final title = role == AppRole.management
        ? 'Koordinasi & Eskalasi'
        : role == AppRole.hse
            ? 'Koordinasi HSE'
            : 'Koordinasi Lapangan';

    return AdaptivePage(
      onRefresh: _load,
      slivers: [
        RoleWorkspaceBanner(
          role: role,
          variant: RoleBannerVariant.compact,
          note: _counts.isEmpty
              ? null
              : '${_counts['open'] ?? 0} terbuka · '
                  '${_counts['needs_my_response'] ?? 0} perlu balasan',
        ),
        const SizedBox(height: AppTheme.lg),
        SectionHeader(
          title: title,
          icon: Icons.forum_rounded,
          subtitle:
              'Koordinasikan kendala lapangan, verifikasi HSE, dan keputusan Manajemen dalam satu kanal.',
          action: SbButton(
            label: 'Koordinasi Baru',
            icon: Icons.add_comment_rounded,
            height: 48,
            expand: false,
            onPressed: _newRequest,
          ),
        ),
        _CoordinationStats(counts: _counts),
        const SizedBox(height: AppTheme.md),
        _CoordinationFilters(
          value: _filter,
          onChanged: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: AppTheme.lg),
        if (_loading)
          const _CoordinationSkeleton()
        else if (_loadError != null && _requests.isEmpty)
          EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Kanal koordinasi belum tersinkron',
            message: '$_loadError',
            compact: true,
            action: SbButton(
              label: 'Coba Lagi',
              icon: Icons.refresh_rounded,
              height: 44,
              expand: false,
              onPressed: _load,
            ),
          )
        else if (_visible.isEmpty)
          EmptyState(
            icon: Icons.forum_outlined,
            title: 'Tidak ada koordinasi aktif',
            message: _filter == 'open'
                ? 'Semua koordinasi sudah selesai. Kirim pesan baru jika ada kendala lapangan.'
                : 'Ganti filter atau kirim koordinasi baru.',
            compact: true,
          )
        else
          for (final request in _visible)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: _CoordinationCard(
                request: request,
                busy: _busyId == (request['id'] ?? '').toString(),
                onRespond: () => _respond(request),
              ),
            ),
      ],
    );
  }
}

class _CoordinationStats extends StatelessWidget {
  const _CoordinationStats({required this.counts});
  final Map<String, dynamic> counts;

  int _n(String key) {
    final raw = counts[key];
    return raw is num ? raw.toInt() : 0;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Perlu respons saya', _n('needs_my_response'), AppTheme.brand),
      ('Urgent', _n('urgent'), AppTheme.riskCritical),
      ('Aktif', _n('open'), AppTheme.riskHigh),
      ('Terkirim', _n('sent_by_me'), AppTheme.inkMuted),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 620 ? 4 : 2;
        final width = (c.maxWidth - AppTheme.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppTheme.md,
          runSpacing: AppTheme.md,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: AppTheme.brMd,
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${item.$2}',
                        style: AppTheme.mono(
                          size: 22,
                          weight: FontWeight.w800,
                          color: item.$2 > 0 ? item.$3 : AppTheme.inkFaint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.inkMuted,
                          ),
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

class _CoordinationFilters extends StatelessWidget {
  const _CoordinationFilters({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('open', 'Aktif'),
      ('mine', 'Untuk Saya'),
      ('urgent', 'Urgent'),
      ('all', 'Semua'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            GestureDetector(
              onTap: () => onChanged(options[i].$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 42),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: value == options[i].$1
                      ? AppTheme.brand
                      : AppTheme.surface,
                  borderRadius: AppTheme.brSm,
                  border: Border.all(
                    color: value == options[i].$1
                        ? AppTheme.brand
                        : AppTheme.hairline,
                  ),
                ),
                child: Text(
                  options[i].$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: value == options[i].$1
                        ? Colors.white
                        : AppTheme.inkMuted,
                  ),
                ),
              ),
            ),
            if (i != options.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _CoordinationCard extends StatelessWidget {
  const _CoordinationCard({
    required this.request,
    required this.busy,
    required this.onRespond,
  });

  final Map<String, dynamic> request;
  final bool busy;
  final VoidCallback onRespond;

  static String roleLabel(dynamic role) {
    switch (role.toString().toLowerCase()) {
      case 'supervisor':
        return 'Supervisor';
      case 'hse':
        return 'HSE';
      case 'management':
        return 'Manajemen';
      default:
        return 'Pekerja';
    }
  }

  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
        return AppTheme.online;
      case 'ACKNOWLEDGED':
        return AppTheme.brand;
      default:
        return AppTheme.riskHigh;
    }
  }

  static String statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
        return 'SELESAI';
      case 'ACKNOWLEDGED':
        return 'DIBACA';
      default:
        return 'TERBUKA';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (request['status'] ?? 'OPEN').toString();
    final priority = (request['priority'] ?? 'NORMAL').toString();
    final urgent = priority.toUpperCase() == 'URGENT';
    final color = urgent && status.toUpperCase() != 'RESOLVED'
        ? AppTheme.riskCritical
        : statusColor(status);
    final created = DateTime.tryParse((request['created_at'] ?? '').toString());

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
                  (request['subject'] ?? 'Koordinasi').toString(),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SbPill(
                    label: statusLabel(status),
                    color: color,
                    dense: true,
                  ),
                  if (urgent) ...[
                    const SizedBox(height: 4),
                    const SbPill(
                      label: 'URGENT',
                      icon: Icons.priority_high_rounded,
                      color: AppTheme.riskCritical,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              SbTag(
                label:
                    '${roleLabel(request['from_role'])} → ${roleLabel(request['to_role'])}',
                icon: Icons.swap_horiz_rounded,
              ),
              if ((request['from_name'] ?? '').toString().isNotEmpty)
                SbTag(
                  label: request['from_name'].toString(),
                  icon: Icons.person_rounded,
                ),
              if ((request['zone_name'] ?? '').toString().isNotEmpty)
                SbTag(
                  label: request['zone_name'].toString().split(' (').first,
                  icon: Icons.place_rounded,
                ),
              if (created != null)
                SbTag(
                  label: DateFormat('d MMM, HH:mm').format(created.toLocal()),
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            (request['message'] ?? '').toString(),
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppTheme.ink,
            ),
          ),
          if ((request['response'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.online.withValues(alpha: 0.06),
                borderRadius: AppTheme.brSm,
                border:
                    Border.all(color: AppTheme.online.withValues(alpha: 0.20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BALASAN ${(request['responded_by_name'] ?? '').toString().toUpperCase()}',
                    style: AppTheme.eyebrow(color: AppTheme.online),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request['response'].toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (status.toUpperCase() != 'RESOLVED') ...[
            const SizedBox(height: 13),
            SbButton(
              label: status.toUpperCase() == 'ACKNOWLEDGED'
                  ? 'Balas & Selesaikan'
                  : 'Tanggapi Koordinasi',
              icon: Icons.reply_rounded,
              height: 45,
              variant: SbButtonVariant.ghost,
              tone: AppTheme.brand,
              loading: busy,
              onPressed: busy ? null : onRespond,
            ),
          ],
        ],
      ),
    );
  }
}

class _NewCoordinationSheet extends StatefulWidget {
  const _NewCoordinationSheet();

  @override
  State<_NewCoordinationSheet> createState() => _NewCoordinationSheetState();
}

class _NewCoordinationSheetState extends State<_NewCoordinationSheet> {
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _message = TextEditingController();
  late String _toRole;
  bool _urgent = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final me = UserSession.instance.currentUser.value?.role ?? AppRole.supervisor;
    _toRole = me == AppRole.supervisor ? 'hse' : 'supervisor';
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final me = UserSession.instance.currentUser.value;
    final subject = _subject.text.trim();
    final message = _message.text.trim();

    if (subject.isEmpty) {
      setState(() => _error = 'Subjek koordinasi wajib diisi.');
      return;
    }
    if (message.isEmpty) {
      setState(() => _error = 'Isi koordinasi wajib diisi.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ApiService.instance.sendCoordination(
      toRole: _toRole,
      subject: subject,
      message: message,
      priority: _urgent ? 'URGENT' : 'NORMAL',
      zoneName: me?.workZone,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.online,
          content: Text(result.message ?? 'Koordinasi terkirim.'),
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _error = result.error ?? 'Gagal mengirim koordinasi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = UserSession.instance.currentUser.value;
    final options = [
      if (me?.role != AppRole.supervisor) ('supervisor', 'Supervisor'),
      if (me?.role != AppRole.hse) ('hse', 'HSE'),
      if (me?.role != AppRole.management) ('management', 'Manajemen'),
    ];

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
                      color: const Color(0xFF0E7490).withValues(alpha: 0.11),
                      borderRadius: AppTheme.brSm,
                    ),
                    child: const Icon(
                      Icons.add_comment_rounded,
                      size: 20,
                      color: Color(0xFF0E7490),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Koordinasi Baru',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('TUJUAN KOORDINASI', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final option in options)
                    GestureDetector(
                      onTap: () => setState(() => _toRole = option.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 170),
                        constraints: const BoxConstraints(minHeight: 42),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: _toRole == option.$1
                              ? const Color(0xFF0E7490)
                              : AppTheme.surface,
                          borderRadius: AppTheme.brSm,
                          border: Border.all(
                            color: _toRole == option.$1
                                ? const Color(0xFF0E7490)
                                : AppTheme.hairline,
                          ),
                        ),
                        child: Text(
                          option.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _toRole == option.$1
                                ? Colors.white
                                : AppTheme.inkMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PRIORITAS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.inkFaint,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _urgent,
                    activeTrackColor: AppTheme.riskCritical,
                    onChanged: (value) => setState(() => _urgent = value),
                  ),
                  Text(
                    _urgent ? 'URGENT' : 'Normal',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _urgent ? AppTheme.riskCritical : AppTheme.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('SUBJEK', style: AppTheme.eyebrow()),
              const SizedBox(height: 7),
              TextField(
                controller: _subject,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
                decoration: const InputDecoration(
                  hintText: 'Contoh: Akses jalan hauling tertutup material longsor',
                ),
              ),
              const SizedBox(height: 8),
              Text('ISI KOORDINASI', style: AppTheme.eyebrow()),
              const SizedBox(height: 7),
              TextField(
                controller: _message,
                maxLines: 4,
                maxLength: 800,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
                decoration: const InputDecoration(
                  hintText:
                      'Jelaskan kondisi, lokasi, dampak, dan bantuan yang dibutuhkan…',
                ),
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
              const SizedBox(height: 10),
              SbButton(
                label: 'Kirim Koordinasi',
                icon: Icons.send_rounded,
                loading: _submitting,
                tone: const Color(0xFF0E7490),
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoordinationReply {
  const _CoordinationReply({required this.response, required this.status});
  final String response;
  final String status;
}

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.request});
  final Map<String, dynamic> request;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final TextEditingController _response = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  void _send(String status) {
    final text = _response.text.trim();
    if (status == 'RESOLVED' && text.isEmpty) {
      setState(() => _error = 'Balasan wajib diisi sebelum menandai selesai.');
      return;
    }
    if (status == 'ACKNOWLEDGED' && text.isEmpty) {
      setState(() => _error = 'Tuliskan balasan singkat sebelum menandai dibaca.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    Navigator.pop(
      context,
      _CoordinationReply(response: text, status: status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
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
              const Text(
                'Tanggapi Koordinasi',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: AppTheme.brSm,
                  border: Border.all(color: AppTheme.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (request['subject'] ?? 'Koordinasi').toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (request['message'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('BALASAN / TINDAK LANJUT', style: AppTheme.eyebrow()),
              const SizedBox(height: 7),
              TextField(
                controller: _response,
                maxLines: 4,
                maxLength: 800,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
                decoration: const InputDecoration(
                  hintText:
                      'Contoh: Jalur alternatif sudah dibuka, water truck dijadwalkan pukul 14.00…',
                ),
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
                label: 'Kirim & Selesaikan',
                icon: Icons.check_circle_rounded,
                loading: _submitting,
                tone: AppTheme.online,
                onPressed: () => _send('RESOLVED'),
              ),
              const SizedBox(height: AppTheme.sm),
              SbButton(
                label: 'Tandai Sudah Dibaca',
                icon: Icons.done_rounded,
                variant: SbButtonVariant.ghost,
                tone: AppTheme.brand,
                onPressed: () => _send('ACKNOWLEDGED'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoordinationSkeleton extends StatelessWidget {
  const _CoordinationSkeleton();

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
                SkeletonBox(height: 15, width: 230),
                SizedBox(height: 12),
                SkeletonBox(height: 11, width: 170),
                SizedBox(height: 12),
                SkeletonBox(height: 11),
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
