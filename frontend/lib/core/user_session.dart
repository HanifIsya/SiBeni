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

  /// Runs the field: inspects, coordinates, executes approved actions, reads
  /// the K3 / energy / emissions dashboard.
  supervisor,

  /// Receives and verifies reports, then writes the corrective action that
  /// Management will approve. HSE does not file reports.
  hse,

  /// Approves HSE's action plans, evaluates results, and owns the official
  /// K3 / ESG record.
  management,
}

/// Fine-grained capabilities, so screens ask "can I?" rather than comparing roles.
extension AppRoleCapabilities on AppRole {
  /// Only the field roles file hazard reports. HSE receives them; Management
  /// evaluates them. Keeping this false for HSE also removes the "Lapor" tab.
  bool get canFileReport => this == AppRole.worker || this == AppRole.supervisor;

  bool get canTriggerSos => true;

  /// The hazard report register (M-06). Supervisor no longer reviews reports:
  /// their responsibility is inspection and coordination.
  bool get canReviewReports => this == AppRole.hse || this == AppRole.management;

  /// HSE verifies a report and issues the corrective action.
  bool get canVerifyReports => this == AppRole.hse;

  /// HSE authors corrective actions; Management approves them.
  bool get canIssueActions => this == AppRole.hse;

  /// Management is the decision gate for every HSE action plan.
  bool get canApproveActions => this == AppRole.management;
  bool get canEvaluateActions => this == AppRole.management;
  bool get canCloseReports => this == AppRole.management;

  /// Corrective-action pipeline: HSE verifies up to stage 3, Supervisor executes
  /// stages 4–6. Management uses approve/evaluate instead of stage advancement.
  bool get canVerifyTickets => this == AppRole.supervisor || this == AppRole.hse;
  bool get canExecuteActions => this == AppRole.supervisor;

  /// Field inspection and coordination.
  bool get canInspect => this == AppRole.supervisor || this == AppRole.hse;
  bool get canCoordinate =>
      this == AppRole.supervisor || this == AppRole.hse || this == AppRole.management;

  /// Publishing and amending early warnings.
  bool get canManageWarnings => this == AppRole.hse || this == AppRole.management;

  /// Read the K3 / ESG figures.
  bool get canViewInsight =>
      this == AppRole.supervisor || this == AppRole.hse || this == AppRole.management;

  /// Write the official K3 / ESG figures. Management owns the record.
  bool get canEditInsight => this == AppRole.management;

  /// Short label used by the role-aware workspace banner.
  String get workspaceTitle {
    switch (this) {
      case AppRole.worker:
        return 'Ruang Kerja Pekerja';
      case AppRole.supervisor:
        return 'Konsol Supervisor';
      case AppRole.hse:
        return 'Konsol Verifikasi HSE';
      case AppRole.management:
        return 'Konsol Evaluasi Manajemen';
    }
  }

  String get workspaceSubtitle {
    switch (this) {
      case AppRole.worker:
        return 'Laporkan bahaya, terima tindak lanjut, dan gunakan tombol darurat.';
      case AppRole.supervisor:
        return 'Inspeksi lapangan, koordinasi HSE/Manajemen, dan jalankan tindakan yang sudah disetujui.';
      case AppRole.hse:
        return 'Terima laporan, verifikasi temuan, lalu susun tindakan korektif untuk disetujui Manajemen.';
      case AppRole.management:
        return 'Setujui rencana tindakan, evaluasi hasilnya, dan tutup laporan K3.';
    }
  }

  List<String> get workspaceSteps {
    switch (this) {
      case AppRole.worker:
        return const ['Lapor', 'Pantau notifikasi', 'Darurat'];
      case AppRole.supervisor:
        return const ['Inspeksi', 'Koordinasi', 'Laksanakan tindakan', 'Dashboard K3'];
      case AppRole.hse:
        return const ['Verifikasi laporan', 'Susun tindakan', 'Awasi pelaksanaan'];
      case AppRole.management:
        return const ['Setujui tindakan', 'Evaluasi hasil', 'Tutup laporan', 'Keputusan K3'];
    }
  }
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
        return 'Melaporkan bahaya, menerima tindak lanjut, dan mengaktifkan alarm darurat.';
      case AppRole.supervisor:
        return 'Inspeksi lapangan, koordinasi dengan HSE/Manajemen, dan pelaksanaan tindakan yang disetujui.';
      case AppRole.hse:
        return 'Menerima & memverifikasi laporan, menyusun tindakan korektif, dan mengawasi pelaksanaan.';
      case AppRole.management:
        return 'Menyetujui rencana tindakan HSE, mengevaluasi hasil, menutup laporan, dan menetapkan keputusan K3/ESG.';
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