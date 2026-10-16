import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// ---------------------------------------------------------------------------
/// ZoneGeometry — the map footprint of an operational zone.
///
/// Geometry lives in Postgres (`mining_zones.polygon_coordinates`), never in
/// the client bundle, so relocating a site is a data change rather than a
/// release. Shapes accepted by [fromJson]:
///
///   { "center": [lat, lng], "polygon": [[lat,lng], ...], "assembly": [lat,lng] }
///   [ {"lat":..,"lng":..}, ... ]          // plain polygon ring
///   [[lat,lng], ...]                      // plain polygon ring
/// ---------------------------------------------------------------------------
class ZoneGeometry {
  const ZoneGeometry({
    this.center,
    this.polygon = const [],
    this.assembly,
  });

  final LatLng? center;
  final List<LatLng> polygon;
  final LatLng? assembly;

  bool get isEmpty => center == null && polygon.isEmpty;

  static ZoneGeometry fromJson(dynamic raw) {
    if (raw == null) return const ZoneGeometry();

    if (raw is Map) {
      final center = _latLng(raw['center'] ?? raw['center_location']);
      final assembly = _latLng(raw['assembly'] ?? raw['assembly_point']);
      final polygon = _ring(raw['polygon'] ?? raw['coordinates'] ?? raw['ring']);
      return ZoneGeometry(
        center: center ?? _centroid(polygon),
        polygon: polygon,
        assembly: assembly,
      );
    }

    final ring = _ring(raw);
    return ZoneGeometry(center: _centroid(ring), polygon: ring);
  }

  static LatLng? _latLng(dynamic value) {
    if (value is List && value.length >= 2) {
      final lat = (value[0] as num?)?.toDouble();
      final lng = (value[1] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    if (value is Map) {
      final lat = (value['lat'] as num?)?.toDouble();
      final lng = (value['lng'] as num?)?.toDouble() ?? (value['lon'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  static List<LatLng> _ring(dynamic value) {
    if (value is! List) return const [];
    return value
        .map(_latLng)
        .whereType<LatLng>()
        .toList(growable: false);
  }

  static LatLng? _centroid(List<LatLng> points) {
    if (points.isEmpty) return null;
    var lat = 0.0;
    var lng = 0.0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  /// Great-circle distance in metres to another point.
  static double distanceMetres(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
    return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(h)));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}