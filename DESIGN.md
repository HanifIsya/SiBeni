# SPESIFIKASI DESAIN SISTEM & PANDUAN ANTARMUKA PENGGUNA (UI/UX)
# SI BENI — Siaga Bencana Dini

**Aplikasi Bergerak Keselamatan dan Kesehatan Kerja (K3) Industri Pertambangan**  
**Standar Kepatuhan**: Kepmen ESDM No. 1827 K/30/MEM/2018 | ISO 45001:2018 (Occupational Health & Safety)  
**Organisasi Operasional**: PT Consnet Mining  
**Platform**: Android Mobile (Offline-First) & Responsive Web HSE Dashboard  
**Versi Dokumen**: 2.0.0 (Production Release)

---

## 1. Filosofi Desain Industri Tambang (Field Ergonomics)

Operasional pertambangan terbuka (*open pit*) dan jalur pengangkutan material (*hauling road*) menghadirkan tantangan lingkungan ekstrem yang tidak dijumpai pada aplikasi komersial biasa:
1. **Intensitas Cahaya Matahari Tinggi (Sunlight Glare)**: Penggunaan di bawah terik matahari langsung mewajibkan rasio kontras visual minimum **WCAG AAA (7:1)**. Elemen transparan, gradien tipis (*glassmorphism*), dan abu-abu muda dilarang pada elemen interaktif utama.
2. **Penggunaan Sarung Tangan K3 (Heavy-Duty Work Gloves)**: Seluruh target sentuh (*touch target*) memiliki dimensi minimum **52 × 52 dp**, dengan jarak antar-elemen sentuh minimum **12 dp** untuk mengeliminasi salah ketuk akibat getaran kabin alat berat.
3. **Keterbatasan Jaringan & Blank Spot (Offline-First Integrity)**: Jaringan seluler di dasar pit tambang bersifat intermiten. Status jaringan wajib ditampilkan secara transparan, dengan mekanisme penyimpanan lokal otomatis dan pengiriman tanpa kehilangan data (*zero data loss*).
4. **Keadaan Darurat Tanpa Ambivalensi (Zero Latency SOS)**: Tombol darurat wajib dapat diakses seketika dengan gestur pengaman tahan 3 detik (*3-second intentional hold*) yang disertai umpan balik haptik/getar.

---

## 2. Token Warna & Taksonomi Risiko K3

Sistem warna SI BENI mengadopsi standar rambu keselamatan pertambangan Republik Indonesia:

```
  [ BRAND NAVY ]       [ K3 SAFETY EMERALD ]       [ WARNING AMBER ]       [ CRITICAL CRIMSON ]
     #0F4C81                  #15803D                   #D97706                   #DC2626
  (Struktur & Topbar)       (Status Aman & Lulus)      (Offline & Waspada)       (SOS & Bahaya Kritis)
```

### 2.1 Palet Utama
- **Brand Primary (`#0F4C81`, Deep Industrial Navy)**: Digunakan pada AppBar, tombol aksi utama, dan kartu penanda identitas resmi PT Consnet Mining.
- **Brand Secondary (`#00B4D8`, Cyan Siaga)**: Aksen visual untuk indikator telemetri, ikon teknologi, dan radar BMKG.
- **Brand Safety Green (`#15803D`, Emerald K3)**: Penanda status kepatuhan, inspeksi lulus, jalur evakuasi aman, dan dekarbonisasi.

### 2.2 Taksonomi 4 Tingkat Risiko (*Risk Level*)

| Tingkat Risiko | Kode Warna Fill | Warna Latar / Badge | Arti & Tindakan Operasional di Tambang |
| :--- | :--- | :--- | :--- |
| **Rendah (Low)** | `#16A34A` | `#DCFCE7` | Kondisi kerja normal; waspada biasa. Tidak ada anomali lereng/cuaca. |
| **Sedang (Medium)** | `#EAB308` | `#FEF9C3` | Waspada (*Caution*); debu tebal, kabut pagi, atau pekerjaan panas di bengkel. |
| **Tinggi (High)** | `#F97316` | `#FFEDD5` | Siaga (*High Hazard*); hujan lebat, jalan hauling licin, retakan lereng minor. Kecepatan maksimal hauler dibatasi 25 km/jam. |
| **Sangat Tinggi (Critical)** | `#DC2626` | `#FEE2E2` | Bahaya Segera (*Evacuation / Emergency*); longsor aktif, kebakaran unit, kebocoran B3, atau tombol SOS aktif. |

### 2.3 Status Konektivitas Lapangan
- **Terhubung (Online)**: Latar hijau lembut (`#F0FDF4`), teks `#15803D`. Menandakan koneksi live ke Supabase dan BMKG.
- **Mode Offline (Antrean Lokal)**: Latar kuning jingga (`#FEF3C7`), border `#D97706`, teks `#92400E`. Menyatakan data tersimpan di penyimpanan lokal perangkat dan akan disinkronisasi otomatis begitu sinyal pulih.

---

## 3. Tipografi & Tata Huruf

- **Font Antarmuka**: `Plus Jakarta Sans` / `Inter`
  - Dipilih karena geometri huruf yang kokoh (*tall x-height*) dan keterbacaan tinggi pada layar smartphone dengan pelindung layar anti-gores tebal.
- **Font Telemetri & Data Angka**: `JetBrains Mono` / Monospace Tabular
  - Digunakan untuk seluruh koordinat GPS (`-2.1458291, 115.3489124`), nomor NRP/NIK karyawan (`OP-104`), catatan waktu (*timestamp*), dan angka analitik KPI (`1.247.652 jam`).

---

## 4. Arsitektur Layar & Alur Pengguna

### 4.1 Autentikasi Pengguna Riil (Login & Pendaftaran)
- **Login Akun**: Menggunakan email resmi atau nomor NRP/NIK terdaftar dan kata sandi terenkripsi via **Supabase Auth**.
- **Pendaftaran Karyawan Baru (Self-Registration)**: Memungkinkan pekerja baru mendaftarkan diri dengan mengisi Nama Lengkap, NRP Karyawan, Peran Kerja (*Role*), Zona Tambang, dan Kata Sandi.
- **Pemisahan Peran Pengguna (Role-Based Access Control)**:
  1. *Pekerja / Operator*: Mengakses Peta Risiko, Form Lapor Cepat Bahaya/Near Miss, dan Tombol Darurat SOS.
  2. *Supervisor*: Memperoleh akses modul Inspeksi Lapangan K3 dan verifikasi temuan *Corrective Action*.
  3. *Tim HSE*: Kontrol penuh siklus hidup tiket perbaikan (Tahap 1 s/d 6), siaga SOS, dan Dashboard K3 terpadu.
  4. *Manajemen Eksekutif*: Dashboard analitik metrik K3 (Jam Kerja Selamat, TRIR) dan pemantauan ESG energi serta emisi karbon.

### 4.2 M-01: Peta Risiko Tambang (OpenStreetMap Terintegrasi)
- Peta geospasial interaktif menggunakan engine **OpenStreetMap** (`flutter_map`), mendukung gestur geser (*pan*), perbesar (*pinch zoom*), dan rotasi.
- Menampilkan 7 zona operasional PT Consnet Mining:
  1. `Pit Utama` (Area penambangan aktif)
  2. `Jalan Angkut KM 0-15` (Haul Road)
  3. `Stockpile & ROM Timbunan`
  4. `Workshop & Maintenance Alat Berat`
  5. `Fasilitas Pengolahan` (Crusher Plant)
  6. `Gudang Logistik & Handak`
  7. `Fasilitas Pendukung` (Klinik & Site Office)
- Setiap zona memiliki pin interaktif dengan warna tingkat risiko dan informasi titik kumpul (*Assembly Point*).
- Posisi GPS riil pekerja ditampilkan dengan penanda lingkaran biru cerah berdenyut.

### 4.3 M-02: Form Lapor Cepat Bahaya & Near Miss (Offline-First)
- Format pelaporan tunggal terstruktur yang tuntas dalam waktu **< 30 detik**:
  1. Pemilih Tipe Insiden: Kartu besar **BAHAYA** vs **NEAR MISS**.
  2. Deteksi otomatis koordinat GPS dan pemilihan zona operasional.
  3. Grid chip kategori bahaya: *Alat Berat, Longsor/Geoteknik, Kebakaran, Debu/Lingkungan, Cuaca Ekstrem, APD*.
  4. Kotak foto bukti bahaya dengan kompresi otomatis pada klien (< 1 MB).
  5. Input deskripsi dengan dukungan dikte suara (*voice note*).
  6. Tombol simpan dual-state: *"KIRIM LAPORAN KE HSE"* saat online, dan *"SIMPAN LAPORAN OFFLINE"* saat tidak ada sinyal.

### 4.4 M-03: Tanggap Darurat & SOS 3 Detik
- Tombol **TOMBOL DARURAT (SOS)** setinggi 64 dp dengan animasi bar penahan 3 detik (*3s Hold-to-Activate*) untuk mencegah aktivasi tak sengaja akibat guncangan kendaraan.
- Begitu terpicu:
  - Menyimpan catatan SOS ke tabel `emergency_sos_logs` di Supabase.
  - Membuka dialog konfirmasi darurat dengan rute evakuasi menuju *Titik Kumpul (Assembly Point)* terdekat.
  - Menampilkan 4 Prinsip Tanggap Darurat dan 6 Langkah Evakuasi Terstruktur.

### 4.5 M-04: Inspeksi K3 & Pelacak Tindak Lanjut (*Corrective Action*)
- Checklist kepatuhan keselamatan berkala (*APD, Alat Berat, Jalan Angkut, APAR, Housekeeping, Lingkungan*).
- Visualisasi alur 6 tahap *Corrective Action* berstandar K3:
  `1. Inspeksi Lapangan` $\rightarrow$ `2. Temuan Bahaya` $\rightarrow$ `3. Verifikasi HSE` $\rightarrow$ `4. Penugasan PIC` $\rightarrow$ `5. Perbaikan Fisik` $\rightarrow$ `6. Selesai & Ditutup`.
- Pengguna dengan peran Supervisor atau HSE dapat memajukan tahapan tiket dengan catatan verifikasi digital.

### 4.6 M-05: Dashboard Analitik K3, Energi & Emisi Karbon
- Menampilkan 5 kartu metrik utama:
  - Total Jam Kerja Selamat (*Safe Man-Hours*): `1.247.652 jam`
  - Tingkat Kejadian Kecelakaan (*TRIR*): `0,48`
  - Konsumsi Energi Total: `24.785 GJ`
  - Intensitas Energi: `2,41 GJ/ton material`
  - Total Emisi Karbon: `12.456 ton CO₂e`
- Diagram batang komposisi sumber energi: Listrik PLN & Genset (45%), Gas Alam (25%), Solar Industri BBM (15%), Lainnya (15%).

---

## 5. Standar Kode & Kualitas Produksi

1. **Zero Raw Hardcoding**: Semua data zona, peringatan cuaca, tiket tindakan perbaikan, dan angka KPI ditarik langsung dari database PostgreSQL Supabase via REST API live di Render.
2. **Offline Graceful Degradation**: Jika jaringan terputus, aplikasi tidak boleh menampilkan layar putih/crash, melainkan menggunakan data cache terenkripsi lokal dan menampilkan status antrean offline.
3. **Penyimpanan Kredensial Aman**: Sesi autentikasi disimpan menggunakan penyimpanan aman lokal (`shared_preferences` / Supabase Session Storage) dengan pembaruan token otomatis.
