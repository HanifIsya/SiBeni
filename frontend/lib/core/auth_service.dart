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

  /// The caller's access token, forwarded to the B2B API so that Row Level
  /// Security is evaluated against this user rather than `anon`.
  ///
  /// Reads are defensive: before [initialize] has run there is no client yet,
  /// and a widget that asks for the token (or a test that never signs in) must
  /// get `null` instead of an exception.
  String? get accessToken {
    try {
      return client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  /// The Supabase auth id (a UUID), which is what `hazard_reports.reporter_id`
  /// and `emergency_sos_logs.worker_id` expect. The employee number is NOT a
  /// valid value for those columns.
  String? get userId {
    try {
      return client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

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
          authId: userId,
          employeeId: res['employee_id'] as String? ?? '—',
          fullName: res['full_name'] as String? ?? 'Karyawan Tambang',
          role: AppRole.values.firstWhere(
            (r) => r.name == res['role'],
            orElse: () => AppRole.worker,
          ),
          workZone: res['work_zone'] as String? ?? 'Pit Utama',
          phone: res['phone_number'] as String?,
          avatarUrl: res['avatar_url'] as String?,
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

  /// Self-registration.
  ///
  /// Privileged roles require an operational invite code verified by the database
  /// trigger; without a valid code the profile defaults securely to `worker`.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? employeeId,
    required AppRole role,
    required String workZone,
    String? phone,
    String? inviteCode,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'employee_id': employeeId?.trim(),
        'role': role.name,
        'work_zone': workZone,
        'phone_number': phone?.trim(),
        'invite_code': inviteCode?.trim(),
      },
    );
    if (response.user != null) {
      await loadUserProfile(response.user!.id);
    }
    return response;
  }

  /// Update the signed-in user's own profile.
  ///
  /// Allowed by the "Users can update own profile" policy. `role` is
  /// deliberately absent from the payload: nobody may change their own role.
  Future<({bool ok, String? error})> updateProfile({
    required String fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final uid = userId;
    if (uid == null) return (ok: false, error: 'Sesi berakhir. Silakan masuk kembali.');

    try {
      final patch = <String, dynamic>{
        'full_name': fullName.trim(),
        'phone_number': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (avatarUrl != null) patch['avatar_url'] = avatarUrl;

      final res = await client
          .from('profiles')
          .update(patch)
          .eq('id', uid)
          .select('id, full_name, phone_number, avatar_url')
          .maybeSingle();

      if (res == null) {
        return (ok: false, error: 'Profil tidak dapat diperbarui. Akses ditolak.');
      }

      await loadUserProfile(uid);
      return (ok: true, error: null);
    } catch (e) {
      debugPrint('updateProfile failed: $e');
      return (ok: false, error: 'Gagal menyimpan profil. Periksa koneksi Anda.');
    }
  }

  Future<String?> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/png',
  }) async {
    final uid = userId;
    if (uid == null) return null;

    try {
      // Path is scoped to the user id, matching the storage RLS policy.
      final path = '$uid/avatar.png';
      await client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );
      final publicUrl = client.storage.from('avatars').getPublicUrl(path);
      return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('uploadAvatar failed: $e');
      return null;
    }
  }

  Future<String?> signedAvatarUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    try {
      return client.storage.from('avatars').createSignedUrl(path, const Duration(hours: 6).inSeconds);
    } catch (_) {
      return null;
    }
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