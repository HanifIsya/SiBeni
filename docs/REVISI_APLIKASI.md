# Revisi Aplikasi SI BENI — Tanggapan Masukan Klien (Oktober 2026)

Dokumen ini mencatat seluruh revisi yang dikerjakan berdasarkan masukan klien pada
uji coba aplikasi: pemisahan alur kerja per peran, perbaikan bug alur HSE, penambahan
evaluasi Manajemen, serta kanal koordinasi dan notifikasi.

---

## 1. Ringkasan Masukan Klien & Solusi

| # | Masukan Klien | Solusi yang Diimplementasikan |
| :-: | :--- | :--- |
| 1 | Alur HSE bug: setelah `laporan diterima → ditinjau → tindakan`, laporan langsung hilang sebelum tindakan diketik | Form tindakan korektif wajib diisi lengkap (uraian, PIC, severity, tenggat) sebelum boleh dikirim. Server menolak `PENDING_APPROVAL` tanpa rincian tindakan (`400`). |
| 2 | HSE tidak boleh punya menu "Lapor" | Tab "Lapor" dihapus untuk HSE. HSE mendapat tab **Laporan** (register + verifikasi), **Inspeksi**, **Koordinasi**, dan **Dashboard**. |
| 3 | Tampilan Supervisor harus berbeda dari Pekerja | Supervisor mendapat navigasi, app bar, banner, dan alur kerja tersendiri: **Inspeksi lapangan**, **Koordinasi**, pelaksanaan tindakan, dan **Dashboard K3 & ESG**. |
| 4 | Supervisor perlu koordinasi dengan HSE dan Manajemen | Kanal **Koordinasi** dua arah (Supervisor ↔ HSE ↔ Manajemen) dengan status, prioritas, balasan, dan notifikasi. |
| 5 | Manajemen perlu evaluasi kinerja K3 dan tampilan keputusan | Konsol **Evaluasi Manajemen**: menyetujui/menolak rencana tindakan HSE, menilai efektivitas (1–5), dan menutup laporan. |
| 6 | Tindakan korektif harus otomatis sampai ke Pekerja, Supervisor, dan Manajemen | Fan-out notifikasi per penerima pada setiap tahap: laporan baru, verifikasi HSE, pengajuan tindakan, persetujuan/penolakan, pelaksanaan, penyelesaian, dan evaluasi. |
| 7 | Tampilan tiap peran harus terlihat berbeda walau formulir laporan sama | App bar berwarna khas peran, banner "ruang kerja" per peran dengan langkah kerja, navigasi bottom/rail berbeda, dan penanda konteks peran di setiap layar operasional. |
| 8 | Data lama tetap dipakai, jangan dihapus | Migrasi `006` bersifat aditif: kolom/tabel baru, tanpa menghapus data. Tindakan lama otomatis dianggap `APPROVED` agar alur yang sedang berjalan tidak terblokir. |

---

## 2. Matriks Peran (Sebelum vs Sesudah)

| Peran | Sebelum Revisi | Sesudah Revisi |
| :--- | :--- | :--- |
| **Pekerja / Operator** | Peta, Lapor, Darurat | **Tidak berubah** (klien menyatakan "aman"): Peta, Lapor, Darurat |
| **Supervisor** | Peta, Lapor, Inspeksi, Insight (mirip Pekerja) | Peta, Lapor, **Inspeksi**, **Koordinasi**, **Dashboard K3/ESG** + pelaksanaan tindakan yang disetujui Manajemen |
| **HSE** | Peta, Lapor, Darurat, Inspeksi, Laporan | Peta, **Laporan**, **Inspeksi**, **Koordinasi**, **Dashboard K3/ESG** — tanpa menu "Lapor" |
| **Manajemen** | Peta, Lapor, Darurat, Laporan, Insight | Peta, **Laporan**, **Evaluasi**, **Koordinasi**, **Dashboard K3/ESG** |

Matriks kapabilitas didefinisikan di `frontend/lib/core/user_session.dart` dan
ditegakkan ulang di Postgres melalui RLS, sehingga klien yang dimodifikasi tidak
dapat melewati batas peran.

---

## 3. Alur Laporan Bahaya yang Baru

```
SUBMITTED ──(HSE verifikasi)──► IN_REVIEW
    │                              │
    │ (HSE tolak)                  │ (HSE susun tindakan lengkap)
    ▼                              ▼
REJECTED                     PENDING_APPROVAL
                                   │
              (Manajemen setujui)  │  (Manajemen tolak)
                                   ▼        └──► IN_REVIEW (HSE revisi)
                            ACTION_REQUIRED
                                   │
                 (Supervisor laksanakan tahap 4 → 5 → 6)
                                   ▼
                    Menunggu evaluasi Manajemen
                                   │
                    (Manajemen nilai efektivitas 1–5)
                                   ▼
                                CLOSED
```

Poin penting:

- **HSE tidak dapat menutup laporan secara langsung** — penutupan adalah keputusan Manajemen (`403` bila dipaksa).
- **Laporan tidak dapat masuk `PENDING_APPROVAL`** tanpa tindakan korektif lengkap.
- **Manajemen tidak dapat memajukan tahap lapangan** — itu ranah Supervisor.
- **Supervisor tidak dapat memulai** sebelum Manajemen menyetujui (`409` bila dipaksa).

---

## 4. Perbaikan Bug Alur HSE

Bug yang dilaporkan: menekan tombol "Tindakan" membuat laporan langsung hilang
sebelum teks tindakan sempat diketik.

Perbaikan dua lapis:

1. **UI** (`frontend/lib/features/report_review_screen.dart`): tombol tindakan
   membuka form yang menuntut uraian tindakan, nama PIC, tingkat severity, dan
   tenggat. Tombol kirim nonaktif sampai seluruh field valid.
2. **Server** (`backend/src/app/api/reports/route.ts`): request
   `PENDING_APPROVAL` ditolak `400` bila `action.description`, PIC, atau tenggat
   kosong. Validasi ini terbukti lewat uji end-to-end:

   ```
   PASS  report cannot enter PENDING_APPROVAL without action detail — status=400
   PASS  action requires typed description — status=400
   ```

---

## 5. Fitur Baru

### 5.1 Konsol Evaluasi Manajemen
- **Persetujuan tindakan**: daftar tindakan `PENDING` dari HSE/inspeksi dengan
  konteks laporan asal; Manajemen menyetujui atau menolak dengan catatan.
- **Evaluasi & penutupan**: tindakan yang selesai (tahap 6) masuk antrean
  evaluasi; Manajemen menilai efektivitas 1–5 dan menutup laporan.
- **Indikator keputusan**: jumlah menunggu persetujuan, siap dievaluasi,
  terlambat, disetujui, ditolak, dan sudah dievaluasi.

### 5.2 Notifikasi per Pengguna
- Tabel `notifications`: satu baris per penerima, sehingga status "sudah dibaca"
  bersifat personal.
- Lonceng di app bar dengan badge jumlah belum dibaca, plus kotak masuk lengkap
  (tandai dibaca, tandai semua).
- Kategori: `REPORT`, `ACTION`, `APPROVAL`, `EVALUATION`, `COORDINATION`.
- Setiap tahap alur mengirim notifikasi ke pihak terkait: Pekerja (pelapor),
  Supervisor, HSE, dan Manajemen.

### 5.3 Kanal Koordinasi Supervisor ↔ HSE ↔ Manajemen
- Kirim koordinasi dengan subjek, pesan, prioritas (`NORMAL`/`URGENT`), dan zona.
- Penerima dapat menandai `ACKNOWLEDGED` atau menyelesaikan dengan balasan
  (`RESOLVED`).
- Koordinasi `URGENT` otomatis juga memberi tahu Manajemen untuk pengawasan.
- Filter: semua, terbuka, untuk saya, urgent.

### 5.4 Dashboard K3, Energi & Emisi per Peran
- Supervisor, HSE, dan Manajemen dapat membaca dashboard K3/energi/emisi.
- **Hanya Manajemen** yang dapat mengisi angka resmi (`canEditInsight`).
- Setiap layar menampilkan banner konteks peran sehingga pengguna tahu
  tanggung jawabnya di layar tersebut.

### 5.5 Tampilan Khas per Peran
| Peran | Warna Aksen | Judul Ruang Kerja |
| :--- | :--- | :--- |
| Pekerja | Navy/biru tua | Ruang Kerja Pekerja |
| Supervisor | Cyan `#0E7490` | Konsol Supervisor |
| HSE | Hijau `#12805C` | Konsol Verifikasi HSE |
| Manajemen | Violet `#6D28D9` | Konsol Evaluasi Manajemen |

SOS tetap tersedia satu ketukan dari menu overflow app bar dan dari peta untuk
peran non-pekerja, tanpa memakan slot navigasi utama.

---

## 6. Perubahan Basis Data (Migrasi 006)

Berkas: `supabase/migrations/006_role_workflow_management_notifications.sql` —
sudah diterapkan pada proyek Supabase produksi dan bersifat **aditif**.

- **Kolom baru `corrective_actions`**: `management_status`, `management_notes`,
  `management_reviewed_by`, `management_reviewed_at`, `effectiveness_rating`,
  `evaluated_at`, `assigned_worker_id`, `created_by`, `source`.
- **Tabel `notifications`** + indeks + RLS (penerima hanya melihat/menandai
  notifikasinya sendiri; Manajemen dapat melihat untuk pengawasan).
- **Tabel `coordination_requests`** + indeks + RLS + trigger `updated_at`.
- **Policy `corrective_actions`**: izin `INSERT` untuk peran operasional dan izin
  `UPDATE` untuk PIC/Supervisor/HSE/Manajemen.
- **Trigger `guard_action_management_columns`**: kolom keputusan Manajemen hanya
  dapat diubah oleh akun berperan `management`.
- **Data lama aman**: tindakan lama diberi `management_status = 'APPROVED'`;
  indeks baru untuk register laporan dan tindakan.

---

## 7. Perubahan API

| Endpoint | Perubahan |
| :--- | :--- |
| `PATCH /api/reports` | Verifikasi HSE, validasi tindakan wajib lengkap, penolakan laporan, larangan HSE menutup langsung, fan-out notifikasi |
| `GET /api/reports` | Menyertakan `latest_action` (status persetujuan & evaluasi) dan hitungan status baru |
| `GET/PATCH /api/inspections` | Keputusan Manajemen (`APPROVED`/`REJECTED`/`EVALUATED`) dan tahap lapangan; validasi gate persetujuan |
| `POST /api/inspections` | Temuan inspeksi otomatis menjadi tindakan korektif `PENDING` untuk disetujui Manajemen |
| `GET/PATCH /api/notifications` | Kotak masuk personal, hitung belum dibaca, tandai dibaca |
| `GET/POST/PATCH /api/coordination` | Kanal koordinasi dengan status dan balasan |

---

## 8. Verifikasi

| Pemeriksaan | Hasil |
| :--- | :--- |
| `flutter analyze` | **No issues found!** |
| `flutter test` | **82 uji lulus** (tata letak lintas viewport, logika peran, regresi UX) |
| `npm run build` (Next.js) | **Sukses** — seluruh route baru terkompilasi |
| `node backend/e2e-writepaths.mjs` | **46/46 pemeriksaan lulus** terhadap API + Supabase sungguhan |

Uji end-to-end mencakup seluruh alur revisi, termasuk penolakan `403` untuk setiap
tindakan di luar kewenangan peran dan `400` untuk tindakan yang belum diketik.

---

## 9. Revisi UI/UX Putaran Kedua (Masukan Klien)

### 9.1 Menu "Inspeksi" kosong pada HSE

**Gejala**: tab Inspeksi menampilkan layar kosong bagi akun HSE.

**Akar masalah** (bukan satu, melainkan berlapis):

1. Kegagalan yang terjadi diam-diam: API mengembalikan `400`/timeout, lapisan baca fell back
   ke cache kosong, dan layar menampilkan "tidak ada tiket" — padahal tidak ada
   yang pernah berhasil dimuat.
2. Cold start Render (plan gratis) bisa lebih lama dari satu jendela request, sehingga
   permintaan pertama habis waktu.
3. Cache offline bersifat global: data peran lain (bahkan register HSE) bisa
   tersaji ke akun lain.
4. Pesan empty state menyesatkan ("Semua tindakan korektif sudah ditutup") untuk
   layar yang sebenarnya gagal memuat.

**Perbaikan**:

- `ApiService` kini melaporkan status baca (`ApiRead`: dari server / dari cache /
  gagal + alasannya) sehingga layar bisa membedakan "tidak ada data" dari
  "gagal memuat".
- Retry otomatis satu kali untuk kegagalan jaringan/5xx, timeout baca diperlonggar
  (25 detik), dan timeout pendek 12 detik.
- Cache offline di-*namespace* per UUID akun: satu peran tidak pernah membaca
  cache peran lain.
- Layar Inspeksi, Register Laporan, dan Kanal Koordinasi menampilkan kartu
  "DATA BELUM TERSINKRON" dengan tombol **Coba Lagi**, bukan layar kosong.
- Layar Inspeksi kini selalu punya isi: strip ringkasan (temuan aktif, menunggu
  persetujuan, menunggu evaluasi, selesai), empty state yang menjelaskan apa
  yang harus dilakukan peran tersebut + tombol aksi, dan riwayat inspeksi.

### 9.2 Tombol SOS Writing Ganda

Ikon `Icons.sos_rounded` (huruf SOS) diletakkan berdampingan dengan teks "SOS"
sehingga tombol menampilkan dua tulisan SOS. Kini hanya ada **satu** wordmark
"SOS" di dalam tombol, dan ikon sirene (`crisis_alert`) dipakai di peta, tab, dan
menu overflow.

### 9.3 Tombol "Keluar Akun" di Dua Tempat

Dulu tersedia di tab **Profil**, sheet **Pengaturan**, dan sheet **Profil** (avatar).
Kini hanya ada di tab **Profil** (dengan konfirmasi). Sheet profil menampilkan
catatan kecil: "Keluar akun tersedia di tab Profil."

### 9.4 Header Akun Terlalu Padat

- App bar: chip nomor pegawai dihapus; tersisa mark, nama produk, nama pengguna,
  dan peran.
- Header halaman Profil: judul ringkas "Profil" tanpa subjudul panjang.
- Sheet profil: hanya nama + peran; nomor pegawai, zona, dan kontak pindah ke
  baris data di dalam kartu.

### 9.5 Kartu yang Terlihat "Generik"

Kartu sebelumnya memakai sudut membulat penuh + bayangan lembut yang membuat
antarmuka terbaca seperti templat. Bahasa visual sekarang mengikuti perangkat
tambang: **sudut terpotong (chamfer) 10 px**, border 1 px tegas, bayangan dangkal
saja, dan aksen garis 3 px tanpa pembulatan.

- `frontend/lib/widgets/chamfer.dart` — `ChamferBorder` + `ChamferClipper`
  (geometri dipakai bersama oleh gambar border dan klip konten).
- `SbCard`, `SbButton`, dan `EmptyState` memakai siluet yang sama.
- Ikon avatar pada banner peran memakai kotak terpotong, bukan lingkaran.
- Avatar inisial diberi warna peran sehingga dua akun tidak pernah tertukar.

### 9.6 Kartu Konsol Peran yang Selalu Muncul

Kartu "Konsol Evaluasi Manajemen" (dan sejenisnya) sebelumnya dipaksakan di atas
setiap layar. Sekarang:

- Layar **beranda** (Peta) memakai panel penuh: peran, misi, dan langkah kerja.
- Layar **kerja** memakai strip ringkas satu baris dengan data langsung, misalnya
  "2 menunggu persetujuan · 1 siap dievaluasi" (Manajemen), "3 temuan aktif"
  (Inspeksi), "1 terbuka · 2 perlu balasan" (Koordinasi).

Tidak ada lagi teks peran yang *hardcoded* di atas layar.

### 9.7 Foto Profil Milik Akun Tertentu

**Akar masalah**: berkas foto pada bucket `avatars` di-*seed* dengan gambar yang
identik untuk seluruh akun (etag dan ukuran sama persis), sehingga semua akun
menampilkan foto yang sama dan pengguna mengira fotonya ikut berganti. Policy
storage juga hanya memeriksa `bucket_id`, sehingga satu akun secara teknis dapat
menimpa berkas akun lain.

**Perbaikan** (`supabase/migrations/007_avatar_ownership.sql`):

- Policy storage dikunci ke pemilik folder (`<uuid-akun>/avatar.png`).
- Semua `profiles.avatar_url` dikosongkan dan berkas foto bersama dihapus; setiap
  akun kini menampilkan inisial berwarna perannya sampai mengunggah foto sendiri.
- Inisial fallback memakai warna peran, dan foto lama di-evict dari cache gambar
  segera setelah unggahan baru.

### 9.8 Ringkasan Perubahan

| Area | Sebelum | Sesudah |
| :--- | :--- | :--- |
| Tab Inspeksi (HSE) | Layar kosong / pesan menyesatkan | Strip ringkasan + status sinkronisasi + tombol Coba Lagi + empty state yang menjelaskan |
| Tombol SOS | Dua tulisan "SOS" | Satu wordmark "SOS" |
| Keluar akun | Di 3 tempat | Hanya di tab Profil |
| Header app bar | Mark + produk + chip pegawai + nama/peran | Mark + produk + nama/peran |
| Kartu | Sudut bulat penuh + bayalan lembut | Chamfer 10 px + border tegas + bayangan dangkal |
| Kartu konsol peran | Selalu di atas setiap layar | Panel penuh hanya di beranda; strip ringkas + data langsung di layar kerja |
| Foto profil | Foto bersama untuk semua akun | Inisial per peran; storage dikunci ke pemilik |

Tes regresi baru: `frontend/test/ux_regression_test.dart` (6 uji) yang mengunci
perilaku di atas.

---

## 10. Catatan Rilis

1. Jalankan migrasi `006` dan `007` (sudah diterapkan pada proyek
   `qgdnrsnbxwqrouigrskb`).
2. Deploy backend: Render membangun ulang otomatis dari branch `main` (jika webhook
   GitHub tidak aktif, picu deploy manual dari dashboard Render).
3. Build aplikasi: `cd frontend && flutter build apk --release`
   atau `flutter build appbundle --release` untuk rilis Play Store.
4. Data laporan lama tetap utuh dan tetap dapat ditindaklanjuti dengan alur baru.
5. Foto profil akun lama dikosongkan (foto bersama antar akun dihapus); pengguna
   dapat mengunggah foto sendiri kapan saja.
