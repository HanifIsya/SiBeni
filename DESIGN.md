---
name: "SI BENI (Siaga Bencana Dini) — Industrial K3 Design System"
version: "1.0.0"
platform: "Android Mobile (Offline-First) & Responsive Web Dashboard"
organization: "PT Consnet Mining"

colors:
  # Brand & Mascot Palette
  brand-primary: "#0F4C81"        # Deep Industrial Navy (Trust, Authority)
  brand-secondary: "#00B4D8"      # SI BENI Robot Cyan (Tech, Early Warning Accent)
  brand-safety-green: "#15803D"   # K3 Safety Emerald (Safe Status, Compliance)

  # Surfaces (High-Contrast Outdoor Legibility)
  surface-bg: "#F8FAFC"           # Primary App Background
  surface-card: "#FFFFFF"         # Elevated Card Surface
  surface-dark: "#0B192C"         # Dark Header / Sidebar / High-Glare Mode
  surface-muted: "#F1F5F9"        # Input Backgrounds & Offline Banner Surface
  border-subtle: "#CBD5E1"        # 1px High-Visibility Card & Input Borders

  # Text & Iconography (WCAG AAA targeted for harsh sunlight)
  on-surface-primary: "#0F172A"
  on-surface-secondary: "#475569"
  on-surface-inverse: "#FFFFFF"

  # 4-Tier Risk Level (Tingkat Risiko)
  risk-low: "#16A34A"             # Rendah — Normal Operations
  risk-low-bg: "#DCFCE7"
  risk-medium: "#EAB308"          # Sedang — Waspada
  risk-medium-bg: "#FEF9C3"
  risk-high: "#F97316"            # Tinggi — Siaga
  risk-high-bg: "#FFEDD5"
  risk-critical: "#DC2626"        # Sangat Tinggi — Awas / Evakuasi / SOS
  risk-critical-bg: "#FEE2E2"

  # Connectivity & Sync States
  status-online: "#16A34A"        # Connected to HSE server
  status-offline: "#D97706"       # Offline mode, local queueing
  status-offline-bg: "#FEF3C7"
  status-offline-text: "#92400E"
  status-syncing: "#0284C7"       # Auto-syncing saved reports

typography:
  font-family-sans: "'Plus Jakarta Sans', 'Inter', 'Roboto', sans-serif"
  font-family-mono: "'JetBrains Mono', monospace"   # GPS, KPI numbers, timestamps
  scale:
    headline-display:
      fontSize: "28px"
      fontWeight: 800
      lineHeight: 1.2
      letterSpacing: "-0.02em"
    headline-lg:
      fontSize: "22px"
      fontWeight: 700
      lineHeight: 1.25
    headline-md:
      fontSize: "18px"
      fontWeight: 700
      lineHeight: 1.3
    body-lg:
      fontSize: "16px"
      fontWeight: 500
      lineHeight: 1.5
    body-md:
      fontSize: "14px"
      fontWeight: 400
      lineHeight: 1.5
    label-lg:
      fontSize: "14px"
      fontWeight: 700
      lineHeight: 1.2
      letterSpacing: "0.02em"
    label-sm:
      fontSize: "12px"
      fontWeight: 600
      lineHeight: 1.2
      letterSpacing: "0.04em"

spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  touch-target-min: "52px"        # Oversized for gloved/dusty hands
  sos-target: "64px"              # Emergency SOS button height

rounded:
  none: "0px"
  sm: "6px"
  md: "12px"
  lg: "16px"
  full: "9999px"

components:
  button-primary:
    backgroundColor: "{colors.brand-primary}"
    textColor: "{colors.on-surface-inverse}"
    height: "{spacing.touch-target-min}"
    rounded: "{rounded.md}"
    typography: "{typography.scale.label-lg}"
  button-sos:
    backgroundColor: "{colors.risk-critical}"
    textColor: "{colors.on-surface-inverse}"
    height: "{spacing.sos-target}"
    rounded: "{rounded.full}"
    typography: "{typography.scale.headline-md}"
  card-standard:
    backgroundColor: "{colors.surface-card}"
    borderColor: "{colors.border-subtle}"
    borderWidth: "1px"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
---

# SI BENI — Design System

## Overview

- **Product**: **SI BENI (Siaga Bencana Dini)** — aplikasi pendukung Keselamatan dan Kesehatan Kerja (K3) di industri pertambangan.
- **Organization**: **PT Consnet Mining**, a mineral mining and material hauling company with dispersed operational zones: `Pit`, `Jalan Angkut` (Haul Road), `Stockpile`, `Workshop`, `Fasilitas Pengolahan` (Processing Plant), `Gudang` (Warehouse), and `Fasilitas Pendukung` (Support Facilities).
- **Core design philosophy**: **Rugged Industrial Clarity, Offline-First Resilience, and Zero-Latency Emergency Action.** Field workers face heavy equipment hazards, landslides, fires, dust, extreme weather, and unstable connectivity. Every screen prioritizes sunlight readability, gloved-hand ergonomics, transparent offline-sync states, and instant access to emergency tools.
- **Mascot integration**: Subtle, functional use of the SI BENI white-and-cyan robot avatar for contextual safety tips, empty states, and onboarding. It must never clutter critical emergency workflows.

### Personas & Platform Split

1. **Field Workers & Heavy Equipment Operators (Android Mobile)**: Receive BMKG/BNPB early warnings, view work-zone risk maps, submit hazard/near-miss reports (online or offline), follow contextual evacuation guides, and trigger the Emergency SOS.
2. **Supervisors & HSE Team (Android Mobile + Web Dashboard)**: Verify worker reports, run K3 checklist inspections, assign and track corrective actions, activate emergency procedures, and coordinate field response.
3. **Company Management (Web Dashboard & Mobile Executive Tab)**: Monitor safety KPIs (Safe Work Hours, TRIR), K3 compliance, energy consumption, and carbon emission trends (CO₂e).

---

## Colors

- **Brand Primary (`#0F4C81`, Deep Industrial Navy)**: top app bars, primary buttons, active bottom-nav tabs, structural headers.
- **Brand Secondary (`#00B4D8`, SI BENI Cyan)**: informational badges, BMKG/BNPB data-sync indicators, interactive highlights.
- **K3 Safety Emerald (`#15803D`)**: safe-status banners, K3 inspection headers, completed corrective-action badges.

### 4-Tier Risk Level System (`Tingkat Risiko`)

Mandatory across all maps, zone chips, inspection severity tags, early warning cards, and charts.

| Level | Fill | Badge surface | Meaning |
| --- | --- | --- | --- |
| **Rendah** (Low) | `#16A34A` | `#DCFCE7` | Safe zone; normal alertness |
| **Sedang** (Medium) | `#EAB308` | `#FEF9C3` | Moderate hazard; heightened caution (`Waspada`) |
| **Tinggi** (High) | `#F97316` | `#FFEDD5` | High hazard (e.g., heavy rain + strong wind, slippery haul road); standby (`Siaga`) |
| **Sangat Tinggi** (Critical) | `#DC2626` | `#FEE2E2` | Immediate danger (landslide, fire, hazmat leak) or SOS activation (`Awas / Darurat`) |

### Offline & Sync Status

- **Offline Queue Warning (`#D97706` Amber)**: persistent top status pill when connectivity drops, reassuring workers that reports are saved locally.
- **Auto-Sync Active (`#0284C7` Blue)**: shown while the app checks the network and uploads queued reports to HSE.

---

## Typography

- **Primary typeface**: `Plus Jakarta Sans` or `Inter` (fallback `Roboto`) for crisp geometric legibility on compact Android screens in direct sunlight.
- **Numeric & telemetry typeface**: `JetBrains Mono` (or `font-variant-numeric: tabular-nums`) for GPS coordinates, incident timestamps, offline queue counters, and dashboard KPIs (`1.247.652 jam`, `TRIR 0,48`, `24.785 GJ`, `12.456 ton CO2e`).

### Hierarchy Rules

- **Emergency & warning headers (22–28px, Bold/ExtraBold, uppercase for alert level)**: e.g., `PERINGATAN DINI: WASPADA HUJAN LEBAT & ANGIN KENCANG`.
- **Section & card titles (18px, Bold)**: `Peta Risiko`, `Lapor Cepat`, `Langkah Evakuasi`, `Inspeksi K3`.
- **Body & checklist text (14–16px, Regular/Medium)**: minimum 14px on all mobile views so dust and vibration never hinder reading.

---

## Layout

- **Mobile viewport**: Android `360×800` to `412×915`; vertical single-column scroll with a fixed top status header and a fixed 5-tab bottom navigation bar.
- **Web dashboard viewport**: Desktop `1440×900`; fixed left dark sidebar (`240px`, `#0B192C`) and a 12-column responsive analytics grid.
- **Spacing grid**: 8px base unit (4, 8, 16, 24, 32). Horizontal screen padding: `16px` mobile, `24px` web.

### Field Ergonomics (Gloved & Single-Handed Use)

- Minimum touch target `52×52px` for all primary buttons, category selectors, and checklist toggles.
- Minimum `12px` vertical gap between interactive cards to prevent accidental taps on bumpy haul roads.
- A persistent floating or top-pinned **Tombol Darurat (SOS)** reachable within 1 tap from home, map, and emergency screens.

---

## Elevation & Depth

- **Borders over soft shadows**: sunlight washes out subtle shadows. Cards use a crisp `1px solid #CBD5E1` plus a light shadow (`0 2px 4px rgba(15, 23, 42, 0.06)`).
- **Active alert elevation**: Early Warning cards and Emergency banners use a `4px` solid left accent border or a full `2px` perimeter border in their semantic risk color (`#F97316` or `#DC2626`).
- **Sticky layers**:
  - Layer 1 (`z-index: 10`): content cards and interactive maps.
  - Layer 2 (`z-index: 20`): persistent Connectivity Bar (`Online` / `Mode Offline: X Laporan Tersimpan`).
  - Layer 3 (`z-index: 30`): Bottom Navigation Bar and floating `TOMBOL DARURAT (SOS)`.

---

## Shapes

- **Cards & containers**: `12px` radius (`rounded-md`).
- **Inputs, photo dropzones & buttons**: `10–12px` radius with `2px` focus rings in `#0F4C81`.
- **Risk badges & zone pills**: full pill (`9999px`), to differ visually from square clickable buttons.
- **Emergency SOS button**: circular or full-width pill (`9999px`) with a high-contrast outer pulse ring.

---

## Components

### 1. Connectivity & Offline Sync Bar (persistent sub-header)

- Shows network state and offline queue count.
- **Online**: compact green dot + `"Terhubung • Data BMKG/BNPB Aktif"`.
- **Offline**: amber banner (`#FEF3C7` background, `#D97706` border, `#92400E` text) + cloud-slash icon + `"Mode Offline Aktif • 2 Laporan Disimpan Lokal (Kirim Otomatis Saat Online)"`.

### 2. BMKG & BNPB Early Warning Banner (`Kartu Peringatan Dini`)

- Header with warning-triangle icon, source badge (`BMKG / BNPB Official`), and severity chip (`WASPADA` / `SIAGA` / `AWAS`).
- Shows headline (e.g., `"HUJAN LEBAT DISERTAI ANGIN KENCANG"`), validity period (`Periode: 07:00 WIB - 19:00 WIB`), affected zones (`Pit Utama, Jalan Angkut KM 4, Stockpile`), and hazard chips (`Banjir`, `Tanah Longsor`, `Angin Kencang`, `Debu`, `Kebakaran`).
- Primary CTA: `"Lihat Panduan Keselamatan"` (opens contextual emergency guide).

### 3. Interactive Mining Risk Map (`Peta Risiko Area Tambang`)

- Vector/satellite map with geofenced polygons for the 7 operational areas: `Pit`, `Jalan Angkut`, `Stockpile`, `Workshop`, `Fasilitas Pengolahan`, `Gudang`, `Fasilitas Pendukung`.
- Polygon overlays follow the 4-tier `Tingkat Risiko` legend.
- Floating layer-toggle pills: `[Tingkat Risiko]` `[Jalur Evakuasi]` `[Titik Kumpul]` `[Posisi Pekerja]`.

### 4. Quick Report Form Card (`Lapor Cepat Bahaya & Near Miss`)

- **Segmented type selector** (two large side-by-side cards):
  - `⚠️ BAHAYA (HAZARD)`: unsafe condition or act that may cause injury or damage.
  - `⚡ NEAR MISS`: close call that caused no injury but carried high risk.
- **Structured fields**:
  - `Lokasi Area Kerja`: auto-GPS tagger + quick-select chips (`Pit`, `Jalan Angkut`, `Stockpile`, `Workshop`, `Gudang`, `Fasilitas Pengolahan`).
  - `Kategori Bahaya`: chip grid (`Alat Berat`, `Longsor/Geoteknik`, `Kebakaran`, `Debu/Lingkungan`, `Cuaca Ekstrem`, `APD/Perilaku`).
  - `Waktu Kejadian`: auto-populated timestamp, manually editable.
  - `Dokumentasi Foto`: large dashed camera box (`min-height: 140px`), instant camera launch, thumbnail preview.
  - `Deskripsi Kondisi`: multiline text with voice-to-text mic for fast dictation.
- **Dual-state submit button**: `"KIRIM LAPORAN KE HSE"` (Navy/Green) when online; `"SIMPAN LAPORAN OFFLINE"` (Amber) when offline.

### 5. Emergency SOS & Evacuation Stepper (`Tanggap Darurat & Evakuasi`)

- **SOS trigger**: prominent red (`#DC2626`) button with siren icon, `"TOMBOL DARURAT (TEKAN & TAHAN 3 DETIK)"`; broadcasts live GPS and worker ID to Supervisors and HSE.
- **Emergency type grid (`Jenis Keadaan Darurat`)**: 5 icon cards — (1) `Kebakaran`, (2) `Cedera / Kecelakaan`, (3) `Kebocoran Bahan Berbahaya`, (4) `Banjir / Longsor`, (5) `Ancaman Keamanan`.
- **4 Core Principles callout (`Prinsip Tanggap Darurat`)**, 2×2 grid: `1. Utamakan Keselamatan`, `2. Laporkan Segera`, `3. Ikuti Arahan`, `4. Cegah Risiko Lanjutan`.
- **6-step evacuation checklist (`Langkah Evakuasi`)**, numbered vertical stepper with icons:
  1. *Kenali Tanda Alarm Darurat* — hentikan aktivitas/alat berat saat alarm berbunyi.
  2. *Menuju Jalur Evakuasi Terdekat* — ikuti rambu rute evakuasi digital.
  3. *Tetap Tenang dan Tertib* — jangan berlari atau kembali mengambil barang.
  4. *Menuju Titik Kumpul (Assembly Point)* — berkumpul di zona aman terdekat.
  5. *Ikuti Arahan Petugas* — tunggu instruksi tim HSE dan Supervisor.
  6. *Pastikan Semua Orang Telah Dievakuasi* — absensi keselamatan di titik kumpul.

### 6. K3 Inspection & Corrective Action Tracker (`Inspeksi K3 & Tindak Lanjut`)

- **Category tabs**: `Alat Berat`, `Jalan Angkut`, `Area Kerja`, `Penggunaan APD`, `APAR`, `Housekeeping`, `Lingkungan`.
- **6-stage pipeline bar (`Alur Inspeksi K3 & Corrective Action`)**, graded Green (Stage 1) → Red/Complete (Stage 6): `1. Inspeksi Lapangan` → `2. Identifikasi Temuan` → `3. Verifikasi HSE` → `4. Penugasan Corrective Action` → `5. Perbaikan & Pengendalian` → `6. Monitoring & Selesai`.

---

## Screen Blueprints & User Flows

| Screen ID | Screen Name | Target Role | Key UI Elements & Data Points |
| --- | --- | --- | --- |
| **M-01** | **Beranda & Peta Risiko** (Home & Risk Map) | Pekerja, Supervisor, HSE | Top bar with worker zone badge (`Pit Utara`), Offline/Online pill, BMKG/BNPB Early Warning banner, interactive 4-color `Peta Risiko Area Tambang`, quick-action cards for `Lapor Cepat` and `Tombol Darurat`. |
| **M-02** | **Lapor Cepat Bahaya & Near Miss** | Pekerja, Operator | Slogan banner *"Lapor Hari Ini, Cegah Kecelakaan Esok Hari"*, `Bahaya` vs `Near Miss` toggle, GPS zone selector (`Pit`, `Jalan Angkut`, `Stockpile`, `Workshop`), hazard category selector, camera upload box, description input, offline-capable submit button with local queue list. |
| **M-03** | **Tanggap Darurat & Peta Evakuasi** | Seluruh Pekerja, Supervisor | High-priority `TOMBOL DARURAT (SOS)`, 5 `Jenis Keadaan Darurat` filters, contextual action guide, offline digital map with `Jalur Evakuasi` (green dashed arrows) and `Titik Kumpul` markers, 6-step `Langkah Evakuasi` stepper. |
| **M-04** | **Inspeksi K3 & Corrective Action** | Tim HSE, Supervisor | Checklist form for `APD`, `Alat Berat`, `Jalan Angkut`, `APAR`, `Housekeeping`; finding severity tagger; photo attachment; PIC assignment; 6-step `Corrective Action` tracker. |
| **M-05 / W-01** | **Dashboard K3, Energi & Emisi** | Tim HSE, Supervisor, Manajemen | Location & date filters; 5 KPI cards (`Total Jam Kerja Aman: 1.247.652 jam`, `TRIR: 0,48`, `Energi Total: 24.785 GJ`, `Intensitas Energi: 2,41 GJ/ton`, `Emisi Total CO2e: 12.456 ton`); `K3 - Tren Insiden` line chart; `Energi - Konsumsi per Sumber` donut (`Listrik 45%`, `Gas Alam 25%`, `BBM 15%`, `Lainnya 15%`); `Emisi - Tren Emisi (CO2e)` line chart. |

---

## Do's and Don'ts

**Do**

- Enforce the exact 4-tier Indonesian risk taxonomy (`Rendah` `#16A34A`, `Sedang` `#EAB308`, `Tinggi` `#F97316`, `Sangat Tinggi` `#DC2626`) across all maps, badges, and charts.
- Show a visible **Mode Offline** indicator and queued-report badge on mobile screens; unstable pit connectivity is a core requirement.
- Keep all interface copy in clear, action-oriented **Bahasa Indonesia** using K3 terminology (`Bahaya`, `Near Miss`, `Titik Kumpul`, `Jalur Evakuasi`, `Alat Berat`, `Jalan Angkut`, `Corrective Action`).
- Use large, glove-friendly buttons (`min-height: 52px`) with high-contrast borders (`1px solid #CBD5E1`) for bright outdoor glare.

**Don't**

- Don't hide the **Tombol Darurat (SOS)** in settings menus or collapsible drawers; it must stay immediately reachable.
- Don't build multi-page wizard forms for hazard reporting. Use a **single structured reporting flow** (`alur pelaporan tunggal dengan isian terstruktur`) completable in under 30 seconds.
- Don't use low-contrast pastel text, glassmorphism, or thin 10px fonts; they become unreadable in dusty open-pit conditions.

---

## Agent Prompt Guide (Google Stitch)

Attach this `DESIGN.md` to your Stitch session, then use these prompts to generate each screen consistently.

### Screen 1 — Mobile Home & Risk Map

> Using the attached DESIGN.md for SI BENI, generate a mobile Android screen for "Peta Risiko & Peringatan Dini" at PT Consnet Mining. Include a navy top header (`#0F4C81`) showing the SI BENI robot avatar, current worker zone "Area: Pit Utama", and an active Online/BMKG sync badge. Below, place a high-priority orange Early Warning Card ("PERINGATAN DINI BMKG: WASPADA HUJAN LEBAT & ANGIN KENCANG", Period: 07.00 - 19.00 WIB, Potential Hazards: Tanah Longsor, Banjir, Jalan Angkut Licin). In the center, render an interactive mining risk map with geofenced zones (Pit, Jalan Angkut, Stockpile, Workshop) color-coded with the 4 risk levels (Rendah Green, Sedang Yellow, Tinggi Orange, Sangat Tinggi Red) and a compact Tingkat Risiko legend. Include a prominent floating red "TOMBOL DARURAT (SOS)" button and a 5-tab bottom navigation bar (Peta Risiko, Lapor Cepat, Darurat, Inspeksi K3, Dashboard).

### Screen 2 — Quick Hazard & Near Miss Report (Offline Mode)

> Using the attached DESIGN.md, generate a mobile Android screen for "Lapor Cepat Bahaya & Near Miss". Below the app bar, display an amber Offline Mode banner ("Mode Offline Aktif • Laporan disimpan lokal & terkirim otomatis saat jaringan stabil — 1 Laporan Menunggu Sinkronisasi"). Add the sub-header "Lapor Hari Ini, Cegah Kecelakaan Esok Hari". Add a large 2-option segmented card selector for "BAHAYA (HAZARD)" (selected, orange highlight) and "NEAR MISS" (yellow icon). Below, a single-screen structured form with: 1) Lokasi Area Kerja chips (Pit, Jalan Angkut, Stockpile, Workshop, Gudang) with GPS coordinates, 2) Kategori Bahaya selector (Alat Berat, Longsor, Kebakaran, Debu, Cuaca Ekstrem), 3) a large dashed camera upload box with a preview of a haul road crack, 4) Deskripsi Kondisi text area with voice mic button, and 5) a full-width amber primary button "SIMPAN LAPORAN OFFLINE (KIRIM OTOMATIS)".

### Screen 3 — Emergency Response & Evacuation

> Using the attached DESIGN.md, generate a mobile Android screen for "Tanggap Darurat & Evakuasi". At the top, place an oversized crimson red button (`#DC2626`) labeled "TOMBOL DARURAT (SOS) — HUBUNGI HSE & SUPERVISOR". Below it, a horizontally scrollable row of 5 "Jenis Keadaan Darurat" icon cards: Kebakaran, Cedera/Kecelakaan, Kebocoran Bahan Berbahaya, Banjir/Longsor, Ancaman Keamanan. Next, an interactive "Peta Jalur Evakuasi & Titik Kumpul" card with a green dashed evacuation route from "Pit Utama" to "Titik Kumpul A (Assembly Point)" with distance "350m". Below the map, the "Prinsip Tanggap Darurat" 2x2 grid (Utamakan Keselamatan, Laporkan Segera, Ikuti Arahan, Cegah Risiko Lanjutan) and the 6-step vertical "Langkah Evakuasi" checklist.

### Screen 4 — K3 Inspection & Corrective Action

> Using the attached DESIGN.md, generate a mobile Android screen for Supervisors and HSE titled "Inspeksi K3 & Corrective Action". Include a horizontal progress bar showing the 6-stage "Alur Inspeksi K3 & Corrective Action" (1 to 6, graded green to red). Add filter tabs: "Penggunaan APD", "Alat Berat", "Jalan Angkut", "APAR", "Housekeeping", "Lingkungan". Show an active checklist card for "Jalan Angkut & Alat Berat - Shift Pagi" with pass/fail toggle buttons, a photo evidence thumbnail, and an active "Corrective Action" card showing PIC, target completion time, HSE verification status, and a green "Verifikasi & Selesaikan" button.

### Screen 5 — Web & Mobile Executive Dashboard

> Using the attached DESIGN.md, generate the "Dashboard K3, Energi & Emisi" analytics interface for PT Consnet Mining. Include a dark slate left sidebar (`#0B192C`) with items: Dashboard (active, green `#16A34A`), K3, Energi, Emisi, Target & KPI, Laporan, Pengaturan. In the top header, display "K3, ENERGI & EMISI" with a date range picker ("1 - 17 Mei") and location filter ("Semua Lokasi"). Across the top row, render 5 KPI cards with trend badges: 1) Total Jam Kerja Aman (`1.247.652 jam`, `+12,4%`), 2) TRIR (`0,48`, `-20,0%`), 3) Energi Total (`24.785 GJ`, `-3,1%`), 4) Intensitas Energi (`2,41 GJ/ton`, `-5,5%`), 5) Emisi Total CO2e (`12.456 ton`, `-6,8%`). Below, a 3-column chart grid: 1) "K3 - Tren Insiden" line chart (TRIR vs Target), 2) "Energi - Konsumsi per Sumber" donut chart (`24.785 GJ` split across Listrik, Gas Alam, BBM), 3) "Emisi - Tren Emisi (CO2e)" downward-trend line chart.
