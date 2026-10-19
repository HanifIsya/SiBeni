import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api_service.dart';
import '../core/app_config.dart';
import '../core/location_service.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../core/zone_model.dart';
import '../features/warning_manage_screen.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/pills.dart';
import '../widgets/role_workspace.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_card.dart';
import '../widgets/states.dart';

/// Operational risk map.
///
/// Everything rendered here is data-driven: zone footprints and assembly points
/// come from Postgres, the blue dot is the device's real GNSS fix, and warnings
/// come from the early-warning feed. Nothing on this screen is hardcoded.
class RiskMapScreen extends StatefulWidget {
  const RiskMapScreen({
    super.key,
    required this.onNavigateToReport,
    required this.onNavigateToEmergency,
  });

  final VoidCallback onNavigateToReport;
  final VoidCallback onNavigateToEmergency;

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> {
  final MapController _map = MapController();

  List<Map<String, dynamic>> _warnings = [];
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    LocationService.instance.ensureFix();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final warnings = await ApiService.instance.getEarlyWarnings();
    final zones = await ApiService.instance.getMiningZones();
    if (!mounted) return;
    setState(() {
      _warnings = warnings;
      _zones = zones;
      _loading = false;
    });
  }

  // ----------------------------------------------------------------- derived
  LatLng? get _fix {
    final p = LocationService.instance.position.value;
    return p == null ? null : LatLng(p.latitude, p.longitude);
  }

  LatLng? get _initialCentre {
    final me = _fix;
    if (me != null) return me;
    for (final z in _zones) {
      final c = ZoneGeometry.fromJson(z['polygon_coordinates']).center;
      if (c != null) return c;
    }
    return null;
  }

  Map<String, dynamic>? get _activeZone {
    final user = UserSession.instance.currentUser.value;
    if (user == null || _zones.isEmpty) return _zones.isEmpty ? null : _zones.first;
    final target = user.workZone.toLowerCase();
    return _zones.firstWhere(
      (z) => (z['name'] ?? '').toString().toLowerCase().startsWith(target.split(' (').first),
      orElse: () => _zones.first,
    );
  }

  String get _situationalRisk {
    final active = _activeZone;
    if (active != null) return (active['current_risk_level'] ?? 'low').toString();
    final levels = _zones.map((z) => (z['current_risk_level'] ?? 'low').toString()).toList();
    if (levels.contains('critical')) return 'critical';
    if (levels.contains('high')) return 'high';
    if (levels.contains('medium')) return 'medium';
    return 'low';
  }

  // ------------------------------------------------------------------ actions
  Future<void> _recentre() async {
    await LocationService.instance.ensureFix();
    final me = _fix;
    if (me != null) {
      _map.move(me, math.max(_map.camera.zoom, 16));
    } else {
      final centre = _initialCentre;
      if (centre != null) _map.move(centre, 15);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            me != null
                ? 'Dipusatkan pada posisi Anda (${LocationService.instance.accuracyLabel})'
                : 'Belum ada sinyal GPS. Tampilkan pusat zona.',
          ),
        ),
      );
    }
  }

  /// Frame the whole concession: every zone footprint in view.
  ///
  /// This is the "lokasi PT" control. The camera is fitted to the union of the
  /// zone geometry read from Postgres, so it stays correct if the site moves or
  /// a zone is added, and it never depends on the device having a GPS fix.
  void _fitSite() {
    final points = <LatLng>[];
    for (final zone in _zones) {
      final geometry = _geometry(zone);
      if (geometry.center != null) points.add(geometry.center!);
      points.addAll(geometry.polygon);
    }

    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geometri zona belum tersedia di server.')),
      );
      return;
    }

    if (points.length == 1) {
      _map.move(points.first, 15.5);
    } else {
      final bounds = LatLngBounds.fromPoints(points);
      _map.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(46)),
      );
    }
  }

  void _openZone(Map<String, dynamic> zone) {
    final geometry = ZoneGeometry.fromJson(zone['polygon_coordinates']);
    final assemblyName = (zone['evacuation_assembly_point'] ?? '').toString();
    final route = (zone['evacuation_route_info'] ?? '').toString();
    final me = _fix;

    int? metres;
    if (me != null && geometry.assembly != null) {
      metres = ZoneGeometry.distanceMetres(me, geometry.assembly!).round();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ZoneSheet(
        name: (zone['name'] ?? 'Zona').toString().split(' (').first,
        description: (zone['description'] ?? '').toString(),
        level: (zone['current_risk_level'] ?? 'low').toString(),
        hazards: List<String>.from(zone['active_hazards'] ?? const []),
        assemblyName: assemblyName,
        route: route,
        distanceMetres: metres,
        declaredDistance: zone['distance_to_assembly_point_m'] as int?,
        hasFix: me != null,
        onNavigateEmergency: widget.onNavigateToEmergency,
        canManageWarnings: _role.canManageWarnings,
        onManageWarnings: _openWarningManager,
      ),
    );
  }

  AppRole get _role => UserSession.instance.currentUser.value?.role ?? AppRole.worker;

  void _openWarningManager() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const WarningManageScreen(),
    );
  }

  // -------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final role = _role;
    return ValueListenableBuilder<GpsStatus>(
      valueListenable: LocationService.instance.status,
      builder: (context, gps, _) {
        return AdaptivePage(
          onRefresh: _load,
          slivers: [
            if (role != AppRole.worker) ...[
              RoleWorkspaceBanner(role: role, dense: true),
              const SizedBox(height: AppTheme.md),
            ],
            Reveal(child: _SituationCard(risk: _situationalRisk)),
            const SizedBox(height: AppTheme.lg),

            if (_loading && _warnings.isEmpty)
              const _WarningSkeleton()
            else if (_warnings.isNotEmpty) ...[
              SectionHeader(
                title: 'Peringatan Dini',
                icon: Icons.campaign_rounded,
                subtitle: '${_warnings.length} peringatan aktif untuk zona Anda',
              ),
              for (final w in _warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.md),
                  child: _WarningCard(data: w),
                ),
              const SizedBox(height: AppTheme.xs),
            ] else ...[
              SectionHeader(
                title: 'Peringatan Dini',
                icon: Icons.campaign_rounded,
              ),
              const EmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: 'Tidak ada peringatan aktif',
                message: 'Tidak ada peringatan aktif untuk saat ini.',
                compact: true,
              ),
              const SizedBox(height: AppTheme.lg),
            ],

            SectionHeader(
              title: 'Peta Risiko',
              icon: Icons.map_rounded,
              subtitle: 'Ketuk zona untuk detail dan rute evakuasi',
            ),
            _MapCard(
              mapController: _map,
              zones: _zones,
              warnings: _warnings,
              onZoneTap: _openZone,
              onRecentre: _recentre,
              onFitSite: _fitSite,
            ),
            const SizedBox(height: AppTheme.md),
            const _Legend(),
            const SizedBox(height: AppTheme.xl),

            Row(
              children: [
                Expanded(
                  child: SbButton(
                    label: 'Lapor',
                    icon: Icons.add_circle_outline_rounded,
                    onPressed: widget.onNavigateToReport,
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: SbButton(
                    label: 'Darurat',
                    icon: Icons.sos_rounded,
                    variant: SbButtonVariant.danger,
                    onPressed: widget.onNavigateToEmergency,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// Situation summary
// ===========================================================================
class _SituationCard extends StatelessWidget {
  const _SituationCard({required this.risk});
  final String risk;

  @override
  Widget build(BuildContext context) {
    final user = UserSession.instance.currentUser.value;

    return SbHeroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: AppTheme.brMd,
                ),
                child: Icon(AppTheme.riskIcon(risk), color: const Color(0xFFFFD5D5), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTheme.riskLabel(risk) == 'RENDAH'
                          ? 'Kondisi Aman'
                          : 'Status ${AppTheme.riskLabel(risk).toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.zoneShortName ?? 'Zona tidak ditentukan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.onDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _DarkDivider(),
          const SizedBox(height: 12),
          const _GpsReadout(),
        ],
      ),
    );
  }
}

class _DarkDivider extends StatelessWidget {
  const _DarkDivider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.12),
      );
}

/// Live GNSS readout — never a fabricated coordinate.
class _GpsReadout extends StatelessWidget {
  const _GpsReadout();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GpsStatus>(
      valueListenable: LocationService.instance.status,
      builder: (context, status, _) {
        final ready = status == GpsStatus.ready;
        return Row(
          children: [
            Icon(
              ready ? Icons.my_location_rounded : Icons.location_searching_rounded,
              size: 16,
              color: ready ? const Color(0xFF7DD3FC) : AppTheme.onDarkMuted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                ready
                    ? LocationService.instance.coordinatesLabel
                    : _pendingLabel(status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ready
                    ? AppTheme.mono(size: 12.5, weight: FontWeight.w700, color: Colors.white)
                    : const TextStyle(fontSize: 12, color: AppTheme.onDarkMuted),
              ),
            ),
            if (ready) ...[
              const SizedBox(width: 8),
              SbPill(
                label: LocationService.instance.accuracyLabel,
                color: const Color(0xFF7DD3FC),
                dense: true,
              ),
            ] else if (status == GpsStatus.blocked || status == GpsStatus.serviceOff)
              GestureDetector(
                onTap: () => LocationService.instance.openSettings(),
                child: const Text(
                  'Aktifkan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7DD3FC),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _pendingLabel(GpsStatus status) {
    switch (status) {
      case GpsStatus.blocked:
        return 'Izin lokasi diblokir';
      case GpsStatus.serviceOff:
        return 'Layanan lokasi mati';
      case GpsStatus.locating:
        return 'Mencari sinyal GNSS…';
      case GpsStatus.requesting:
        return 'Menunggu izin lokasi';
      default:
        return 'Posisi belum tersedia';
    }
  }
}

/// Tiny adapter so the hero panel can subscribe to the position notifier.
// (hero panel reads LocationService directly through ValueListenableBuilder)

// ===========================================================================
// Warnings
// ===========================================================================
class _WarningSkeleton extends StatelessWidget {
  const _WarningSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.md),
          child: SbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 14, width: 150),
                const SizedBox(height: 12),
                const SkeletonBox(height: 12),
                const SizedBox(height: 8),
                const SkeletonBox(height: 12, width: 220),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarningCard extends StatefulWidget {
  const _WarningCard({required this.data});
  final Map<String, dynamic> data;

  @override
  State<_WarningCard> createState() => _WarningCardState();
}

class _WarningCardState extends State<_WarningCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final severity = (widget.data['severity'] ?? 'medium').toString();
    final color = AppTheme.riskColor(severity);
    final tags = List<String>.from(widget.data['hazard_tags'] ?? const []);
    final zones = List<String>.from(widget.data['affected_zones'] ?? const []);
    final instructions = (widget.data['safety_instructions'] ?? '').toString().trim();

    return SbCard(
      accent: color,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppTheme.riskIcon(severity), size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (widget.data['title'] ?? 'Peringatan dini').toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    letterSpacing: -0.1,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RiskPill(level: severity, dense: true, icon: false),
            ],
          ),
          if ((widget.data['description'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.data['description'].toString(),
              style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.inkMuted),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((t) => SbTag(label: t, color: color)).toList(),
            ),
          ],
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SbPanel(
                    color: AppTheme.canvas,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TINDAKAN KESELAMATAN',
                            style: AppTheme.eyebrow(color: color)),
                        const SizedBox(height: 6),
                        Text(
                          instructions,
                          style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.ink),
                        ),
                      ],
                    ),
                  ),
                ],
                if (zones.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Zona terdampak',
                    style: AppTheme.eyebrow(),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: zones
                        .map((z) => SbTag(
                              label: z.split(' (').first,
                              icon: Icons.place_rounded,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          if (instructions.isNotEmpty || zones.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _expanded = !_expanded);
                },
                icon: Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(_expanded ? 'Ringkas' : 'Rincian'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 40),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Map
// ===========================================================================
class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.mapController,
    required this.zones,
    required this.warnings,
    required this.onZoneTap,
    required this.onRecentre,
    required this.onFitSite,
  });

  final MapController mapController;
  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> warnings;
  final void Function(Map<String, dynamic>) onZoneTap;
  final VoidCallback onRecentre;
  final VoidCallback onFitSite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth * 0.82).clamp(260.0, 400.0);

        return ClipRRect(
          borderRadius: AppTheme.brLg,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: AppTheme.brLg,
              border: Border.all(color: AppTheme.hairline),
              boxShadow: AppTheme.shadowSoft,
            ),
            child: ValueListenableBuilder<GpsStatus>(
              valueListenable: LocationService.instance.status,
              builder: (context, gps, _) {
                final me = LocationService.instance.position.value;
                final mePoint = me == null ? null : LatLng(me.latitude, me.longitude);
                final centres = zones
                    .map((z) => ZoneGeometry.fromJson(z['polygon_coordinates']).center)
                    .whereType<LatLng>()
                    .toList();

                final initial = mePoint ??
                    (centres.isNotEmpty ? centres.first : const LatLng(0, 0));

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: initial,
                        initialZoom: 15,
                        minZoom: 4,
                        maxZoom: 18.5,
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

                        // Zone footprints, tinted by live risk level.
                        PolygonLayer(
                          polygons: zones
                              .map((z) {
                                final g = ZoneGeometry.fromJson(z['polygon_coordinates']);
                                if (g.polygon.length < 3) return null;
                                final color = AppTheme.riskColor(
                                    (z['current_risk_level'] ?? 'low').toString());
                                return Polygon(
                                  points: g.polygon,
                                  color: color.withValues(alpha: 0.16),
                                  borderColor: color.withValues(alpha: 0.85),
                                  borderStrokeWidth: 1.6,
                                );
                              })
                              .whereType<Polygon>()
                              .toList(),
                        ),

                        MarkerLayer(
                          markers: [
                            for (final z in zones)
                              if (_geometry(z).center case final LatLng point)
                                _zoneMarker(
                                  point: point,
                                  label: (z['name'] ?? 'Zona').toString().split(' (').first,
                                  level: (z['current_risk_level'] ?? 'low').toString(),
                                  onTap: () => onZoneTap(z),
                                ),
                          ],
                        ),

                        MarkerLayer(
                          markers: [
                            for (final z in zones)
                              if (_geometry(z).assembly case final LatLng point)
                                Marker(
                                  point: point,
                                  width: 26,
                                  height: 26,
                                  child: const _AssemblyMarker(),
                                ),
                          ],
                        ),

                        if (mePoint != null)
                          MarkerLayer(
                            markers: [_selfMarker(mePoint)],
                          ),

                        const RichAttributionWidget(
                          alignment: AttributionAlignment.bottomLeft,
                          attributions: [TextSourceAttribution('OpenStreetMap')],
                        ),
                      ],
                    ),

                    // Map controls
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Column(
                        children: [
                          _MapButton(
                            icon: Icons.add_rounded,
                            onTap: () => mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom + 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MapButton(
                            icon: Icons.remove_rounded,
                            onTap: () => mapController.move(
                              mapController.camera.center,
                              mapController.camera.zoom - 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MapButton(
                            icon: Icons.my_location_rounded,
                            filled: true,
                            tooltip: 'Posisikan ke lokasi saya',
                            onTap: onRecentre,
                          ),
                          const SizedBox(height: 8),
                          _MapButton(
                            icon: Icons.factory_rounded,
                            tooltip: 'Tampilkan seluruh lokasiPT',
                            onTap: onFitSite,
                          ),
                        ],
                      ),
                    ),

                    // GPS prompt when the device has no fix yet.
                    if (gps != GpsStatus.ready)
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 34,
                        child: _GpsPrompt(status: gps, onTap: onRecentre),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Zone geometry parser, shared by the map card and the screen state.
ZoneGeometry _geometry(Map<String, dynamic> zone) =>
    ZoneGeometry.fromJson(zone['polygon_coordinates']);

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: filled ? AppTheme.brand : Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Color(0x1A0B1622), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Icon(icon, size: 18, color: filled ? Colors.white : AppTheme.ink),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _GpsPrompt extends StatelessWidget {
  const _GpsPrompt({required this.status, required this.onTap});
  final GpsStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final blocked = status == GpsStatus.blocked || status == GpsStatus.serviceOff;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.ink.withValues(alpha: 0.92),
          borderRadius: AppTheme.brMd,
        ),
        child: Row(
          children: [
            Icon(
              blocked ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
              size: 16,
              color: blocked ? const Color(0xFFFCD34D) : const Color(0xFF7DD3FC),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                blocked
                    ? 'Lokasi tidak aktif — ketuk untuk membuka setelan'
                    : 'Ketuk untuk mengambil posisi GNSS Anda',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable zone pin. Returned as a [Marker] because the FlutterMap marker
/// layer requires concrete [Marker] entries, not arbitrary widgets.
Marker _zoneMarker({
  required LatLng point,
  required String label,
  required String level,
  required VoidCallback onTap,
}) {
  final color = AppTheme.riskColor(level);
  return Marker(
    point: point,
    width: 108,
    height: 54,
    alignment: Alignment.topCenter,
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            constraints: const BoxConstraints(maxWidth: 104),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.brSm,
              border: Border.all(color: color, width: 1.6),
              boxShadow: const [
                BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ),
          Icon(Icons.place_rounded, color: color, size: 24),
        ],
      ),
    ),
  );
}

class _AssemblyMarker extends StatelessWidget {
  const _AssemblyMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.riskLow,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.flag_rounded, size: 13, color: Colors.white),
    );
  }
}

/// The worker's live GNSS position.
Marker _selfMarker(LatLng point) {
  return Marker(
    point: point,
    width: 34,
    height: 34,
    child: Container(
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.45),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Rendah', 'low'),
      ('Sedang', 'medium'),
      ('Tinggi', 'high'),
      ('Kritis', 'critical'),
    ];
    return Wrap(
      spacing: AppTheme.sm,
      runSpacing: AppTheme.sm,
      alignment: WrapAlignment.center,
      children: [
        for (final (label, key) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppTheme.riskColor(key),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.inkMuted,
                ),
              ),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Text(
              'Posisi Anda',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.inkMuted,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(color: AppTheme.riskLow, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Text(
              'Titik kumpul',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.inkMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// Zone detail sheet
// ===========================================================================
class _ZoneSheet extends StatelessWidget {
  const _ZoneSheet({
    required this.name,
    required this.description,
    required this.level,
    required this.hazards,
    required this.assemblyName,
    required this.route,
    required this.distanceMetres,
    required this.declaredDistance,
    required this.hasFix,
    required this.onNavigateEmergency,
    required this.canManageWarnings,
    required this.onManageWarnings,
  });

  final String name;
  final String description;
  final String level;
  final List<String> hazards;
  final String assemblyName;
  final String route;
  final int? distanceMetres;
  final int? declaredDistance;
  final bool hasFix;
  final VoidCallback onNavigateEmergency;
  final bool canManageWarnings;
  final VoidCallback onManageWarnings;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(level);
    final distance = distanceMetres ?? declaredDistance;

    return SafeArea(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                RiskPill(level: level),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppTheme.inkMuted),
              ),
            ],
            const SizedBox(height: 18),

            SbCard(
              color: AppTheme.riskBg(level),
              borderColor: color.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(AppTheme.md),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, color: AppTheme.riskLow, size: 22),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assemblyName.isEmpty ? 'Titik kumpul' : assemblyName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                        if (distance != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            hasFix
                                ? 'Jarak dari posisi Anda ${_fmtMetres(distance)}'
                                : 'Jarak terjadwal ${_fmtMetres(distance)}',
                            style: AppTheme.mono(size: 11, color: AppTheme.inkMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (route.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('RUTE EVAKUASI', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              Text(
                route,
                style: const TextStyle(fontSize: 13, height: 1.55, color: AppTheme.ink),
              ),
            ],

            if (hazards.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('BAHAYA AKTIF', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: hazards
                    .map((h) => SbTag(label: h, color: color, icon: Icons.warning_amber_rounded))
                    .toList(),
              ),
            ] else ...[
              const SizedBox(height: 18),
              const EmptyState(
                icon: Icons.verified_outlined,
                title: 'Tidak ada bahaya aktif',
                compact: true,
              ),
            ],

            const SizedBox(height: 22),
            SbButton(
              label: 'Aktifkan Tanggap Darurat',
              icon: Icons.sos_rounded,
              variant: SbButtonVariant.danger,
              onPressed: () {
                Navigator.pop(context);
                onNavigateEmergency();
              },
            ),

            // Zone administration is limited to HSE / management.
            if (canManageWarnings) ...[
              const SizedBox(height: 10),
              SbButton(
                label: 'Kelola Peringatan Dini',
                icon: Icons.campaign_rounded,
                variant: SbButtonVariant.ghost,
                tone: AppTheme.brand,
                onPressed: () {
                  Navigator.pop(context);
                  onManageWarnings();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtMetres(int m) {
    if (m < 1000) return '$m m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }
}