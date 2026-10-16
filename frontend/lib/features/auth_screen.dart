import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/user_session.dart';
import '../core/auth_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  const AuthScreen({super.key, required this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final _emailController = TextEditingController(text: 'pekerja@consnetmining.com');
  final _passwordController = TextEditingController(text: 'Consnet123!');
  final _fullNameController = TextEditingController();
  final _employeeIdController = TextEditingController();

  AppRole _selectedRole = AppRole.worker;
  String _selectedZone = 'Pit Utama (Area Penambangan Aktif)';

  final List<String> _zones = [
    'Pit Utama (Area Penambangan Aktif)',
    'Jalan Angkut (Haul Road KM 0-15)',
    'Stockpile & ROM Timbunan',
    'Workshop & Maintenance Alat Berat',
    'Fasilitas Pengolahan (Crusher Plant)',
    'Gudang Logistik & Handak',
    'Fasilitas Pendukung (Site Office)',
  ];

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Silakan masukkan alamat email yang valid.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Kata sandi minimal 6 karakter.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLoginMode) {
        // Real Supabase Auth Login
        final res = await AuthService().signIn(email: email, password: password);
        if (res.user != null) {
          widget.onAuthSuccess();
        } else {
          setState(() => _errorMessage = 'Email atau kata sandi tidak cocok.');
        }
      } else {
        // Real Supabase Auth Registration
        if (_fullNameController.text.trim().isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Nama lengkap wajib diisi.';
          });
          return;
        }

        final res = await AuthService().signUp(
          email: email,
          password: password,
          fullName: _fullNameController.text.trim(),
          employeeId: _employeeIdController.text.trim().isEmpty
              ? 'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
              : _employeeIdController.text.trim(),
          role: _selectedRole,
          workZone: _selectedZone,
        );

        if (res.user != null) {
          widget.onAuthSuccess();
        } else {
          setState(() => _errorMessage = 'Pendaftaran gagal. Silakan periksa koneksi atau gunakan email lain.');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Autentikasi gagal: ${e.toString().replaceAll('AuthException:', '').trim()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _autofillAccount(String email, String roleName) {
    setState(() {
      _isLoginMode = true;
      _emailController.text = email;
      _passwordController.text = 'Consnet123!';
      _errorMessage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Akun $roleName telah diisi otomatis. Ketuk "MASUK KE SISTEM K3"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Enterprise Industrial Brand Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Color(0x330F4C81), blurRadius: 16, offset: Offset(0, 6)),
                        ],
                      ),
                      child: const Icon(Icons.shield, color: AppTheme.brandSecondary, size: 36),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SI BENI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.brandPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Siaga Bencana Dini • PT Consnet Mining',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Segmented Tab Switcher (Masuk vs Daftar)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isLoginMode = true;
                          _errorMessage = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isLoginMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _isLoginMode ? const [BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
                          ),
                          child: Center(
                            child: Text(
                              'Masuk Akun',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isLoginMode ? AppTheme.brandPrimary : AppTheme.onSurfaceSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isLoginMode = false;
                          _errorMessage = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isLoginMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: !_isLoginMode ? const [BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
                          ),
                          child: Center(
                            child: Text(
                              'Daftar Baru',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !_isLoginMode ? AppTheme.brandPrimary : AppTheme.onSurfaceSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Error Message Banner
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.riskCriticalBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.riskCritical),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.riskCritical, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.riskCritical),
                        ),
                      ),
                    ],
                  ),
                ),

              // Form Input Fields
              if (!_isLoginMode) ...[
                Text('Nama Lengkap Karyawan', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Ahmad Rizky',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                  ),
                ),
                const SizedBox(height: 12),

                Text('NRP / NIK Karyawan', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _employeeIdController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: OP-501',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                  ),
                ),
                const SizedBox(height: 12),

                Text('Peran K3 (Role)', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: AppRole.values.map((role) {
                    final isSelected = _selectedRole == role;
                    return ChoiceChip(
                      label: Text(role.name.toUpperCase()),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedRole = role),
                      selectedColor: AppTheme.brandPrimary,
                      labelStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.onSurfacePrimary,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                Text('Zona Penugasan Tambang', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedZone,
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                  ),
                  items: _zones.map((z) => DropdownMenuItem(value: z, child: Text(z, style: GoogleFonts.plusJakartaSans(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedZone = val);
                  },
                ),
                const SizedBox(height: 12),
              ],

              Text('Alamat Email Perusahaan', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'nama@consnetmining.com',
                  prefixIcon: const Icon(Icons.mail_outline, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                ),
              ),
              const SizedBox(height: 12),

              Text('Kata Sandi', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Minimal 6 karakter',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                ),
              ),
              const SizedBox(height: 24),

              // Main Action Button (min 52px target)
              SizedBox(
                width: double.infinity,
                height: AppTheme.minTouchTarget,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          _isLoginMode ? 'MASUK KE SISTEM K3' : 'DAFTAR SEBAGAI KARYAWAN',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Expandable Quick Test Credentials Guide
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.vpn_key_outlined, size: 16, color: AppTheme.brandPrimary),
                        const SizedBox(width: 6),
                        Text(
                          'AKUN RESMI PERUSAHAAN (SUPABASE AUTH)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.brandPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ketuk salah satu akun untuk mengisi otomatis kredensial aktif:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary),
                    ),
                    const SizedBox(height: 10),
                    _buildAccountChip('Pekerja / Operator', 'pekerja@consnetmining.com', Icons.construction),
                    _buildAccountChip('Supervisor', 'supervisor@consnetmining.com', Icons.supervised_user_circle),
                    _buildAccountChip('Tim HSE', 'hse@consnetmining.com', Icons.health_and_safety),
                    _buildAccountChip('Manajemen', 'manajemen@consnetmining.com', Icons.business_center),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountChip(String role, String email, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: InkWell(
        onTap: () => _autofillAccount(email, role),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AppTheme.brandPrimary),
                  const SizedBox(width: 8),
                  Text(role, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(email, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.brandPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
