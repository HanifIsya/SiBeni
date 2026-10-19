-- ==============================================================================
-- SI BENI (Siaga Bencana Dini) — PT Consnet Mining
-- Migration 006: Role workflow, management approval, notifications & coordination
-- ==============================================================================
-- Client revision (Oktober 2026) memisahkan tanggung jawab tiap peran:
--
--   PEKERJA    : melapor, melihat tugas/tindakan yang ditujukan kepadanya.
--   SUPERVISOR : inspeksi lapangan, koordinasi HSE/Manajemen, pelaksanaan
--                tindakan yang sudah disetujui, membaca dashboard K3/energi.
--   HSE        : menerima & memverifikasi laporan, MENYUSUN tindakan korektif.
--                HSE tidak lagi memiliki menu "Lapor".
--   MANAJEMEN  : menyetujui/menolak rencana tindakan HSE, mengevaluasi hasil,
--                dan menutup laporan.
--
-- Alur laporan bahaya yang baru:
--
--   SUBMITTED ──(HSE verifikasi)──► IN_REVIEW
--       │                              │
--       │ (HSE tolak)                  │ (HSE beri tindakan)
--       ▼                              ▼
--    REJECTED                    PENDING_APPROVAL
--                                         │
--                    (Manajemen setujui)  │  (Manajemen tolak)
--                                         ▼            │
--                                  ACTION_REQUIRED     └──► IN_REVIEW
--                                         │
--                         (Supervisor selesaikan tindakan)
--                                         ▼
--                                    CLOSED (evaluasi Manajemen)
--
-- Catatan: hse_status bertipe VARCHAR(50), jadi status baru tidak memerlukan
-- perubahan enum dan tetap kompatibel dengan data lama.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. KOLOM PERSETUJUAN & EVALUASI PADA TINDAKAN KOREKTIF
-- ------------------------------------------------------------------------------
ALTER TABLE corrective_actions
    ADD COLUMN IF NOT EXISTS management_status VARCHAR(30) DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS management_notes TEXT,
    ADD COLUMN IF NOT EXISTS management_reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS management_reviewed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS effectiveness_rating INT,
    ADD COLUMN IF NOT EXISTS evaluated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS assigned_worker_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS source VARCHAR(30) DEFAULT 'inspection';

-- Data lama tidak boleh tiba-tiba terblokir. Tindakan yang sudah berjalan
-- dianggap sudah disetujui; tindakan selesai tetap muncul di antrean evaluasi
-- manajemen karena evaluated_at masih NULL.
UPDATE corrective_actions
SET management_status = 'APPROVED'
WHERE management_status IS NULL;

CREATE INDEX IF NOT EXISTS idx_corrective_actions_management_status
    ON corrective_actions (management_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_hazard_report
    ON corrective_actions (hazard_report_id);

-- ------------------------------------------------------------------------------
-- 2. TABEL NOTIFIKASI
-- ------------------------------------------------------------------------------
-- Satu baris per penerima. Ini membuat status "sudah dibaca" benar-benar
-- personal, bukan global untuk seluruh peran.
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    recipient_role user_role,
    title VARCHAR(200) NOT NULL,
    body TEXT,
    category VARCHAR(40) NOT NULL DEFAULT 'INFO',
    related_report_id UUID REFERENCES hazard_reports(id) ON DELETE CASCADE,
    related_action_id UUID REFERENCES corrective_actions(id) ON DELETE CASCADE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient
    ON notifications (recipient_id, is_read, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Notifications visible to their recipient" ON notifications;
CREATE POLICY "Notifications visible to their recipient"
    ON notifications FOR SELECT
    TO authenticated
    USING (
        recipient_id = (select auth.uid())
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role = 'management'
        )
    );

DROP POLICY IF EXISTS "Authenticated users can create notifications" ON notifications;
CREATE POLICY "Authenticated users can create notifications"
    ON notifications FOR INSERT
    TO authenticated
    WITH CHECK (recipient_id IS NOT NULL);

DROP POLICY IF EXISTS "Recipients can mark notifications read" ON notifications;
CREATE POLICY "Recipients can mark notifications read"
    ON notifications FOR UPDATE
    TO authenticated
    USING (
        recipient_id = (select auth.uid())
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role = 'management'
        )
    );

-- ------------------------------------------------------------------------------
-- 3. TABEL KOORDINASI SUPERVISOR ↔ HSE ↔ MANAJEMEN
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coordination_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    from_name VARCHAR(150) NOT NULL,
    from_role user_role NOT NULL,
    to_role user_role NOT NULL,
    subject VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL', -- NORMAL | URGENT
    zone_name VARCHAR(100),
    related_action_id UUID REFERENCES corrective_actions(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN', -- OPEN | ACKNOWLEDGED | RESOLVED
    response TEXT,
    responded_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    responded_by_name VARCHAR(150),
    responded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_coordination_to_role
    ON coordination_requests (to_role, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_coordination_from_id
    ON coordination_requests (from_id, created_at DESC);

ALTER TABLE coordination_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Coordination visible to sender, recipient role and management" ON coordination_requests;
CREATE POLICY "Coordination visible to sender, recipient role and management"
    ON coordination_requests FOR SELECT
    TO authenticated
    USING (
        from_id = (select auth.uid())
        OR to_role = (
            SELECT profiles.role FROM profiles
            WHERE profiles.id = (select auth.uid())
        )
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role = 'management'
        )
    );

DROP POLICY IF EXISTS "Operational roles can send coordination" ON coordination_requests;
CREATE POLICY "Operational roles can send coordination"
    ON coordination_requests FOR INSERT
    TO authenticated
    WITH CHECK (
        from_id = (select auth.uid())
        AND from_role = (
            SELECT profiles.role FROM profiles
            WHERE profiles.id = (select auth.uid())
        )
        AND EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('supervisor', 'hse', 'management')
        )
    );

DROP POLICY IF EXISTS "Sender, recipient and management can update coordination" ON coordination_requests;
CREATE POLICY "Sender, recipient and management can update coordination"
    ON coordination_requests FOR UPDATE
    TO authenticated
    USING (
        from_id = (select auth.uid())
        OR to_role = (
            SELECT profiles.role FROM profiles
            WHERE profiles.id = (select auth.uid())
        )
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role = 'management'
        )
    );

DROP TRIGGER IF EXISTS touch_coordination_requests_updated_at ON coordination_requests;
CREATE TRIGGER touch_coordination_requests_updated_at
    BEFORE UPDATE ON coordination_requests
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ------------------------------------------------------------------------------
-- 4. KEBijAKAN TINDAKAN KOREKTIF
-- ------------------------------------------------------------------------------
-- Sebelumnya corrective_actions tidak memiliki policy INSERT sama sekali,
-- sehingga temuan inspeksi bisa gagal dibuat tanpa terlihat. Policy ini
-- melengkapi jalur tulis yang memang sudah dipakai API.
DROP POLICY IF EXISTS "Corrective actions insertable by operational roles" ON corrective_actions;
CREATE POLICY "Corrective actions insertable by operational roles"
    ON corrective_actions FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('supervisor', 'hse', 'management')
        )
    );

DROP POLICY IF EXISTS "Corrective actions editable by assigned PIC or HSE" ON corrective_actions;
DROP POLICY IF EXISTS "Corrective actions editable by assigned PIC, supervisor, HSE or management" ON corrective_actions;
CREATE POLICY "Corrective actions editable by assigned PIC, supervisor, HSE or management"
    ON corrective_actions FOR UPDATE
    TO authenticated
    USING (
        assigned_pic_id = (select auth.uid())
        OR assigned_worker_id = (select auth.uid())
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('supervisor', 'hse', 'management')
        )
    );

-- Kolom keputusan manajemen hanya boleh diubah oleh Manajemen. Tanpa guard ini,
-- pengguna dengan peran lain dapat mengakali UI dan menyetujui tindakannya
-- sendiri. Guard sengaja hanya memeriksa UPDATE: HSE tetap boleh INSERT dengan
-- management_status = 'PENDING'.
CREATE OR REPLACE FUNCTION public.guard_action_management_columns()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    actor_role text;
BEGIN
    IF TG_OP = 'UPDATE' AND (
        NEW.management_status IS DISTINCT FROM OLD.management_status
        OR NEW.management_notes IS DISTINCT FROM OLD.management_notes
        OR NEW.management_reviewed_by IS DISTINCT FROM OLD.management_reviewed_by
        OR NEW.management_reviewed_at IS DISTINCT FROM OLD.management_reviewed_at
        OR NEW.effectiveness_rating IS DISTINCT FROM OLD.effectiveness_rating
        OR NEW.evaluated_at IS DISTINCT FROM OLD.evaluated_at
    ) THEN
        SELECT p.role::text INTO actor_role
        FROM public.profiles p
        WHERE p.id = (SELECT auth.uid());

        IF actor_role IS NULL OR actor_role <> 'management' THEN
            RAISE EXCEPTION 'hanya Manajemen yang dapat mengubah keputusan persetujuan/evaluasi'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_action_management_columns ON corrective_actions;
CREATE TRIGGER guard_action_management_columns
    BEFORE UPDATE ON corrective_actions
    FOR EACH ROW EXECUTE FUNCTION public.guard_action_management_columns();

-- ------------------------------------------------------------------------------
-- 5. INDEKS & KOMENTAR OPERASIONAL
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_hazard_reports_hse_status_updated
    ON hazard_reports (hse_status, updated_at DESC);

COMMENT ON COLUMN hazard_reports.hse_status IS
    'SUBMITTED | IN_REVIEW | PENDING_APPROVAL | ACTION_REQUIRED | CLOSED | REJECTED';
COMMENT ON COLUMN corrective_actions.management_status IS
    'PENDING | APPROVED | REJECTED | EVALUATED';
COMMENT ON TABLE notifications IS
    'Notifikasi per pengguna: laporan baru, tindakan HSE, persetujuan/evaluasi Manajemen, koordinasi.';
COMMENT ON TABLE coordination_requests IS
    'Kanal koordinasi Supervisor dengan HSE dan Manajemen, termasuk balasan dan status.';
