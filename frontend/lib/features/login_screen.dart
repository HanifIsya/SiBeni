import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/user_session.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _employeeIdController = TextEditingController(text: 'OP-104');
  final _nameController = TextEditingController(text: 'Budi Santoso');
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

  void _loginWithCustomData() {
    final profile = UserProfile(
      employeeId: _employeeIdController.text.trim().isEmpty ? 'EMP-001' : _employeeIdController.text.trim(),
      fullName: _nameController.text.trim().isEmpty ? 'Pekerja Tambang' : _nameController.text.trim(),
      role: _selectedRole,
      workZone: _selectedZone,
      phone: '+62 812-3456-7890',
    );
    UserSession().login(profile);
    widget.onLoginSuccess();
  }

  void _loginWithPersona(UserProfile persona) {
    UserSession().login(persona);
    widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Mascot Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Color(0x330F4C81), blurRadius: 16, offset: Offset(0, 6)),
                        ],
                      ),
                      child: const Icon(Icons.smart_toy_rounded, color: AppTheme.brandSecondary, size: 44),
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

              // Fast Persona Switcher (For quick evaluator testing)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.touch_app_outlined, color: AppTheme.brandPrimary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'PILIH ROLE / AKUN DEMO (1-TAP TEST)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: UserSession.demoPersonas.map((persona) {
                        IconData roleIcon;
                        Color roleColor;
                        switch (persona.role) {
                          case AppRole.worker:
                            roleIcon = Icons.construction;
                            roleColor = AppTheme.brandPrimary;
                            break;
                          case AppRole.supervisor:
                            roleIcon = Icons.supervised_user_circle;
                            roleColor = AppTheme.riskHigh;
                            break;
                          case AppRole.hse:
                            roleIcon = Icons.health_and_safety;
                            roleColor = AppTheme.brandSafetyGreen;
                            break;
                          case AppRole.management:
                            roleIcon = Icons.business_center;
                            roleColor = Colors.indigo;
                            break;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            onTap: () => _loginWithPersona(persona),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: roleColor.withValues(alpha: 0.15),
                                    child: Icon(roleIcon, size: 20, color: roleColor),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          persona.fullName,
                                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${persona.roleDisplayName} • ${persona.employeeId}',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.onSurfaceSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.onSurfaceSecondary),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Or Custom Login Form
              Text(
                'Atau Masuk dengan Data Karyawan:',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.onSurfacePrimary),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _employeeIdController,
                decoration: InputDecoration(
                  labelText: 'Nomor Registrasi Karyawan (NRP/NIK)',
                  labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap Karyawan',
                  labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _selectedZone,
                decoration: InputDecoration(
                  labelText: 'Zona Penugasan Tambang',
                  labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _zones.map((zone) {
                  return DropdownMenuItem(
                    value: zone,
                    child: Text(zone, style: GoogleFonts.plusJakartaSans(fontSize: 12), overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedZone = val);
                },
              ),
              const SizedBox(height: 14),

              Text('Peran Kerja (Role):', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: AppTheme.minTouchTarget,
                child: ElevatedButton(
                  onPressed: _loginWithCustomData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('MASUK APLIKASI', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
