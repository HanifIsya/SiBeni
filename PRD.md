# Product Requirements Document (PRD)
# SI BENI — Siaga Bencana Dini

**Aplikasi Pendukung Keselamatan dan Kesehatan Kerja (K3) & Pengendalian Risiko Bencana di Industri Pertambangan**

---

| Dokumen | Versi | Tanggal | Organisasi Target | Status |
| :--- | :--- | :--- | :--- | :--- |
| **PRD SI BENI** | **1.0.0** | **16 Oktober 2026** | **PT Consnet Mining** | **Approved for Implementation** |

---

## 1. Executive Summary & Product Vision

### 1.1 Latar Belakang & Profil Organisasi
**PT Consnet Mining** merupakan perusahaan pertambangan mineral dan pengangkutan material (*hauling*) berskala besar dengan zona operasional terdistribusi dan medan berat:
- **Pit (Tambang Terbuka)**: Area penggalian aktif dengan dinamika lereng tambang dan alat berat.
- **Jalan Angkut (Haul Road)**: Jalur logistik truk bertonase besar dengan kerentanan debu, licin saat hujan, dan risiko tabrakan/amblas.
- **Stockpile**: Area penimbunan material batuan/bijih dengan risiko longsor timbunan dan swa-bakar (*spontaneous combustion*).
- **Workshop**: Bengkel perbaikan alat berat dengan potensi bahaya kebakaran, mekanikal, dan zat berbahaya.
- **Fasilitas Pengolahan (Processing Plant)**: Jalur *crusher*, *conveyor*, dan *chemical processing*.
- **Gudang (Warehouse)**: Penyimpanan suku cadang, bahan peledak (*explosives magazine*), dan B3 (*Bahan Berbahaya dan Beracun*).
- **Fasilitas Pendukung (Support Facilities)**: Kantor site, mess pekerja, klinik K3, dan gardu kelistrikan.

### 1.2 Visi & Misi K3 Organisasi
- **Visi**: Menjadi perusahaan pertambangan yang aman, produktif, dan berkelanjutan dengan mengutamakan keselamatan pekerja serta pengendalian dampak lingkungan dan emisi karbon.
- **Misi**:
  1. Menerapkan K3 secara konsisten pada seluruh kegiatan operasional pertambangan.
  2. Mengidentifikasi dan mengendalikan bahaya sebelum menimbulkan kecelakaan atau kerugian (*Zero Harm*).
  3. Meningkatkan kesiapsiagaan dan kemampuan tanggap darurat pekerja di area tambang.
  4. Memantau penggunaan energi dan mengupayakan pengurangan emisi karbon dari kegiatan operasional.
  5. Memanfaatkan teknologi informasi untuk meningkatkan kecepatan pelaporan, pemantauan, dan pengambilan keputusan.

### 1.3 Tujuan Strategis Aplikasi SI BENI
Aplikasi **SI BENI (Siaga Bencana Dini)** dirancang untuk menutup celah kritis dalam rantai keselamatan pertambangan:
1. **Menurunkan angka kecelakaan kerja & near miss** melalui pelaporan cepat partisipatif berdurasi < 30 detik.
2. **Mempercepat alur eskalasi dan tindak lanjut (*corrective action*)** dari temuan lapangan ke Tim HSE dan Supervisor.
3. **Meningkatkan kesiapsiagaan darurat** melalui integrasi peringatan dini resmi (BMKG & BNPB), rute evakuasi terdekat, panduan keselamatan kontekstual, dan tombol darurat instan (*Emergency SOS*).
4. **Menjamin keandalan di area *blank spot*** melalui arsitektur *Offline-First* dengan sinkronisasi otomatis (*auto-sync*).
5. **Membangun budaya keselamatan berbasis data** dengan agregasi otomatis metrik K3 (TRIR, Jam Kerja Aman) serta pemantauan energi dan emisi karbon (CO₂e).

---

## 2. Problem Statement & Root Cause Analysis

Berdasarkan kajian operasional lapangan PT Consnet Mining dan riset keselamatan tambang (*Pramayu et al., 2025*), ditemukan masalah mendasar: **"Rendahnya Pelaporan dan Kesiapsiagaan Bahaya di Area Tambang"**.

Berikut dekonstruksi akar penyebab masalah menggunakan **Fishbone Diagram (6M Method)**:

```
                          FISHBONE DIAGRAM K3 INDUSTRI TAMBANG
  MANUSIA (MAN)                METODE (METHOD)                  MESIN (MACHINE)
  ┌───────────────────────┐    ┌───────────────────────────┐    ┌───────────────────────────┐
  │• Budaya lapor near    │    │• Prosedur pelaporan manual│    │• Aplikasi lumpuh tanpa    │
  │  miss masih lemah     │    │  belum sederhana / lambat │    │  koneksi internet         │
  │• Pemahaman tanggap    │    │• Koordinasi keadaan       │    │• Peta evakuasi belum      │
  │  darurat rendah       │    │  darurat belum optimal    │    │  terdigitalisasi          │
  │• Kurang pelatihan     │    │• Alur tindak lanjut       │    │• Belum ada peringatan dini│
  │  tanggap bencana      │    │  temuan belum jelas       │    │  berbasis geolokasi       │
  └───────────┬───────────┘    └─────────────┬─────────────┘    └─────────────┬─────────────┘
              │                              │                                │
              └──────────────────────────────┼────────────────────────────────┘
                                             │
                                             ├──────────────────────────────────► [ AKAR MASALAH UTAMA ]
                                             │                                     Rendahnya Pelaporan
              ┌──────────────────────────────┼────────────────────────────────┐    dan Kesiapsiagaan Bahaya
              │                              │                                │    di Area Tambang
  ┌───────────┴───────────┐    ┌─────────────┴─────────────┐    ┌─────────────┴─────────────┐
  │• Data risiko & ling-  │    │• Area tambang luas &      │    │• Evaluasi K3 belum        │
  │  kungan terpisah-pisah│    │  tersebar multi-zona      │    │  berbasis data real-time  │
  │• Info BMKG/BNPB belum │    │• Jaringan internet tidak  │    │• Koordinasi HSE &         │
  │  sampai ke pekerja pit│    │  stabil (banyak blank spot│    │  supervisor perlu diperkuat
  │• Data energi & emisi  │    │• Cuaca ekstrem, debu tebal│    │• Kebijakan pelaporan belum│
  │  belum terpantau      │    │  longsor, dan kebakaran   │    │  tersosialisasikan merata │
  └───────────────────────┘    └───────────────────────────┘    └───────────────────────────┘
  MATERIAL / DATA (MATERIAL)   LINGKUNGAN (ENVIRONMENT)         MANAJEMEN (MANAGEMENT)
```

### Tabel Matriks Solusi SI BENI terhadap Akar Masalah

| Dimensi Fishbone | Akar Masalah Lapangan | Solusi Implementasi di Aplikasi SI BENI |
| :--- | :--- | :--- |
| **Manusia (Man)** | • Rendahnya inisiatif pelaporan *near miss*<br>• Kebingungan saat terjadi bahaya mendadak | • Form pelaporan ringkas (< 30 detik) dengan kategori cepat & foto<br>• Panduan tanggap darurat kontekstual berbasis jenis bahaya |
| **Metode (Method)** | • Birokrasi pelaporan berbelit-belit<br>• Tindak lanjut (*corrective action*) tidak terpantau | • Alur pelaporan tunggal terstruktur<br>• Pipeline 6 tahap inspeksi K3 & *corrective action* dengan PIC & batas waktu |
| **Mesin (Machine)** | • Sistem gagal beroperasi di *blank spot* lereng tambang<br>• Peta cetak usang | • Arsitektur **Offline-First** (lokal SQLite/Hive + antrean sinkronisasi)<br>• Peta risiko digital 7 zona operasional + rute evakuasi & *assembly point* |
| **Material/Data** | • Peringatan cuaca BMKG/BNPB terhambat di kantor site<br>• Data emisi belum terintegrasi | • Ingesti data resmi BMKG/BNPB langsung ke banner peringatan di perangkat pekerja<br>• Modul pemantauan konsumsi energi (BBM/Listrik/Gas) & emisi CO₂e |
| **Lingkungan (Environment)** | • Medan terbuka ekstrem, sinar matahari terik, sarung tangan pekerja, guncangan kendaraan | • Desain industri kontras tinggi (WCAG AAA), font besar, target sentuh min 52px, tombol SOS 64px |
| **Manajemen (Management)** | • Keputusan K3 bersifat reaktif<br>• Kurangnya sinkronisasi HSE dan site supervisor | • Dashboard web eksekutif terpusat dengan indikator KPI (TRIR, Safe Hours, Emisi CO₂e)<br>• Verifikasi laporan lapangan dan disposisi *corrective action* secara real-time |

---

## 3. User Personas & Platform Architecture

### 3.1 Daftar Aktor & Peran

```
+---------------------------------------------------------------------------------------------------+
|                                       AKTOR & HAK AKSES                                           |
+--------------------------+-----------------------+-----------------------+------------------------+
| 1. Pekerja & Operator    | 2. Supervisor Site    | 3. Tim HSE            | 4. Manajemen Perusahaan|
| (Mobile Android)         | (Mobile + Web)        | (Mobile + Web Admin)  | (Web Executive Dash)   |
+--------------------------+-----------------------+-----------------------+------------------------+
| • Terima peringatan dini | • Verifikasi laporan  | • Validasi temuan K3  | • Tinjau KPI K3 (TRIR) |
| • Lihat peta risiko zona | • Disposisi tugas     | • Kelola peringatan   | • Analisis tren energi |
| • Lapor Bahaya/Near Miss | • Koordinasi darurat  | • Inspeksi periodik   | • Monitoring emisi CO2e|
| • Aktivasi SOS Darurat   | • Pantau zona bahaya  | • Tutup tiket CA      | • Ambil keputusan site |
+--------------------------+-----------------------+-----------------------+------------------------+
                                        ▲
                                        │ Integrasi API Eksternal
                         +------------------------------+
                         | Sumber Resmi: BMKG & BNPB    |
                         | (Prakiraan Cuaca, Gempa, dll)|
                         +------------------------------+
```

### 3.2 Platform Split & Tech Stack
Sesuai arahan teknis:
- **Mobile Frontend**: **Flutter (Dart 3.x)**
  - Target: Android (tablet & smartphone rugged), dukungan Web responsive.
  - State Management: `flutter_bloc` / `riverpod`.
  - Offline Engine: `hive` / `isar` / `sqflite` + `connectivity_plus`.
  - Background Service: Sinkronisasi antrean laporan saat sinyal seluler/WiFi kembali aktif.
- **Database, Auth & Realtime**: **Supabase (PostgreSQL 15+)**
  - Autentikasi: Supabase Auth (Email/ID Karyawan + RBAC Roles: `worker`, `supervisor`, `hse`, `management`).
  - Penyimpanan Berkas: Supabase Storage Bucket (`hazard-photos`, `inspection-evidence`).
  - Realtime Engine: Postgres Changes via WebSocket untuk *live alert*, pembaruan status SOS, dan peta risiko.
  - Keamanan: Row Level Security (RLS) pada seluruh tabel transaksi.
- **Backend Service & Web Dashboard**: **Next.js (App Router / TypeScript) di hosting Render**
  - REST & Webhook APIs: Ingesti data BMKG & BNPB secara otomatis (cron job).
  - Admin & Executive Dashboard: Antarmuka web modern untuk Tim HSE, Supervisor, dan Direksi/Manajemen.
  - Hosting: Web Service di **Render** (`render.yaml` infrastructure-as-code).

---

## 4. Alur Kerja Sistem (Flowchart & Incident Lifecycle)

Alur kerja berikut diadaptasi secara langsung dari bagan **Flowchart Diagram** dokumen desain:

```
[ MULAI ]
    │
    ├──────────────────────────────────────────┐
    ▼                                          ▼
[ Informasi Peringatan Dini ]             [ Penemuan Bahaya ]
  (BMKG / BNPB / Sensor)                    (Oleh Pekerja)
    │                                          │
    └───────────────────┬──────────────────────┘
                        ▼
    [ Pekerja Menerima Informasi / Menemukan Kondisi ]
                        │
                        ▼
            / Apakah Terdapat \
           <   Kondisi Bahaya? >
            \                 /
              ├───────────┬───────────┐
          (TIDAK)         │          (YA)
              │           │           ▼
              │           │   [ Pekerja Melakukan Pelaporan ]
              │           │   [ Melalui Aplikasi SI BENI    ]
              │           │           │
              │           │           ▼
              │           │   [ Input Data Form Terstruktur:  ]
              │           │   [ • Jenis: Bahaya / Near Miss   ]
              │           │   [ • Lokasi: Area Tambang + GPS  ]
              │           │   [ • Kategori Bahaya             ]
              │           │   [ • Waktu Kejadian & Foto       ]
              │           │   [ • Deskripsi / Voice Note      ]
              │           │           │
              │           │           ▼
              │           │   / Ada Jaringan \
              │           │  <   Internet?    >
              │           │   \              /
              │           │    ├────────────┬────────────┐
              │           │ (TIDAK)         │           (YA)
              │           │    │            │            │
              │           │    ▼            │            │
              │           │ [ Simpan Laporan│            │
              │           │   Secara Offline│            │
              │           │   di SQLite/Hive]            │
              │           │    │            │            │
              │           │    ▼            │            │
              │           │ [ Listener Cek  │            │
              │           │   Jaringan Auto ]            │
              │           │    │            │            │
              │           │    └──────┬─────┘            │
              │           │           ▼                  ▼
              │           │      [ Kirim Laporan ke HSE Server ]
              │           │           │
              │           │           ▼
              │           │      [ Laporan Diterima Tim HSE    ]
              │           │           │
              │           │           ▼
              │           │  [ HSE Memverifikasi Laporan       ]
              │           │           │
              │           │           ▼
              │           │   / Kondisi Darurat? \
              │           │  <   (Emergency SOS)  >
              │           │   \                  /
              │           │    ├────────────┬────────────┐
              │           │  (YA)           │         (TIDAK)
              │           │    │            │            │
              │           │    ▼            │            ▼
              │           │ [ Aktifkan      │   [ Tindak Lanjut /      ]
              │           │   Prosedur SOS ]│   [ Corrective Action    ]
              │           │    │            │            │
              │           │    ▼            │            ▼
              │           │ [ Panduan       │   [ Perbaikan Fasilitas, ]
              │           │   Evakuasi &    │   [ Kontrol Risiko Lap.  ]
              │           │   Titik Kumpul ]│            │
              │           │    │            │            ▼
              │           │    ▼            │   [ Monitoring Hasil     ]
              │           │ [ Koordinasi Tim│   [ Tindakan K3          ]
              │           │   Medis/Ambulans│            │
              │           │   & Pemadam ]   │            │
              │           │    │            │            │
              │           │    ▼            │            │
              │           │ [ Penanganan    │            │
              │           │   Darurat TKP ] │            │
              │           │    │            │            │
              │           └────┼────────────┴────────────┘
              │                ▼
              │       [ Monitoring Melalui Dashboard SI BENI ]
              │       [ Sumber Data: Laporan Pekerja, Inspeksi]
              │       [ Lapangan, BMKG/BNPB, Energi & Emisi  ]
              │                │
              │                ▼
              │       [ Evaluasi Data K3:                     ]
              │       [ • Angka Kecelakaan & Near Miss        ]
              │       [ • Kepatuhan K3 & Tindak Lanjut        ]
              │       [ • Konsumsi Energi (BBM/Listrik/Gas)   ]
              │       [ • Estimasi Emisi Karbon (CO2e)        ]
              │                │
              │                ▼
              │       [ Pengambilan Keputusan Strategis       ]
              │       [ & Laporan Berkala ke Manajemen        ]
              │                │
              ▼                ▼
     [ Lanjutkan Aktivitas ] [ SELESAI ]
     [ Tetap Waspada K3    ]
```

---

## 5. Spesifikasi Fungsional 5 Fitur Utama

### 5.1 Fitur 1: Peta Risiko & Peringatan Dini (Screen M-01)
- **Deskripsi**: Menyajikan gambaran spasial keselamatan di 7 zona kerja tambang PT Consnet Mining yang dilengkapi peringatan dini resmi BMKG dan BNPB.
- **7 Zona Kerja Terpetakan**:
  1. `Pit Utama / Pit Utara`
  2. `Jalan Angkut (Haul Road KM 0 - 15)`
  3. `Stockpile & ROM`
  4. `Workshop Alat Berat`
  5. `Fasilitas Pengolahan (Crushing Plant)`
  6. `Gudang Logistik & Handak`
  7. `Fasilitas Pendukung (Mess & Kantor)`
- **Taksonomi 4 Tingkat Risiko (Wajib Konsisten)**:
  - **Rendah (`#16A34A` / Hijau)**: Operasi normal, kondisi aman terkendali.
  - **Sedang (`#EAB308` / Kuning)**: Tingkat waspada; potensi bahaya ringan (kabut, jalan agak licin).
  - **Tinggi (`#F97316` / Oranye)**: Tingkat siaga; bahaya nyata (hujan lebat, kecepatan angin tinggi, retakan lereng minor).
  - **Sangat Tinggi (`#DC2626` / Merah)**: Kondisi bahaya kritis / darurat evakuasi segera (longsor aktif, kebakaran, gas beracun).
- **Banner Peringatan Dini BMKG & BNPB**:
  - Judul peringatan resmi, periode berlaku (misal: *07:00 - 19:00 WIB*), zona terdampak, dan rekomendasi K3.
  - Tag bahaya: `Tanah Longsor`, `Banjir`, `Angin Kencang`, `Debu Ekstrem`, `Kebakaran`.
  - Tombol CTA cepat: `"Lihat Panduan Keselamatan"`.

### 5.2 Fitur 2: Lapor Cepat Bahaya & Near Miss — Offline-First (Screen M-02)
- **Filosofi Form**: Slogan *"Lapor Hari Ini, Cegah Kecelakaan Esok Hari"*. Pelaporan tunggal terstruktur yang tuntas dalam < 30 detik tanpa tahapan *wizard* berbelit.
- **Komponen Form Input**:
  1. **Tipe Kejadian**: Segmented Selector ukuran besar:
     - `⚠️ BAHAYA (HAZARD)`: Kondisi atau tindakan tidak aman (*unsafe condition/act*).
     - `⚡ NEAR MISS`: Insiden hampir celaka yang berpotensi mencederai manusia atau merusak aset.
  2. **Lokasi Area Kerja**:
     - Deteksi otomatis GPS koordinat latitude & longitude (`JetBrains Mono`).
     - Chip pemilih cepat 7 zona operasional tambang.
  3. **Kategori Bahaya (Chip Grid)**:
     - `Alat Berat` (Hauler, Excavator, Grader)
     - `Longsor / Geoteknik` (Retakan lereng, *crest failure*)
     - `Kebakaran` (Panel listrik, tumpahan oli)
     - `Debu / Lingkungan` (Jalan berdebu tanpa *water spray*, limpasan air asam tambang)
     - `Cuaca Ekstrem` (Hujan deras, sambaran petir)
     - `APD & Perilaku Tidak Aman`
  4. **Dokumentasi Foto**:
     - *Dashed camera box* interaktif (tinggi minimum 140px).
     - Kompresi gambar otomatis pada sisi klien (*client-side compression* max 1MB) sebelum disimpan/diunggah.
  5. **Deskripsi Kondisi & Voice Dictation**:
     - Input teks lapang dengan tombol rekam suara (*speech-to-text* atau audio clip).
  6. **Mekanisme Dual-State Submit (Offline-First)**:
     - **Saat Online**: Tombol berwarna Navy/Green `"KIRIM LAPORAN KE HSE"`. Data & foto langsung terunggah ke Supabase.
     - **Saat Offline**: Tombol berubah menjadi Amber (`#D97706`) `"SIMPAN LAPORAN OFFLINE"`. Data disimpan ke antrean lokal (`sync_queue`), menampilkan *toast* konfirmasi dengan hitungan antrean, dan otomatis terkirim begitu terhubung ke jaringan.

### 5.3 Fitur 3: Tanggap Darurat & Evakuasi (Screen M-03)
- **Tombol Darurat (SOS Button)**:
  - Desain tombol merah darah (`#DC2626`) setinggi 64px berbentuk kapsul/lingkaran dengan cincin berdenyut (*pulsing animation*).
  - Mekanisme **Tekan & Tahan 3 Detik** (*Long Press 3s*) untuk mencegah ketidaksengajaan akibat getaran jalan.
  - Aksi instan: Memancarkan broadcast SOS real-time via WebSocket ke seluruh konsol HSE dan Supervisor, memuat identitas pekerja, zona, dan titik koordinat GPS akurat.
- **Filter 5 Jenis Keadaan Darurat**:
  1. `Kebakaran`
  2. `Cedera / Kecelakaan Kerja`
  3. `Kebocoran Bahan Kimia / B3`
  4. `Longsor / Banjir Tambang`
  5. `Ancaman Keamanan / Sabotase`
- **Peta Evakuasi Digital Interaktif**:
  - Menampilkan posisi saat ini pekerja, jalur evakuasi digital (garis hijau putus-putus berarah), serta titik kumpul terdekat (*Assembly Point A, B, C*) lengkap dengan jarak tempuh (misal: *350m - 4 Menit Berjalan*).
- **4 Prinsip Tanggap Darurat (Grid 2×2)**:
  1. *Utamakan Keselamatan Jiwa*
  2. *Laporkan Segera ke Pusat Kendali*
  3. *Ikuti Arahan Petugas Evakuasi*
  4. *Cegah Risiko Lanjutan di Lokasi*
- **6 Langkah Evakuasi Terstruktur (Vertical Stepper)**:
  1. *Kenali Tanda Alarm Darurat*: Hentikan aktivitas kerja dan mesin alat berat segera.
  2. *Menuju Jalur Evakuasi Terdekat*: Ikuti panduan visual rute hijau pada aplikasi atau rambu fisik.
  3. *Tetap Tenang dan Tertib*: Jangan panik, dilarang berlari tergesa-gesa atau berbalik mengambil barang pribadi.
  4. *Menuju Titik Kumpul (Assembly Point)*: Berkumpul di area aman terbuka yang telah ditentukan.
  5. *Ikuti Arahan Petugas HSE*: Tunggu instruksi *Headcount* dan verifikasi keamanan zona.
  6. *Pastikan Seluruh Rekan Telah Dievakuasi*: Berikan konfirmasi kehadiran pada fitur absensi darurat digital.

### 5.4 Fitur 4: Inspeksi K3 & Corrective Action (Screen M-04)
- **Pengguna Utama**: Tim HSE & Pengawas Operasional (Supervisor).
- **Kategori Inspeksi Lapangan**:
  - `Alat Berat & Kendaraan Tambang` (Rem, klakson mundur, sabuk pengaman, APAR unit)
  - `Jalan Angkut (Haul Road)` (Tinggi *safety berm*, *drainase*, kondisi permukaan)
  - `Kepatuhan APD` (Helm, kacamata safety, rompi reflektif, sepatu boots, masker)
  - `Peralatan Pemadam (APAR & Hydrant)` (Tekanan tabung, masa uji, aksesibilitas)
  - `Housekeeping & 5S Area Kerja`
  - `Pengelolaan Lingkungan & Limbah B3`
- **Pipeline 6 Tahapan Corrective Action**:
  ```
  [1. Inspeksi Lapangan] ──► [2. Temuan Bahaya] ──► [3. Verifikasi HSE]
                                                          │
  [6. Selesai & Tutup]   ◄── [5. Perbaikan Fisik] ◄── [4. Penugasan PIC]
  ```
  - Setiap temuan dilengkapi: Tingkat Keparahan (*Critical/High/Medium/Low*), Penanggung Jawab (*PIC Assignment*), Batas Waktu (*Target Due Date*), Bukti Foto Sebelum (*Before*), dan Bukti Foto Sesudah (*After*).

### 5.5 Fitur 5: Dashboard K3, Energi & Emisi (Screen M-05 & W-01)
- **Tujuan**: Konsol analitik untuk Manajemen Eksekutif dan HSE Officer guna memantau *lagging & leading indicators* keselamatan serta parameter keberlanjutan (*ESG*).
- **5 Kartu KPI Utama**:
  1. **Total Jam Kerja Selamat (Safe Man-Hours)**: Target berjalan, e.g., `1.247.652 jam` (`+12,4%`).
  2. **TRIR (Total Recordable Incident Rate)**: e.g., `0,48` (`-20,0%` MoM, di bawah batas ambang industri).
  3. **Total Konsumsi Energi**: e.g., `24.785 GJ` (`-3,1%`).
  4. **Intensitas Energi**: e.g., `2,41 GJ / Ton Material` (`-5,5%` peningkatan efisiensi).
  5. **Total Emisi Gas Rumah Kaca (CO₂e)**: e.g., `12.456 ton CO₂e` (`-6,8%`).
- **Visualisasi Grafik**:
  - **Tren Insiden K3 (Line Chart)**: Jumlah *near miss* vs kecelakaan aktual vs target nol insiden bulanan.
  - **Distribusi Sumber Energi (Donut Chart)**: Listrik PLN/Genset (45%), Gas Alam (25%), Solar Industri/BBM (15%), Bahan Bakar Lain (15%).
  - **Tren Pengurangan Emisi Karbon (Bar/Area Chart)**: Progres dekarbonisasi operasional tambang.

---

## 6. Desain Basis Data (Supabase / PostgreSQL)

Berikut skema tabel terperinci yang siap dimigrasikan ke PostgreSQL Supabase:

### 6.1 Tabel Inti Aplikasi

```sql
-- 1. PROFIL PENGGUNA & PERAN
CREATE TYPE user_role AS ENUM ('worker', 'operator', 'supervisor', 'hse', 'management');
CREATE TYPE risk_level AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE report_type AS ENUM ('hazard', 'near_miss');
CREATE TYPE emergency_type AS ENUM ('fire', 'injury', 'chemical_leak', 'landslide_flood', 'security');
CREATE TYPE ca_status AS ENUM ('inspection', 'identified', 'verified', 'assigned', 'in_progress', 'completed', 'verified_closed');

CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    employee_id VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    phone_number VARCHAR(30),
    role user_role DEFAULT 'worker',
    work_zone VARCHAR(100) DEFAULT 'Pit Utama',
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. MASTER ZONA OPERASIONAL & TINGKAT RISIKO
CREATE TABLE mining_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(30) UNIQUE NOT NULL, -- 'PIT_01', 'HAUL_ROAD', 'STOCKPILE', dll
    name VARCHAR(100) NOT NULL,
    description TEXT,
    current_risk_level risk_level DEFAULT 'low',
    active_hazards TEXT[],
    polygon_coordinates JSONB, -- GeoJSON Polygons batas zona
    evacuation_assembly_point VARCHAR(100),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. PERINGATAN DINI (BMKG & BNPB)
CREATE TABLE early_warnings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source VARCHAR(50) NOT NULL, -- 'BMKG', 'BNPB', 'HSE_INTERNAL'
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    severity risk_level NOT NULL,
    affected_zones TEXT[] NOT NULL,
    hazard_tags TEXT[] NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    safety_instructions TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. LAPORAN BAHAYA & NEAR MISS (OFFLINE-CAPABLE SYNC)
CREATE TABLE hazard_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    local_id VARCHAR(100), -- ID dari client sqlite untuk rekonsiliasi idempotensi
    reporter_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    report_type report_type NOT NULL,
    zone_id UUID REFERENCES mining_zones(id) ON DELETE SET NULL,
    zone_name VARCHAR(100) NOT NULL,
    category VARCHAR(100) NOT NULL, -- 'Alat Berat', 'Longsor', dll
    incident_timestamp TIMESTAMPTZ NOT NULL,
    gps_latitude NUMERIC(10, 7),
    gps_longitude NUMERIC(10, 7),
    description TEXT NOT NULL,
    photo_urls TEXT[],
    audio_note_url TEXT,
    is_emergency BOOLEAN DEFAULT FALSE,
    sync_status VARCHAR(30) DEFAULT 'synced',
    hse_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. INSIDEN DARURAT & BROADCAST SOS
CREATE TABLE emergency_sos_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    worker_name VARCHAR(150),
    zone_name VARCHAR(100),
    gps_latitude NUMERIC(10, 7),
    gps_longitude NUMERIC(10, 7),
    emergency_type emergency_type,
    status VARCHAR(50) DEFAULT 'ACTIVE', -- 'ACTIVE', 'RESPONDED', 'RESOLVED'
    responded_by UUID REFERENCES profiles(id),
    responded_at TIMESTAMPTZ,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. INSPEKSI K3 & CORRECTIVE ACTION PIPELINE
CREATE TABLE k3_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inspector_id UUID REFERENCES profiles(id),
    inspection_category VARCHAR(100) NOT NULL, -- 'APD', 'Alat Berat', 'APAR', dll
    zone_id UUID REFERENCES mining_zones(id),
    title VARCHAR(200) NOT NULL,
    notes TEXT,
    inspection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE corrective_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inspection_id UUID REFERENCES k3_inspections(id) ON DELETE CASCADE,
    hazard_report_id UUID REFERENCES hazard_reports(id) ON DELETE SET NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    severity risk_level NOT NULL DEFAULT 'medium',
    status ca_status DEFAULT 'inspection',
    assigned_pic_id UUID REFERENCES profiles(id),
    assigned_pic_name VARCHAR(150),
    target_due_date DATE NOT NULL,
    completion_date DATE,
    evidence_photo_before TEXT,
    evidence_photo_after TEXT,
    hse_verifier_id UUID REFERENCES profiles(id),
    hse_verification_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. LOG KONSUMSI ENERGI & EMISI KARBON (ESG)
CREATE TABLE energy_emission_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_date DATE NOT NULL UNIQUE,
    safe_man_hours NUMERIC(12, 2) DEFAULT 0,
    total_recordable_incidents INT DEFAULT 0,
    calculated_trir NUMERIC(6, 3) DEFAULT 0,
    energy_electricity_gj NUMERIC(10, 2) DEFAULT 0,
    energy_natural_gas_gj NUMERIC(10, 2) DEFAULT 0,
    energy_diesel_fuel_gj NUMERIC(10, 2) DEFAULT 0,
    energy_other_gj NUMERIC(10, 2) DEFAULT 0,
    total_energy_gj NUMERIC(10, 2) DEFAULT 0,
    material_hauled_ton NUMERIC(12, 2) DEFAULT 0,
    energy_intensity_gj_per_ton NUMERIC(8, 4) DEFAULT 0,
    total_co2e_emissions_ton NUMERIC(10, 2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 7. Arsitektur Teknis & Mekanisme Sinkronisasi

### 7.1 Strategi Offline-First Mobile (Flutter)
1. **Penyimpanan Lokal**:
   - SQLite (`sqflite`) atau `Hive` menyimpan cache profil pengguna, konfigurasi zona tambang, rute evakuasi, dan antrean data `sync_queue`.
2. **Idempotent Sync Queue**:
   - Setiap laporan yang dibuat dalam mode offline diberikan `local_uuid`.
   - Foto dikompresi dan disimpan secara lokal di direktori `ApplicationDocumentsDirectory`.
   - Ketika koneksi terdeteksi via `connectivity_plus`, background sync worker memicu pengunggahan berkas ke Supabase Storage, dilanjutkan dengan pengiriman payload data melalui REST API/Supabase SDK dengan penanganan transaksi atomic.

```
[ Form Lapor Lapangan ]
          │
          ▼
   / Ada Koneksi? \
  <   Internet     >
   \              /
    ├───► (YA)  ──► Upload Berkas ke Storage ──► Insert DB Supabase ──► Status: SYNCED
    │
    └───► (TIDAK) ──► Simpan ke Hive/SQLite (Queue: PENDING)
                            │
                            ▼
                    [ Connectivity Listener ]
                            │
                  (Koneksi Tersedia Kembali)
                            │
                            ▼
                    Eksekusi Antrean Sinkronisasi (FIFO)
                    ──► Upload Berkas ──► Insert DB ──► Status: SYNCED
```

### 7.2 Backend & Web Service (Next.js di Render)
- **Peran Backend**:
  1. **Ingestor BMKG/BNPB**: Endpoint Cron Job terjadwal yang membaca API publik BMKG untuk prakiraan cuaca ekstrem & gempa, lalu memperbarui tabel `early_warnings` dan memicu notifikasi push ke aplikasi seluler.
  2. **Konsol Web Dashboard**: Antarmuka responsif bagi Manajemen dan Tim HSE untuk mengelola verifikasi tiket *Corrective Action*, pemetaan spasial zona bahaya, dan visualisasi grafik KPI K3/Emisi.
  3. **Webhook Notifications**: Mengirimkan notifikasi darurat via WhatsApp/Telegram Bot atau Push Notification saat tombol SOS diaktifkan.

---

## 8. Panduan Desain & UI/UX (Sesuai `DESIGN.md`)

- **Palet Warna Utama**:
  - `brand-primary`: `#0F4C81` (Deep Industrial Navy)
  - `brand-secondary`: `#00B4D8` (SI BENI Robot Cyan)
  - `brand-safety-green`: `#15803D` (K3 Safety Emerald)
  - `surface-bg`: `#F8FAFC`
  - `border-subtle`: `#CBD5E1` (Batas tegas 1px kontras tinggi di bawah sinar terik matahari)
- **Tingkat Risiko 4-Warna**:
  - Rendah: `#16A34A`
  - Sedang: `#EAB308`
  - Tinggi: `#F97316`
  - Sangat Tinggi: `#DC2626`
- **Tipografi**:
  - Display & Body: `Plus Jakarta Sans` / `Inter`
  - Telemetri & Angka KPI: `JetBrains Mono` / Monospace (*tabular figures*)
- **Ergonomi Lapangan**:
  - Minimal ukuran tap target: `52×52px` (ramah sarung tangan).
  - Tombol darurat SOS: `64px` tinggi kapsul/lingkaran dengan gestur *hold 3 seconds*.

---

## 9. Non-Functional Requirements (NFR)

1. **Availability & Reliability**: Ketersediaan fitur keselamatan darurat 99.9% di level klien tanpa ketergantungan mutlak pada sinyal jaringan (*Offline-First*).
2. **Latency**:
   - Pemicuan tombol SOS terkirim ke server < 1.5 detik pada koneksi normal.
   - Waktu muat form pelaporan bahaya < 500 ms di perangkat seluler.
3. **Data Integrity & Security**:
   - Enkripsi transmisi TLS 1.3 / HTTPS.
   - Row Level Security (RLS) PostgreSQL untuk membatasi akses edit laporan hanya oleh pemilik atau Tim HSE.
4. **Usability**: Tingkat keterbacaan teks memenuhi standar WCAG AAA untuk kontras di bawah cahaya terik matahari tambang terbuka (*open pit*).

---

## 10. Indikator Keberhasilan (KPI) Proyek

1. **Kecepatan Pelaporan Bahaya**: Rata-rata waktu pengisian laporan bahaya/near miss berkurang dari sebelumnya manual (> 2 jam) menjadi < 30 detik secara digital.
2. **Tingkat Partisipasi Pekerja**: Kenaikan jumlah laporan *near miss* proaktif sebesar > 40% dalam 3 bulan pertama implementasi.
3. **Waktu Respon Darurat**: Penurunan durasi eskalasi insiden darurat ke tim tanggap darurat menjadi < 2 menit pasca tombol SOS ditekan.
4. **Penyelesaian Corrective Action**: > 90% tindakan perbaikan terselesaikan tepat waktu sebelum batas *target due date*.
5. **Keberlanjutan Lingkungan**: Ketersediaan data analitik real-time konsumsi BBM dan estimasi emisi karbon untuk audit ESG perusahaan.
