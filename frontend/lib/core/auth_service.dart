import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'user_session.dart';

/// Authentication gateway.
///
/// The Supabase project is the identity authority; the app never stores or
/// invents credentials, and role assignment stays server-side.
class AuthService {
  AuthService._internal();

  static final AuthService instance = AuthService._internal();

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );

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
          employeeId: res['employee_id'] as String? ?? '—',
          fullName: res['full_name'] as String? ?? 'Karyawan Tambang',
          role: AppRole.values.firstWhere(
            (r) => r.name == res['role'],
            orElse: () => AppRole.worker,
          ),
          workZone: res['work_zone'] as String? ?? 'Pit Utama',
          phone: res['phone_number'] as String?,
        );
        await UserSession.instance.login(profile);
        return profile;
      }
    } catch (e) {
      debugPrint('loadUserProfile failed: $e');
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
    String? employeeId,
    required AppRole role,
    required String workZone,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'employee_id': employeeId?.trim(),
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
    } catch (_) {
      // Signing out locally must always succeed, even without a network.
    }
    await UserSession.instance.logout();
  }
}