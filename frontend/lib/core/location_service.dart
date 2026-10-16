import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum GpsStatus {
  /// Not started yet.
  idle,

  /// Waiting for the user to accept the OS permission prompt.
  requesting,

  /// Fix in progress.
  locating,

  /// A live fix is available.
  ready,

  /// Permission permanently denied — needs a trip to app settings.
  blocked,

  /// Location services are switched off device-wide.
  serviceOff,

  /// Device or plugin cannot provide a fix.
  unavailable,
}

/// ---------------------------------------------------------------------------
/// LocationService
///
/// Single source of truth for the worker's real position.
/// Nothing in this class fabricates coordinates: if a fix cannot be obtained
/// the status explains why and downstream consumers receive `null`.
/// ---------------------------------------------------------------------------
class LocationService {
  LocationService._internal();

  static final LocationService instance = LocationService._internal();

  final ValueNotifier<GpsStatus> status = ValueNotifier<GpsStatus>(GpsStatus.idle);
  final ValueNotifier<Position?> position = ValueNotifier<Position?>(null);
  final ValueNotifier<DateTime?> fixTime = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);

  static const Duration _fixTimeout = Duration(seconds: 12);

  StreamSubscription<Position>? _stream;
  Timer? _watchdog;

  double? get latitude => position.value?.latitude;
  double? get longitude => position.value?.longitude;
  double? get accuracy => position.value?.accuracy;
  bool get hasFix => position.value != null;

  /// Request permission (if needed) and take a first fix. Safe to call often.
  Future<bool> ensureFix({bool highAccuracy = true}) async {
    if (hasFix && status.value == GpsStatus.ready) return true;

    message.value = null;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        status.value = GpsStatus.serviceOff;
        message.value = 'Layanan lokasi dimatikan di perangkat';
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        status.value = GpsStatus.requesting;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        status.value = GpsStatus.unavailable;
        message.value = 'Izin lokasi ditolak';
        return false;
      }
      if (permission == LocationPermission.deniedForever) {
        status.value = GpsStatus.blocked;
        message.value = 'Izin lokasi diblokir permanen';
        return false;
      }

      status.value = GpsStatus.locating;
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: highAccuracy ? LocationAccuracy.best : LocationAccuracy.medium,
          timeLimit: _fixTimeout,
        ),
      );

      position.value = fix;
      fixTime.value = DateTime.now();
      status.value = GpsStatus.ready;
      return true;
    } on TimeoutException {
      status.value = GpsStatus.unavailable;
      message.value = 'Sinyal GPS tidak ditemukan';
      return false;
    } catch (e) {
      status.value = GpsStatus.unavailable;
      message.value = 'Gagal membaca GPS';
      debugPrint('LocationService error: $e');
      return false;
    }
  }

  /// Stream live position updates until [stopWatching] is called.
  Future<void> startWatching() async {
    if (_stream != null) return;
    if (status.value == GpsStatus.blocked || status.value == GpsStatus.serviceOff) {
      await ensureFix();
      if (status.value != GpsStatus.ready) return;
    }

    await _stream?.cancel();
    _stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (fix) {
        position.value = fix;
        fixTime.value = DateTime.now();
        status.value = GpsStatus.ready;
        message.value = null;
        _watchdog?.cancel();
      },
      onError: (Object e) {
        debugPrint('GPS stream error: $e');
        message.value = 'Sinyal GPS terputus';
      },
    );
  }

  void stopWatching() {
    _stream?.cancel();
    _stream = null;
    _watchdog?.cancel();
  }

  /// Opens the OS location settings so a blocked user can recover.
  Future<void> openSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Compact coordinate string, or a dash when unknown.
  String get coordinatesLabel {
    final p = position.value;
    if (p == null) return '—';
    return '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
  }

  /// Accuracy + freshness badge, e.g. "±8 m · 12 dtk lalu".
  String get accuracyLabel {
    final p = position.value;
    if (p == null) return 'Menunggu sinyal';
    final accuracyM = p.accuracy.isFinite ? p.accuracy.round() : 0;
    return '±${accuracyM < 1000 ? '$accuracyM m' : '${(accuracyM / 1000).toStringAsFixed(1)} km'}';
  }

  void dispose() {
    _stream?.cancel();
    _watchdog?.cancel();
  }
}