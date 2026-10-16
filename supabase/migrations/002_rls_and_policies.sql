-- ==============================================================================
-- SI BENI (Siaga Bencana Dini) - PT Consnet Mining
-- Migration 002: Row Level Security (RLS) & Policies
-- ==============================================================================

-- Enable RLS on core tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE mining_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE early_warnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE hazard_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_sos_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE k3_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE corrective_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE energy_emission_metrics ENABLE ROW LEVEL SECURITY;

-- 1. PROFILES POLICIES
CREATE POLICY "Public profiles are viewable by authenticated users"
    ON profiles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    TO authenticated
    USING ((select auth.uid()) = id);

-- 2. MINING ZONES POLICIES
CREATE POLICY "Mining zones viewable by all authenticated users"
    ON mining_zones FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Mining zones manageable by HSE and management"
    ON mining_zones FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('hse', 'management')
        )
    );

-- 3. EARLY WARNINGS POLICIES
CREATE POLICY "Early warnings viewable by everyone"
    ON early_warnings FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Early warnings manageable by HSE and system backend"
    ON early_warnings FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('hse', 'management')
        )
    );

-- 4. HAZARD REPORTS POLICIES
CREATE POLICY "Workers can view own submitted reports"
    ON hazard_reports FOR SELECT
    TO authenticated
    USING (
        reporter_id = (select auth.uid())
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('supervisor', 'hse', 'management')
        )
    );

CREATE POLICY "Workers can insert new hazard reports"
    ON hazard_reports FOR INSERT
    TO authenticated
    WITH CHECK ((select auth.uid()) = reporter_id OR reporter_id IS NULL);

CREATE POLICY "HSE and supervisors can update report status"
    ON hazard_reports FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('supervisor', 'hse', 'management')
        )
    );

-- 5. EMERGENCY SOS POLICIES
CREATE POLICY "All workers can trigger SOS broadcast"
    ON emergency_sos_logs FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "All authenticated users can view active SOS events"
    ON emergency_sos_logs FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "HSE and supervisors can respond to and resolve SOS"
    ON emergency_sos_logs FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('supervisor', 'hse')
        )
    );

-- 6. K3 INSPECTIONS & CORRECTIVE ACTIONS POLICIES
CREATE POLICY "Inspections viewable by authenticated users"
    ON k3_inspections FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Inspections manageable by HSE and supervisors"
    ON k3_inspections FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('supervisor', 'hse')
        )
    );

CREATE POLICY "Corrective actions viewable by authenticated users"
    ON corrective_actions FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Corrective actions editable by assigned PIC or HSE"
    ON corrective_actions FOR UPDATE
    TO authenticated
    USING (
        assigned_pic_id = (select auth.uid())
        OR EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('supervisor', 'hse')
        )
    );

-- 7. ESG METRICS POLICIES
CREATE POLICY "ESG metrics viewable by all authenticated users"
    ON energy_emission_metrics FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "ESG metrics insertable/updatable by HSE and management"
    ON energy_emission_metrics FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = (select auth.uid())
            AND profiles.role IN ('hse', 'management')
        )
    );
