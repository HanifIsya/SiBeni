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

/// M-07 — Early warning administration.
///
/// Answering "are the early warnings hardcoded?": they are not. They are rows
/// in `early_warnings`, sourced from `/api/bmkg`, and this screen is where HSE
/// and management publish, amend, or stand them down. Nothing in the client
/// bundle contains a warning.
class WarningManageScreen extends StatefulWidget {
  const WarningManageScreen({super.key});

  @override
  State<WarningManageScreen> createState() => _WarningManageScreenState();
}

class _WarningManageScreenState extends State<WarningManageScreen> {
  List<Map<String, dynamic>> _warnings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // includeInactive so a stood-down warning can be reviewed and reactivated.
    final warnings = await ApiService.instance.getEarlyWarnings(includeInactive: true);
    if (!mounted) return;
    setState(() {
      _warnings = warnings;
      _loading = false;
    });
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final result = await showModalBottomSheet<WarningDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WarningFormSheet(existing: existing),
    );
    if (result == null || !mounted) return;

    final response = existing == null
        ? await ApiService.instance.createWarning(result.toJson())
        : await ApiService.instance.updateWarning(existing['id'].toString(), result.toJson());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: response.isSuccess ? AppTheme.online : AppTheme.riskCritical,
        content: Text(response.message ?? response.error ?? ''),
      ),
    );
    if (response.isSuccess) _load();
  }

  Future<void> _deactivate(Map<String, dynamic> warning) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        title: const Text(
          'Nonaktifkan peringatan?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink),
        ),
        content: const Text(
          'Peringatan ini akan hilang dari peta semua pengguna. Riwayatnya tetap tersimpan.',
          style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.riskCritical),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final response = await ApiService.instance.deactivateWarning(warning['id'].toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: response.isSuccess ? AppTheme.online : AppTheme.riskCritical,
        content: Text(response.message ?? response.error ?? ''),
      ),
    );
    if (response.isSuccess) _load();
  }

  @override
  Widget build(BuildContext context) {
    final active = _warnings.where((w) => w['is_active'] == true).length;

    return AdaptivePage(
      onRefresh: _load,
      slivers: [
        SectionHeader(
          title: 'Kelola Peringatan',
          icon: Icons.campaign_rounded,
          subtitle: '$active aktif · ${_warnings.length} total',
          action: SbButton(
            label: 'Terbitkan',
            icon: Icons.add_rounded,
            height: 48,
            expand: false,
            onPressed: () => _edit(),
          ),
        ),

        if (_loading)
          const _WarningSkeleton()
        else if (_warnings.isEmpty)
          const EmptyState(
            icon: Icons.notifications_off_rounded,
            title: 'Belum ada peringatan',
            message: 'Terbitkan peringatan agar seluruh pekerja melihatnya di peta.',
          )
        else
          for (final warning in _warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.md),
              child: _WarningCard(
                warning: warning,
                onEdit: () => _edit(warning),
                onDeactivate: () => _deactivate(warning),
              ),
            ),
      ],
    );
  }
}

// ===========================================================================
class WarningDraft {
  WarningDraft({
    required this.title,
    required this.description,
    required this.severity,
    required this.affectedZones,
    required this.hazardTags,
    required this.instructions,
    required this.validUntil,
  });

  final String title;
  final String description;
  final String severity;
  final List<String> affectedZones;
  final List<String> hazardTags;
  final String instructions;
  final DateTime validUntil;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'severity': severity,
        'affected_zones': affectedZones,
        'hazard_tags': hazardTags,
        'safety_instructions': instructions,
        'valid_until': validUntil.toIso8601String(),
      };

  static List<String> _asList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }
}

class _WarningFormSheet extends StatefulWidget {
  const _WarningFormSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_WarningFormSheet> createState() => _WarningFormSheetState();
}

class _WarningFormSheetState extends State<_WarningFormSheet> {
  late final _title = TextEditingController(text: (widget.existing?['title'] ?? '').toString());
  late final _description =
      TextEditingController(text: (widget.existing?['description'] ?? '').toString());
  late final _instructions =
      TextEditingController(text: (widget.existing?['safety_instructions'] ?? '').toString());
  late final _zones =
      TextEditingController(text: WarningDraft._asList(widget.existing?['affected_zones']).join(', '));
  late final _tags =
      TextEditingController(text: WarningDraft._asList(widget.existing?['hazard_tags']).join(', '));

  late String _severity = (widget.existing?['severity'] ?? 'medium').toString();
  late DateTime _validUntil = _parseDate(widget.existing?['valid_until']) ??
      DateTime.now().add(const Duration(hours: 12));
  String? _error;

  static DateTime? _parseDate(dynamic raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _instructions.dispose();
    _zones.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = 'Judul dan deskripsi wajib diisi.');
      return;
    }
    Navigator.pop(
      context,
      WarningDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        severity: _severity,
        affectedZones: _zones.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        hazardTags: _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        instructions: _instructions.text.trim(),
        validUntil: _validUntil,
      ),
    );
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

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
              Text(
                isEdit ? 'Ambil Peringatan' : 'Terbitkan Peringatan',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.ink,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.riskCritical,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              Text('Tingkat', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: ['low', 'medium', 'high', 'critical'].map((level) {
                  final selected = _severity == level;
                  final color = AppTheme.riskColor(level);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _severity = level);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      constraints: const BoxConstraints(minHeight: 46),
                      decoration: BoxDecoration(
                        color: selected ? color : AppTheme.surface,
                        borderRadius: AppTheme.brSm,
                        border: Border.all(color: selected ? color : AppTheme.hairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppTheme.riskIcon(level),
                              size: 15, color: selected ? Colors.white : color),
                          const SizedBox(width: 7),
                          Text(
                            AppTheme.riskLabel(level),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              _Field(controller: _title, label: 'Judul peringatan', maxLines: 2),
              const SizedBox(height: 12),
              _Field(controller: _description, label: 'Deskripsi', maxLines: 4),
              const SizedBox(height: 12),
              _Field(
                controller: _zones,
                label: 'Zona terdampak (pisahkan dengan koma)',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _tags,
                label: 'Label bahaya (pisahkan dengan koma)',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _instructions,
                label: 'Tindakan keselamatan',
                maxLines: 4,
              ),

              const SizedBox(height: 16),
              Text('BERLAKU SAMPAI', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              SbButton(
                label: DateFormat('EEEE, d MMMM yyyy').format(_validUntil),
                icon: Icons.event_rounded,
                variant: SbButtonVariant.ghost,
                tone: AppTheme.brand,
                height: 48,
                onPressed: _pickExpiry,
              ),

              const SizedBox(height: 20),
              SbButton(
                label: isEdit ? 'Simpan Perubahan' : 'Terbitkan',
                icon: isEdit ? Icons.save_rounded : Icons.campaign_rounded,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 13.5, color: AppTheme.ink),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.warning,
    required this.onEdit,
    required this.onDeactivate,
  });

  final Map<String, dynamic> warning;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final severity = (warning['severity'] ?? 'medium').toString();
    final active = warning['is_active'] == true;
    final until = DateTime.tryParse((warning['valid_until'] ?? '').toString());
    final expired = until != null && until.isBefore(DateTime.now());

    return Opacity(
      opacity: active ? 1 : 0.55,
      child: SbCard(
        accent: AppTheme.riskColor(severity),
        padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    (warning['title'] ?? 'Peringatan').toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RiskPill(level: severity, dense: true, icon: false),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              (warning['description'] ?? '').toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.inkMuted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SbTag(
                  label: (warning['source'] ?? 'HSE').toString(),
                  icon: Icons.radar_rounded,
                ),
                if (until != null)
                  SbTag(
                    label: active
                        ? (expired ? 'Kedaluwarsa' : 'Sampai ${DateFormat('d MMM HH:mm').format(until)}')
                        : 'Nonaktif',
                    icon: Icons.schedule_rounded,
                    color: expired || !active ? AppTheme.riskCritical : AppTheme.inkMuted,
                  ),
                ...WarningDraft._asList(warning['hazard_tags'])
                    .take(3)
                    .map((t) => SbTag(label: t)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SbButton(
                    label: 'Ubah',
                    icon: Icons.edit_rounded,
                    height: 44,
                    variant: SbButtonVariant.ghost,
                    tone: AppTheme.brand,
                    onPressed: onEdit,
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: SbButton(
                      label: 'Nonaktifkan',
                      icon: Icons.visibility_off_rounded,
                      height: 44,
                      variant: SbButtonVariant.ghost,
                      tone: AppTheme.riskCritical,
                      onPressed: onDeactivate,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningSkeleton extends StatelessWidget {
  const _WarningSkeleton();

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
                SkeletonBox(height: 15, width: 230),
                SizedBox(height: 12),
                SkeletonBox(height: 11),
                SizedBox(height: 8),
                SkeletonBox(height: 11, width: 180),
              ],
            ),
          ),
        ),
      ),
    );
  }
}