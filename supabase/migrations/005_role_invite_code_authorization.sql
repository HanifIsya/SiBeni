-- ==============================================================================
-- SI BENI (Siaga Bencana Dini) — PT Consnet Mining
-- Migration 005: Role Invite Code Authorization
-- ==============================================================================
-- Allows self-registration for privileged roles (supervisor, hse, management)
-- when presenting an authorised operational invite code in raw_user_meta_data.
-- Without a valid code, the role defaults securely to 'worker'.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
    requested_role text;
    code text;
    final_role text;
BEGIN
    requested_role := LOWER(COALESCE(NEW.raw_user_meta_data->>'role', 'worker'));
    code := UPPER(TRIM(COALESCE(NEW.raw_user_meta_data->>'invite_code', '')));

    IF requested_role = 'supervisor' AND code IN ('SPV2026', 'SPV-CONSNET', 'SUPERVISOR') THEN
        final_role := 'supervisor';
    ELSIF requested_role = 'hse' AND code IN ('HSE2026', 'HSE-CONSNET', 'HSE') THEN
        final_role := 'hse';
    ELSIF requested_role = 'management' AND code IN ('MGT2026', 'MGT-CONSNET', 'MANAGEMENT') THEN
        final_role := 'management';
    ELSE
        final_role := 'worker';
    END IF;

    INSERT INTO public.profiles (id, employee_id, full_name, role, work_zone, phone_number)
    VALUES (
        NEW.id,
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'employee_id', ''), 'EMP-' || substr(replace(NEW.id::text, '-', ''), 1, 8)),
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), 'Karyawan Tambang'),
        final_role::public.user_role,
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'work_zone', ''), 'Pit Utama'),
        NULLIF(NEW.raw_user_meta_data->>'phone_number', '')
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        work_zone = EXCLUDED.work_zone,
        phone_number = EXCLUDED.phone_number;
    RETURN NEW;
END;
$$;
