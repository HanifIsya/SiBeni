import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/auth_service.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../widgets/adaptive_page.dart';
import '../widgets/states.dart';
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

  bool get _dirty =>
      _name.text.trim() != (_user?.fullName ?? '') ||
      _phone.text.trim() != (_user?.phone ?? '');

  Future<void> _pickAvatar() async {
    setState(() => _uploading = true);
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
      final path = await AuthService.instance.uploadAvatar(
        bytes: bytes,
        fileName: file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
      );

      if (!mounted) return;
      setState(() {
        _uploading = false;
        if (path != null) {
          _avatarUrl = path;
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
      setState(() => _error = 'Nama minimal 3 karakter.');
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
      setState(() => _avatarUrl = _user?.avatarUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.online,
          content: Text('Profil berhasil disimpan.'),
        ),
      );
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return AdaptivePage(
      maxWidth: 560,
      slivers: [
        const SectionHeader(
          title: 'Edit Profil',
          icon: Icons.badge_rounded,
          subtitle: 'Data yang ditampilkan kepada rekan tim',
        ),

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
                      child: _avatarUrl != null
                          ? Image.network(
                              _avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => _Initials(user),
                            )
                          : _Initials(user),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _uploading ? null : _pickAvatar,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppTheme.brand,
                            shape: BoxShape.circle,
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
                                  size: 17, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _uploading ? null : _pickAvatar,
                child: Text(
                  'Ubah foto profil',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _uploading ? AppTheme.inkFaint : AppTheme.brand,
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

        SbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama Lengkap', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(hintText: 'Nama lengkap Anda'),
              ),
              const SizedBox(height: 16),
              Text('Nomor HP', style: AppTheme.eyebrow()),
              const SizedBox(height: 8),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: '+62 812-0000-0000',
                  prefixIcon: Icon(Icons.phone_outlined, size: 19),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.md),

        // Read-only identity fields: assigned by HSE, not self-editable.
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
                'Peran dan zona penugasan ditetapkan oleh HSE. Hubungi mereka untuk perubahan.',
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
        SbButton(
          label: 'Simpan Perubahan',
          icon: Icons.save_rounded,
          loading: _saving,
          onPressed: (_dirty && !_saving) ? _save : null,
        ),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.user);
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.brand,
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
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.inkMuted),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
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