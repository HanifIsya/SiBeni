-- ==============================================================================
-- SI BENI (Siaga Bencana Dini) — PT Consnet Mining
-- Migration 004: Site relocation, write-path hardening, self-service profile
-- ==============================================================================
-- Three problems are solved here.
--
-- 1. SITE RELOCATION
--    The concession was previously anchored to a placeholder coordinate in
--    Kalimantan. PT Consnet Mining is a fictional site for this project; the
--    operating area now sits in the Driyorejo industrial corridor east of
--    Surabaya, East Java. Geometry stays data-driven — nothing in the client
--    bundle carries a coordinate.
--
-- 2. WRITE-PATH HARDENING
--    hazard_reports.local_id had a *non-unique* index, so PostgREST's
--    `ON CONFLICT (local_id)` upsert failed outright and every report filed
--    from the field was silently discarded. This migration makes local_id
--    genuinely unique, which is what idempotent offline sync requires.
--
-- 3. SELF-SERVICE PROFILE
--    Self-registration could not persist a profile row (no INSERT policy and
--    no trigger), and avatars had nowhere to live. Both are fixed below.
-- ==============================================================================


-- ------------------------------------------------------------------------------
-- 1. SITE RELOCATION — Surabaya, East Java
-- ------------------------------------------------------------------------------
-- Active pit
UPDATE mining_zones SET polygon_coordinates = '{"center":[-7.2200000,112.7500000],"polygon":[[-7.2200000,112.7459977],[-7.2148910,112.7487632],[-7.2168425,112.7532379],[-7.2231575,112.7532379],[-7.2251090,112.7487632]],"assembly":[-7.2210753,112.7470219]}'::jsonb
WHERE code = 'ZONE_PIT';

-- Haul road corridor
UPDATE mining_zones SET polygon_coordinates = '{"center":[-7.2234000,112.7536000],"polygon":[[-7.2234000,112.7506752],[-7.2196665,112.7526962],[-7.2210926,112.7559662],[-7.2257074,112.7559662],[-7.2271335,112.7526962]],"assembly":[-7.2268407,112.7565102]}'::jsonb
WHERE code = 'ZONE_HAUL_ROAD';

-- Stockpile / ROM pad
UPDATE mining_zones SET polygon_coordinates = '{"center":[-7.2275000,112.7574000],"polygon":[[-7.2275000,112.7547831],[-7.2241595,112.7565913],[-7.2254355,112.7595171],[-7.2295645,112.7595171],[-7.2308405,112.7565913]],"assembly":[-7.2262424,112.7552043]}'::jsonb
WHERE code = 'ZONE_STOCKPILE';

-- Crusher plant
UPDATE mining_zones SET polygon_coordinates = '{"center":[-7.2299000,112.7601000],"polygon":[[-7.2299000,112.7577909],[-7.2269525,112.7593865],[-7.2280784,112.7619681],[-7.2317216,112.7619681],[-7.2328475,112.7593865]],"assembly":[-7.2280429,112.7607813]}'::jsonb
WHERE code = 'ZONE_PROCESSING';

-- Heavy equipment workshop
UPDATE mining_zones SET polygon_coordinates = '{"center":[-7.2177000,112.7478000],"polygon":[[-7.2177000,112.7461067],[-7.2155385,112.7472768],[-7.2163641,112.7491699],[-7.2190359,112.7491699],[-7.2198615,112.7472768]],"assembly":[-7.2178174,112.7491531]}'::jsonb
WHERE code = 'ZONE_WORKSHOP';

-- Logistics & explosives magazine
UPDATE mining_zones SET polygon_coordinates = '{"center":[-7.2153000,112.7444000],"polygon":[[-7.2153000,112.7423989],[-7.2127455,112.7437816],[-7.2137212,112.7460189],[-7.2168788,112.7460189],[-7.2178545,112.7437816]],"assembly":[-7.2123566,112.7464775]}'::jsonb
WHERE code = 'ZONE_WAREHOUSE';

-- Site office, clinic & mess
UPDATE mining_zones SET polygon_coordinates = '{"center":[-7.2166000,112.7462000],"polygon":[[-7.2166000,112.7448146],[-7.2148315,112.7457719],[-7.2155070,112.7473208],[-7.2176930,112.7473208],[-7.2183685,112.7457719]],"assembly":[-7.2169687,112.7451789]}'::jsonb
WHERE code = 'ZONE_SUPPORT';

-- 3. ROLE-SCOPED ACCESS
--    The role matrix has to be expressed here, because this is what the API
--    enforces. The previous policies let Supervisor write official ESG
--    metrics, and let any reviewer close a hazard report without the
--    separation of duty a safety system needs.
--
--    Insight / ESG record  → management only (it is the official K3 figure)
--    Report review         → hse + management (supervisors observe)
--    Corrective action     → supervisor + hse (unchanged)

DROP POLICY IF EXISTS "ESG metrics insertable/updatable by HSE and management" ON energy_emission_metrics;
CREATE POLICY "ESG metrics insertable/updatable by management"
    ON energy_emission_metrics FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role = 'management'
        )
    );

DROP POLICY IF EXISTS "HSE and supervisors can update report status" ON hazard_reports;
CREATE POLICY "HSE and management can update report status"
    ON hazard_reports FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('hse', 'management')
        )
    );

-- Refresh the operational narrative so it matches the new location.
UPDATE mining_zones SET description = 'Area penggalian terbuka kelas material agregat dengan aktivitas excavator dan dump truck, berada di koridor industri Driyorejo, Surabaya Timur.'
WHERE code = 'ZONE_PIT';
UPDATE mining_zones SET description = 'Jalur angkut material dari pit menuju stockpile dan fasilitas pengolahan sepanjang KM 0-15.'
WHERE code = 'ZONE_HAUL_ROAD';
UPDATE mining_zones SET description = 'Area penampungan material curah dengan mobilitas wheel loader dan conveyor hopper.'
WHERE code = 'ZONE_STOCKPILE';
UPDATE mining_zones SET description = 'Bengkel terpadu perbaikan unit alat berat, crane, dan penggantian oli.'
WHERE code = 'ZONE_WORKSHOP';
UPDATE mining_zones SET description = 'Unit pengecilan bijih dan penyaringan material dengan conveyor bertingkat.'
WHERE code = 'ZONE_PROCESSING';
UPDATE mining_zones SET description = 'Penyimpanan material berbahaya B3, suku cadang, dan gudang bahan peledak terisolasi.'
WHERE code = 'ZONE_WAREHOUSE';
UPDATE mining_zones SET description = 'Area perkantoran manajemen site, klinik K3, mess pekerja, dan kantin operasional.'
WHERE code = 'ZONE_SUPPORT';

-- Mark the migration for anyone auditing the site later.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM mining_zones WHERE polygon_coordinates IS NULL) THEN
        RAISE WARNING 'mining_zones still contains rows without polygon_coordinates';
    END IF;
END $$;


-- ------------------------------------------------------------------------------
-- 2. WRITE-PATH HARDENING
-- ------------------------------------------------------------------------------

-- Idempotent offline sync REQUIRES a unique constraint, not just an index.
-- (Migration 001 created a plain index, which made every ON CONFLICT upsert fail.)
--
-- This must be a PLAIN unique index. A partial index (`WHERE local_id IS NOT
-- NULL`) cannot satisfy PostgREST's `ON CONFLICT (local_id)`, because Postgres
-- requires the inference clause to match the index predicate exactly — and the
-- upsert still failed with "no unique or exclusion constraint". Plain UNIQUE is
-- correct anyway: NULL local_ids never conflict in Postgres.
DROP INDEX IF EXISTS uniq_hazard_reports_local_id;
CREATE UNIQUE INDEX IF NOT EXISTS uniq_hazard_reports_local_id
    ON hazard_reports (local_id);

-- Reports awaiting HSE review need to be queryable by state.
CREATE INDEX IF NOT EXISTS idx_hazard_reports_hse_status
    ON hazard_reports (hse_status, created_at DESC);

-- Early warnings are now editable; track who changed them and when.
ALTER TABLE early_warnings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
CREATE INDEX IF NOT EXISTS idx_early_warnings_active_window
    ON early_warnings (is_active, valid_from DESC);

-- These tables are mutated by the API but were created without updated_at, so
-- every query naming that column failed outright.
ALTER TABLE hazard_reports ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE energy_emission_metrics ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_energy_metrics_date ON energy_emission_metrics (record_date DESC);

-- Keep updated_at honest without relying on every caller to set it.
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS touch_hazard_reports_updated_at ON hazard_reports;
CREATE TRIGGER touch_hazard_reports_updated_at
    BEFORE UPDATE ON hazard_reports
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS touch_energy_metrics_updated_at ON energy_emission_metrics;
CREATE TRIGGER touch_energy_metrics_updated_at
    BEFORE UPDATE ON energy_emission_metrics
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS touch_early_warnings_updated_at ON early_warnings;
CREATE TRIGGER touch_early_warnings_updated_at
    BEFORE UPDATE ON early_warnings
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Offline sync must be safe to RETRY. PostgREST resolves an upsert conflict with
-- an UPDATE, and there was no UPDATE policy for a worker — so a device that
-- timed out mid-submission could never deliver the same local_id again, and the
-- report was permanently stuck in the outbox.
DROP POLICY IF EXISTS "Workers can update own report for idempotent retry" ON hazard_reports;
CREATE POLICY "Workers can update own report for idempotent retry"
    ON hazard_reports FOR UPDATE
    TO authenticated
    USING (reporter_id = (select auth.uid()))
    WITH CHECK (reporter_id = (select auth.uid()));

-- That UPDATE policy is only safe because the review verdict is fenced off in
-- the database: a worker may rewrite their own submission, but nothing else.
CREATE OR REPLACE FUNCTION public.guard_report_review_columns()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    actor_role text;
BEGIN
    IF NEW.hse_status IS DISTINCT FROM OLD.hse_status
       OR NEW.hse_notes IS DISTINCT FROM OLD.hse_notes
       OR NEW.reporter_id IS DISTINCT FROM OLD.reporter_id THEN
        SELECT p.role::text INTO actor_role
        FROM public.profiles p
        WHERE p.id = (SELECT auth.uid());

        IF actor_role IS NULL OR actor_role NOT IN ('hse', 'management') THEN
            RAISE EXCEPTION 'hanya HSE atau manajemen yang dapat mengubah status tinjauan laporan'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_report_review_columns ON hazard_reports;
CREATE TRIGGER guard_report_review_columns
    BEFORE UPDATE ON hazard_reports
    FOR EACH ROW EXECUTE FUNCTION public.guard_report_review_columns();


-- ------------------------------------------------------------------------------
-- 3. SELF-SERVICE PROFILE
-- ------------------------------------------------------------------------------

-- Self-registration previously produced an auth user with no profile row, so
-- the app could never resolve a role and the user bounced back to the login
-- screen. Let the user create exactly their own profile.
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile"
    ON profiles FOR INSERT
    TO authenticated
    WITH CHECK ((select auth.uid()) = id);

-- Provision the profile automatically on sign-up, from the metadata the app
-- already sends. SECURITY DEFINER so it can run as the migration owner.
-- Provision the profile automatically on sign-up, from the metadata the app
-- already sends.
--
-- SECURITY INVOKER (not DEFINER) on purpose. A SECURITY DEFINER trigger runs as
-- the migration owner and therefore bypasses RLS entirely, which would let
-- anyone self-assign an arbitrary role at sign-up. Under SECURITY INVOKER the
-- insert is evaluated against the caller and must satisfy the
-- "Users can insert own profile" policy (auth.uid() = id), so a new account can
-- only ever describe itself.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, employee_id, full_name, role, work_zone, phone_number)
    VALUES (
        NEW.id,
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'employee_id', ''), 'EMP-' || substr(replace(NEW.id::text, '-', ''), 1, 8)),
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), 'Karyawan Tambang'),
        -- New accounts always start as workers. Roles are granted by HSE.
        'worker',
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'work_zone', ''), 'Pit Utama'),
        NULLIF(NEW.raw_user_meta_data->>'phone_number', '')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- Avatars: private bucket, one folder per user, readable only by their peers
-- through an authenticated URL.
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users can read avatars" ON storage.objects;
CREATE POLICY "Users can read avatars"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = (select auth.uid())::text
    );

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = (select auth.uid())::text
    );

DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = (select auth.uid())::text
    );