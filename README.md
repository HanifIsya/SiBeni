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
- 🎨 **[Design System (DESIGN.md)](./DESIGN.md)**: Sistem desain industri tangguh (*Rugged Industrial UI*), rasio kontras tinggi di bawah sinar terik matahari, taksonomi 4 tingkat risiko warna K3, ergonomi sarung tangan (target sentuh 52px, tombol SOS 64px), dan cetak biru layar (M-01 s/d M-05 & W-01).

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

## ⚡ 5 Fitur Utama SI BENI

1. **Peta Risiko & Peringatan Dini (Screen M-01)**
   - Pemetaan spasial 7 zona kerja operasional tambang: *Pit Utama, Jalan Angkut KM 0-15, Stockpile, Workshop, Fasilitas Pengolahan, Gudang Handak, dan Fasilitas Pendukung*.
   - Standarisasi 4 Tingkat Risiko: **Rendah (Hijau)**, **Sedang (Kuning)**, **Tinggi (Oranye)**, **Sangat Tinggi (Merah)**.
   - Peringatan dini resmi dari BMKG & BNPB untuk mitigasi cuaca ekstrem, tanah longsor, dan banjir.

2. **Lapor Cepat Bahaya & Near Miss — Offline-First (Screen M-02)**
   - Slogan: *"Lapor Hari Ini, Cegah Kecelakaan Esok Hari"*.
   - Alur tunggal terstruktur dalam tempo < 30 detik: pemilih tipe insiden (*Bahaya* vs *Near Miss*), tagging koordinat GPS & zona otomatis, kategori bahaya, kamera kompresi instan, dan input deskripsi / suara.
   - **Mode Offline**: Laporan disimpan lokal di SQLite/Hive dan disinkronisasikan secara otomatis saat terhubung kembali ke jaringan (*auto-sync*).

3. **Tanggap Darurat, SOS 3 Detik & Peta Evakuasi (Screen M-03)**
   - **Tombol Darurat (SOS)** tinggi 64px dengan gestur tekan-tahan 3 detik (*Long-Press 3s*) untuk menghindari kepencet di jalan tambang.
   - 5 Filter Keadaan Darurat (*Kebakaran, Cedera, B3, Longsor/Banjir, Keamanan*).
   - Jalur evakuasi digital ke *Assembly Point* terdekat, 4 prinsip darurat, dan *stepper* 6 langkah evakuasi.

4. **Inspeksi K3 & Corrective Action (Screen M-04)**
   - Checklist digital berkala: *APD, Alat Berat, Jalan Angkut, APAR, Housekeeping, Lingkungan*.
   - Alur 6 Tahap Tindak Lanjut (*Inspection → Identified → Verified → Assigned → In Progress → Closed*).

5. **Dashboard K3, Energi & Emisi Karbon (Screen M-05 & W-01)**
   - 5 KPI Teratas:
     - Total Jam Kerja Aman (*Safe Man-Hours*): `1.247.652 jam`
     - TRIR (*Total Recordable Incident Rate*): `0,48`
     - Konsumsi Energi Total: `24.785 GJ`
     - Intensitas Energi: `2,41 GJ/ton`
     - Emisi Karbon Total: `12.456 ton CO₂e`
   - Grafik tren insiden bulanan, diagram sumber energi (Listrik 45%, Gas Alam 25%, BBM 15%, Lainnya 15%), dan progres dekarbonisasi.

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
3. Masukkan data awal dengan menjalankan:
   - `supabase/seed.sql`

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
