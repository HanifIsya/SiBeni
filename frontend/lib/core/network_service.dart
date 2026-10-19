import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Physical transport currently available to the device.
enum LinkType {
  none,
  wifi,
  cellular,
  ethernet,
  bluetooth,
}

/// Why the app believes it is (or is not) able to reach the server.
enum OnlineState {
  /// No transport at all.
  offline,

  /// Transport exists but the user disabled mobile data usage.
  mobileBlocked,

  /// Transport exists but the server could not be reached.
  unreachable,

  /// Verified round-trip to the API succeeded.
  online,
}

/// ---------------------------------------------------------------------------
/// NetworkService
///
/// Owns the single source of truth for connectivity.
///
/// Unlike a naive `ConnectivityResult` check this service:
///  1. Distinguishes Wi-Fi from cellular so the UI can explain itself.
///  2. Respects a user preference for "mobile data allowed / Wi-Fi only",
///     which is essential in a mine where LTE is often the only link.
///  3. Probes the real backend endpoint instead of assuming a transport means
///     the internet works (captive portals, dead uplink, roaming, etc.).
/// ---------------------------------------------------------------------------
class NetworkService {
  NetworkService._internal();

  static final NetworkService instance = NetworkService._internal();

  static const String _allowMobileKey = 'sibeni_allow_mobile_data';

  final ValueNotifier<LinkType> link = ValueNotifier<LinkType>(LinkType.none);
  final ValueNotifier<OnlineState> state = ValueNotifier<OnlineState>(OnlineState.offline);

  /// Whether cellular data may be used to reach the server.
  final ValueNotifier<bool> allowMobileData = ValueNotifier<bool>(true);

  /// True when the app may talk to the server right now.
  bool get isOnline => state.value == OnlineState.online;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;
  DateTime _lastProbe = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    allowMobileData.value = prefs.getBool(_allowMobileKey) ?? true;

    try {
      _sub = Connectivity().onConnectivityChanged.listen(
            _onConnectivityChanged,
            // A platform error must never take the app down; the HTTP probe
            // is the authoritative check.
            onError: (Object _) => _probeNow(),
          );
      final results = await Connectivity().checkConnectivity();
      _onConnectivityChanged(results, probe: true);
    } catch (_) {
      // The connectivity plugin is not always available (missing permission,
      // unusual ROM, or a stripped build). Losing the transport hint is fine:
      // the round-trip to the server is the only thing that really matters.
      link.value = LinkType.none;
      _probeNow();
    }
  }

  Future<void> setAllowMobileData(bool value) async {
    allowMobileData.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_allowMobileKey, value);
    await refresh(force: true);
  }

  /// Re-evaluate connectivity. Cheap calls are throttled to one probe / 20s.
  Future<void> refresh({bool force = false}) async {
    List<ConnectivityResult> results;
    try {
      results = await Connectivity().checkConnectivity();
    } catch (_) {
      results = const [];
    }
    _onConnectivityChanged(results, force: force);
  }

  /// Run a reachability probe right now, regardless of the transport hint.
  void _probeNow() {
    if (link.value == LinkType.cellular && !allowMobileData.value) {
      state.value = OnlineState.mobileBlocked;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      _lastProbe = DateTime.now();
      final ok = await probeBackend();
      state.value = ok
          ? OnlineState.online
          : (link.value == LinkType.none
              ? OnlineState.offline
              : OnlineState.unreachable);
    });
  }

  void _onConnectivityChanged(List<ConnectivityResult> results, {bool probe = false, bool force = false}) {
    link.value = _resolveLink(results);

    // A blocked cellular link is the one transport decision the user made
    // explicitly, so it is honoured without asking the server.
    if (link.value == LinkType.cellular && !allowMobileData.value) {
      state.value = OnlineState.mobileBlocked;
      return;
    }

    final now = DateTime.now();
    if (!force && !probe && now.difference(_lastProbe) < const Duration(seconds: 20)) {
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      _lastProbe = now;
      final ok = await probeBackend();
      // The HTTP round-trip is the truth. Android does not always report a
      // transport type (it can answer with an empty list), and believing that
      // guess used to keep the app from talking to the server at all.
      state.value = ok
          ? OnlineState.online
          : (link.value == LinkType.none
              ? OnlineState.offline
              : OnlineState.unreachable);
    });
  }
  /// Lightweight reachability check against the health endpoint.
  ///
  /// Having a transport is not the same as having a working uplink — captive
  /// portals and dead site backhaul are common underground. This performs a
  /// real HTTP round-trip so the UI never claims to be online when it is not.
  ///
  /// The request is attempted even when the platform reports no transport at
  /// all: the platform guess is unreliable, the round-trip is not.
  Future<bool> probeBackend({Duration timeout = const Duration(seconds: 8)}) async {
    if (link.value == LinkType.cellular && !allowMobileData.value) return false;

    try {
      final res = await http.get(
        Uri.parse(AppConfig.api('/api/health')),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  LinkType _resolveLink(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return LinkType.wifi;
    if (results.contains(ConnectivityResult.ethernet)) return LinkType.ethernet;
    if (results.contains(ConnectivityResult.bluetooth)) return LinkType.bluetooth;
    if (results.contains(ConnectivityResult.mobile)) return LinkType.cellular;
    if (results.contains(ConnectivityResult.vpn)) return LinkType.wifi;
    return LinkType.none;
  }

  /// Short, human explanation of the current state (used in tooltips/sheets).
  String describe() {
    switch (state.value) {
      case OnlineState.online:
        return link.value == LinkType.cellular ? 'Online • Seluler' : 'Online • Wi-Fi';
      case OnlineState.mobileBlocked:
        return 'Hanya Wi-Fi';
      case OnlineState.unreachable:
        return 'Server tidak terjangkau';
      case OnlineState.offline:
        return 'Offline';
    }
  }

  @visibleForTesting
  static LinkType resolveForTest(List<ConnectivityResult> results) =>
      NetworkService._internal()._resolveLink(results);

  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
  }
}