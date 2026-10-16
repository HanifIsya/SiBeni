# SI BENI — Design System & UI/UX Specification

**Sistem Keselamatan Tambang Buka Pit**
PT Consnet Mining · Android-first, responsif hingga tablet dan web

| | |
| :--- | :--- |
| **Document** | Design System v3.0 |
| **Scope** | Flutter client (`frontend/lib`), design tokens, motion, interaction |
| **Compliance** | Kepmen ESDM 1827 K/30/MEM/2018 · ISO 45001:2018 · WCAG 2.2 AA (AAA on critical surfaces) |
| **Status** | Production |

---

## 1. Design Intent

> **Calm under pressure.** A mining safety tool is used at the worst possible
> moment: an operator standing in the rain on a haul road, gloved, shaken by a
> 100-tonne hauler, with one bar of signal. The interface therefore optimises
> for *legibility and certainty*, never for decoration.

Three principles govern every decision in this document:

1. **Colour means a decision.** Colour is never decorative. If something is
   amber, the operator must be able to say what amber requires of them.
2. **Nothing is fabricated.** No placeholder coordinates, no invented KPI
   figures, no "sample" risk levels. If the system does not know, it says so.
3. **Interaction is confirmed.** Under gloves and vibration, every tap must
   answer with immediate, unmissable feedback.

### 1.1 What was removed, and why

The previous revision (v2.x) carried implementation detail into the interface —
provider names in headings, transport names in status bars, database names in
button labels. These are *system facts*, not *user facts*. The worker needs to
know the hazard, the zone, and the distance. They do not need to know which map
renderer drew the polygon.

| Removed from UI | Reason |
| :--- | :--- |
| `(OpenStreetMap)` in map headings, `OSM Live Tiles` chip | Provider detail. A single, legally-required attribution remains in the map corner. |
| `Terhubung • Data BMKG/BNPB Aktif (Live Render & Supabase)` | Redundant; replaced by a compact live status capsule. |
| `KIRIM LAPORAN KE HSE` / `Tahap berhasil diperbarui ke … di database Supabase!` | Infrastructure leaked into copy. Now: `Kirim Laporan`. |
| `Tiket Tindak Lanjut Aktif (Supabase)` | Infrastructure leak. Now: `Tindak Lanjut`. |
| `Sesi Terverifikasi Supabase Auth` | Infrastructure leak. Replaced by a one-line security note. |
| `GPS Terdeteksi: -2.1458291, 115.3489124 (Pit Radar)` | Hardcoded coordinate presented as live. Now a real GNSS fix or an explicit "not available". |
| `1.247.652 jam` style KPI defaults | Fabricated safety figures. Now an em dash until the server returns data. |

---

## 2. Foundations

### 2.1 Colour

#### Structure & brand

| Token | Hex | Role |
| :--- | :--- | :--- |
| `brandDeep` | `#062235` | App bar, hero panels — the app's anchor surface |
| `brand` | `#0B3A5D` | Primary actions, links, active navigation |
| `accent` | `#22B8E6` | Telemetry accent: GNSS position, live indicators |
| `accentDeep` | `#0E8FB8` | Secondary data series |

#### Surfaces

| Token | Hex | Role |
| :--- | :--- | :--- |
| `canvas` | `#F4F6FA` | Page background |
| `surface` | `#FFFFFF` | Cards, sheets, inputs |
| `surfaceMuted` | `#EDF1F6` | Secondary panels, skeletons |
| `surfaceSunken` | `#E6ECF3` | Track fills, segmented control background |
| `hairline` | `#DDE4ED` | The single border treatment (1 px) |

#### Text

| Token | Hex | Contrast on `surface` |
| :--- | :--- | :--- |
| `ink` | `#0B1622` | 17.4 : 1 (AAA) |
| `inkMuted` | `#5A6B7D` | 5.2 : 1 (AA) |
| `inkFaint` | `#8494A6` | 3.1 : 1 — **metadata and labels only, never load-bearing** |
| `onDarkMuted` | `#A9C0D4` | 7.9 : 1 on `brandDeep` (AAA) |

#### Risk taxonomy

The four-level scale is the semantic backbone of the product. It appears in map
fills, zone pins, ticket accents, and warning cards — and never varies.

| Level | Indicator | Surface | Meaning & required action |
| :--- | :--- | :--- | :--- |
| **Rendah** | `#12805C` | `#E4F6EF` | Normal working conditions. Routine vigilance. |
| **Sedang** | `#B45309` | `#FDF3E3` | Caution. Heavy dust, morning fog, hot work in the workshop. |
| **Tinggi** | `#D9480F` | `#FDEEE4` | High hazard. Heavy rain, slick haul road, minor slope cracking. **Hauler speed capped at 25 km/h.** |
| **Kritis** | `#C81E1E` | `#FCEAEA` | Imminent danger. Active landslide, unit fire, chemical release, or an active SOS. **Evacuate.** |

Connectivity uses the same discipline, in the same visual language:

| State | Indicator | Surface | Meaning |
| :--- | :--- | :--- | :--- |
| Online · Wi-Fi | `#12805C` | — | Verified round-trip to the server. |
| Online · Seluler | `#12805C` | — | Verified round-trip over mobile data. |
| Wi-Fi Saja | `#B45309` | — | Cellular is disabled by user preference. |
| Terputus | `#B45309` | — | Transport present, server unreachable. |
| Offline | `#8494A6` | — | No transport. Reports are queued on device. |

### 2.2 Typography

| Family | Use |
| :--- | :--- |
| **Plus Jakarta Sans** | All interface copy. Chosen for a tall x-height and wide counters, which stay legible through a scratched screen protector in direct sun. |
| **JetBrains Mono** | Telemetry only: coordinates, accuracy, employee IDs, dates, KPI figures. Tabular figures prevent layout jitter as numbers change. |

| Style | Size / Weight | Use |
| :--- | :--- | :--- |
| `displaySmall` | 28 / 800, −0.6 tracking | Auth hero only |
| `headlineMedium` | 22 / 800 | Screen-level statements |
| `headlineSmall` | 19 / 800 | Bottom-sheet titles |
| `titleLarge` | 16.5 / 700 | Section titles |
| `titleMedium` | 14.5 / 700 | Card titles, form labels |
| `bodyLarge` | 14.5 / 500, 1.5 line-height | Descriptions, safety instructions |
| `bodySmall` | 11.5 / 400, 1.45 | Metadata |
| `labelSmall` | 10.5 / 800, +1.1 tracking | Eyebrows (`ALUR 6 TAHAP`) |
| `mono` | 11 – 24 / 600–800 | Telemetry |

### 2.3 Spacing, radius, elevation

An 4-pt base scale keeps rhythm consistent: `xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 28`.

Radii express hierarchy: `sm 10` (chips, inline controls) · `md 14` (buttons, panels) ·
`lg 20` (cards) · `xl 28` (hero panels, sheets) · `pill 999` (capsules).

Two elevation levels only — `shadowSoft` for resting cards, `shadowLift` for hero
panels and pressed emphasis. A third would flatten the hierarchy.

### 2.4 Ergonomics

- **Touch target:** 52 dp minimum for primary controls; 48 dp for secondary inline
  controls. The SOS ring is 190 dp.
- **Target gap:** 12 dp minimum between adjacent controls, to defeat mis-taps
  caused by cab vibration.
- **OS text scaling is clamped to 0.9 – 1.3** at the app root. Beyond 1.3 the
  safety taxonomy stops being scannable; below 0.9 it is unreadable in sun.

---

## 3. Responsiveness

The previous layout was phone-only and overflowed. The shell is now adaptive:

| Width | Behaviour |
| :--- | :--- |
| `< 720 dp` | Bottom `NavigationBar`, 18 dp gutter, single-column content |
| `≥ 720 dp` | `NavigationRail`, 24 dp gutter |
| `≥ 1040 dp` | 28 dp gutter, content capped at **820 dp** |

Enforcement rules, applied by `AdaptivePage` on every screen:

1. Content width is capped so line length never exceeds a comfortable measure.
2. Every screen is a `CustomScrollView` — nothing can be pushed off-screen.
3. `keyboardDismissBehavior: onDrag` and `adjustResize` keep the submit button
   reachable while typing.
4. Grid layouts compute their tile width from the available space rather than a
   fixed `childAspectRatio`.
5. Numeric and telemetry blocks use `FittedBox` so a long figure shrinks instead
   of overflowing.
6. Any text that cannot fit degrades gracefully via `maxLines` + `ellipsis`.

---

## 4. Information Architecture

Navigation is role-aware and always five destinations at most.

```
SI BENI ─────────────────────────────── [Online · Seluler] (IS)
│
├─ Peta         Risk map, early warnings, GNSS position
├─ Lapor        Hazard & near-miss capture            ← all roles
├─ Darurat      3-second hold SOS + evacuation         ← all roles
├─ Inspeksi     Corrective-action pipeline            ← Supervisor, HSE, Management
└─ Insight      K3, energy & carbon metrics           ← HSE, Management
```

The app bar is a single 58 dp band carrying only identity and system state:
brand mark, employee ID, name · role, live connectivity capsule, avatar, settings.
The previous design spent a further 40 dp on a full-width connectivity banner on
every screen; that is now a capsule, reclaimed as reading area.

### 4.1 M-01 · Risk Map

- **Situation panel** (dark hero): overall risk for the worker's zone, live GNSS
  coordinate and accuracy. One glance answers "am I safe, and where am I".
- **Early warnings**: severity-coded cards. Collapsed by default; expand to reveal
  safety instructions and affected zones. Source attribution is shown as a small
  source pill, never as a heading.
- **Map**: zone footprints rendered as risk-coloured polygons with tappable pins;
  evacuation assembly points as green flags; the worker's real GNSS position as a
  cyan disc. Pan, pinch-zoom; rotation disabled to prevent disorientation in gloves.
- **Legend** below the map: the four risk levels, plus position and assembly-point keys.
- **Actions**: `Lapor` and `Darurat` as a pinned pair at the foot of the screen.

> **Data contract.** Zone geometry (`polygon_coordinates`: centre, ring, assembly
> point) lives in `mining_zones` and is read at runtime. No coordinate is compiled
> into the client. Relocating a site is a data change, not a release.
> See `supabase/migrations/003_zone_geometry.sql`.

### 4.2 M-02 · Quick Report

Ordered for a 30-second completion, with no back-navigation:

1. **Type** — `BAHAYA` or `NEAR MISS` as two large, risk-coloured cards.
2. **Location** — live GNSS readout with accuracy, plus zone chips. If no fix is
   available the report still sends; the coordinate is simply omitted.
3. **Category** — six hazard tiles, each ≥ 48 dp tall.
4. **Description** — single multi-line field, 500 character cap.
5. **Submit** — one primary button. Its label and colour follow the network state
   (`Kirim Laporan` / `Simpan Laporan`).

A persistent footnote states, in one line, how many reports are queued.

### 4.3 M-03 · Emergency

- **SOS control**: a 190 dp radial target. A 3-second hold fills the ring; the
  countdown is shown to 0.1 s. Releasing early cancels. Vibrates on completion.
  The hold exists because a momentary tap must not trigger an evacuation.
- **Incident type**: five chips, ≥ 48 dp.
- **Evacuation card**: mini-map from the worker's live position to the zone's
  assembly point, with the **measured** great-circle distance, plus the zone's
  published route text.
- **Principles and steps**: four principle cards, six numbered steps — collapsed
  to a reference, never above the SOS control.

Failure path: if the broadcast cannot be delivered, the SOS is written to the
offline outbox as an emergency record and the dialog states *"Sinyal tersimpan"*
rather than implying the control room has been reached.

### 4.4 M-04 · Inspection & Corrective Action

- Six-stage pipeline rendered as a connected step track: Inspeksi → Temuan →
  Verifikasi → Tugaskan → Perbaikan → Selesai.
- Tickets carry a severity accent rail, a stage progress bar, PIC, and target date
  (turning critical when overdue).
- Filter capsule: Semua · Aktif · Selesai.
- Only Supervisor, HSE and Management see the advance control.

### 4.5 M-05 · Insight

Four KPI tiles plus a carbon hero panel and an energy-composition breakdown with
animated bar fills. Missing values render as `—`. There are no hardcoded targets
or trend percentages.

---

## 5. Motion

Motion confirms cause and effect. Nothing loops for decoration.

| Interaction | Response | Duration |
| :--- | :--- | :--- |
| Any tappable element | Scale to 0.96–0.97 + opacity dip | 140 ms, `easeOutCubic` |
| Screen content entry | Fade + 14 px rise, staggered 55 ms per item | 420 ms |
| Connectivity change | Capsule colour + label cross-fade | 260 ms |
| Live indicator | Pulsing halo, only while online | 1600 ms loop |
| Energy bars | Grow from zero on load | 700 ms |
| SOS hold | Radial progress, ring cap round | 3 s |
| Loading placeholders | Skeleton shimmer, reverse loop | 1250 ms |

Haptics accompany every deliberate action: light impact on button press, medium
on advance-stage, heavy on SOS completion.

---

## 6. Connectivity Architecture

`NetworkService` is the single source of truth. A transport being present does
**not** mean the uplink works — mine sites are full of captive portals and dead
backhaul. The service therefore:

1. Resolves the transport to `wifi · cellular · ethernet · none`.
2. Applies the user's **mobile-data policy** (§6.1).
3. Performs a real HTTP round-trip to `/api/health` before declaring `online`.

States surfaced: `online`, `mobileBlocked`, `unreachable`, `offline`.

### 6.1 Mobile data policy

Mining LTE is frequently the *only* link, so cellular access is **enabled by
default**. The operator can restrict usage in Settings → *Izinkan Data Seluler*
(persisted locally). With cellular disabled:

- API reads are served from cache.
- The outbox holds reports until Wi-Fi returns.
- The status capsule reads `Wi-Fi Saja` — never a generic "online".

### 6.2 Zero-loss outbox

`OfflineSyncManager` writes every report to durable storage **before** attempting
delivery, then flushes item-by-item with bounded retries. A report that fails
part-way is never dropped; the queue count is always visible in the status
capsule and the report screen.

---

## 7. Location Integrity

`LocationService` is the only source of coordinates. It surfaces six states —
`idle · requesting · locating · ready · blocked · serviceOff · unavailable` — and
each is presented honestly:

- **No fix** → the map shows a prompt with a shortcut to system settings; the
  report omits coordinates rather than inventing them.
- **Blocked permission** → the prompt reads *"Lokasi tidak aktif"*.
- **Available** → coordinate in monospace plus accuracy, e.g. `±8 m`.

There is no fallback coordinate anywhere in the codebase. If the device cannot
resolve a position, the map falls back to zone geometry from the database.

---

## 8. Component Inventory

| Component | File | Purpose |
| :--- | :--- | :--- |
| `SbCard` | `widgets/sb_card.dart` | The single card primitive — radius, border and elevation language |
| `SbPanel` | `widgets/sb_card.dart` | Dense metadata block |
| `SbHeroPanel` | `widgets/sb_card.dart` | Dark, high-contrast situation readout |
| `SbButton` | `widgets/sb_button.dart` | Primary / secondary / ghost / danger, with busy state |
| `SbIconButton` | `widgets/sb_button.dart` | Round action, optional badge |
| `SbSegmented` | `widgets/sb_button.dart` | Animated segmented control |
| `SbPill` · `RiskPill` · `SbTag` | `widgets/pills.dart` | Status, risk level, taxonomy tags |
| `PulseDot` | `widgets/pills.dart` | Live-connection indicator |
| `Pressable` | `widgets/pressable.dart` | Universal press feedback |
| `SectionHeader` | `widgets/states.dart` | Section title + optional action |
| `EmptyState` | `widgets/states.dart` | Explicit "no data" — never a fabricated default |
| `SkeletonBox` | `widgets/states.dart` | Loading placeholder |
| `Reveal` | `widgets/states.dart` | Staggered entrance |
| `AdaptivePage` | `widgets/adaptive_page.dart` | Gutter, max width, scroll, refresh |
| `NetworkPill` | `widgets/network_pill.dart` | Live connectivity + queue capsule |

---

## 9. Content Rules

1. **Say the action, not the infrastructure.** "Kirim Laporan", not "Kirim ke API".
2. **One sentence, one idea.** No parenthetical system details.
3. **Never show a value the system does not have.** `—` over a guess.
4. **Errors are actionable.** *"Tidak ada koneksi ke server"* — not a stack trace.
5. **Numbers get units.** `350 m`, `2,41 GJ/t`, `±8 m`.
6. **Indonesian locale throughout**, with `.` thousands and `,` decimals.

---

## 10. Accessibility

- Every interactive element has a semantic label and a ≥ 48 dp target
  (52 dp for primary controls).
- Risk is never encoded by hue alone — each level carries an icon and a text label.
- Text contrast ≥ AA everywhere, AAA on all critical safety surfaces.
- Press feedback is redundant across three channels: motion, opacity, haptics.
- Text scaling honoured within a 0.9 – 1.3 clamp.

---

## 11. Release Configuration

| Item | Value |
| :--- | :--- |
| Application ID | `com.consnet.sibeni.sibeni` |
| Version | 1.1.0 (+2) |
| Min SDK | Flutter default (21) |
| Signing | Release keystore (`android/sibeni-release.jks` + `android/key.properties`, git-ignored and injected from the CI secret store) |
| Permissions | INTERNET, ACCESS_NETWORK_STATE, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, CAMERA |

Build:

```bash
cd frontend
flutter pub get
flutter analyze
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```