import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api_service.dart';
import '../core/app_config.dart';
import '../core/location_service.dart';
import '../core/offline_sync_manager.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../core/zone_model.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/pills.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_card.dart';
import '../widgets/states.dart';

/// Emergency response module.
///
/// The SOS control is a deliberate 3-second hold: deliberate intent prevents
/// false activations from machine vibration while still being fast under stress.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  static const _types = [
    ('Kebakaran', 'fire', Icons.local_fire_department_rounded),
    ('Cedera / Medis', 'injury', Icons.medical_services_rounded),
    ('Kebocoran B3', 'chemical_leak', Icons.science_rounded),
    ('Longsor / Banjir', 'landslide_flood', Icons.landscape_rounded),
    ('Keamanan', 'security', Icons.security_rounded),
  ];

  static const _principles = [
    ('Amankan diri', 'Lepaskan diri dari sumber bahaya'),
    ('Laporkan', 'Sampaikan lokasi & jenis bahaya'),
    ('Ikuti arahan', 'Patuhi petugas HSE di lokasi'),
    ('Cegah lanjutan', 'Hentikan mesin dan aktivitas sekitar'),
  ];

  static const _steps = [
    ('Kenali tanda alarm', 'Hentikan aktivitas dan matikan mesin'),
    ('Tentukan arah evakuasi', 'Ikuti rambu dan jalur terpendek aman'),
    ('Tenang dan tertib', 'Jangan berlari atau kembali ambil barang'),
    ('Menuju titik kumpul', 'Berkumpul di area terbuka yang ditandai'),
    ('Ikuti-petugas HSE', 'Tunggu instruksi dan verifikasi lapangan'),
    ('Lakukan absensi', 'Pastikan seluruh pekerja tercatat aman'),
  ];

  int _selected = 0;
  double _hold = 0;
  Timer? _timer;
  bool _broadcasting = false;
  List<Map<String, dynamic>> _zones = const [];

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    final zones = await ApiService.instance.getMiningZones();
    if (!mounted || zones.isEmpty) return;
    setState(() => _zones = zones);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------- hold
  void _startHold() {
    if (_broadcasting) return;
    _timer?.cancel();
    setState(() => _hold = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _hold + (0.04 / AppConfig.sosHoldSeconds);
      if (next >= 1) {
        t.cancel();
        setState(() => _hold = 1);
        HapticFeedback.heavyImpact();
        _trigger();
      } else {
        setState(() => _hold = next);
      }
    });
  }

  void _cancelHold() {
    _timer?.cancel();
    if (_hold < 1 && mounted) setState(() => _hold = 0);
  }

  // ---------------------------------------------------------------- dispatch
  Future<void> _trigger() async {
    setState(() => _broadcasting = true);
    final user = UserSession.instance.currentUser.value;
    final gps = LocationService.instance.position.value;

    final delivered = await ApiService.instance.broadcastSos(
      workerId: user?.employeeId ?? 'unknown',
      workerName: user?.fullName ?? 'Pekerja Tambang',
      zoneName: user?.workZone ?? '',
      emergencyType: _types[_selected].$2,
      latitude: gps?.latitude,
      longitude: gps?.longitude,
    );

    // Guarantee the record survives even when the uplink is down.
    if (!delivered) {
      await OfflineSyncManager.instance.enqueueReport({
        'local_id': 'sos-${DateTime.now().microsecondsSinceEpoch}',
        'reporter_id': user?.employeeId,
        'reporter_name': user?.fullName,
        'report_type': 'hazard',
        'zone_name': user?.workZone ?? '',
        'category': 'Tanggap Darurat',
        'incident_timestamp': DateTime.now().toIso8601String(),
        if (gps != null) 'gps_latitude': gps.latitude,
        if (gps != null) 'gps_longitude': gps.longitude,
        'description': 'SOS ${_types[_selected].$1}',
        'photo_urls': <String>[],
        'is_emergency': true,
        'emergency_type': _types[_selected].$2,
        'sync_status': 'queued',
      });
    }

    if (!mounted) return;
    setState(() {
      _broadcasting = false;
      _hold = 0;
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SosConfirmation(
        delivered: delivered,
        type: _types[_selected].$1,
        worker: user?.fullName ?? 'Pekerja Tambang',
        zone: user?.zoneShortName ?? '',
      ),
    );
  }

  // ------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return AdaptivePage(
      slivers: [
        const SectionHeader(
          title: 'Tanggap Darurat',
          icon: Icons.emergency_rounded,
          subtitle: 'Aktifkan alarm, lalu ikuti rute evakuasi',
        ),

        _SosHoldButton(
          progress: _hold,
          busy: _broadcasting,
          onStart: _startHold,
          onCancel: _cancelHold,
        ),
        const SizedBox(height: AppTheme.lg),

        SectionHeader(title: 'Jenis Keadaan', icon: Icons.category_rounded, dense: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_types.length, (i) {
            final t = _types[i];
            final selected = i == _selected;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selected = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.riskCriticalBg : AppTheme.surface,
                  borderRadius: AppTheme.brMd,
                  border: Border.all(
                    color: selected ? AppTheme.riskCritical : AppTheme.hairline,
                    width: selected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.$3,
                      size: 18,
                      color: selected ? AppTheme.riskCritical : AppTheme.inkFaint,
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        t.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppTheme.riskCritical : AppTheme.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppTheme.lg),

        _EvacuationCard(zones: _zones),
        const SizedBox(height: AppTheme.lg),

        const SectionHeader(title: 'Prinsip Respons', icon: Icons.priority_high_rounded, dense: true),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 520 ? 4 : 2;
            final width = (c.maxWidth - AppTheme.sm * (columns - 1)) / columns;
            return Wrap(
              spacing: AppTheme.sm,
              runSpacing: AppTheme.sm,
              children: List.generate(_principles.length, (i) {
                return SizedBox(
                  width: width,
                  child: _PrincipleCard(
                    index: i + 1,
                    title: _principles[i].$1,
                    detail: _principles[i].$2,
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: AppTheme.lg),

        const SectionHeader(title: 'Langkah Evakuasi', icon: Icons.route_rounded, dense: true),
        SbCard(
          child: Column(
            children: List.generate(_steps.length, (i) {
              return Padding(
                padding: EdgeInsets.only(bottom: i == _steps.length - 1 ? 0 : AppTheme.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: AppTheme.brand,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: AppTheme.mono(
                          size: 11.5,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _steps[i].$1,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _steps[i].$2,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
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

// ===========================================================================
// SOS control
// ===========================================================================
class _SosHoldButton extends StatelessWidget {
  const _SosHoldButton({
    required this.progress,
    required this.busy,
    required this.onStart,
    required this.onCancel,
  });

  final double progress;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final remaining = (AppConfig.sosHoldSeconds * (1 - progress));
    final label = busy
        ? 'Mengirim sinyal…'
        : progress > 0
            ? 'Lanjutkan ${remaining.toStringAsFixed(1)} dtk'
            : 'Tahan untuk mengaktifkan';

    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) => onStart(),
          onTapUp: (_) => onCancel(),
          onTapCancel: onCancel,
          child: LayoutBuilder(
            builder: (context, c) {
              final size = math.min(c.maxWidth, 190.0);
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: size,
                        height: size,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: AppTheme.riskCriticalBg,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.riskCritical),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE03434), Color(0xFFB31515)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.shadowGlow(AppTheme.riskCritical),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sos_rounded, color: Colors.white, size: 44),
                              const SizedBox(height: 2),
                              const Text(
                                'SOS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppTheme.md),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: progress > 0 ? AppTheme.riskCritical : AppTheme.inkMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Tahan ${AppConfig.sosHoldSeconds} detik untuk menyiarkan sinyal',
          style: const TextStyle(fontSize: 11.5, color: AppTheme.inkFaint),
        ),
      ],
    );
  }
}

class _SosConfirmation extends StatelessWidget {
  const _SosConfirmation({
    required this.delivered,
    required this.type,
    required this.worker,
    required this.zone,
  });

  final bool delivered;
  final String type;
  final String worker;
  final String zone;

  @override
  Widget build(BuildContext context) {
    final gps = LocationService.instance.position.value;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      actionsPadding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: delivered ? AppTheme.riskCriticalBg : AppTheme.offlineBg,
              borderRadius: AppTheme.brMd,
            ),
            child: Icon(
              delivered ? Icons.campaign_rounded : Icons.save_rounded,
              color: delivered ? AppTheme.riskCritical : AppTheme.offline,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              delivered ? 'Sinyal terkirim' : 'Sinyal tersimpan',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppTheme.ink,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            delivered
                ? 'Pusat kendali HSE menerima alarm Anda.'
                : 'Alarm dicatat di perangkat dan akan terkirim otomatis saat jaringan tersedia.',
            style: const TextStyle(fontSize: 13, height: 1.5, color: AppTheme.inkMuted),
          ),
          const SizedBox(height: 14),
          SbPanel(
            child: Column(
              children: [
                _Line(label: 'Jenis', value: type),
                _Line(label: 'Pelapor', value: worker),
                _Line(label: 'Zona', value: zone.isEmpty ? '—' : zone),
                _Line(
                  label: 'Koordinat',
                  value: gps == null
                      ? 'Tidak tersedia'
                      : '${gps.latitude.toStringAsFixed(5)}, ${gps.longitude.toStringAsFixed(5)}',
                  mono: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.riskCriticalBg,
              borderRadius: AppTheme.brMd,
            ),
            child: const Text(
              'Segera menuju titik kumpul terdekat. Jangan kembali mengambil barang.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: AppTheme.riskCritical,
              ),
            ),
          ),
        ],
      ),
      actions: [
        SbButton(
          label: 'Saya sudah aman',
          expand: false,
          onPressed: () => Navigator.pop(context),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.inkFaint),
            ),
          ),
          Expanded(
            child: Text(
              value,
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

// ===========================================================================
// Evacuation
// ===========================================================================
class _EvacuationCard extends StatelessWidget {
  const _EvacuationCard({required this.zones});
  final List<Map<String, dynamic>> zones;

  @override
  Widget build(BuildContext context) {
    final user = UserSession.instance.currentUser.value;
    final zoneName = user?.zoneShortName ?? '';

    return ValueListenableBuilder<GpsStatus>(
      valueListenable: LocationService.instance.status,
      builder: (context, status, _) {
        final me = LocationService.instance.position.value;

        Map<String, dynamic>? zone;
        for (final z in zones) {
          if ((z['name'] ?? '').toString().split(' (').first == zoneName) {
            zone = z;
            break;
          }
        }
        zone ??= zones.isEmpty ? null : zones.first;

        final geometry = ZoneGeometry.fromJson(zone?['polygon_coordinates']);
        final assembly = geometry.assembly;
        int? liveDistance;
        if (me != null && assembly != null) {
          liveDistance = ZoneGeometry.distanceMetres(
            LatLng(me.latitude, me.longitude),
            assembly,
          ).round();
        }

        final route = (zone?['evacuation_route_info'] ?? '').toString();
        final assemblyName = (zone?['evacuation_assembly_point'] ?? '').toString();
        final declared = zone?['distance_to_assembly_point_m'] as int?;

        return SbCard(
          padding: const EdgeInsets.all(0),
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (assembly != null)
                _MiniMap(
                  assembly: assembly,
                  from: me == null ? null : LatLng(me.latitude, me.longitude),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(AppTheme.lg),
                  child: EmptyState(
                    icon: Icons.map_outlined,
                    title: 'Geometri zona belum tersedia',
                    compact: true,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag_rounded, size: 18, color: AppTheme.riskLow),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            assemblyName.isEmpty ? 'Titik kumpul zona' : assemblyName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                        if (liveDistance != null || declared != null)
                          SbPill(
                            label: liveDistance != null
                                ? _fmt(liveDistance)
                                : _fmt(declared!),
                            icon: Icons.straighten_rounded,
                            color: AppTheme.riskLow,
                            background: AppTheme.riskLowBg,
                          ),
                      ],
                    ),
                    if (route.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        route,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: AppTheme.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmt(int m) => m < 1000 ? '$m m' : '${(m / 1000).toStringAsFixed(1)} km';
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.assembly, this.from});
  final LatLng assembly;
  final LatLng? from;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final height = (c.maxWidth * 0.5).clamp(150.0, 220.0);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: from ?? assembly,
              initialZoom: 16.5,
              minZoom: 11,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: AppConfig.tileUserAgent,
                maxZoom: 19,
              ),
              if (from != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [from!, assembly],
                      color: AppTheme.riskLow,
                      strokeWidth: 4,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: assembly,
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.riskLow,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.4),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.flag_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                  if (from != null)
                    Marker(
                      point: from!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.4),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard({required this.index, required this.title, required this.detail});
  final int index;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.brMd,
        border: Border.all(color: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppTheme.brand,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: AppTheme.mono(size: 11, weight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.inkMuted),
          ),
        ],
      ),
    );
  }
}