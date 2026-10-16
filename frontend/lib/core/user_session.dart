import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppRole {
  worker,
  supervisor,
  hse,
  management,
}

/// The signed-in worker as the UI understands them.
class UserProfile {
  const UserProfile({
    required this.employeeId,
    required this.fullName,
    required this.role,
    required this.workZone,
    this.phone,
  });

  final String employeeId;
  final String fullName;
  final AppRole role;
  final String workZone;
  final String? phone;

  String get roleDisplayName {
    switch (role) {
      case AppRole.worker:
        return 'Pekerja';
      case AppRole.supervisor:
        return 'Supervisor';
      case AppRole.hse:
        return 'HSE';
      case AppRole.management:
        return 'Manajemen';
    }
  }

  String get roleLongName {
    switch (role) {
      case AppRole.worker:
        return 'Pekerja Lapangan / Operator';
      case AppRole.supervisor:
        return 'Supervisor Lapangan';
      case AppRole.hse:
        return 'Tim Keselamatan & Kesehatan Kerja';
      case AppRole.management:
        return 'Manajemen Eksekutif';
    }
  }

  String get zoneShortName => workZone.split(' (').first;

  bool get canVerify => role == AppRole.supervisor || role == AppRole.hse || role == AppRole.management;

  bool get seesInsights => role == AppRole.hse || role == AppRole.management;

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'fullName': fullName,
        'role': role.name,
        'workZone': workZone,
        'phone': phone,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        employeeId: json['employeeId'] as String? ?? '—',
        fullName: json['fullName'] as String? ?? 'Karyawan Tambang',
        role: AppRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => AppRole.worker,
        ),
        workZone: json['workZone'] as String? ?? 'Pit Utama',
        phone: json['phone'] as String?,
      );
}

/// Locally cached identity, rehydrated from Supabase Auth on launch.
class UserSession {
  UserSession._internal();

  static final UserSession instance = UserSession._internal();

  final ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(null);

  static const String _userKey = 'sibeni_current_user_profile';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) {
      currentUser.value = null;
      return;
    }
    try {
      currentUser.value = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      currentUser.value = null;
    }
  }

  Future<void> login(UserProfile profile) async {
    currentUser.value = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(profile.toJson()));
  }

  Future<void> logout() async {
    currentUser.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}