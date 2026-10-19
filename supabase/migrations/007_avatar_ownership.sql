-- ==============================================================================
-- SI BENI (Siaga Bencana Dini) — PT Consnet Mining
-- Migration 007: Avatar ownership isolation
-- ==============================================================================
-- Temuan dari uji lapangan:
--
--   1. Bucket `avatars` hanya dijaga oleh `bucket_id = 'avatars'`. Artinya
--      setiap akun terautentikasi dapat menulis, menimpa, dan menghapus file
--      milik akun lain. Foto satu akun bisa menggantikan foto akun lain.
--
--   2. Data awal (seed) mengunggah satu berkas gambar yang sama ke seluruh
--      akun, sehingga setiap peran tampil dengan foto yang identik dan
--      pengguna mengira fotonya ikut berganti antar akun.
--
-- Perbaikan:
--   - Policy storage dibatasi ke pemilik folder (folder pertama = UUID akun).
--   - Semua akun kembali ke foto inisial masing-masing; foto hanya muncul
--     setelah akun tersebut mengunggah fotonya sendiri.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. POLICY PEMBATASAN PEMILIK
-- ------------------------------------------------------------------------------
-- Bucket harus publik: aplikasi menyimpan tautan foto profil pada kolom
-- avatar_url dan memuatnya langsung (Image.network). Migrasi 004 membuat bucket
-- privat sehingga tautan yang tersimpan tidak dapat dimuat. Bucket tetap publik
-- untuk *pembacaan*, tetapi hanya pemilik folder yang boleh menulis.
UPDATE storage.buckets
SET public = true
WHERE id = 'avatars';

-- Foldername() memecah nama objek menjadi segmen path. Foto profil disimpan
-- sebagai "<uuid-akun>/avatar.png", jadi segmen pertama harus sama dengan
-- UUID pengguna yang sedang masuk.
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    )
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );

DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );

-- ------------------------------------------------------------------------------
-- 2. PEMBERSIHAN DATA AWAL
-- ------------------------------------------------------------------------------
-- Foto awal dicabut supaya setiap akun menampilkan inisialnya sendiri, bukan
-- gambar milik akun lain. Pengguna tetap dapat mengunggah foto sendiri; berkas
-- tersebut tersimpan di folder UUID miliknya dan tidak dapat disentuh akun
-- lain.
UPDATE public.profiles
SET avatar_url = NULL
WHERE avatar_url IS NOT NULL;

COMMENT ON POLICY "Users can upload own avatar" ON storage.objects IS
    'Hanya akun pemilik folder (uuid-akun) yang boleh mengunggah foto profilnya.';
COMMENT ON POLICY "Users can update own avatar" ON storage.objects IS
    'Hanya akun pemilik folder (uuid-akun) yang boleh mengganti foto profilnya.';
COMMENT ON POLICY "Users can delete own avatar" ON storage.objects IS
    'Hanya akun pemilik folder (uuid-akun) yang boleh menghapus foto profilnya.';
