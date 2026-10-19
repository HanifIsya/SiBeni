import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/auth_service.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/role_workspace.dart';
import '../widgets/sb_button.dart';
import '../widgets/sb_card.dart';

/// Self-service account editing: display name, contact number, and avatar.
///
/// The scope is deliberately limited to what a worker owns. Role and employee
/// number are assigned by HSE and cannot be edited here — and the API would
/// reject such a write regardless, because the update payload never includes
/// them.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  String? _avatarUrl;
  Uint8List? _localAvatarBytes;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  UserProfile? get _user => UserSession.instance.currentUser.value;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _user?.fullName ?? '');
    _phone = TextEditingController(text: _user?.phone ?? '');
    _avatarUrl = _user?.avatarUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null || !mounted) {
        setState(() => _uploading = false);
        return;
      }

      final bytes = await file.readAsBytes();
      setState(() {
        _localAvatarBytes = bytes;
        _uploading = true;
        _error = null;
      });

      final path = await AuthService.instance.uploadAvatar(
        bytes: bytes,
        fileName: file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
      );

      if (!mounted) return;
      setState(() {
        _uploading = false;
        if (path != null) {
          // Drop the cached copy of the previous photo so the new picture is
          // the one on screen — on this account, and only on this account.
          final previous = _avatarUrl;
          _avatarUrl = path;
          if (previous != null && previous.isNotEmpty) {
            PaintingBinding.instance.imageCache
                .evict(NetworkImage(previous));
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.online,
              content: Text('Foto profil berhasil diunggah. Ketuk "Simpan Perubahan" untuk menyimpan.'),
            ),
          );
        } else {
          _error = 'Foto tidak dapat diunggah. Periksa koneksi Anda.';
        }
      });
    } catch (e) {
      debugPrint('pickAvatar failed: $e');
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Gagal memproses foto.';
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();

    if (name.length < 3) {
      setState(() => _error = 'Nama lengkap minimal 3 karakter.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await AuthService.instance.updateProfile(
      fullName: name,
      phone: _phone.text.trim(),
      avatarUrl: _avatarUrl,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.ok) {
      setState(() {
        _avatarUrl = _user?.avatarUrl;
      });
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_rounded, color: AppTheme.online, size: 54),
            title: const Text(
              'Perubahan Disimpan',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            content: const Text(
              'Profil dan foto akun Anda telah berhasil diperbarui di sistem SI BENI.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.inkMuted, height: 1.4),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: 130,
                height: 42,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.online,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      setState(() => _error = result.error);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Keluar Akun?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink),
        ),
        content: const Text(
          'Anda akan keluar dari sesi ini dan kembali ke halaman login.',
          style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.riskCritical),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) Navigator.maybePop(context);
      await AuthService.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return AdaptivePage(
      maxWidth: 560,
      slivers: [
        // Minimal account header: the screen is about the person, so the
        // header only says what the screen is. Everything else lives in the
        // cards below.
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.md),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
                tooltip: 'Kembali',
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Profil',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Avatar Card
        SbCard(
          child: Column(
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.hairline, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _localAvatarBytes != null
                          ? Image.memory(
                              _localAvatarBytes!,
                              fit: BoxFit.cover,
                            )
                          : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                              ? Image.network(
                                  _avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) => _Initials(user),
                                )
                              : _Initials(user)),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _uploading ? null : _pickAvatar,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppTheme.brand,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: _uploading
                              ? const Padding(
                                  padding: EdgeInsets.all(9),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_rounded,
                                  size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Foto ini hanya berlaku untuk akun Anda.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppTheme.inkFaint),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _uploading ? null : _pickAvatar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.brand.withValues(alpha: 0.08),
                    borderRadius: AppTheme.brPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_camera_outlined, size: 15, color: AppTheme.brand),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _uploading ? 'Mengunggah...' : 'Ganti Foto Profil',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.lg),

        if (_error != null) ...[
          _ErrorBanner(message: _error!),
          const SizedBox(height: AppTheme.md),
        ],

        // Editable Form
        SbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama Lengkap', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Nama lengkap Anda',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              Text('Nomor HP / WhatsApp', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: '+62 812-0000-0000',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.md),

        // Read-only identity fields
        SbCard(
          padding: const EdgeInsets.all(AppTheme.md),
          child: Column(
            children: [
              _ReadOnlyRow(label: 'Nomor Pegawai', value: user?.employeeId ?? '—'),
              const Divider(height: 18),
              _ReadOnlyRow(label: 'Peran', value: user?.roleDisplayName ?? '—'),
              const Divider(height: 18),
              _ReadOnlyRow(
                label: 'Zona Penugasan',
                value: user?.zoneShortName ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_rounded, size: 13, color: AppTheme.inkFaint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Peran dan zona penugasan ditetapkan oleh HSE. Hubungi admin untuk perubahan.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: AppTheme.inkFaint,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTheme.xl),

        // Save Button (Always clickable with active state)
        SbButton(
          label: 'Simpan Perubahan',
          icon: Icons.save_rounded,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),

        const SizedBox(height: AppTheme.md),

        // Logout Button
        SbButton(
          label: 'Keluar Akun (Log Out)',
          icon: Icons.logout_rounded,
          variant: SbButtonVariant.danger,
          onPressed: _logout,
        ),
        const SizedBox(height: AppTheme.lg),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.user);
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    // Tint the fallback avatar with the role colour so two accounts are never
    // mistaken for each other, even before a photo is uploaded.
    final color = RoleWorkspaceBanner.colorFor(user?.role ?? AppRole.worker);
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        user?.initials ?? '?',
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.inkMuted),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ),
      ],
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