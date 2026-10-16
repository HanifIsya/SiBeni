import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_config.dart';
import '../core/auth_service.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_card.dart';
import '../widgets/states.dart';

/// A role chip used both for sign-up selection and demo-account hints.
class _RoleOption {
  const _RoleOption(this.role, this.label, this.icon);
  final AppRole role;
  final String label;
  final IconData icon;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _employeeId = TextEditingController();
  final _inviteCode = TextEditingController();

  AppRole _role = AppRole.worker;
  String _zone = 'Pit Utama';

  static const _roles = [
    _RoleOption(AppRole.worker, 'Pekerja', Icons.construction_rounded),
    _RoleOption(AppRole.supervisor, 'Supervisor', Icons.supervised_user_circle_rounded),
    _RoleOption(AppRole.hse, 'HSE', Icons.health_and_safety_rounded),
    _RoleOption(AppRole.management, 'Manajemen', Icons.business_center_rounded),
  ];

  static const _zones = [
    'Pit Utama',
    'Jalan Angkut',
    'Stockpile & ROM',
    'Workshop',
    'Crusher Plant',
    'Gudang Logistik',
    'Fasilitas Pendukung',
  ];

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _employeeId.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final password = _password.text;

    if (!email.contains('@')) {
      setState(() => _error = 'Masukkan alamat email yang valid.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Kata sandi minimal 6 karakter.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        final res = await AuthService.instance.signIn(email: email, password: password);
        if (res.user == null) {
          setState(() => _error = 'Email atau kata sandi tidak cocok.');
        }
      } else {
        if (_fullName.text.trim().isEmpty) {
          setState(() {
            _loading = false;
            _error = 'Nama lengkap wajib diisi.';
          });
          return;
        }

        String? code;
        if (_role != AppRole.worker) {
          code = _inviteCode.text.trim().toUpperCase();
          if (code.isEmpty) {
            setState(() {
              _loading = false;
              _error = 'Masukkan kode otorisasi peran ${_role.name.toUpperCase()}.';
            });
            return;
          }
          final validCodes = switch (_role) {
            AppRole.supervisor => const ['SPV2026', 'SPV-CONSNET', 'SUPERVISOR'],
            AppRole.hse => const ['HSE2026', 'HSE-CONSNET', 'HSE'],
            AppRole.management => const ['MGT2026', 'MGT-CONSNET', 'MANAGEMENT'],
            _ => const <String>[],
          };
          if (!validCodes.contains(code)) {
            setState(() {
              _loading = false;
              _error = 'Kode otorisasi tidak valid untuk peran ${_role.name.toUpperCase()}.';
            });
            return;
          }
        }

        final res = await AuthService.instance.signUp(
          email: email,
          password: password,
          fullName: _fullName.text.trim(),
          employeeId: _employeeId.text.trim().isEmpty ? null : _employeeId.text.trim(),
          role: _role,
          workZone: _zone,
          inviteCode: code,
        );
        if (res.user == null) {
          setState(() => _error = 'Pendaftaran gagal. Periksa email atau hubungi HSE.');
        }
      }
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('Invalid login credentials')) {
      return 'Email atau kata sandi tidak cocok.';
    }
    if (raw.contains('User already registered')) {
      return 'Email ini sudah terdaftar. Silakan masuk.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Email belum dikonfirmasi oleh admin HSE.';
    }
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'Tidak ada koneksi ke server. Periksa jaringan Anda.';
    }
    return 'Autentikasi gagal. Silakan coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.brandDeep,
      body: SafeArea(
        child: AdaptivePage(
          maxWidth: 520,
          slivers: [
            const SizedBox(height: 18),
            const _BrandMark(),
            const SizedBox(height: 26),

            // Sign-in / sign-up switch
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: AppTheme.brMd,
              ),
              child: Row(
                children: [
                  _SwitchTab(
                    label: 'Masuk',
                    selected: _isLogin,
                    onTap: () => setState(() {
                      _isLogin = true;
                      _error = null;
                    }),
                  ),
                  _SwitchTab(
                    label: 'Daftar',
                    selected: !_isLogin,
                    onTap: () => setState(() {
                      _isLogin = false;
                      _error = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 14),
            ],

            if (!_isLogin) ...[
              SbCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Identitas Pekerja',
                      dense: true,
                    ),
                    _Field(
                      controller: _fullName,
                      label: 'Nama lengkap',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _employeeId,
                      label: 'Nomor pegawai',
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    Text('Peran', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _roles.map((r) {
                        final selected = r.role == _role;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _role = r.role);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.brand.withValues(alpha: 0.10)
                                  : AppTheme.canvas,
                              borderRadius: AppTheme.brSm,
                              border: Border.all(
                                color: selected ? AppTheme.brand : AppTheme.hairline,
                                width: selected ? 1.6 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  r.icon,
                                  size: 15,
                                  color: selected ? AppTheme.brand : AppTheme.inkFaint,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  r.label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                    color: selected ? AppTheme.brand : AppTheme.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_role != AppRole.worker) ...[
                      const SizedBox(height: 14),
                      _Field(
                        controller: _inviteCode,
                        label: 'Kode otorisasi peran ${_role.name.toUpperCase()}',
                        icon: Icons.vpn_key_outlined,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Pendaftaran peran non-pekerja memerlukan kode resmi (misal: ${_role == AppRole.supervisor ? 'SPV2026' : _role == AppRole.hse ? 'HSE2026' : 'MGT2026'}).',
                        style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint, height: 1.3),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Zona penugasan', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _zones.map((z) {
                        final selected = z == _zone;
                        return GestureDetector(
                          onTap: () => setState(() => _zone = z),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.brand : AppTheme.canvas,
                              borderRadius: AppTheme.brSm,
                              border: Border.all(
                                color: selected ? AppTheme.brand : AppTheme.hairline,
                              ),
                            ),
                            child: Text(
                              z,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : AppTheme.inkMuted,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            SbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Akses Akun', dense: true),
                  _Field(
                    controller: _email,
                    label: 'Email perusahaan',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _password,
                    label: 'Kata sandi',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 19,
                        color: AppTheme.inkFaint,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SbButton(
              label: _isLogin ? 'Masuk' : 'Buat Akun',
              loading: _loading,
              icon: _isLogin ? Icons.login_rounded : Icons.person_add_alt_1_rounded,
              onPressed: _submit,
            ),
            const SizedBox(height: 22),

            const _SecurityNote(),
            const SizedBox(height: 18),
            Center(
              child: Text(
                '${AppConfig.appName} · ${AppConfig.appTagline}\n${AppConfig.organisation}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.6,
                  color: Color(0xFF7E97AC),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: AppTheme.brLg,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          AppConfig.appName,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppConfig.appTagline.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }
}

class _SwitchTab extends StatelessWidget {
  const _SwitchTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: AppTheme.brSm,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: selected ? AppTheme.brandDeep : const Color(0xFF9FB6C8),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.ink),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19, color: AppTheme.inkFaint),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.riskCriticalBg,
        borderRadius: AppTheme.brMd,
        border: Border.all(color: AppTheme.riskCritical.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.riskCritical, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppTheme.riskCritical,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_rounded, size: 13, color: Color(0xFF7E97AC)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Sesi terenkripsi. Laporan tetap tersimpan di perangkat bila jaringan hilang.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }
}