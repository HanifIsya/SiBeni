import { NextRequest, NextResponse } from "next/server";
import { getUserClient } from "@/lib/supabase";
import { resolveProfile } from "@/lib/auth";
import { notifyRoles, notifyUser } from "@/lib/notify";

export const dynamic = "force-dynamic";

const REVIEW_ROLES = ["hse", "management"];

const VALID_STATUS = [
  "SUBMITTED",
  "IN_REVIEW",
  "PENDING_APPROVAL",
  "ACTION_REQUIRED",
  "CLOSED",
  "REJECTED",
];

const VALID_SEVERITY = ["low", "medium", "high", "critical"];

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
        "id, local_id, reporter_id, reporter_name, report_type, zone_name, category, " +
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

    // Attach the latest corrective action so Management sees the actual next
    // decision (approve/evaluate) instead of guessing from the report status.
    const reportIds = reports.map((r) => r.id).filter(Boolean);
    const latestActionByReport: Record<string, Record<string, any>> = {};
    if (reportIds.length > 0) {
      const { data: actions } = await client
        .from("corrective_actions")
        .select(
          "id, hazard_report_id, title, management_status, stage_number, effectiveness_rating, management_notes, evaluated_at, target_due_date"
        )
        .in("hazard_report_id", reportIds)
        .order("created_at", { ascending: false });

      for (const action of actions ?? []) {
        if (action.hazard_report_id && !latestActionByReport[action.hazard_report_id]) {
          latestActionByReport[action.hazard_report_id] = action;
        }
      }
    }

    const enrichedReports: Record<string, any>[] = reports.map((report) => ({
      ...report,
      latest_action: latestActionByReport[report.id] ?? null,
    }));

    const count = (value: string) =>
      enrichedReports.filter(
        (r) => String(r.hse_status || "").toUpperCase() === value
      ).length;

    const counts = {
      total: reports.length,
      submitted: count("SUBMITTED"),
      in_review: count("IN_REVIEW"),
      pending_approval: count("PENDING_APPROVAL"),
      action_required: count("ACTION_REQUIRED"),
      closed: count("CLOSED"),
      rejected: count("REJECTED"),
      emergency: enrichedReports.filter((r) => Boolean(r.is_emergency)).length,
    };

    return NextResponse.json({
      reports: enrichedReports,
      counts,
      viewer_role: profile.role,
    });
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

      const resolvedLocalId =
        local_id ?? `srv-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

      // Detect a replay before upserting. This keeps the HSE inbox free of
      // duplicate "laporan baru" notifications when a device retries its
      // offline outbox.
      const { data: existing } = await client
        .from("hazard_reports")
        .select("id")
        .eq("local_id", resolvedLocalId)
        .maybeSingle();

      const payload: Record<string, unknown> = {
        local_id: resolvedLocalId,
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
        results.push({ local_id: resolvedLocalId, synced: false, error: error.message });
      } else {
        results.push({ local_id: resolvedLocalId, server_id: data?.id, synced: true });

        if (!existing && data?.id) {
          await notifyRoles(client, ["hse"], {
            title: report_type === "near_miss" ? "Near-miss baru" : "Laporan bahaya baru",
            body: `${resolvedName} melaporkan ${payload.category} di ${payload.zone_name}. Menunggu verifikasi HSE.`,
            category: "REPORT",
            related_report_id: data.id,
          });
        }
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
 * HSE review and Management decision workflow:
 *
 *   SUBMITTED ──HSE verify──► IN_REVIEW
 *   IN_REVIEW ──HSE action──► PENDING_APPROVAL
 *   PENDING_APPROVAL ──Management approve (via /api/inspections)──► ACTION_REQUIRED
 *   ACTION_REQUIRED ──Management evaluate (via /api/inspections)──► CLOSED
 *   SUBMITTED/IN_REVIEW ──HSE reject──► REJECTED
 *
 * A corrective action can only be sent with a written action description, PIC,
 * severity and due date. This is the server-side guard against the old bug
 * where tapping "Tindakan" closed the report before any action was typed.
 */
export async function PATCH(req: NextRequest) {
  try {
    const body = await req.json();
    const { id, hse_status, hse_notes, action } = body;

    if (!id) {
      return NextResponse.json({ error: "Missing report id" }, { status: 400 });
    }
    if (!hse_status || !VALID_STATUS.includes(String(hse_status).toUpperCase())) {
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
        {
          error:
            "Hanya HSE dan Manajemen yang dapat meninjau laporan. Supervisor berfokus pada inspeksi dan koordinasi.",
        },
        { status: 403 }
      );
    }

    const nextStatus = String(hse_status).toUpperCase();

    // HSE cannot close a report: closure is a Management evaluation decision.
    if (nextStatus === "CLOSED" && profile.role !== "management") {
      return NextResponse.json(
        { error: "Penutupan/evaluasi laporan dilakukan oleh Manajemen." },
        { status: 403 }
      );
    }
    // Only HSE issues corrective actions. Management approves them through the
    // action endpoint, not by writing an action into the report directly.
    if (nextStatus === "PENDING_APPROVAL" && profile.role !== "hse") {
      return NextResponse.json(
        { error: "Tindakan korektif disusun oleh HSE, lalu disetujui Manajemen." },
        { status: 403 }
      );
    }
    if (nextStatus === "ACTION_REQUIRED") {
      return NextResponse.json(
        {
          error:
            "Status ACTION_REQUIRED ditetapkan otomatis setelah Manajemen menyetujui tindakan.",
        },
        { status: 400 }
      );
    }

    const notes = typeof hse_notes === "string" ? hse_notes.trim() : "";

    if (nextStatus === "PENDING_APPROVAL") {
      if (!notes) {
        return NextResponse.json(
          { error: "Catatan verifikasi HSE wajib diisi sebelum mengirim tindakan." },
          { status: 400 }
        );
      }
      if (!action || typeof action !== "object") {
        return NextResponse.json(
          { error: "Rincian tindakan korektif wajib diisi." },
          { status: 400 }
        );
      }
      const description = String(action.description || "").trim();
      const pic = String(action.assigned_pic_name || "").trim();
      const dueDate = String(action.target_due_date || "").trim();
      const severity = String(action.severity || "high").toLowerCase();

      if (!description) {
        return NextResponse.json(
          { error: "Uraian tindakan korektif wajib diketik sebelum dikirim." },
          { status: 400 }
        );
      }
      if (!pic) {
        return NextResponse.json(
          { error: "Nama penanggung jawab (PIC) tindakan wajib diisi." },
          { status: 400 }
        );
      }
      if (!/^\d{4}-\d{2}-\d{2}$/.test(dueDate)) {
        return NextResponse.json(
          { error: "Tenggat tindakan wajib diisi (format YYYY-MM-DD)." },
          { status: 400 }
        );
      }
      if (!VALID_SEVERITY.includes(severity)) {
        return NextResponse.json(
          { error: `Severity must be one of ${VALID_SEVERITY.join(", ")}` },
          { status: 400 }
        );
      }

      const { data: report, error: reportError } = await client
        .from("hazard_reports")
        .select(
          "id, reporter_id, reporter_name, report_type, zone_name, description, hse_status"
        )
        .eq("id", id)
        .maybeSingle();

      if (reportError) {
        return NextResponse.json({ error: reportError.message }, { status: 403 });
      }
      if (!report) {
        return NextResponse.json(
          { error: "Laporan tidak ditemukan atau akses ditolak." },
          { status: 404 }
        );
      }
      if (["CLOSED", "REJECTED"].includes(String(report.hse_status).toUpperCase())) {
        return NextResponse.json(
          { error: "Laporan yang sudah ditutup/ditolak tidak dapat diberi tindakan baru." },
          { status: 409 }
        );
      }

      const { data: existingAction } = await client
        .from("corrective_actions")
        .select("id, management_status")
        .eq("hazard_report_id", id)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (
        existingAction &&
        ["PENDING", "APPROVED"].includes(String(existingAction.management_status).toUpperCase())
      ) {
        return NextResponse.json(
          {
            error:
              "Laporan ini sudah memiliki tindakan yang sedang berjalan. Selesaikan atau evaluasi tindakan tersebut terlebih dahulu.",
          },
          { status: 409 }
        );
      }

      const title =
        String(action.title || "").trim() ||
        `Tindakan: ${String(report.description || "Temuan lapangan").slice(0, 64)}`;

      const { data: createdAction, error: actionError } = await client
        .from("corrective_actions")
        .insert({
          hazard_report_id: id,
          title,
          description,
          severity,
          status: "verified",
          stage_number: 3,
          assigned_pic_name: pic,
          assigned_pic_id: action.assigned_pic_id || null,
          target_due_date: dueDate,
          hse_verifier_id: profile.userId,
          hse_verification_notes: notes,
          assigned_worker_id: report.reporter_id || null,
          created_by: profile.userId,
          management_status: "PENDING",
          source: "hazard_report",
        })
        .select("*")
        .maybeSingle();

      if (actionError) {
        return NextResponse.json({ error: actionError.message }, { status: 403 });
      }

      const { data: updatedReport, error: updateError } = await client
        .from("hazard_reports")
        .update({
          hse_status: "PENDING_APPROVAL",
          hse_notes: notes,
          updated_at: new Date().toISOString(),
        })
        .eq("id", id)
        .select("id, local_id, hse_status, hse_notes, updated_at")
        .maybeSingle();

      if (updateError) {
        // Roll the action back so the report does not point at a half-created
        // workflow if the status update is rejected by RLS.
        if (createdAction?.id) {
          await client.from("corrective_actions").delete().eq("id", createdAction.id);
        }
        return NextResponse.json({ error: updateError.message }, { status: 403 });
      }

      await notifyUser(client, report.reporter_id, {
        title: "Tindakan korektif untuk laporan Anda",
        body: `HSE menyusun tindakan "${title}" untuk laporan di ${report.zone_name}. Menunggu persetujuan Manajemen sebelum dilaksanakan.`,
        category: "ACTION",
        related_report_id: id,
        related_action_id: createdAction?.id ?? null,
      });
      await notifyRoles(client, ["supervisor"], {
        title: "Tindakan korektif baru menunggu persetujuan",
        body: `HSE menyusun tindakan "${title}" di ${report.zone_name}. Siapkan pelaksanaan setelah Manajemen menyetujui.`,
        category: "ACTION",
        related_report_id: id,
        related_action_id: createdAction?.id ?? null,
      });
      await notifyRoles(client, ["management"], {
        title: "Persetujuan tindakan diperlukan",
        body: `HSE mengirim tindakan "${title}" untuk laporan ${report.reporter_name} di ${report.zone_name}. Tinjau dan setujui/tolak.`,
        category: "APPROVAL",
        related_report_id: id,
        related_action_id: createdAction?.id ?? null,
      });

      return NextResponse.json({
        message:
          "Tindakan korektif tersimpan dan dikirim ke Manajemen untuk persetujuan. Pekerja dan Supervisor otomatis menerima notifikasi.",
        report: updatedReport,
        action: createdAction,
        reviewed_by: profile.full_name,
      });
    }

    if (nextStatus === "REJECTED" && !notes) {
      return NextResponse.json(
        { error: "Alasan penolakan laporan wajib diisi." },
        { status: 400 }
      );
    }
    if (nextStatus === "CLOSED" && !notes) {
      return NextResponse.json(
        { error: "Catatan evaluasi/penutupan laporan wajib diisi." },
        { status: 400 }
      );
    }

    const updatePayload: Record<string, unknown> = {
      hse_status: nextStatus,
      updated_at: new Date().toISOString(),
    };
    if (notes) updatePayload.hse_notes = notes;

    const { data, error } = await client
      .from("hazard_reports")
      .update(updatePayload)
      .eq("id", id)
      .select(
        "id, local_id, reporter_id, reporter_name, zone_name, hse_status, hse_notes, updated_at"
      )
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

    if (nextStatus === "IN_REVIEW") {
      await notifyUser(client, data.reporter_id, {
        title: "Laporan Anda sedang diverifikasi HSE",
        body: `Laporan di ${data.zone_name} sudah diterima dan sedang ditinjau HSE.`,
        category: "REPORT",
        related_report_id: id,
      });
    }

    if (nextStatus === "REJECTED") {
      await notifyUser(client, data.reporter_id, {
        title: "Laporan ditolak",
        body: `Laporan di ${data.zone_name} ditolak HSE. Catatan: ${notes}`,
        category: "REPORT",
        related_report_id: id,
      });
    }

    if (nextStatus === "CLOSED") {
      await notifyRoles(client, ["hse", "supervisor"], {
        title: "Laporan ditutup Manajemen",
        body: `Laporan di ${data.zone_name} telah dievaluasi dan ditutup. Catatan: ${notes}`,
        category: "EVALUATION",
        related_report_id: id,
      });
      await notifyUser(client, data.reporter_id, {
        title: "Laporan Anda selesai dievaluasi",
        body: `Laporan di ${data.zone_name} telah ditutup Manajemen. Terima kasih atas laporannya.`,
        category: "EVALUATION",
        related_report_id: id,
      });
    }

    return NextResponse.json({
      message: `Status laporan diperbarui menjadi ${nextStatus}.`,
      report: data,
      reviewed_by: profile.full_name,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
