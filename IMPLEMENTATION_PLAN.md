# Implementation Plan & Action Roadmap
# SI BENI — Siaga Bencana Dini

**Target Repositori**: [https://github.com/HanifIsya/SiBeni](https://github.com/HanifIsya/SiBeni)  
**Arsitektur**: Mobile (Flutter) + Cloud Database/Storage/Auth (Supabase) + Backend Service & Web Dashboard (Next.js di Render)

---

## 1. Struktur Repositori (Monorepo Blueprint)

Repositori diorganisasi secara modular untuk memfasilitasi pengembangan frontend Flutter, backend Next.js, dan skema Supabase:

```
SiBeni/
├── docs/                               # Dokumentasi Teknis & Diagram
│   ├── diagrams/                       # Diagram Fishbone, Flowchart, dan Arsitektur
│   │   ├── fishbone_diagram.png
│   │   └── flowchart_diagram.png
│   ├── PRD.md                          # Product Requirements Document
│   └── IMPLEMENTATION_PLAN.md          # Dokumen Perencanaan & Roadmap Tindakan
├── DESIGN.md                           # Industrial K3 Design System & Spesifikasi UI
├── KELOMPOK 3_HIP 3A_TUGAS 2.pdf       # Dokumen Sumber Kajian Akademik & Perancangan
├── supabase/                           # Skema Basis Data, Migrasi, & Kebijakan Keamanan
│   ├── migrations/
│   │   ├── 001_initial_schema.sql      # Tabel: profiles, zones, reports, emergency, ca, esg
│   │   └── 002_rls_and_policies.sql    # Row Level Security & Hak Akses Berbasis Peran
│   └── seed.sql                        # Data Awal: 7 Zona Tambang, Peringatan BMKG, KPI Sampel
├── backend/                            # Next.js Full-Stack Web Dashboard & API (Render)
│   ├── src/
│   │   ├── app/                        # Next.js App Router (Dashboard & Web Admin)
│   │   │   ├── api/                    # REST Endpoints (BMKG sync, SOS broadcast, webhooks)
│   │   │   │   ├── bmkg/route.ts
│   │   │   │   ├── emergency/route.ts
│   │   │   │   └── reports/route.ts
│   │   │   ├── dashboard/              # Web Dashboard Eksekutif K3, Energi & Emisi
│   │   │   ├── inspections/            # Manajemen & Verifikasi Corrective Action
│   │   │   ├── risk-map/               # Monitoring Peta Risiko Tambang Terpusat
│   │   │   ├── layout.tsx
│   │   │   └── page.tsx
│   │   ├── components/                 # Komponen UI Web (Shadcn/Tailwind)
│   │   └── lib/                        # Supabase Client, BMKG Ingestor, Utilities
│   ├── package.json
│   ├── tsconfig.json
│   └── render.yaml                     # Render Blueprints Infrastructure-as-Code
└── frontend/                           # Aplikasi Mobile Android & Web (Flutter)
    ├── lib/
    │   ├── core/                       # Desain Sistem, Konstanta, Tema & Klien Jaringan
    │   │   ├── theme/                  # Palet Warna K3, Tipografi, Dimensi Target Sentuh
    │   │   ├── constants/              # 7 Zona Operasional, 4 Tingkat Risiko
    │   │   └── database/               # Offline Database (Hive/SQLite Local Storage)
    │   ├── features/
    │   │   ├── risk_map/               # M-01: Peta Risiko Tambang & Peringatan BMKG
    │   │   ├── quick_report/           # M-02: Lapor Cepat Bahaya & Near Miss (Offline-First)
    │   │   ├── emergency_sos/          # M-03: Tanggap Darurat, SOS 3s & Peta Evakuasi
    │   │   ├── k3_inspection/          # M-04: Inspeksi K3 & Pipeline Corrective Action
    │   │   └── esg_dashboard/          # M-05: Dashboard Mobile Metrik K3, Energi & Emisi
    │   └── main.dart                   # Titik Masuk Aplikasi Flutter
    └── pubspec.yaml
```

---

## 2. Rencana Tahapan Eksekusi (Phase-by-Phase Execution Plan)

### Fase 1: Fondasi Proyek, Skema Basis Data & Konfigurasi Lingkungan
- [x] Inisialisasi Git lokal & remote `https://github.com/HanifIsya/SiBeni.git`.
- [x] Susun dokumen `PRD.md` lengkap berdasarkan kajian PDF & `DESIGN.md`.
- [x] Susun `IMPLEMENTATION_PLAN.md` sebagai panduan eksekusi menyeluruh.
- [ ] Buat file migrasi SQL Supabase (`supabase/migrations/001_initial_schema.sql` dan `002_rls_and_policies.sql`).
- [ ] Siapkan seed data komprehensif (`supabase/seed.sql`) untuk 7 zona tambang, data simulasi BMKG, riwayat bahaya, dan metrik ESG.
- [ ] Buat konfigurasi `.env.example` dan dokumentasi koneksi Supabase & Render.

### Fase 2: Backend Service & Web Dashboard (Next.js di Render)
- [ ] Inisialisasi proyek Next.js TypeScript di direktori `backend/`.
- [ ] Konfigurasi Tailwind CSS sesuai palet warna industri `DESIGN.md` (`#0F4C81`, `#00B4D8`, `#15803D`, 4 tingkat risiko).
- [ ] Buat API Endpoint:
  - `GET/POST /api/bmkg`: Ingesti data peringatan dini cuaca & gempa.
  - `POST /api/emergency`: Penanganan darurat broadcast SOS real-time.
  - `GET/POST /api/reports`: Sinkronisasi batch laporan bahaya dari mobile offline.
  - `GET /api/kpi`: Metrik keselamatan (TRIR, Jam Kerja Selamat) dan estimasi emisi karbon.
- [ ] Bangun antarmuka Dashboard Web (Screen W-01):
  - Sidebar navigasi gelap (`#0B192C`).
  - 5 Kartu KPI teratas (Jam Selamat, TRIR, Energi, Intensitas, Emisi CO₂e).
  - Grafik tren insiden K3, distribusi konsumsi energi, dan tren penurunan emisi.
  - Tabel verifikasi laporan lapangan & matriks *Corrective Action*.
- [ ] Konfigurasi deployment Render (`render.yaml` / Render Web Service).

### Fase 3: Aplikasi Mobile Flutter (Android Offline-First)
- [ ] Inisialisasi proyek Flutter di direktori `frontend/`.
- [ ] Implementasikan Tema SI BENI (`theme.dart`):
  - Palet warna kontras tinggi, font `Plus Jakarta Sans` / `Inter`, angka `JetBrains Mono`.
  - Target sentuh minimum 52px, tombol darurat SOS 64px.
- [ ] Bangun Engine Offline-First:
  - Cache lokal untuk data zona, instruksi evakuasi, dan antrean pengiriman laporan.
  - Listener konektivitas untuk auto-sync begitu perangkat mendapatkan sinyal.
- [ ] Kembangkan 5 Tampilan Utama:
  - **M-01: Beranda & Peta Risiko**: Header status koneksi online/offline, banner peringatan BMKG/BNPB, peta interaktif 7 zona tambang berlatar 4 tingkat risiko, tombol SOS mengambang.
  - **M-02: Lapor Cepat Bahaya & Near Miss**: Toggle Bahaya vs Near Miss, pemilih zona kerja & GPS otomatis, grid chip kategori bahaya, box ambil foto bukti, input suara/teks, tombol simpan lokal / kirim.
  - **M-03: Tanggap Darurat & Evakuasi**: Tombol SOS tekan 3 detik beranimasi denyut (*pulse*), 5 filter jenis darurat, peta jalur evakuasi & *assembly point*, 4 prinsip darurat, dan vertical stepper 6 langkah evakuasi.
  - **M-04: Inspeksi K3 & Corrective Action**: Filter kategori (APD, Alat Berat, Haul Road, APAR, dll), checklist kondisi, pelacak alur 6 tahap dari temuan sampai penutupan tiket.
  - **M-05: Dashboard Mobile Eksekutif**: Tinjauan KPI K3, perincian sumber energi tambang, dan grafik tren emisi karbon bulanan.

### Fase 4: Integrasi Antar-Layanan & Pengujian (Verification)
- [ ] Verifikasi alur sinkronisasi offline-to-online:
  - Buat laporan saat perangkat berada dalam mode pesawat (offline).
  - Pastikan banner amber menampilkan hitungan laporan tersimpan lokal.
  - Matikan mode pesawat, pastikan data otomatis terunggah ke Supabase tanpa duplikasi.
- [ ] Verifikasi alur tombol darurat SOS:
  - Tahan tombol SOS selama 3 detik.
  - Pastikan event SOS tercatat di Supabase dan dashboard web menerima broadcast darurat secara real-time.
- [ ] Verifikasi visual UI terhadap token desain pada `DESIGN.md`.

### Fase 5: Version Control, GitHub Push & Deployment Render
- [ ] Buat commit terstruktur:
  - `docs: add comprehensive PRD and implementation roadmap`
  - `feat(db): add supabase schema, rls policies, and seed data`
  - `feat(backend): initialize Next.js web dashboard and api for Render`
  - `feat(frontend): initialize Flutter mobile app with offline-first design system`
- [ ] Push seluruh kode dan artefak ke remote GitHub: `https://github.com/HanifIsya/SiBeni`.
- [ ] Siapkan konfigurasi service Render dan panduan CI/CD GitHub Actions.

---

## 3. Matriks Kesiapan Alat & Layanan (Tools & MCP Readiness)

| Layanan / Alat | Kegunaan | Status Integrasi | Catatan Operasional |
| :--- | :--- | :--- | :--- |
| **GitHub CLI / Git** | Version control & remote repository hosting | Terkoneksi sebagai `HanifIsya` | Siap untuk push commit ke repositori target `SiBeni`. |
| **Supabase MCP** | Manajemen basis data PostgreSQL, Auth, dan Storage | Terhubung ke project `ezcgzrygygmliwnfdhsh` | Migrasi skema SQL dan seed data disiapkan secara lokal dan diaplikasikan. |
| **Render MCP** | Hosting backend web service & web dashboard Next.js | Workspace teridentifikasi (`tea-dapt77bbc2fs73bv2de0`) | Service Next.js dapat dideploy via `render.yaml` atau create web service. |
| **Google Stitch MCP** | Penataan komponen UI & inspeksi aset visual | Aktif | Tersedia panduan prompt pada `DESIGN.md` untuk sinkronisasi layout. |
| **Flutter SDK** | Kompilasi aplikasi Android mobile & Web | Flutter 3.41.1 terpasang lokal | SDK Android 36.1.0 & Chrome web compiler siap. |
| **Node.js / npm** | Runtime backend Next.js | Node v24.12.0 & npm terpasang | Kompatibel dengan Next.js App Router terbaru. |

---

## 4. Langkah Awal Segera (Next Immediate Action)

Setelah dokumen `PRD.md` dan `IMPLEMENTATION_PLAN.md` disetujui, tindakan berikutnya yang akan langsung dieksekusi:
1. Menyiapkan skema migrasi database SQL (`supabase/migrations/`) dan seed data realistis untuk PT Consnet Mining.
2. Menginisialisasi proyek backend Next.js dengan dashboard analitik dan REST API untuk Render.
3. Menginisialisasi aplikasi frontend Flutter dengan konfigurasi tema industri, offline database, dan layar antarmuka.
4. Melakukan commit berkala dan push ke `https://github.com/HanifIsya/SiBeni`.
