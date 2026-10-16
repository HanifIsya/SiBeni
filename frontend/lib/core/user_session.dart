import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The four operational roles.
///
/// Each role owns a distinct slice of the safety system. The matrix below is the
/// single source of truth in the client; the identical matrix is enforced again
/// in Postgres Row Level Security, so a tampered client gains nothing.
enum AppRole {
  /// Filed reports and SOS only. Cannot see the site register or K3 records.
  worker,

  /// Runs the field: verifies corrective actions, reads the Insight figures.
  supervisor,

  /// Owns hazard review: reads every filed report and decides its status.
  hse,

  /// Owns the official K3 / ESG figures and oversees the whole system.
  management,
}

/// Fine-grained capabilities, so screens ask "can I?" rather than comparing roles.
extension AppRoleCapabilities on AppRole {
  bool get canFileReport => true;
  bool get canTriggerSos => true;

  /// Corrective-action verification (M-04).
  bool get canVerifyTickets =>
      this == AppRole.supervisor || this == AppRole.hse || this == AppRole.management;

  /// The hazard report register (M-06).
  bool get canReviewReports => this == AppRole.hse || this == AppRole.management;

  /// Publishing and amending early warnings.
  bool get canManageWarnings => this == AppRole.hse || this == AppRole.management;

  /// Read the K3 / ESG figures.
  bool get canViewInsight =>
      this == AppRole.supervisor || this == AppRole.hse || this == AppRole.management;

  /// Write the official K3 / ESG figures. Management owns the record.
  bool get canEditInsight => this == AppRole.management;
}

/// The signed-in worker as the UI understands them.
class UserProfile {
  const UserProfile({
    required this.employeeId,
    required this.fullName,
    required this.role,
    required this.workZone,
    this.phone,
    this.avatarUrl,
    this.authId,
  });

  final String employeeId;
  final String fullName;
  final AppRole role;
  final String workZone;
  final String? phone;
  final String? avatarUrl;

  /// Supabase auth UUID — the only valid value for reporter/worker foreign keys.
  final String? authId;

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

  /// Plain-language explanation of what this role can and cannot do, shown in
  /// the account sheet so the permission model is never a mystery.
  String get roleScope {
    switch (role) {
      case AppRole.worker:
        return 'Melaporkan bahaya dan mengaktifkan alarm darurat.';
      case AppRole.supervisor:
        return 'Memverifikasi tindakan korektif dan membaca angka K3.';
      case AppRole.hse:
        return 'Meninjau laporan bahaya dan mengelola peringatan dini.';
      case AppRole.management:
        return 'Meninjau laporan dan mengisi angka K3 serta ESG.';
    }
  }

  String get zoneShortName => workZone.split(' (').first;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'fullName': fullName,
        'role': role.name,
        'workZone': workZone,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'authId': authId,
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
        avatarUrl: json['avatarUrl'] as String?,
        authId: json['authId'] as String?,
      );

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? workZone,
  }) {
    return UserProfile(
      employeeId: employeeId,
      fullName: fullName ?? this.fullName,
      role: role,
      workZone: workZone ?? this.workZone,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authId: authId,
    );
  }
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