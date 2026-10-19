import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'auth_service.dart';
import 'network_service.dart';

/// Result of a mutating call, carrying a message the UI can show verbatim.
class ApiResult {
  const ApiResult.ok(this.message, {this.data}) : error = null;
  const ApiResult.fail(this.error) : message = null, data = null;

  final String? message;
  final String? error;
  final Map<String, dynamic>? data;

  bool get isSuccess => error == null;
}

/// Result of a read, including *why* it may be empty.
///
/// A silent empty list is indistinguishable from "there is nothing to show".
/// That ambiguity is what made a failed request look like an empty screen, so
/// every read now reports whether it came from the server, from the offline
/// cache, or not at all.
class ApiRead {
  const ApiRead({this.data, this.fromCache = false, this.error});

  final Map<String, dynamic>? data;

  /// True when the payload was served from the on-device cache.
  final bool fromCache;

  /// Human-readable reason when the server could not be reached.
  final String? error;

  bool get hasData => data != null;
  bool get failed => error != null;
}

/// ---------------------------------------------------------------------------
/// ApiService
///
/// Thin, cached gateway to the SI BENI B2B API.
///
/// Every read follows the same contract:
///   transport available → fetch → validate → persist to cache → return
///   otherwise            → return last known good cache
///
/// Every mutation sends the caller's Supabase JWT. That is not optional: the
/// API forwards it to Postgres so Row Level Security can evaluate the role
/// matrix. An anonymous write would be rejected no matter what the UI shows.
///
/// Nothing here invents data: an empty result means "no data yet", which the UI
/// renders as an explicit empty state rather than fabricated figures.
/// ---------------------------------------------------------------------------
class ApiService {
  ApiService._internal();

  static final ApiService instance = ApiService._internal();

  // ------------------------------------------------------------------ cache
  static const String _kWarnings = 'cache_early_warnings';
  static const String _kZones = 'cache_mining_zones';
  static const String _kKpis = 'cache_kpis';
  static const String _kInspections = 'cache_inspections';
  static const String _kReports = 'cache_reports';
  static const String _kNotifications = 'cache_notifications';
  static const String _kCoordination = 'cache_coordination';

  /// Test seam.
  ///
  /// When set, reads are served by this callback instead of the network. The
  /// widget tests use it to render screens with **real production payloads**,
  /// which is how a stage-6 ticket — the payload that used to blank the HSE
  /// inspection screen — is now covered by an automated test.
  @visibleForTesting
  static Map<String, dynamic>? Function(String url)? readOverride;

  // ---------------------------------------------------------------- headers
  /// Authorization for the current session. The API needs this to evaluate the
  /// role matrix server-side.
  Map<String, String> get _headers {
    final token = AuthService.instance.accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// True when the user has explicitly blocked mobile data.
  ///
  /// This is the only transport state the app may act on without asking the
  /// server. A platform "no network" guess is not enough: Android can report
  /// an empty connectivity list on a perfectly healthy link, and trusting that
  /// guess used to keep the app from ever calling the API.
  bool get _mobileDataBlocked {
    final link = NetworkService.instance.link.value;
    return link == LinkType.cellular && !NetworkService.instance.allowMobileData.value;
  }

  // ------------------------------------------------------------------ reads
  Future<List<Map<String, dynamic>>> getEarlyWarnings({bool includeInactive = false}) async {
    final read = await _getJson(
      AppConfig.api(includeInactive ? '/api/bmkg?all=1' : '/api/bmkg'),
      cacheKey: _kWarnings,
      timeout: AppConfig.shortTimeout,
    );
    final warnings = read.data?['warnings'];
    if (warnings is List) return _mapList(warnings);
    return _readCacheList(_kWarnings);
  }

  Future<List<Map<String, dynamic>>> getMiningZones() async {
    final read = await _getJson(
      AppConfig.api('/api/zones'),
      cacheKey: _kZones,
      timeout: AppConfig.shortTimeout,
    );
    final zones = read.data?['zones'];
    if (zones is List) return _mapList(zones);
    return _readCacheList(_kZones);
  }

  Future<Map<String, dynamic>?> getKpis() async {
    final read = await _getJson(
      AppConfig.api('/api/kpi'),
      cacheKey: _kKpis,
      timeout: AppConfig.shortTimeout,
    );
    return read.data;
  }

  /// Inspection register plus corrective-action tickets.
  ///
  /// The status-aware variant exists because an empty inspection screen is
  /// ambiguous: it can mean "no findings" or "the request never reached the
  /// server". The screen needs to tell those apart.
  Future<ApiRead> getInspectionsRead() async {
    return _getJson(
      AppConfig.api('/api/inspections'),
      cacheKey: _kInspections,
      timeout: AppConfig.longTimeout,
    );
  }

  Future<Map<String, dynamic>> getInspections() async {
    final read = await getInspectionsRead();
    return read.data ??
        const {'corrective_actions': <dynamic>[], 'inspections': <dynamic>[]};
  }

  /// Create and submit a new periodic K3 field inspection.
  Future<ApiResult> createInspection({
    required String category,
    required String zoneName,
    String? title,
    String? notes,
    required int passedItems,
    required int failedItems,
    required List<Map<String, dynamic>> findings,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(AppConfig.api('/api/inspections')),
            headers: _headers,
            body: jsonEncode({
              'inspection_category': category,
              'zone_name': zoneName,
              if (title != null && title.isNotEmpty) 'title': title,
              if (notes != null && notes.isNotEmpty) 'notes': notes,
              'passed_items': passedItems,
              'failed_items': failedItems,
              'findings': findings,
            }),
          )
          .timeout(AppConfig.longTimeout);

      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _invalidate(_kInspections);
        return ApiResult.ok(
          body?['message']?.toString() ?? 'Inspeksi K3 berhasil disimpan.',
          data: body,
        );
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  /// The hazard report register, scoped by RLS to what this role may see.
  Future<ApiRead> getReportsRead({String? status, String? zone}) async {
    final query = <String>[
      if (status != null) 'status=$status',
      if (zone != null) 'zone=${Uri.encodeQueryComponent(zone)}',
    ].join('&');

    return _getJson(
      AppConfig.api('/api/reports${query.isEmpty ? '' : '?$query'}'),
      cacheKey: _kReports,
      timeout: AppConfig.longTimeout,
    );
  }

  Future<({List<Map<String, dynamic>> reports, Map<String, dynamic> counts})>
      getReports({String? status, String? zone}) async {
    final read = await getReportsRead(status: status, zone: zone);

    final data = read.data;
    if (data == null) {
      return (reports: await _readCacheList(_kReports), counts: const <String, dynamic>{});
    }
    final countsRaw = data['counts'];
    return (
      reports: _mapList(data['reports']),
      counts: countsRaw is Map
          ? countsRaw.map((k, v) => MapEntry(k.toString(), v))
          : const <String, dynamic>{},
    );
  }

  /// Personal notification inbox plus the unread badge count.
  Future<({List<Map<String, dynamic>> notifications, int unreadCount})>
      getNotifications({int limit = 60}) async {
    final read = await _getJson(
      AppConfig.api('/api/notifications?limit=$limit'),
      cacheKey: _kNotifications,
      timeout: AppConfig.shortTimeout,
    );
    final data = read.data;
    if (data == null) {
      return (notifications: <Map<String, dynamic>>[], unreadCount: 0);
    }
    return (
      notifications: _mapList(data['notifications']),
      unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ApiResult> markNotificationsRead({
    String? id,
    List<String>? ids,
    bool markAll = false,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse(AppConfig.api('/api/notifications')),
            headers: _headers,
            body: jsonEncode({
              if (markAll) 'mark_all': true,
              'id': ?id,
              if (ids != null && ids.isNotEmpty) 'ids': ids,
            }),
          )
          .timeout(AppConfig.shortTimeout);
      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _invalidate(_kNotifications);
        return ApiResult.ok(
          body?['message']?.toString() ?? 'Notifikasi ditandai sudah dibaca.',
          data: body,
        );
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  /// Coordination channel between Supervisor, HSE and Management.
  Future<ApiRead> getCoordinationRead({String? status}) async {
    final query = status == null ? '' : '?status=$status';
    return _getJson(
      AppConfig.api('/api/coordination$query'),
      cacheKey: _kCoordination,
      timeout: AppConfig.longTimeout,
    );
  }

  Future<({List<Map<String, dynamic>> requests, Map<String, dynamic> counts})>
      getCoordination({String? status}) async {
    final read = await getCoordinationRead(status: status);
    final data = read.data;
    if (data == null) {
      return (
        requests: await _readCacheList(_kCoordination),
        counts: const <String, dynamic>{},
      );
    }
    final countsRaw = data['counts'];
    return (
      requests: _mapList(data['requests']),
      counts: countsRaw is Map
          ? countsRaw.map((k, v) => MapEntry(k.toString(), v))
          : const <String, dynamic>{},
    );
  }

  Future<ApiResult> sendCoordination({
    required String toRole,
    required String subject,
    required String message,
    required String priority,
    String? zoneName,
    String? relatedActionId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(AppConfig.api('/api/coordination')),
            headers: _headers,
            body: jsonEncode({
              'to_role': toRole,
              'subject': subject,
              'message': message,
              'priority': priority,
              if (zoneName != null && zoneName.isNotEmpty) 'zone_name': zoneName,
              'related_action_id': ?relatedActionId,
            }),
          )
          .timeout(AppConfig.shortTimeout);
      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _invalidate(_kCoordination);
        return ApiResult.ok(
          body?['message']?.toString() ?? 'Koordinasi terkirim.',
          data: body,
        );
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  Future<ApiResult> respondCoordination({
    required String id,
    required String response,
    String status = 'RESOLVED',
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse(AppConfig.api('/api/coordination')),
            headers: _headers,
            body: jsonEncode({
              'id': id,
              'response': response,
              'status': status,
            }),
          )
          .timeout(AppConfig.shortTimeout);
      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _invalidate(_kCoordination);
        return ApiResult.ok(
          body?['message']?.toString() ?? 'Koordinasi diperbarui.',
          data: body,
        );
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  // ----------------------------------------------------------------- writes
  /// Advance a corrective action one stage.
  ///
  /// Returns a failure with an actionable message rather than a bare boolean,
  /// because the previous boolean version made the app claim an offline save
  /// that never happened.
  Future<ApiResult> advanceCorrectiveActionStage({
    required String id,
    required int nextStage,
    required String note,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse(AppConfig.api('/api/inspections')),
            headers: _headers,
            body: jsonEncode({
              'id': id,
              'stage_number': nextStage,
              'hse_verification_notes': note,
            }),
          )
          .timeout(AppConfig.shortTimeout);

      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final actualStage = body?['action']?['stage_number'];
        await _invalidate(_kInspections);
        return ApiResult.ok(
          actualStage != null
              ? 'Tindakan korektif dimajukan ke tahap $actualStage.'
              : 'Tindakan korektif diperbarui.',
          data: body,
        );
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  /// Management decision on a corrective action: approve, reject, or evaluate.
  Future<ApiResult> decideCorrectiveAction({
    required String id,
    required String decision,
    String? notes,
    int? effectivenessRating,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse(AppConfig.api('/api/inspections')),
            headers: _headers,
            body: jsonEncode({
              'id': id,
              'management_decision': decision,
              if (notes != null && notes.trim().isNotEmpty) 'management_notes': notes.trim(),
              'effectiveness_rating': ?effectivenessRating,
            }),
          )
          .timeout(AppConfig.shortTimeout);

      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _invalidate(_kInspections);
        await _invalidate(_kReports);
        return ApiResult.ok(
          body?['message']?.toString() ?? 'Keputusan Manajemen tersimpan.',
          data: body,
        );
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  /// HSE review decision on a filed report. When [action] is present the report
  /// moves to PENDING_APPROVAL and the corrective action is stored atomically.
  Future<ApiResult> reviewReport({
    required String id,
    required String status,
    String? notes,
    Map<String, dynamic>? action,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse(AppConfig.api('/api/reports')),
            headers: _headers,
            body: jsonEncode({
              'id': id,
              'hse_status': status,
              if (notes != null && notes.trim().isNotEmpty) 'hse_notes': notes.trim(),
              'action': ?action,
            }),
          )
          .timeout(AppConfig.shortTimeout);

      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _invalidate(_kReports);
        return ApiResult.ok(
          body?['message']?.toString() ?? 'Status laporan diperbarui.',
          data: body,
        );
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  Future<ApiResult> createWarning(Map<String, dynamic> warning) async {
    try {
      final res = await http
          .post(Uri.parse(AppConfig.api('/api/bmkg')), headers: _headers, body: jsonEncode(warning))
          .timeout(AppConfig.shortTimeout);
      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _invalidate(_kWarnings);
        return ApiResult.ok('Peringatan diterbitkan.', data: body);
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  Future<ApiResult> updateWarning(String id, Map<String, dynamic> changes) async {
    try {
      final res = await http
          .patch(
            Uri.parse(AppConfig.api('/api/bmkg')),
            headers: _headers,
            body: jsonEncode({'id': id, ...changes}),
          )
          .timeout(AppConfig.shortTimeout);
      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _invalidate(_kWarnings);
        return ApiResult.ok('Peringatan diperbarui.', data: body);
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  Future<ApiResult> deactivateWarning(String id) async {
    try {
      final res = await http
          .delete(
            Uri.parse(AppConfig.api('/api/bmkg?id=${Uri.encodeQueryComponent(id)}')),
            headers: _headers,
          )
          .timeout(AppConfig.shortTimeout);
      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _invalidate(_kWarnings);
        return ApiResult.ok('Peringatan dinonaktifkan.', data: body);
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  /// Upsert one reporting period of K3 / ESG metrics.
  Future<ApiResult> saveKpis(Map<String, dynamic> metrics) async {
    try {
      final res = await http
          .patch(
            Uri.parse(AppConfig.api('/api/kpi')),
            headers: _headers,
            body: jsonEncode(metrics),
          )
          .timeout(AppConfig.shortTimeout);
      final body = _decode(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _invalidate(_kKpis);
        return ApiResult.ok('Metrik tersimpan.', data: body);
      }
      return ApiResult.fail(_messageFor(res.statusCode, body));
    } catch (e) {
      return ApiResult.fail(_messageForTransport(e));
    }
  }

  /// Broadcast an SOS. `false` means it must be queued, never silently ignored.
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
            headers: _headers,
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

  /// Submits a single queued report. Returns `true` when accepted (2xx).
  Future<bool> queueReport(Map<String, dynamic> report) async {
    if (_mobileDataBlocked) return false;
    try {
      final res = await http
          .post(
            Uri.parse(AppConfig.api('/api/reports')),
            headers: _headers,
            body: jsonEncode([report]),
          )
          .timeout(AppConfig.longTimeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('queueReport failed: $e');
      return false;
    }
  }

  /// Health probe used by the network layer to validate the uplink.
  Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse(AppConfig.api('/api/health')), headers: _headers)
          .timeout(const Duration(seconds: 6));
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // ----------------------------------------------------------------- plumbing
  Map<String, dynamic>? _decode(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Turn an HTTP failure into something a worker can act on.
  String _messageFor(int status, Map<String, dynamic>? body) {
    final serverMessage = body?['error']?.toString();
    if (serverMessage != null && serverMessage.isNotEmpty && serverMessage.length < 160) {
      return serverMessage;
    }
    switch (status) {
      case 400:
        return 'Data yang dikirim tidak lengkap.';
      case 401:
        return 'Sesi berakhir. Silakan masuk kembali.';
      case 403:
        return 'Peran Anda tidak memiliki izin untuk tindakan ini.';
      case 404:
        return 'Data tidak ditemukan.';
      case 409:
        return 'Perubahan sudah diterapkan oleh pengguna lain.';
      default:
        return 'Server tidak merespons (kode $status).';
    }
  }

  String _messageForTransport(Object error) {
    final raw = error.toString();
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('TimeoutException')) {
      return 'Tidak ada koneksi ke server.';
    }
    return 'Gagal menghubungi server.';
  }

  Future<void> _invalidate(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scoped(cacheKey));
  }

  /// Cache keys are namespaced per account.
  ///
  /// The offline cache used to be shared by every role, so a worker who
  /// opened the app after an HSE session could read HSE's cached register.
  /// Scoping the key by user id keeps one role's data out of another role's
  /// pocket, and stops a stale payload from being served to the wrong person.
  String _scoped(String cacheKey) {
    String? uid;
    try {
      uid = AuthService.instance.userId;
    } catch (_) {
      uid = null;
    }
    return uid == null ? '$cacheKey::guest' : '$cacheKey::$uid';
  }

  /// Fetch a JSON payload, with an honest outcome.
  ///
  /// Behaviour:
  ///  - one automatic retry, because the Render free tier can cold-start for
  ///    longer than a single request window;
  ///  - the cache is only used as a fallback, never as a silent substitute for
  ///    a failed request;
  ///  - the caller learns *why* there is no data.
  Future<ApiRead> _getJson(
    String url, {
    required String cacheKey,
    required Duration timeout,
  }) async {
    final key = _scoped(cacheKey);

    final override = readOverride;
    if (override != null) {
      final data = override(url);
      if (data == null) {
        return const ApiRead(error: 'Tidak ada data untuk pengujian.');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
      return ApiRead(data: data);
    }

    if (_mobileDataBlocked) {
      final cached = await _readCache(key);
      return ApiRead(
        data: cached,
        fromCache: cached != null,
        error: cached == null
            ? 'Data seluler sedang diblokir. Aktifkan data seluler di menu Pengaturan.'
            : null,
      );
    }

    String? lastError;
    var retryable = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .get(Uri.parse(url), headers: _headers)
            .timeout(timeout);
        if (res.statusCode == 200) {
          final decoded = _decode(res);
          if (decoded != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(key, jsonEncode(decoded));
            return ApiRead(data: decoded);
          }
          lastError = 'Respons server tidak dapat dibaca.';
          retryable = true;
        } else if (res.statusCode == 401) {
          lastError = 'Sesi Anda berakhir. Silakan masuk kembali.';
          retryable = false;
        } else if (res.statusCode >= 500) {
          lastError = 'Server sedang bermasalah (${res.statusCode}).';
          retryable = true;
        } else {
          // A client error will not fix itself.
          lastError = 'Permintaan ditolak server (${res.statusCode}).';
          retryable = false;
        }
      } catch (e) {
        lastError = _messageForTransport(e);
        retryable = true;
      }
      if (!retryable || attempt == 1) break;
      // A cold start or a flaky site link is usually a one-off; give the
      // server a second chance before telling the user it failed.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }

    final cached = await _readCache(key);
    return ApiRead(
      data: cached,
      fromCache: cached != null,
      error: lastError,
    );
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
      final raw = prefs.getString(_scoped(key));
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