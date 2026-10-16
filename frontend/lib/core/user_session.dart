import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppRole {
  worker,      // Pekerja Lapangan & Operator Alat Berat
  supervisor,  // Pengawas Lapangan / Supervisor
  hse,         // Tim Keselamatan & Kesehatan Kerja (HSE Officer)
  management,  // Manajemen Eksekutif & General Manager
}

class UserProfile {
  final String employeeId;
  final String fullName;
  final AppRole role;
  final String workZone;
  final String phone;

  UserProfile({
    required this.employeeId,
    required this.fullName,
    required this.role,
    required this.workZone,
    required this.phone,
  });

  String get roleDisplayName {
    switch (role) {
      case AppRole.worker:
        return 'Pekerja Lapangan / Operator';
      case AppRole.supervisor:
        return 'Supervisor Lapangan';
      case AppRole.hse:
        return 'Tim HSE & Inspektur';
      case AppRole.management:
        return 'Manajemen Eksekutif';
    }
  }

  Map<String, dynamic> toJson() => {
    'employeeId': employeeId,
    'fullName': fullName,
    'role': role.name,
    'workZone': workZone,
    'phone': phone,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    employeeId: json['employeeId'] ?? 'EMP-001',
    fullName: json['fullName'] ?? 'Pekerja Tambang',
    role: AppRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => AppRole.worker,
    ),
    workZone: json['workZone'] ?? 'Pit Utama',
    phone: json['phone'] ?? '+62 812-3456-7890',
  );
}

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  final ValueNotifier<UserProfile?> currentUser = ValueNotifier<UserProfile?>(null);
  static const String _userKey = 'sibeni_current_user_profile';

  // 4 Preset Demo Personas for instant testing
  static final List<UserProfile> demoPersonas = [
    UserProfile(
      employeeId: 'OP-104',
      fullName: 'Budi Santoso',
      role: AppRole.worker,
      workZone: 'Pit Utama (Area Penambangan Aktif)',
      phone: '+62 812-3456-7890',
    ),
    UserProfile(
      employeeId: 'SP-202',
      fullName: 'Hendro Wijaya',
      role: AppRole.supervisor,
      workZone: 'Jalan Angkut (Haul Road KM 0-15)',
      phone: '+62 813-9876-5432',
    ),
    UserProfile(
      employeeId: 'HSE-01',
      fullName: 'Dr. Citra Utami',
      role: AppRole.hse,
      workZone: 'Fasilitas Pendukung (Klinik & HSE Site)',
      phone: '+62 811-2233-4455',
    ),
    UserProfile(
      employeeId: 'MGT-99',
      fullName: 'Ir. Bambang Suryo',
      role: AppRole.management,
      workZone: 'Fasilitas Pendukung (Site Office)',
      phone: '+62 819-0011-2233',
    ),
  ];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_userKey);
    if (rawUser != null) {
      try {
        currentUser.value = UserProfile.fromJson(jsonDecode(rawUser));
      } catch (_) {
        currentUser.value = demoPersonas[0];
      }
    } else {
      // Default to Worker for immediate preview
      currentUser.value = demoPersonas[0];
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
