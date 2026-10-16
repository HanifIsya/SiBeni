import { NextRequest, NextResponse } from "next/server";
import { getUserClient } from "@/lib/supabase";
import { resolveProfile } from "@/lib/auth";

export const dynamic = "force-dynamic";

const REVIEW_ROLES = ["supervisor", "hse", "management"];

const VALID_STATUS = ["SUBMITTED", "IN_REVIEW", "ACTION_REQUIRED", "CLOSED"];

/**
 * GET /api/reports
 *
 * Hazard & near-miss register. Row Level Security scopes this automatically:
 * a worker only ever sees their own submissions, reviewers see the whole site.
 */
export async function GET(req: NextRequest) {
  try {
    const client = getUserClient(req);
    const profile = await resolveProfile(req);
    if (!profile) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const url = new URL(req.url);
    const status = url.searchParams.get("status");
    const zone = url.searchParams.get("zone");
    const limit = Math.min(Number(url.searchParams.get("limit") || 100), 200);

    let query = client
      .from("hazard_reports")
      .select(
        "id, local_id, reporter_name, report_type, zone_name, category, " +
          "incident_timestamp, gps_latitude, gps_longitude, description, " +
          "photo_urls, is_emergency, sync_status, hse_status, hse_notes, " +
          "created_at, updated_at"
      )
      .order("created_at", { ascending: false })
      .limit(limit);

    if (status && VALID_STATUS.includes(status.toUpperCase())) {
      query = query.eq("hse_status", status.toUpperCase());
    }
    if (zone) {
      query = query.ilike("zone_name", `%${zone}%`);
    }

    const { data, error } = await query;
    if (error) throw error;

    // The client is untyped (no generated Database types), so treat the row
    // shape explicitly rather than letting TypeScript infer a union with the
    // PostgREST error type.
    const reports = (data ?? []) as Record<string, any>[];
    const count = (status: string) =>
      reports.filter((r) => String(r.hse_status || "").toUpperCase() === status).length;

    const counts = {
      total: reports.length,
      submitted: count("SUBMITTED"),
      in_review: count("IN_REVIEW"),
      action_required: count("ACTION_REQUIRED"),
      closed: count("CLOSED"),
      emergency: reports.filter((r) => Boolean(r.is_emergency)).length,
    };

    return NextResponse.json({ reports, counts, viewer_role: profile.role });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/**
 * POST /api/reports
 *
 * Idempotent bulk ingest from the device outbox. `local_id` carries a UNIQUE
 * constraint (migration 004), so a client that retries after a timeout can
 * never create a duplicate record.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const reports = Array.isArray(body) ? body : [body];

    if (reports.length === 0) {
      return NextResponse.json({ message: "No reports to sync", results: [] }, { status: 200 });
    }

    const client = getUserClient(req);
    const profile = await resolveProfile(req);

    const results: any[] = [];

    for (const report of reports) {
      const {
        local_id,
        reporter_employee_id,
        reporter_name,
        report_type,
        zone_id,
        zone_name,
        category,
        incident_timestamp,
        gps_latitude,
        gps_longitude,
        description,
        photo_urls,
        is_emergency,
      } = report;

      // Resolve the reporter to a real profile UUID: reporter_id is a UUID
      // foreign key, so an employee number can never be written directly.
      let reporterId = profile?.id ?? null;
      let resolvedName = reporter_name || profile?.full_name || "Pekerja Tambang";

      if (!reporterId && reporter_employee_id) {
        const { data: byEmployee } = await client
          .from("profiles")
          .select("id, full_name")
          .eq("employee_id", reporter_employee_id)
          .maybeSingle();
        if (byEmployee) {
          reporterId = byEmployee.id;
          resolvedName = byEmployee.full_name;
        }
      }

      const payload: Record<string, unknown> = {
        local_id: local_id ?? `srv-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
        reporter_id: reporterId,
        reporter_name: resolvedName,
        report_type: report_type === "near_miss" ? "near_miss" : "hazard",
        zone_id: zone_id || null,
        zone_name: zone_name || "Pit Utama",
        category: category || "Kondisi Berbahaya",
        incident_timestamp: incident_timestamp || new Date().toISOString(),
        description: description || "Tanpa deskripsi rinci",
        photo_urls: photo_urls || [],
        is_emergency: Boolean(is_emergency),
        sync_status: "synced",
        hse_status: "SUBMITTED",
      };

      // Only attach coordinates the device actually resolved.
      if (gps_latitude != null && gps_longitude != null) {
        payload.gps_latitude = gps_latitude;
        payload.gps_longitude = gps_longitude;
      }

      const { data, error } = await client
        .from("hazard_reports")
        .upsert(payload, { onConflict: "local_id" })
        .select("id, local_id")
        .maybeSingle();

      if (error) {
        results.push({ local_id, synced: false, error: error.message });
      } else {
        results.push({ local_id, server_id: data?.id, synced: true });
      }
    }

    const syncedCount = results.filter((r) => r.synced).length;
    return NextResponse.json({
      message: `Berhasil memproses ${results.length} laporan.`,
      synced: syncedCount,
      results,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/**
 * PATCH /api/reports
 *
 * HSE review workflow: SUBMITTED → IN_REVIEW → ACTION_REQUIRED → CLOSED.
 * RLS restricts this to supervisor / hse / management.
 */
export async function PATCH(req: NextRequest) {
  try {
    const { id, hse_status, hse_notes } = await req.json();

    if (!id) {
      return NextResponse.json({ error: "Missing report id" }, { status: 400 });
    }
    if (!hse_status || !VALID_STATUS.includes(hse_status)) {
      return NextResponse.json(
        { error: `hse_status must be one of ${VALID_STATUS.join(", ")}` },
        { status: 400 }
      );
    }

    const client = getUserClient(req);
    const profile = await resolveProfile(req);
    if (!profile) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
    if (!REVIEW_ROLES.includes(profile.role)) {
      return NextResponse.json(
        { error: "Hanya Supervisor, HSE, atau Manajemen yang dapat meninjau laporan." },
        { status: 403 }
      );
    }

    const updatePayload: Record<string, unknown> = {
      hse_status,
      updated_at: new Date().toISOString(),
    };
    if (typeof hse_notes === "string" && hse_notes.trim()) {
      updatePayload.hse_notes = hse_notes.trim();
    }

    const { data, error } = await client
      .from("hazard_reports")
      .update(updatePayload)
      .eq("id", id)
      .select("id, local_id, hse_status, hse_notes, updated_at")
      .maybeSingle();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 403 });
    }
    if (!data) {
      return NextResponse.json(
        { error: "Laporan tidak ditemukan atau akses ditolak." },
        { status: 404 }
      );
    }

    return NextResponse.json({
      message: `Status laporan diperbarui menjadi ${hse_status}.`,
      report: data,
      reviewed_by: profile.full_name,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}