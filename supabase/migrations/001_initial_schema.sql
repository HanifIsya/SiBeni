-- ==============================================================================
-- SI BENI (Siaga Bencana Dini) - PT Consnet Mining
-- Migration 001: Initial Schema
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. ENUM TYPES
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('worker', 'operator', 'supervisor', 'hse', 'management');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE risk_level AS ENUM ('low', 'medium', 'high', 'critical');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE report_type AS ENUM ('hazard', 'near_miss');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE emergency_type AS ENUM ('fire', 'injury', 'chemical_leak', 'landslide_flood', 'security');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE ca_status AS ENUM (
        'inspection',
        'identified',
        'verified',
        'assigned',
        'in_progress',
        'completed',
        'verified_closed'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. USER PROFILES
CREATE TABLE IF NOT EXISTS profiles (
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

-- 3. MINING OPERATIONAL ZONES
CREATE TABLE IF NOT EXISTS mining_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(30) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    current_risk_level risk_level DEFAULT 'low',
    active_hazards TEXT[] DEFAULT '{}',
    polygon_coordinates JSONB,
    evacuation_assembly_point VARCHAR(100),
    evacuation_route_info TEXT,
    distance_to_assembly_point_m INT DEFAULT 300,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. OFFICIAL EARLY WARNINGS (BMKG & BNPB)
CREATE TABLE IF NOT EXISTS early_warnings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source VARCHAR(50) NOT NULL, -- 'BMKG', 'BNPB', 'HSE_INTERNAL'
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    severity risk_level NOT NULL DEFAULT 'medium',
    affected_zones TEXT[] NOT NULL DEFAULT '{}',
    hazard_tags TEXT[] NOT NULL DEFAULT '{}',
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    safety_instructions TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. HAZARD & NEAR MISS REPORTS (OFFLINE-FIRST SYNC CAPABLE)
CREATE TABLE IF NOT EXISTS hazard_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    local_id VARCHAR(100), -- Unique client-generated UUID for idempotency
    reporter_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    reporter_name VARCHAR(150),
    report_type report_type NOT NULL DEFAULT 'hazard',
    zone_id UUID REFERENCES mining_zones(id) ON DELETE SET NULL,
    zone_name VARCHAR(100) NOT NULL,
    category VARCHAR(100) NOT NULL,
    incident_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    gps_latitude NUMERIC(10, 7),
    gps_longitude NUMERIC(10, 7),
    description TEXT NOT NULL,
    photo_urls TEXT[] DEFAULT '{}',
    audio_note_url TEXT,
    is_emergency BOOLEAN DEFAULT FALSE,
    sync_status VARCHAR(30) DEFAULT 'synced',
    hse_status VARCHAR(50) DEFAULT 'SUBMITTED', -- SUBMITTED, IN_REVIEW, ACTION_REQUIRED, CLOSED
    hse_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. EMERGENCY SOS EVENTS
CREATE TABLE IF NOT EXISTS emergency_sos_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    worker_name VARCHAR(150) NOT NULL,
    zone_name VARCHAR(100) NOT NULL,
    gps_latitude NUMERIC(10, 7),
    gps_longitude NUMERIC(10, 7),
    emergency_type emergency_type NOT NULL,
    status VARCHAR(50) DEFAULT 'ACTIVE', -- ACTIVE, RESPONDED, RESOLVED
    responded_by UUID REFERENCES profiles(id),
    responded_at TIMESTAMPTZ,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. K3 INSPECTIONS & CORRECTIVE ACTIONS
CREATE TABLE IF NOT EXISTS k3_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inspector_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    inspector_name VARCHAR(150),
    inspection_category VARCHAR(100) NOT NULL, -- APD, Alat Berat, Jalan Angkut, APAR, Housekeeping, Lingkungan
    zone_id UUID REFERENCES mining_zones(id) ON DELETE SET NULL,
    zone_name VARCHAR(100),
    title VARCHAR(200) NOT NULL,
    notes TEXT,
    passed_items INT DEFAULT 0,
    failed_items INT DEFAULT 0,
    inspection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS corrective_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inspection_id UUID REFERENCES k3_inspections(id) ON DELETE CASCADE,
    hazard_report_id UUID REFERENCES hazard_reports(id) ON DELETE SET NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    severity risk_level NOT NULL DEFAULT 'medium',
    status ca_status DEFAULT 'identified',
    stage_number INT DEFAULT 2, -- 1..6 aligned with Design System pipeline
    assigned_pic_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    assigned_pic_name VARCHAR(150),
    target_due_date DATE NOT NULL,
    completion_date DATE,
    evidence_photo_before TEXT,
    evidence_photo_after TEXT,
    hse_verifier_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    hse_verification_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. ESG METRICS: K3, ENERGY & CARBON EMISSIONS
CREATE TABLE IF NOT EXISTS energy_emission_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    record_date DATE NOT NULL UNIQUE,
    safe_man_hours NUMERIC(12, 2) DEFAULT 1247652.00,
    total_recordable_incidents INT DEFAULT 2,
    calculated_trir NUMERIC(6, 3) DEFAULT 0.480,
    energy_electricity_gj NUMERIC(10, 2) DEFAULT 11153.25, -- 45%
    energy_natural_gas_gj NUMERIC(10, 2) DEFAULT 6196.25,  -- 25%
    energy_diesel_fuel_gj NUMERIC(10, 2) DEFAULT 3717.75,  -- 15%
    energy_other_gj NUMERIC(10, 2) DEFAULT 3717.75,        -- 15%
    total_energy_gj NUMERIC(10, 2) DEFAULT 24785.00,
    material_hauled_ton NUMERIC(12, 2) DEFAULT 10284.23,
    energy_intensity_gj_per_ton NUMERIC(8, 4) DEFAULT 2.4100,
    total_co2e_emissions_ton NUMERIC(10, 2) DEFAULT 12456.00,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indices for performance
CREATE INDEX IF NOT EXISTS idx_hazard_reports_created_at ON hazard_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_hazard_reports_zone_id ON hazard_reports(zone_id);
CREATE INDEX IF NOT EXISTS idx_hazard_reports_local_id ON hazard_reports(local_id);
CREATE INDEX IF NOT EXISTS idx_early_warnings_active ON early_warnings(is_active, valid_until);
CREATE INDEX IF NOT EXISTS idx_emergency_sos_status ON emergency_sos_logs(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_corrective_actions_status ON corrective_actions(status, target_due_date);
