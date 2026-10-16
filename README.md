# SI BENI (Siaga Bencana Dini)

[![Flutter](https://img.shields.io/badge/Frontend-Flutter%203.x-02569B?logo=flutter)](https://flutter.dev)
[![Next.js](https://img.shields.io/badge/Backend%20%26%20Dashboard-Next.js%20App%20Router-black?logo=next.js)](https://nextjs.org)
[![Supabase](https://img.shields.io/badge/Database%20%26%20Auth-Supabase%20PostgreSQL-3ECF8E?logo=supabase)](https://supabase.com)
[![Render](https://img.shields.io/badge/Hosting-Render-46E3B7?logo=render)](https://render.com)
[![K3 Standard](https://img.shields.io/badge/Safety-Mining%20K3%20Standard-15803D)](https://github.com/HanifIsya/SiBeni)

**SI BENI (Siaga Bencana Dini)** adalah sistem informasi keselamatan dan kesehatan kerja (K3) industri pertambangan terintegrasi untuk **PT Consnet Mining**. Sistem ini menghubungkan pekerja lapangan (*open pit, haul road, workshop*) dengan Tim HSE, Supervisor, dan Manajemen Eksekutif secara real-time maupun dalam kondisi keterbatasan koneksi (*Offline-First*).

---

## 📌 Ringkasan Eksekutif & Dokumen Perencanaan

- 📖 **[Product Requirements Document (PRD.md)](./PRD.md)**: Spesifikasi mendalam mengenai visi produk, dekonstruksi akar masalah (Fishbone 6M), use case diagram, spesifikasi fungsional 5 modul utama, skema basis data, dan metrik keberhasilan K3.
- 🗺️ **[Implementation Plan & Roadmap (IMPLEMENTATION_PLAN.md)](./IMPLEMENTATION_PLAN.md)**: Rencana aksi terstruktur per fase, arsitektur monorepo, panduan integrasi MCP (Supabase, Render, Google Stitch), serta matriks verifikasi.
- 🎨 **[Design System (DESIGN.md)](./DESIGN.md)**: Sistem desain v3.0 — taksonomi 4 tingkat risiko K3, tipografi ganda (*Plus Jakarta Sans* untuk antarmuka, *JetBrains Mono* untuk telemetri), skala spasi/radius/elevasi, token gerak & getaran, aturan responsif (NavigationBar → NavigationRail), dan cetak biru layar (M-01 s/d M-05).

---

## 🏗️ Arsitektur Sistem

```
                                      +------------------------------------+
                                      |     Sumber Resmi BMKG & BNPB       |
                                      |   (Prakiraan Cuaca, Radar Gempa)   |
                                      +-----------------+------------------+
                                                        │ Ingesti Otomatis (Cron)
                                                        ▼
+--------------------------------+            +------------------------------------+
|       Aplikasi Mobile          |            |     Backend Service & Dashboard    |
|       (Flutter Dart)           |            |         (Next.js di Render)        |
+--------------------------------+            +------------------------------------+
| • M-01: Peta Risiko Tambang    |            | • REST API Endpoints (/api/bmkg,   |
| • M-02: Lapor Cepat (Offline)  |◄──────────►|   /api/emergency, /api/reports)    |
| • M-03: SOS Darurat & Evakuasi |  HTTP/WS   | • W-01: Dashboard K3 Eksekutif     |
| • M-04: Inspeksi Lapangan K3   |            | • Verifikasi Tiket Corrective Act. |
| • M-05: Dashboard Mobile       |            | • Pemantauan Emisi Karbon (CO2e)   |
+---------------+----------------+            +-----------------+------------------+
                │                                               │
                │ Real-Time / REST                              │ SQL / Storage
                ▼                                               ▼
+----------------------------------------------------------------------------------+
|                           Supabase Cloud Infrastructure                          |
+----------------------------------------------------------------------------------+
| • PostgreSQL 15+ (RLS Enforced, 7 Zona Tambang, Transaksi Laporan, Pipeline CA)  |
| • Supabase Storage (Foto Bukti Bahaya Lapangan & Verifikasi Hasil Perbaikan)     |
| • Realtime Engine (Pemicu Broadcast Darurat SOS & Perubahan Tingkat Risiko Zona) |
+----------------------------------------------------------------------------------+
```

---

## ⚡ Fitur Utama SI BENI

> **Lokasi site**: koridor industri Driyorejo, Surabaya Timur (`-7.2200, 112.7500`).
> PT Consnet Mining adalah perusahaan fiktif untuk keperluan proyek; seluruh
> koordinat zona berada di database, bukan di dalam aplikasi.

1. **Peta Risiko & Peringatan Dini (M-01)**
   - Pemetaan spasial 7 zona kerja operasional: *Pit Utama, Jalan Angkut KM 0-15, Stockpile, Workshop, Crusher Plant, Gudang Handak, dan Fasilitas Pendukung*.
   - Standarisasi 4 Tingkat Risiko: **Rendah**, **Sedang**, **Tinggi**, **Kritis** — lengkap dengan warna, ikon, dan label teks.
   - Dua kontrol lokasi: **Posisi Saya** (GNSS langsung) dan **Lokasi PT** (menampilkan seluruh area konsesi).
   - Peringatan dini **bukan hardcoded** — bersumber dari tabel `early_warnings` dan dikelola penuh oleh HSE.

2. **Lapor Cepat Bahaya & Near Miss — Offline-First (Screen M-02)**
   - Alur tunggal terstruktur dalam tempo < 30 detik: pemilih tipe insiden (*Bahaya* vs *Near Miss*), koordinat GNSS **riel perangkat** + zona otomatis, kategori bahaya, dan input deskripsi.
   - **Mode Offline**: laporan ditulis ke penyimpanan lokal *sebelum* mencoba dikirim (*write-first*), lalu dikirim ulang otomatis item-per-item ketika jaringan pulih — tanpa kehilangan data.
   - **Paket data didukung**: kebijakan jaringan dikendalikan pengguna (*Izinkan Data Seluler*, aktif secara bawaan). Status `Online · Wi-Fi` / `Online · Seluler` / `Wi-Fi Saja` / `Terputus` / `Offline` selalu terlihat di bilah atas.

3. **Tanggap Darurat, SOS 3 Detik & Peta Evakuasi (Screen M-03)**
   - **Tombol Darurat (SOS)** radial 190px dengan gestur tekan-tahan 3 detik (*Long-Press 3s*) untuk menghindari kepencet di jalan tambang.
   - 5 Filter Keadaan Darurat (*Kebakaran, Cedera, B3, Longsor/Banjir, Keamanan*).
   - Jalur evakuasi digital ke *Assembly Point* terdekat dengan **jarak terukur** dari posisi GNSS pengguna, 4 prinsip darurat, dan *stepper* 6 langkah evakuasi.

4. **Inspeksi K3 & Corrective Action (Screen M-04)**
   - Checklist digital berkala: *APD, Alat Berat, Jalan Angkut, APAR, Housekeeping, Lingkungan*.
   - Alur 6 Tahap Tindak Lanjut (*Inspection → Identified → Verified → Assigned → In Progress → Closed*).

5. **Dashboard K3, Energi & Emisi Karbon (M-05 & W-01)**
   - 4 KPI utama + panel hero emisi karbon: *Safe Man-Hours*, **TRIR**, **Konsumsi Energi**, **Intensitas Energi**, **Emisi CO₂e**.
   - Komposisi energi per sumber dengan bar animasi, dan periode pelaporan dari database.
   - **Tanpa angka hardcoded**: bila server belum mengembalikan nilai, kartu menampilkan `—` — sistem keselamatan tidak pernah menampilkan angka karangan.
   - **Hanya Manajemen** yang dapat mengisi/memperbarui angka resmi ( Supervisor dan HSE membaca saja).

6. **Tinjauan Laporan Bahaya (M-06) — baru**
   - Register laporan dengan ringkasan status dan empat filter: *Baru · Ditinjau · Tindak Lanjut · Ditutup*.
   - Alur keputusan: `SUBMITTED → IN_REVIEW → ACTION_REQUIRED → CLOSED`, dengan catatan peninjauan.
   - Hanya **HSE dan Manajemen** yang dapat menutup laporan.

7. **Kelola Peringatan Dini (M-07) — baru**
   - Terbitkan, ubah, dan nonaktifkan peringatan dini (severity, zona terdampak, label bahaya, tindakan keselamatan, masa berlaku).
   - Akses untuk **HSE dan Manajemen**. Penonaktifan bersifat *soft delete* agar jejak audit tetap ada.

8. **Edit Profil — baru**
   - Pengguna dapat mengubah nama, nomor HP, dan foto profil (unggah ke bucket privat `avatars`).
   - Nomor pegawai, peran, dan zona penugasan bersifat **read-only** — ditetapkan HSE dan tidak dapat diubah dari aplikasi.

---

## 🔐 Pembedaan Peran

Keempat peran memiliki modul yang benar-benar berbeda, bukan sekadar nama berbeda di halaman profil.

| Peran | Modul Utama | Wajib | Tidak Boleh |
| :--- | :--- | :--- | :--- |
| **Pekerja** | Peta, Lapor, Darurat | Melaporkan bahaya, mengaktifkan SOS | Melihat register, memverifikasi tiket, mengubah angka K3 |
| **Supervisor** | + Inspeksi, Insight | Memverifikasi tindakan korektif | Meninjau laporan, menerbitkan peringatan, menulis angka K3 |
| **HSE** | Peta, Lapor, Darurat, Inspeksi, Laporan | Meninjau & menutup laporan, mengelola peringatan | Menulis angka K3/ESG resmi |
| **Manajemen** | Peta, Lapor, Darurat, Laporan, Insight | Seluruh kewenangan | — |

Matriks ini didefinisikan di `frontend/lib/core/user_session.dart` (`AppRoleCapabilities`) **dan** ditegakkan ulang di Postgres melalui Row Level Security, sehingga aplikasi yang dimodifikasi tetap tidak bisa melewati batas peran.

### Kode Otorisasi Pendaftaran Peran (Invite Code)
Saat mendaftar akun baru, peran non-pekerja memerlukan kode otorisasi resmi:
- **Pekerja**: Tanpa kode (default).
- **Supervisor**: `SPV2026` atau `SPV-CONSNET`
- **HSE**: `HSE2026` atau `HSE-CONSNET`
- **Manajemen**: `MGT2026` atau `MGT-CONSNET`

Verifikasi otomatis tersedia di `backend/e2e-writepaths.mjs` — 24 pemeriksaan end-to-end terhadap API sungguhan, termasuk memastikan setiap tindakan terlarang benar-benar menghasilkan `403`.

---

## 🛠️ Persyaratan Lingkungan & Cara Memulai

### Prasyarat
- [Flutter SDK](https://flutter.dev) (v3.24+ / 3.41+)
- [Node.js](https://nodejs.org) (v20+ / v24+)
- Proyek [Supabase](https://supabase.com) dengan Database URL & Anon Key
- Akun [Render](https://render.com) untuk hosting backend service

### Setup Basis Data Supabase
1. Buka SQL Editor di dasbor Supabase Anda.
2. Jalankan skrip migrasi berurutan:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_rls_and_policies.sql`
   - `supabase/migrations/003_zone_geometry.sql` — geometri zona dipindahkan dari kode klien ke database.
   - `supabase/migrations/004_surabaya_site_and_write_paths.sql` — relokasi site ke Surabaya, perbaikan jalur tulis, trigger pemicu, bucket avatar, dan penyesuaian peran.
   - `supabase/migrations/005_role_invite_code_authorization.sql` — otorisasi pendaftaran peran via invite code (`SPV2026`, `HSE2026`, `MGT2026`).
3. Masukkan data awal dengan menjalankan:
   - `supabase/seed.sql`

### Verifikasi Jalur Tulis Backend

Jalur tulis di API sebelumnya gagal secara senyap karena JWT pengguna tidak pernah diteruskan ke PostgREST — sehingga Row Level Security selalu dievaluasi sebagai `anon`. Skrip ini memverifikasi seluruh alur terhadap server sungguhan:

```bash
cd backend
export NEXT_PUBLIC_SUPABASE_URL="https://<ref>.supabase.co"
export NEXT_PUBLIC_SUPABASE_ANON_KEY="<anon-key>"
npm run build && npx next start -p 4310   # terminal terpisah
node e2e-writepaths.mjs
```

Target: **24/24 pemeriksaan lulus**, termasuk penolakan `403` untuk setiap tindakan yang di luar kewenangan peran.

### Menjalankan Aplikasi & Membuat Rilis

```bash
cd frontend
flutter pub get
flutter analyze                 # harus: No issues found!
flutter test                    # 76 uji: tata letak + logika inti + matriks peran
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

Penandatanganan rilis memakai keystore `android/sibeni-release.jks` yang
dikonfigurasi lewat `android/key.properties`. Keduanya **tidak** masuk version
control (`android/.gitignore`) — di CI, kedua berkas itu di-inject dari secret
store sebelum build. Tanpa berkas tersebut, build otomatis jatuh ke *debug key*
agar checkout baru tetap menghasilkan APK yang bisa dijalankan.

---

## 👥 Tim Penyusun & Kontributor
**Kelompok 3 — HIP 3A (Universitas Airlangga)**  
Dosen Pengampu: **Christiant Dimas Renggana, S.Kom**
- Meidia Salsa (432241001)
- Nadirah Aynur Rohmah (432241016)
- Putri Fadhilatul Ilmiah (432241020)
- Nur Afifah (432241022)
- Farid Omar Wardana (432241026)

---

## 📄 Lisensi
Hak Cipta © 2026 PT Consnet Mining & Kelompok 3 HIP 3A. Seluruh hak cipta dilindungi undang-undang.
