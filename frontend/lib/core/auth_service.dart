import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_session.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String supabaseUrl = 'https://qgdnrsnbxwqrouigrskb.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFnZG5yc25ieHdxcm91aWdyc2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxMzU4MjUsImV4cCI6MjEwNzcxMTgyNX0.GidEFVlR4sRH4babQ7sIGRDmNrWRYCOtQ5s_rXvqOH8';

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    // Check existing session
    final session = client.auth.currentSession;
    if (session != null) {
      await loadUserProfile(session.user.id);
    }
  }

  Future<UserProfile?> loadUserProfile(String userId) async {
    try {
      final res = await client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        final profile = UserProfile(
          employeeId: res['employee_id'] ?? 'EMP-001',
          fullName: res['full_name'] ?? 'Karyawan Tambang',
          role: AppRole.values.firstWhere(
            (r) => r.name == res['role'],
            orElse: () => AppRole.worker,
          ),
          workZone: res['work_zone'] ?? 'Pit Utama (Area Penambangan Aktif)',
          phone: res['phone_number'] ?? '+62 812-3456-7890',
        );
        await UserSession().login(profile);
        return profile;
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
    return null;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.user != null) {
      await loadUserProfile(response.user!.id);
    }

    return response;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String employeeId,
    required AppRole role,
    required String workZone,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'employee_id': employeeId.trim(),
        'role': role.name,
        'work_zone': workZone,
      },
    );

    if (response.user != null) {
      await loadUserProfile(response.user!.id);
    }

    return response;
  }

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (_) {}
    await UserSession().logout();
  }
}
