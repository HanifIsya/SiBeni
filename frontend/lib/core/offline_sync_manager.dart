import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  final ValueNotifier<int> queueCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  static const String _queueKey = 'sibeni_offline_queue';
  String backendApiUrl = 'http://localhost:3000/api/reports';

  Future<void> initialize() async {
    await _updateQueueCount();

    // Listen to network changes
    Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = !results.contains(ConnectivityResult.none);
      isOnline.value = hasConnection;
      if (hasConnection && queueCount.value > 0) {
        syncQueuedReports();
      }
    });

    // Check initial connectivity
    final initialResults = await Connectivity().checkConnectivity();
    isOnline.value = !initialResults.contains(ConnectivityResult.none);
  }

  Future<void> _updateQueueCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queueList = prefs.getStringList(_queueKey) ?? [];
    queueCount.value = queueList.length;
  }

  Future<void> enqueueReport(Map<String, dynamic> reportData) async {
    final prefs = await SharedPreferences.getInstance();
    final queueList = prefs.getStringList(_queueKey) ?? [];
    queueList.add(jsonEncode(reportData));
    await prefs.setStringList(_queueKey, queueList);
    await _updateQueueCount();

    if (isOnline.value) {
      await syncQueuedReports();
    }
  }

  Future<void> syncQueuedReports() async {
    if (isSyncing.value) return;
    final prefs = await SharedPreferences.getInstance();
    final queueList = prefs.getStringList(_queueKey) ?? [];
    if (queueList.isEmpty) return;

    isSyncing.value = true;
    try {
      final reports = queueList.map((e) => jsonDecode(e)).toList();
      final response = await http.post(
        Uri.parse(backendApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(reports),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Successfully synced
        await prefs.remove(_queueKey);
        await _updateQueueCount();
      }
    } catch (e) {
      debugPrint('Sync deferred due to connection: $e');
    } finally {
      isSyncing.value = false;
    }
  }
}
