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

    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    final results = await Connectivity().checkConnectivity();
    _onConnectivityChanged(results, probe: true);
  }

  Future<void> setAllowMobileData(bool value) async {
    allowMobileData.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_allowMobileKey, value);
    await refresh(force: true);
  }

  /// Re-evaluate connectivity. Cheap calls are throttled to one probe / 20s.
  Future<void> refresh({bool force = false}) async {
    final results = await Connectivity().checkConnectivity();
    _onConnectivityChanged(results, force: force);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results, {bool probe = false, bool force = false}) {
    link.value = _resolveLink(results);

    final transportUsable = link.value == LinkType.wifi ||
        link.value == LinkType.ethernet ||
        (link.value == LinkType.cellular && allowMobileData.value);

    if (!transportUsable) {
      state.value = link.value == LinkType.none
          ? OnlineState.offline
          : (link.value == LinkType.cellular && !allowMobileData.value
              ? OnlineState.mobileBlocked
              : OnlineState.offline);
      return;
    }

    // Transport present: confirm the server is actually reachable.
    final now = DateTime.now();
    if (!force && !probe && now.difference(_lastProbe) < const Duration(seconds: 20)) {
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      _lastProbe = now;
      final ok = await probeBackend();
      state.value = ok ? OnlineState.online : OnlineState.unreachable;
    });
  }

  /// Lightweight reachability check against the health endpoint.
  ///
  /// Having a transport is not the same as having a working uplink — captive
  /// portals and dead site backhaul are common underground. This performs a
  /// real HTTP round-trip so the UI never claims to be online when it is not.
  Future<bool> probeBackend({Duration timeout = const Duration(seconds: 6)}) async {
    if (link.value == LinkType.none) return false;
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