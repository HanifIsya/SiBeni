import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_service.dart';
import '../core/location_service.dart';
import '../core/network_service.dart';
import '../core/offline_sync_manager.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_card.dart';
import '../widgets/states.dart';

/// Hazard / near-miss reporting.
///
/// Design goal: a gloved worker can file a complete report in under 30 seconds
/// without ever leaving the screen, with or without a signal.
class QuickReportScreen extends StatefulWidget {
  const QuickReportScreen({super.key});

  @override
  State<QuickReportScreen> createState() => _QuickReportScreenState();
}

class _QuickReportScreenState extends State<QuickReportScreen> {
  static const _categories = [
    ('Alat Berat', Icons.precision_manufacturing_rounded),
    ('Lereng & Geoteknik', Icons.landscape_rounded),
    ('Kebakaran', Icons.local_fire_department_rounded),
    ('Debu & Lingkungan', Icons.blur_on_rounded),
    ('Cuaca Ekstrem', Icons.thunderstorm_rounded),
    ('APD', Icons.health_and_safety_rounded),
  ];

  final _description = TextEditingController();
  String _type = 'hazard';
  String _category = _categories.first.$1;
  String? _zoneName;
  bool _submitting = false;

  List<Map<String, dynamic>> _zones = [];
  bool _loadedZones = false;

  @override
  void initState() {
    super.initState();
    _zoneName = UserSession.instance.currentUser.value?.zoneShortName;
    _bootstrap();
    LocationService.instance.ensureFix();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final zones = await ApiService.instance.getMiningZones();
    if (!mounted) return;
    setState(() {
      _zones = zones;
      _loadedZones = true;
      final current = UserSession.instance.currentUser.value?.zoneShortName;
      if (current != null && zones.any((z) => _short(z) == current)) {
        _zoneName = current;
      } else if (_zoneName == null && zones.isNotEmpty) {
        _zoneName = _short(zones.first);
      }
    });
  }

  static String _short(Map<String, dynamic> z) =>
      (z['name'] ?? '').toString().split(' (').first;

  String _zoneIdFor(String? name) {
    for (final z in _zones) {
      if (_short(z) == name) return (z['id'] ?? '').toString();
    }
    return '';
  }

  // ------------------------------------------------------------------ submit
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final text = _description.text.trim();

    if (text.isEmpty) {
      _toast('Tambahkan deskripsi singkat kondisi.', AppTheme.riskHigh);
      return;
    }
    final zone = _zoneName;
    if (zone == null || zone.isEmpty) {
      _toast('Pilih zona kejadian terlebih dahulu.', AppTheme.riskHigh);
      return;
    }

    setState(() => _submitting = true);
    final user = UserSession.instance.currentUser.value;
    final gps = LocationService.instance.position.value;

    final payload = <String, dynamic>{
      'local_id': 'rep-${DateTime.now().microsecondsSinceEpoch}',
      'reporter_id': user?.employeeId,
      'reporter_name': user?.fullName,
      'report_type': _type,
      'zone_id': _zoneIdFor(zone),
      'zone_name': zone,
      'category': _category,
      'incident_timestamp': DateTime.now().toIso8601String(),
      // Only ever send a coordinate the device actually resolved.
      if (gps != null) 'gps_latitude': gps.latitude,
      if (gps != null) 'gps_longitude': gps.longitude,
      'description': text,
      'photo_urls': <String>[],
      'is_emergency': false,
      'sync_status': 'queued',
    };

    final delivered = await OfflineSyncManager.instance.enqueueReport(payload);

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _description.clear();
    });

    final queued = OfflineSyncManager.instance.queueCount.value;
    _toast(
      delivered
          ? 'Laporan terkirim ke HSE.'
          : queued > 0
              ? 'Laporan tersimpan. Akan terkirim otomatis saat jaringan tersedia.'
              : 'Laporan tersimpan di perangkat.',
      delivered ? AppTheme.online : AppTheme.offline,
      icon: delivered ? Icons.cloud_done_rounded : Icons.save_rounded,
    );
  }

  void _toast(String message, Color tone, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: tone,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OnlineState>(
      valueListenable: NetworkService.instance.state,
      builder: (context, state, _) {
        return AdaptivePage(
          slivers: [
            const SectionHeader(
              title: 'Lapor Cepat',
              icon: Icons.assignment_rounded,
              subtitle: 'Selesaikan dalam 30 detik. Aman tanpa sinyal.',
            ),

            // 1 — Type
            _TypeSelector(
              value: _type,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: AppTheme.lg),

            // 2 — Zone + GPS
            SectionHeader(
              title: 'Lokasi Kejadian',
              icon: Icons.place_rounded,
              dense: true,
              action: SbButton(
                label: 'Ambil Ulang GPS',
                icon: Icons.my_location_rounded,
                height: 48,
                expand: false,
                variant: SbButtonVariant.ghost,
                tone: AppTheme.brand,
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  await LocationService.instance.ensureFix();
                },
              ),
            ),
            SbCard(
              padding: const EdgeInsets.all(AppTheme.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GpsStrip(),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text('Zona', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (!_loadedZones)
                    const SkeletonBox(height: 36, radius: 10)
                  else
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: _zones.map((z) {
                        final label = _short(z);
                        final selected = label == _zoneName;
                        return _SelectChip(
                          label: label,
                          selected: selected,
                          onTap: () => setState(() => _zoneName = label),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.lg),

            // 3 — Category
            SectionHeader(title: 'Kategori Bahaya', icon: Icons.category_rounded, dense: true),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final selected = c.$1 == _category;
                return _CategoryCard(
                  label: c.$1,
                  icon: c.$2,
                  selected: selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _category = c.$1);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.lg),

            // 4 — Description
            SectionHeader(title: 'Deskripsi', icon: Icons.notes_rounded, dense: true),
            TextField(
              controller: _description,
              minLines: 4,
              maxLines: 7,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.ink),
              decoration: const InputDecoration(
                hintText: 'Contoh: Retakan badan jalan angkut melebar ±15 cm di KM 4.2…',
              ),
            ),
            const SizedBox(height: AppTheme.lg),

            // 5 — Submit
            SbButton(
              label: state == OnlineState.online ? 'Kirim Laporan' : 'Simpan Laporan',
              icon: state == OnlineState.online
                  ? Icons.send_rounded
                  : Icons.save_alt_rounded,
              loading: _submitting,
              tone: state == OnlineState.online ? AppTheme.brand : AppTheme.offline,
              onPressed: _submit,
            ),
            const SizedBox(height: 10),
            _QueueNotice(state: state),
          ],
        );
      },
    );
  }
}

// ===========================================================================
class _GpsStrip extends StatelessWidget {
  const _GpsStrip();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GpsStatus>(
      valueListenable: LocationService.instance.status,
      builder: (context, status, _) {
        final ready = status == GpsStatus.ready;
        final color = ready ? AppTheme.online : AppTheme.inkFaint;

        return Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppTheme.brSm,
              ),
              child: Icon(Icons.satellite_alt_rounded, size: 17, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ready ? 'Koordinat perangkat' : 'Koordinat belum tersedia',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ready
                        ? LocationService.instance.coordinatesLabel
                        : 'Laporan tetap dapat dikirim tanpa koordinat.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ready
                        ? AppTheme.mono(size: 12.5, weight: FontWeight.w700, color: AppTheme.ink)
                        : const TextStyle(fontSize: 11.5, color: AppTheme.inkFaint),
                  ),
                ],
              ),
            ),
            if (ready)
              SbPillLabel(
                label: LocationService.instance.accuracyLabel,
                color: AppTheme.online,
              ),
          ],
        );
      },
    );
  }
}

class _QueueNotice extends StatelessWidget {
  const _QueueNotice({required this.state});
  final OnlineState state;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: OfflineSyncManager.instance.queueCount,
      builder: (context, queue, _) {
        final offline = state != OnlineState.online;
        final color = offline ? AppTheme.offline : AppTheme.inkFaint;
        final message = offline
            ? queue > 0
                ? '$queue laporan menunggu jaringan.'
                : 'Mode offline. Laporan disimpan di perangkat.'
            : queue > 0
                ? 'Mengirim $queue laporan tertunda…'
                : 'Semua laporan sudah tersinkron.';

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              offline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('hazard', 'BAHAYA', 'Kondisi / tindakan tidak aman', Icons.dangerous_rounded, AppTheme.riskHigh),
    ('near_miss', 'NEAR MISS', 'Hampir celaka tanpa korban', Icons.flash_on_rounded, AppTheme.riskMedium),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((o) {
        final selected = o.$1 == value;
        final color = o.$5;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: o.$1 == 'hazard' ? AppTheme.md : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(o.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 74,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.riskBg(o.$1) : AppTheme.surface,
                  borderRadius: AppTheme.brMd,
                  border: Border.all(
                    color: selected ? color : AppTheme.hairline,
                    width: selected ? 1.8 : 1,
                  ),
                  boxShadow: selected ? AppTheme.shadowSoft : null,
                ),
                child: Row(
                  children: [
                    Icon(o.$4, size: 24, color: selected ? color : AppTheme.inkFaint),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                              color: selected ? color : AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            o.$3,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              height: 1.3,
                              color: AppTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        constraints: const BoxConstraints(minWidth: 120, minHeight: 48),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brand : AppTheme.surface,
          borderRadius: AppTheme.brMd,
          border: Border.all(color: selected ? AppTheme.brand : AppTheme.hairline),
          boxShadow: selected ? AppTheme.shadowSoft : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: selected ? Colors.white : AppTheme.inkFaint),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brand : AppTheme.canvas,
          borderRadius: AppTheme.brSm,
          border: Border.all(color: selected ? AppTheme.brand : AppTheme.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : AppTheme.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// Lightweight pill that avoids pulling in the full SbPill for one label.
class SbPillLabel extends StatelessWidget {
  const SbPillLabel({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppTheme.brPill,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTheme.mono(size: 10.5, weight: FontWeight.w700, color: color),
      ),
    );
  }
}