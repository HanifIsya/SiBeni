-- ==============================================================================
-- SI BENI (Siaga Bencana Dini) - PT Consnet Mining
-- Seed Data: 7 Mining Zones, Warnings, Sample Reports, and ESG Metrics
-- ==============================================================================

-- 1. SEED 7 OPERATIONAL MINING ZONES
INSERT INTO mining_zones (code, name, description, current_risk_level, active_hazards, evacuation_assembly_point, evacuation_route_info, distance_to_assembly_point_m)
VALUES
(
    'ZONE_PIT',
    'Pit Utama (Area Penambangan Aktif)',
    'Area penggalian terbuka dengan aktivitas excavator kelas 100t dan dump truck 60t.',
    'high',
    ARRAY['Potensi Longsor Lereng Barat', 'Jalan Licin Akibat Hujan'],
    'Titik Kumpul A (Assembly Point Pit Utama)',
    'Ikuti marka jalur hijau ke arah tanggul barat daya menuju Shelter Darurat A.',
    350
),
(
    'ZONE_HAUL_ROAD',
    'Jalan Angkut (Haul Road KM 0 - 15)',
    'Jalur lalu lintas utama pengangkutan material tambang menuju stockpile dan pengolahan.',
    'medium',
    ARRAY['Debu Tebal Jarak Pandang < 30m', 'Blind Spot di KM 4.2'],
    'Titik Kumpul B (Rest Area KM 7)',
    'Menepi ke safety berm sisi kiri, matikan mesin, jalan kaki ke Rest Area Pos Pantau KM 7.',
    500
),
(
    'ZONE_STOCKPILE',
    'Stockpile & ROM Timbunan',
    'Area penampungan material curah dengan mobilitas wheel loader dan conveyor hopper.',
    'low',
    ARRAY['Swa-bakar Batuan Minor'],
    'Titik Kumpul C (Depan Kantor Timbangan)',
    'Jauhi area tumpukan material curah, lurus ke arah gerbang timbangan jembatan.',
    280
),
(
    'ZONE_WORKSHOP',
    'Workshop & Maintenance Alat Berat',
    'Bengkel terpadu perbaikan unit heavy equipment, crane, dan penggantian oli.',
    'medium',
    ARRAY['Ceceran Bahan Pelumas', 'Pekerjaan Panas / Hot Work di Bay 3'],
    'Titik Kumpul D (Lapangan Parkir LV Workshop)',
    'Keluar melalui pintu darurat sisi timur ke area parkir kendaraan ringan (LV).',
    150
),
(
    'ZONE_PROCESSING',
    'Fasilitas Pengolahan (Crusher Plant)',
    'Unit peremukan bijih dan screening material dengan conveyor bertingkat.',
    'high',
    ARRAY['Bising Ekstrem', 'Getaran Tinggi Mesin Crusher'],
    'Titik Kumpul E (Assembly Point Processing Plant)',
    'Turun melalui tangga tangga darurat berpagar kuning ke lapangan terbuka depan MCC.',
    220
),
(
    'ZONE_WAREHOUSE',
    'Gudang Logistik & Handak',
    'Penyimpanan material berbahaya B3, suku cadang, dan gudang bahan peledak terisolasi.',
    'low',
    ARRAY[]::TEXT[],
    'Titik Kumpul F (Pintu Masuk Utama Gudang Handak)',
    'Bergerak berlawanan arah angin (upwind) menuju pos pengamanan gerbang ring 1.',
    400
),
(
    'ZONE_SUPPORT',
    'Fasilitas Pendukung (Mess & Site Office)',
    'Area perkantoran manajemen site, klinik K3, mess pekerja, dan kantin operasional.',
    'low',
    ARRAY[]::TEXT[],
    'Titik Kumpul Utama Site Office (Lapangan Upacara K3)',
    'Evakuasi menuju lapangan tengah depan gedung Safety Induction.',
    120
)
ON CONFLICT (code) DO UPDATE
SET current_risk_level = EXCLUDED.current_risk_level,
    active_hazards = EXCLUDED.active_hazards,
    updated_at = NOW();

-- 2. SEED OFFICIAL EARLY WARNINGS (BMKG & BNPB)
INSERT INTO early_warnings (source, title, description, severity, affected_zones, hazard_tags, valid_from, valid_until, safety_instructions, is_active)
VALUES
(
    'BMKG',
    'PERINGATAN DINI: WASPADA HUJAN LEBAT DISERTAI ANGIN KENCANG & PETIR',
    'Berdasarkan pantauan radar BMKG Wilayah IV, terdapat awan konvektif Cumulonimbus aktif yang bergerak ke arah konsesi tambang PT Consnet Mining.',
    'high',
    ARRAY['Pit Utama (Area Penambangan Aktif)', 'Jalan Angkut (Haul Road KM 0 - 15)', 'Stockpile & ROM Timbunan'],
    ARRAY['Tanah Longsor', 'Banjir Tambang', 'Jalan Angkut Licin', 'Sambaran Petir'],
    NOW() - INTERVAL '1 hour',
    NOW() + INTERVAL '11 hours',
    '1. Kurangi kecepatan hauler maksimal 25 km/jam.\n2. Waspadai genangan lumpur dan blind spot di KM 4.\n3. Operator unit tambang terbuka dilarang mendekati lereng dengan kemiringan > 45 derajat.\n4. Aktifkan radio komunikasi channel 3 Emergency.',
    TRUE
),
(
    'BNPB',
    'INFORMASI KESIAPSIAGAAN: POTENSI PERGERAKAN TANAH DI WILAYAH LERENG TAMBANG',
    'Satelit pemantau geoteknik BNPB mencatat kejenuhan air tanah mencapai level 85% setelah hujan terus-menerus selama 48 jam.',
    'medium',
    ARRAY['Pit Utama (Area Penambangan Aktif)'],
    ARRAY['Pergerakan Tanah', 'Retakan Lereng'],
    NOW() - INTERVAL '6 hours',
    NOW() + INTERVAL '18 hours',
    'HSE Geoteknik wajib memantau prisma pemantau lereng (slope monitoring radar) setiap 30 menit.',
    TRUE
);

-- 3. SEED INITIAL SAMPLE HAZARD & NEAR MISS REPORTS
INSERT INTO hazard_reports (local_id, reporter_name, report_type, zone_name, category, incident_timestamp, gps_latitude, gps_longitude, description, photo_urls, is_emergency, sync_status, hse_status)
VALUES
(
    'seed-rep-001',
    'Budi Santoso (Operator Hauler #14)',
    'hazard',
    'Jalan Angkut (Haul Road KM 0 - 15)',
    'Alat Berat & Kondisi Jalan',
    NOW() - INTERVAL '3 hours',
    -2.1458291,
    115.3489124,
    'Ditemukan retakan melintang selebar 15cm pada KM 4.2 arah Stockpile, berpotensi amblas jika dilalui heavy hauler muatan penuh.',
    ARRAY['https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?auto=format&fit=crop&w=800&q=80'],
    FALSE,
    'synced',
    'IN_REVIEW'
),
(
    'seed-rep-002',
    'Ahmad Fauzi (Rigger)',
    'near_miss',
    'Workshop & Maintenance Alat Berat',
    'Alat Berat',
    NOW() - INTERVAL '5 hours',
    -2.1441020,
    115.3498011,
    'Sling crane pengangkat bucket excavator terlepas satu sisi saat manuver. Tidak ada korban jiwa atau kerusakan unit, rigger segera menghindar.',
    ARRAY['https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=800&q=80'],
    FALSE,
    'synced',
    'ACTION_REQUIRED'
);

-- 4. SEED SAMPLE CORRECTIVE ACTIONS (Alur 6 Tahap)
INSERT INTO corrective_actions (title, description, severity, status, stage_number, assigned_pic_name, target_due_date, evidence_photo_before, hse_verification_notes)
VALUES
(
    'Penimbunan dan Pemadatan Ulang Retakan Haul Road KM 4.2',
    'Divisi Road Maintenance wajib mengerahkan motor grader dan compactor untuk meratakan serta memadatkan retakan badan jalan sebelum shift malam dimulai.',
    'high',
    'assigned',
    4,
    'Hendro Wijaya (Supervisor Road Maintenance)',
    CURRENT_DATE + INTERVAL '1 day',
    'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?auto=format&fit=crop&w=800&q=80',
    'Diprioritaskan sebelum hujan lebat berlanjut.'
),
(
    'Pemeriksaan dan Sertifikasi Ulang Webbing Sling Crane Bay 3',
    'Seluruh alat bantu angkat (lifting gear) di Workshop Bay 3 harus diinspeksi ulang dan diberi color-code bulanan yang valid.',
    'medium',
    'in_progress',
    5,
    'Supriyanto (Lead Mekanik Workshop)',
    CURRENT_DATE + INTERVAL '2 days',
    'https://images.unsplash.com/photo-1504307651254-35680f356dfd?auto=format&fit=crop&w=800&q=80',
    'Sling yang aus segera dipotong dan diafkir.'
);

-- 5. SEED ESG METRICS (Sesuai slide presentasi & DESIGN.md)
INSERT INTO energy_emission_metrics (
    record_date,
    safe_man_hours,
    total_recordable_incidents,
    calculated_trir,
    energy_electricity_gj,
    energy_natural_gas_gj,
    energy_diesel_fuel_gj,
    energy_other_gj,
    total_energy_gj,
    material_hauled_ton,
    energy_intensity_gj_per_ton,
    total_co2e_emissions_ton
)
VALUES (
    CURRENT_DATE,
    1247652.00,
    2,
    0.480,
    11153.25, -- 45% Listrik
    6196.25,  -- 25% Gas Alam
    3717.75,  -- 15% BBM Solar Industri
    3717.75,  -- 15% Lainnya
    24785.00,
    10284.23,
    2.4100,
    12456.00
)
ON CONFLICT (record_date) DO UPDATE
SET safe_man_hours = EXCLUDED.safe_man_hours,
    calculated_trir = EXCLUDED.calculated_trir,
    total_energy_gj = EXCLUDED.total_energy_gj,
    total_co2e_emissions_ton = EXCLUDED.total_co2e_emissions_ton;
