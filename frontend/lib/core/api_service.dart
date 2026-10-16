import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = 'https://sibeni-backend.onrender.com';

  // 1. GET EARLY WARNINGS (BMKG & BNPB)
  Future<List<Map<String, dynamic>>> getEarlyWarnings() async {
    const cacheKey = 'cache_early_warnings';
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/bmkg')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['warnings'] != null) {
          final list = List<Map<String, dynamic>>.from(data['warnings']);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, jsonEncode(list));
          return list;
        }
      }
    } catch (e) {
      debugPrint('Error fetching early warnings, using cache: $e');
    }

    // Fallback to cache
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(cached));
    }
    return [];
  }

  // 2. GET MINING ZONES (7 ZONES)
  Future<List<Map<String, dynamic>>> getMiningZones() async {
    const cacheKey = 'cache_mining_zones';
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/zones')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['zones'] != null) {
          final list = List<Map<String, dynamic>>.from(data['zones']);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cacheKey, jsonEncode(list));
          return list;
        }
      }
    } catch (e) {
      debugPrint('Error fetching zones, using cache: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(cached));
    }
    return [];
  }

  // 3. GET KPI & ESG METRICS
  Future<Map<String, dynamic>?> getKpis() async {
    const cacheKey = 'cache_kpis';
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/kpi')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(data));
        return data;
      }
    } catch (e) {
      debugPrint('Error fetching KPIs, using cache: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      return jsonDecode(cached);
    }
    return null;
  }

  // 4. GET INSPECTIONS & CORRECTIVE ACTIONS
  Future<Map<String, dynamic>> getInspectionsAndCorrectiveActions() async {
    const cacheKey = 'cache_inspections';
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/inspections')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(data));
        return data;
      }
    } catch (e) {
      debugPrint('Error fetching inspections, using cache: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      return jsonDecode(cached);
    }
    return {'corrective_actions': [], 'inspections': []};
  }

  // 5. UPDATE CORRECTIVE ACTION STAGE
  Future<bool> advanceCorrectiveActionStage(String caId, int nextStage, String note) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/api/inspections'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': caId,
          'stage_number': nextStage,
          'status': nextStage >= 6 ? 'completed' : 'in_progress',
          'hse_verification_notes': note,
        }),
      ).timeout(const Duration(seconds: 8));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating corrective action: $e');
      return false;
    }
  }

  // 6. TRIGGER EMERGENCY SOS
  Future<Map<String, dynamic>?> triggerSos({
    required String workerId,
    required String workerName,
    required String zoneName,
    required String emergencyType,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/emergency'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'worker_id': workerId,
          'worker_name': workerName,
          'zone_name': zoneName,
          'emergency_type': emergencyType,
          'gps_latitude': latitude,
          'gps_longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error broadcasting SOS to server: $e');
    }
    return null;
  }
}
