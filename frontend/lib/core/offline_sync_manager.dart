import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'app_config.dart';
import 'network_service.dart';

/// ---------------------------------------------------------------------------
/// OfflineSyncManager
///
/// Durable, zero-loss outbox for hazard / near-miss reports.
///
/// Reports are always written to disk first, then flushed. That ordering is
/// what guarantees nothing is lost when a worker loses signal mid-submission.
/// The flush gate is [NetworkService], which already understands the user's
/// Wi-Fi-only vs cellular-allowed preference.
/// ---------------------------------------------------------------------------
class OfflineSyncManager {
  OfflineSyncManager._internal();

  static final OfflineSyncManager instance = OfflineSyncManager._internal();

  final ValueNotifier<int> queueCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  static const String _queueKey = 'sibeni_offline_queue';
  static const int _maxAttempts = 5;

  void initialize() {
    NetworkService.instance.state.addListener(_onNetworkChanged);
  }

  void _onNetworkChanged() {
    if (NetworkService.instance.isOnline) {
      unawaited(syncQueuedReports());
    }
  }

  Future<void> refreshQueueCount() async {
    queueCount.value = (await _readQueue()).length;
  }

  /// Persist a report and attempt immediate delivery.
  /// Returns `true` when it reached the server during this call.
  ///
  /// The interactive flush is deliberately short (one retry) so the submit
  /// button never appears hung while a flaky link is being probed. The
  /// background flush retries harder and runs when connectivity returns.
  Future<bool> enqueueReport(Map<String, dynamic> reportData) async {
    final queue = await _readQueue();
    queue.add(jsonEncode(reportData));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_queueKey, queue);
    queueCount.value = queue.length;

    await syncQueuedReports(attempts: 2);
    return queueCount.value == 0;
  }

  /// Flush the outbox. Returns `true` when the queue is empty afterwards.
  Future<bool> syncQueuedReports({int attempts = _maxAttempts}) async {
    if (isSyncing.value) return queueCount.value == 0;
    if (!NetworkService.instance.isOnline) return false;

    final queue = await _readQueue();
    if (queue.isEmpty) {
      queueCount.value = 0;
      return true;
    }

    isSyncing.value = true;
    lastError.value = null;
    try {
      final pending = queue
          .map((e) => jsonDecode(e))
          .whereType<Map<String, dynamic>>()
          .toList();

      final accepted = <Map<String, dynamic>>[];
      for (final report in pending) {
        final ok = await _deliver(report, attempts);
        if (ok) {
          accepted.add(report);
        } else {
          // Network flaked on this one item: stop, keep the rest queued.
          break;
        }
      }

      if (accepted.isNotEmpty) {
        final remaining = queue
            .where((raw) {
              final decoded = jsonDecode(raw) as Map<String, dynamic>;
              return !accepted.any((a) => a['local_id'] == decoded['local_id']);
            })
            .toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_queueKey, remaining);
        queueCount.value = remaining.length;
        lastSyncedAt.value = DateTime.now();
      }
      return queueCount.value == 0;
    } catch (e) {
      lastError.value = 'Sinkronisasi tertunda';
      debugPrint('syncQueuedReports failed: $e');
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  Future<bool> _deliver(Map<String, dynamic> report, int attempts) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final ok = await ApiService.instance
          .queueReport(report)
          .timeout(AppConfig.shortTimeout, onTimeout: () => false);
      if (ok) return true;
      if (!NetworkService.instance.isOnline) return false;
      if (attempt < attempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    return false;
  }

  Future<List<String>> _readQueue() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_queueKey) ?? [];
  }
}