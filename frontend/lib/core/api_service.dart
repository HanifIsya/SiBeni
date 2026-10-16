import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'network_service.dart';

/// Thin, cached gateway to the SI BENI B2B API.
///
/// Every read follows the same contract:
///   network available → fetch → validate → persist to cache → return
///   network unavailable / failure → return last known good cache
///
/// Nothing here invents data: an empty result means "no data yet", which the
/// UI renders as an explicit empty state rather than fabricated figures.
class ApiService {
  ApiService._internal();

  static final ApiService instance = ApiService._internal();

  // ------------------------------------------------------------------ cache
  static const String _kWarnings = 'cache_early_warnings';
  static const String _kZones = 'cache_mining_zones';
  static const String _kKpis = 'cache_kpis';
  static const String _kInspections = 'cache_inspections';

  // ------------------------------------------------------------- endpoints
  Future<List<Map<String, dynamic>>> getEarlyWarnings() async {
    final data = await _getJson(
      AppConfig.api('/api/bmkg'),
      cacheKey: _kWarnings,
      timeout: AppConfig.shortTimeout,
    );
    final warnings = data?['warnings'];
    if (warnings is List) return _mapList(warnings);
    return _readCacheList(_kWarnings);
  }

  Future<List<Map<String, dynamic>>> getMiningZones() async {
    final data = await _getJson(
      AppConfig.api('/api/zones'),
      cacheKey: _kZones,
      timeout: AppConfig.shortTimeout,
    );
    final zones = data?['zones'];
    if (zones is List) return _mapList(zones);
    return _readCacheList(_kZones);
  }

  Future<Map<String, dynamic>?> getKpis() async {
    return _getJson(
      AppConfig.api('/api/kpi'),
      cacheKey: _kKpis,
      timeout: AppConfig.shortTimeout,
    );
  }

  Future<Map<String, dynamic>> getInspections() async {
    return await _getJson(
          AppConfig.api('/api/inspections'),
          cacheKey: _kInspections,
          timeout: AppConfig.longTimeout,
        ) ??
        const {'corrective_actions': <dynamic>[], 'inspections': <dynamic>[]};
  }

  Future<bool> advanceCorrectiveActionStage({
    required String id,
    required int nextStage,
    required String note,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse(AppConfig.api('/api/inspections')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'stage_number': nextStage,
              'status': nextStage >= 6 ? 'completed' : 'in_progress',
              'hse_verification_notes': note,
            }),
          )
          .timeout(AppConfig.shortTimeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('advanceCorrectiveActionStage failed: $e');
      return false;
    }
  }

  /// Broadcasts an SOS. Returns `true` when the control room received it.
  Future<bool> broadcastSos({
    required String workerId,
    required String workerName,
    required String zoneName,
    required String emergencyType,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(AppConfig.api('/api/emergency')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'worker_id': workerId,
              'worker_name': workerName,
              'zone_name': zoneName,
              'emergency_type': emergencyType,
              'gps_latitude': latitude,
              'gps_longitude': longitude,
            }),
          )
          .timeout(AppConfig.shortTimeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('broadcastSos failed: $e');
      return false;
    }
  }

  /// Health probe used by the network layer to validate the uplink.
  Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse(AppConfig.api('/api/health')))
          .timeout(const Duration(seconds: 6));
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  /// Submits a single queued report. Returns `true` when accepted (2xx).
  Future<bool> queueReport(Map<String, dynamic> report) async {
    if (NetworkService.instance.link.value == LinkType.none) return false;
    if (NetworkService.instance.link.value == LinkType.cellular &&
        !NetworkService.instance.allowMobileData.value) {
      return false;
    }
    try {
      final res = await http
          .post(
            Uri.parse(AppConfig.api('/api/reports')),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode([report]),
          )
          .timeout(AppConfig.longTimeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('queueReport failed: $e');
      return false;
    }
  }

  // ----------------------------------------------------------------- plumbing
  Future<Map<String, dynamic>?> _getJson(
    String url, {
    required String cacheKey,
    required Duration timeout,
  }) async {
    // Short-circuit only when there is genuinely no transport. A transport that
    // has not been probed yet still deserves an attempt before falling back.
    if (NetworkService.instance.link.value == LinkType.none) {
      return _readCache(cacheKey);
    }
    if (NetworkService.instance.link.value == LinkType.cellular &&
        !NetworkService.instance.allowMobileData.value) {
      return _readCache(cacheKey);
    }
    try {
      final res = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, jsonEncode(decoded));
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('GET $url failed, serving cache: $e');
    }
    return _readCache(cacheKey);
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _readCacheList(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return [];
      return _mapList(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}