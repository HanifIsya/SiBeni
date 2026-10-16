# AUDIT & PRODUCTION ROADMAP
# SI BENI (Siaga Bencana Dini) — Enterprise Mining K3 Mobile & Cloud

**Standard Acuan**: Kepmen ESDM No. 1827 K/30/MEM/2018 (Pedoman Pelaksanaan Kaidah Pertambangan yang Baik)  
**Target Rilis**: Android Native Production Release (`.apk`) + Live Next.js Web Dashboard (Render) + Realtime Supabase PostgreSQL

---

## 1. Temuan Audit (Root-Cause Audit of Previous Mock Elements)

| Area / Komponen | Masalah Sebelumnya (Mock / AI-Vibe) | Solusi Produksi Riil (Production-Grade) |
| :--- | :--- | :--- |
| **Autentikasi Pengguna** | Shortcut "1-Tap Demo Persona" yang terasa seperti prototipe mainan. Tidak ada akun riil, tanpa enkripsi kata sandi, dan tanpa registrasi mandiri. | **Autentikasi Asli Supabase Auth (`auth.users`)**: Form Login resmi (Email/NRP + Password) dan Register (Nama, NRP, Role, Zona Kerja, Password). Dilengkapi session persistence, token refresh, dan proteksi RLS berbasis JWT. Akun resmi perusahaan terdaftar di database. |
| **Peta Risiko & Spasial** | Grid canvas statis/tiruan yang tidak dapat digeser (*pan*), tidak dapat diperbesar (*zoom*), dan tanpa peta satelit/geografis nyata. | **Peta Asli OpenStreetMap (`flutter_map` + `latlong2`)**: Peta dinamis dengan tile OpenStreetMap, koordinat geografis aktual area konsesi Kalimantan/Indonesia, marker interaktif tiap zona tambang dengan pill tingkat risiko, geofence batas tambang, serta titik kumpul (*Assembly Point*). |
| **Desain Sistem (`DESIGN.md`)** | Mengandung gaya bahasa AI generik (*buzzwords*, formatting prompt Stitch yang tidak realistis untuk standar teknik pertambangan). | **Perombakan Total `DESIGN.md`**: Ditulis ulang sebagai dokumen spesifikasi rekayasa antarmuka industri K3 tambang formal, berorientasi standar Kepmen ESDM 1827/2018, rasio kontras WCAG AAA untuk terik matahari open pit, tactile ergonomics sarung tangan, dan alur pelaporan lapangan teruji. |
| **Manajemen Peran (Actor-Based)** | Pilihan peran tercampur aduk tanpa pemisahan antarmuka yang tegas. | **Pemisahan Role Berdasarkan Data Akun**: Pekerja lapangan hanya melihat instrumen keselamatan esensial (*Peta, Lapor Cepat, SOS*), Supervisor mendapatkan verifikasi tiket CA, sedangkan Tim HSE dan Manajemen mendapatkan akses inspeksi komprehensif & dashboard ESG. |
| **Data Transaksional** | Sebagian data masih menggunakan fallback lokal ketika render atau database sedang idle. | **100% Live Database Connectivity**: Seluruh zona, peringatan BMKG/BNPB, tiket perbaikan lapangan, dan metrik emisi diambil langsung dari Supabase PostgreSQL dengan cache terstruktur saat jaringan pit offline. |

---

## 2. Arsitektur Autentikasi Produksi (Supabase Auth)

```
[ Form Login / Register K3 ]
              │
              ├──► Register ──► supabase.auth.signUp(email, password, user_metadata)
              │                       │
              │                       ▼ (Trigger DB: on_auth_user_created)
              │                 Auto-Insert ke `public.profiles`
              │                 (id, employee_id, full_name, role, work_zone)
              │
              └──► Login    ──► supabase.auth.signInWithPassword(email, password)
                                      │
                                      ▼ (Berhasil)
                               Ambil Profil dari `public.profiles`
                                      │
                                      ▼
                        Inisialisasi Sesi & Hak Akses Tab
```

### Akun Produksi Default (Pre-seeded & Active di Supabase):
1. **Pekerja / Operator**: `pekerja@consnetmining.com` / `Consnet123!` (Budi Santoso, NRP: `OP-104`, Pit Utama)
2. **Supervisor Lapangan**: `supervisor@consnetmining.com` / `Consnet123!` (Hendro Wijaya, NRP: `SPV-202`, Haul Road)
3. **Tim HSE & Inspektur**: `hse@consnetmining.com` / `Consnet123!` (Dr. Citra Utami, NRP: `HSE-001`, Site Klinik)
4. **Manajemen Eksekutif**: `manajemen@consnetmining.com` / `Consnet123!` (Ir. Bambang Suryo, NRP: `MGT-099`, Site Office)
*Pekerja baru juga dapat mendaftar langsung secara mandiri melalui tombol "Daftar Akun K3 Baru" di aplikasi.*

---

## 3. Spesifikasi OpenStreetMap Tambang (Peta Vektor & Geospasial)

- **Tile Provider**: Standard Slippy Map Tiles (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`).
- **Koordinat Default Konsesi**: Latitude `-2.1458291`, Longitude `115.3489124` (Wilayah pertambangan teruji).
- **Interaktivitas Peta**:
  - Dukungan sentuhan multi-jari (*pinch to zoom*, *drag to pan*).
  - Marker interaktif pada 7 zona operasional:
    - *Pit Utama*: Marker Merah/Oranye berdenyut jika ada peringatan lereng.
    - *Haul Road*: Polyline rute jalan tambang dan marker batas kecepatan.
    - *Stockpile, Workshop, Crusher, Handak, Site Office*.
  - Layer Jalur Evakuasi Hijau Putus-putus ke *Assembly Point A*.
  - Indikator akurasi GPS posisi pekerja lapangan.

---

## 4. Rencana Kerja Eksekusi & Audit

1. [x] Audit kegagalan otentikasi awal (perbaikan email validation & trigger `AFTER INSERT`).
2. [x] Verifikasi dan seeding 4 akun riil enterprise di `auth.users` dan `public.profiles`.
3. [x] Instalasi paket OpenStreetMap Flutter (`flutter_map` dan `latlong2`).
4. [ ] Revisi total dokumen `DESIGN.md` menjadi spesifikasi industri K3 murni (menghilangkan format AI prompt generik).
5. [ ] Implementasi `AuthService` dan layar `LoginScreen` + `RegisterScreen` resmi berbasis Supabase Auth.
6. [ ] Implementasi peta interaktif OpenStreetMap pada `RiskMapScreen` dan `EmergencyScreen`.
7. [ ] Implementasi drawer profil pengguna riil (Lihat ID Karyawan, Role, Zona Kerja, Tombol Logout resmi).
8. [ ] Pengujian build Android APK rilis produksi (`flutter build apk --release`).
9. [ ] Commit seluruh pembaruan ke repositori GitHub: `https://github.com/HanifIsya/SiBeni`.
