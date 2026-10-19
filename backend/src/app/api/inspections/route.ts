import { NextRequest, NextResponse } from "next/server";
import { getUserClient } from "@/lib/supabase";
import { resolveProfile } from "@/lib/auth";
import { notifyRoles, notifyUser } from "@/lib/notify";

export const dynamic = "force-dynamic";

/**
 * Corrective-action stage map. A ticket may only move forward one stage at a
 * time and cannot be reopened after closure — that rule belongs on the server,
 * not only in the UI.
 */
function statusForStage(stage: number): string {
  switch (stage) {
    case 1:
      return "inspection";
    case 2:
      return "identified";
    case 3:
      return "verified";
    case 4:
      return "assigned";
    case 5:
      return "in_progress";
    default:
      return "completed";
  }
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

export async function GET(req: NextRequest) {
  try {
    const client = getUserClient(req);
    const { data: correctiveActions, error: caError } = await client
      .from("corrective_actions")
      .select("*")
      .order("created_at", { ascending: false });

    if (caError) {
      return NextResponse.json({ error: caError.message }, { status: 500 });
    }

    const { data: inspections } = await client
      .from("k3_inspections")
      .select("*")
      .order("created_at", { ascending: false });

    // Attach the originating hazard report so Management can evaluate the
    // action in context without a second round-trip per card.
    const actions = (correctiveActions ?? []) as Record<string, any>[];
    const reportIds = [
      ...new Set(actions.map((a) => a.hazard_report_id).filter(Boolean)),
    ] as string[];

    const reportsById: Record<string, Record<string, any>> = {};
    if (reportIds.length > 0) {
      const { data: reports } = await client
        .from("hazard_reports")
        .select(
          "id, reporter_id, reporter_name, zone_name, description, hse_status, hse_notes"
        )
        .in("id", reportIds);

      for (const report of reports ?? []) {
        reportsById[report.id] = report;
      }
    }

    const enriched: Record<string, any>[] = actions.map((action) => ({
      ...action,
      hazard_report: action.hazard_report_id
        ? reportsById[action.hazard_report_id] ?? null
        : null,
    }));

    const counts = {
      total: enriched.length,
      pending_approval: enriched.filter(
        (a) => String(a.management_status || "").toUpperCase() === "PENDING"
      ).length,
      approved: enriched.filter(
        (a) => String(a.management_status || "").toUpperCase() === "APPROVED"
      ).length,
      rejected: enriched.filter(
        (a) => String(a.management_status || "").toUpperCase() === "REJECTED"
      ).length,
      evaluated: enriched.filter(
        (a) => String(a.management_status || "").toUpperCase() === "EVALUATED"
      ).length,
      waiting_evaluation: enriched.filter(
        (a) =>
          Number(a.stage_number || 0) >= 6 &&
          String(a.management_status || "").toUpperCase() === "APPROVED" &&
          !a.evaluated_at
      ).length,
      overdue: enriched.filter(
        (a) =>
          a.target_due_date &&
          String(a.target_due_date) < today() &&
          Number(a.stage_number || 0) < 6
      ).length,
    };

    return NextResponse.json({
      corrective_actions: enriched,
      inspections: inspections || [],
      counts,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/**
 * POST /api/inspections — conduct and submit a new K3 inspection.
 *
 * Authored by Supervisor, HSE, or Management. If the checklist contains any
 * defects/failed items ("Temuan"), it automatically creates corresponding
 * corrective action tickets. Findings enter at stage 3 (verified) because the
 * inspector has already witnessed them; Management then approves the plan
 * before field execution begins.
 */
export async function POST(req: NextRequest) {
  try {
    const profile = await resolveProfile(req);
    if (!profile) {
      return NextResponse.json(
        { error: "Sesi tidak valid. Silakan masuk kembali." },
        { status: 401 }
      );
    }
    if (!["supervisor", "hse", "management"].includes(profile.role)) {
      return NextResponse.json(
        { error: "Pembuatan laporan inspeksi hanya untuk Supervisor, HSE, atau Manajemen." },
        { status: 403 }
      );
    }

    const body = await req.json();
    const {
      inspection_category,
      zone_name,
      title,
      notes,
      passed_items,
      failed_items,
      findings,
    } = body;

    if (!inspection_category || !zone_name) {
      return NextResponse.json(
        { error: "Kategori inspeksi dan zona kerja wajib diisi." },
        { status: 400 }
      );
    }

    const client = getUserClient(req);

    // 1. Insert inspection record
    const { data: inspection, error: inspError } = await client
      .from("k3_inspections")
      .insert({
        inspector_id: profile.id,
        inspector_name: profile.full_name,
        inspection_category,
        zone_name,
        title: title || `Inspeksi ${inspection_category} - ${zone_name}`,
        notes: notes || null,
        passed_items: Number(passed_items || 0),
        failed_items: Number(failed_items || 0),
        inspection_date: today(),
      })
      .select()
      .single();

    if (inspError) {
      return NextResponse.json({ error: inspError.message }, { status: 403 });
    }

    // 2. If there are findings, generate corrective action tickets automatically
    const createdActions: Record<string, any>[] = [];
    const createErrors: string[] = [];

    if (Array.isArray(findings) && findings.length > 0) {
      for (const finding of findings) {
        if (!finding || !finding.item) continue;

        const severity = ["low", "medium", "high", "critical"].includes(
          String(finding.severity || "").toLowerCase()
        )
          ? String(finding.severity).toLowerCase()
          : "medium";

        const { data: ca, error: caErr } = await client
          .from("corrective_actions")
          .insert({
            inspection_id: inspection.id,
            title: `Temuan: ${finding.item}`,
            description:
              finding.note || `Temuan pada inspeksi ${inspection_category} di ${zone_name}.`,
            severity,
            status: "verified",
            stage_number: 3, // Tahap 3: terverifikasi oleh inspektur
            assigned_pic_name: finding.assigned_pic_name || `Pengawas ${zone_name}`,
            target_due_date: new Date(Date.now() + 3 * 86400 * 1000)
              .toISOString()
              .slice(0, 10),
            hse_verifier_id: profile.userId,
            hse_verification_notes: `Ditemukan saat inspeksi lapangan oleh ${profile.full_name} (${profile.role}).`,
            management_status: "PENDING",
            created_by: profile.userId,
            source: "inspection",
          })
          .select()
          .maybeSingle();

        if (caErr) {
          createErrors.push(caErr.message);
        } else if (ca) {
          createdActions.push(ca);

          await notifyRoles(client, ["management"], {
            title: "Persetujuan tindakan inspeksi diperlukan",
            body: `${profile.full_name} menemukan "${finding.item}" di ${zone_name}. Tinjau rencana tindakan.`,
            category: "APPROVAL",
            related_action_id: ca.id,
          });
          await notifyRoles(client, ["supervisor"], {
            title: "Temuan inspeksi baru",
            body: `Temuan "${finding.item}" di ${zone_name} menunggu persetujuan Manajemen sebelum dikerjakan.`,
            category: "ACTION",
            related_action_id: ca.id,
          });
        }
      }
    }

    return NextResponse.json({
      message: "Laporan inspeksi K3 berhasil disimpan.",
      inspection,
      created_actions: createdActions,
      findings_count: createdActions.length,
      errors: createErrors,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/**
 * PATCH /api/inspections
 *
 * Two distinct operations:
 *
 * 1. Management decision — `management_decision` APPROVED / REJECTED /
 *    EVALUATED. Approval activates the action (stage 4) and flips the linked
 *    report to ACTION_REQUIRED. Evaluation records effectiveness and closes
 *    the linked report.
 *
 * 2. Stage advancement — HSE verifies up to stage 3; Supervisor executes
 *    stages 4–6. Neither can bypass the Management gate.
 */
export async function PATCH(req: NextRequest) {
  try {
    const body = await req.json();
    const {
      id,
      stage_number,
      hse_verification_notes,
      management_decision,
      management_notes,
      effectiveness_rating,
    } = body;

    if (!id) {
      return NextResponse.json({ error: "Missing corrective action id" }, { status: 400 });
    }

    const profile = await resolveProfile(req);
    if (!profile) {
      return NextResponse.json(
        { error: "Sesi tidak valid. Silakan masuk kembali." },
        { status: 401 }
      );
    }

    const client = getUserClient(req);
    const { data: current, error: readErr } = await client
      .from("corrective_actions")
      .select("*")
      .eq("id", id)
      .maybeSingle();

    if (readErr) {
      return NextResponse.json({ error: readErr.message }, { status: 403 });
    }
    if (!current) {
      return NextResponse.json(
        { error: "Tiket tidak ditemukan atau akses ditolak." },
        { status: 404 }
      );
    }

    const notes =
      typeof management_notes === "string"
        ? management_notes.trim()
        : typeof hse_verification_notes === "string"
          ? hse_verification_notes.trim()
          : "";

    // -----------------------------------------------------------------------
    // Management approval / evaluation path
    // -----------------------------------------------------------------------
    if (management_decision) {
      if (profile.role !== "management") {
        return NextResponse.json(
          {
            error:
              "Persetujuan dan evaluasi tindakan hanya dapat dilakukan oleh Manajemen.",
          },
          { status: 403 }
        );
      }

      const decision = String(management_decision).toUpperCase();
      if (!["APPROVED", "REJECTED", "EVALUATED"].includes(decision)) {
        return NextResponse.json(
          { error: "management_decision harus APPROVED, REJECTED, atau EVALUATED." },
          { status: 400 }
        );
      }

      if (decision === "REJECTED" && !notes) {
        return NextResponse.json(
          { error: "Alasan penolakan tindakan wajib diisi." },
          { status: 400 }
        );
      }
      if (decision === "EVALUATED" && !notes) {
        return NextResponse.json(
          { error: "Catatan evaluasi hasil tindakan wajib diisi." },
          { status: 400 }
        );
      }

      const rating = Number(effectiveness_rating);
      if (
        decision === "EVALUATED" &&
        (!Number.isInteger(rating) || rating < 1 || rating > 5)
      ) {
        return NextResponse.json(
          { error: "Efektivitas tindakan wajib dinilai 1–5." },
          { status: 400 }
        );
      }

      if (decision === "APPROVED" && Number(current.stage_number || 0) < 3) {
        return NextResponse.json(
          { error: "HSE harus memverifikasi temuan hingga tahap 3 sebelum persetujuan." },
          { status: 409 }
        );
      }
      if (decision === "EVALUATED" && Number(current.stage_number || 0) < 6) {
        return NextResponse.json(
          { error: "Tindakan belum selesai. Evaluasi hanya dapat dilakukan setelah tahap 6." },
          { status: 409 }
        );
      }
      if (String(current.management_status || "").toUpperCase() === "EVALUATED") {
        return NextResponse.json(
          { error: "Tindakan ini sudah dievaluasi." },
          { status: 409 }
        );
      }

      const now = new Date().toISOString();
      const updatePayload: Record<string, unknown> = {
        management_status: decision,
        management_notes: notes,
        management_reviewed_by: profile.userId,
        management_reviewed_at: now,
        updated_at: now,
      };

      if (decision === "APPROVED") {
        const nextStage = Math.max(Number(current.stage_number || 3), 4);
        updatePayload.stage_number = nextStage;
        updatePayload.status = statusForStage(nextStage);
      }
      if (decision === "EVALUATED") {
        updatePayload.effectiveness_rating = rating;
        updatePayload.evaluated_at = now;
        if (!current.completion_date) updatePayload.completion_date = today();
      }

      const { data: updated, error } = await client
        .from("corrective_actions")
        .update(updatePayload)
        .eq("id", id)
        .select("*")
        .maybeSingle();

      if (error) {
        return NextResponse.json({ error: error.message }, { status: 403 });
      }
      if (!updated) {
        return NextResponse.json(
          { error: "Pembaruan ditolak oleh kebijakan akses." },
          { status: 403 }
        );
      }

      const reportId = updated.hazard_report_id as string | null;
      let updatedReport: Record<string, any> | null = null;

      if (reportId) {
        const reportStatus =
          decision === "APPROVED"
            ? "ACTION_REQUIRED"
            : decision === "REJECTED"
              ? "IN_REVIEW"
              : "CLOSED";

        const reportUpdate: Record<string, unknown> = {
          hse_status: reportStatus,
          updated_at: now,
        };
        if (decision === "REJECTED") {
          reportUpdate.hse_notes = `Ditolak Manajemen: ${notes}`;
        }
        if (decision === "EVALUATED") {
          reportUpdate.hse_notes = `Evaluasi Manajemen: ${notes}`;
        }

        const { data: report } = await client
          .from("hazard_reports")
          .update(reportUpdate)
          .eq("id", reportId)
          .select("id, reporter_id, reporter_name, zone_name, hse_status, hse_notes")
          .maybeSingle();
        updatedReport = report ?? null;

        if (report?.reporter_id) {
          const title =
            decision === "APPROVED"
              ? "Tindakan korektif disetujui"
              : decision === "REJECTED"
                ? "Tindakan korektif dikembalikan ke HSE"
                : "Tindakan selesai dievaluasi";
          const bodyText =
            decision === "APPROVED"
              ? `Manajemen menyetujui tindakan "${updated.title}". Tindakan sekarang masuk ke akun pekerja dan supervisor untuk dilaksanakan.`
              : decision === "REJECTED"
                ? `Manajemen menolak rencana tindakan "${updated.title}". Catatan: ${notes}`
                : `Manajemen mengevaluasi tindakan "${updated.title}" dengan efektivitas ${rating}/5. Laporan ditutup.`;

          await notifyUser(client, report.reporter_id, {
            title,
            body: bodyText,
            category: decision === "EVALUATED" ? "EVALUATION" : "APPROVAL",
            related_report_id: reportId,
            related_action_id: updated.id,
          });
        }
      }

      if (decision === "APPROVED") {
        await notifyRoles(client, ["hse"], {
          title: "Tindakan disetujui Manajemen",
          body: `Tindakan "${updated.title}" disetujui. Supervisor dapat memulai pelaksanaan.`,
          category: "APPROVAL",
          related_report_id: reportId,
          related_action_id: updated.id,
        });
        await notifyRoles(client, ["supervisor"], {
          title: "Tindakan siap dilaksanakan",
          body: `Manajemen menyetujui tindakan "${updated.title}". Silakan mulai perbaikan dan selesaikan sebelum tenggat.`,
          category: "ACTION",
          related_report_id: reportId,
          related_action_id: updated.id,
        });
      }

      if (decision === "REJECTED") {
        await notifyRoles(client, ["hse"], {
          title: "Rencana tindakan dikembalikan",
          body: `Manajemen menolak rencana "${updated.title}". Catatan: ${notes}`,
          category: "APPROVAL",
          related_report_id: reportId,
          related_action_id: updated.id,
        });
      }

      if (decision === "EVALUATED") {
        await notifyRoles(client, ["hse", "supervisor"], {
          title: "Evaluasi Manajemen selesai",
          body: `Tindakan "${updated.title}" dievaluasi dengan efektivitas ${rating}/5. Laporan ditutup.`,
          category: "EVALUATION",
          related_report_id: reportId,
          related_action_id: updated.id,
        });
      }

      return NextResponse.json({
        message:
          decision === "APPROVED"
            ? "Tindakan disetujui. Pekerja dan Supervisor telah menerima notifikasi."
            : decision === "REJECTED"
              ? "Tindakan dikembalikan ke HSE."
              : "Evaluasi tersimpan dan laporan ditutup.",
        action: updated,
        report: updatedReport,
        reviewed_by: profile.full_name,
      });
    }

    // -----------------------------------------------------------------------
    // Stage advancement path
    // -----------------------------------------------------------------------
    if (!["supervisor", "hse"].includes(profile.role)) {
      return NextResponse.json(
        {
          error:
            "Tahap tindakan dijalankan oleh HSE (verifikasi) dan Supervisor (pelaksanaan). Manajemen menggunakan keputusan persetujuan/evaluasi.",
        },
        { status: 403 }
      );
    }

    const managementStatus = String(current.management_status || "APPROVED").toUpperCase();
    if (managementStatus === "REJECTED") {
      return NextResponse.json(
        { error: "Tindakan ditolak Manajemen. HSE harus merevisi rencana terlebih dahulu." },
        { status: 409 }
      );
    }
    if (managementStatus === "EVALUATED") {
      return NextResponse.json(
        { error: "Tindakan sudah dievaluasi dan tidak dapat diubah." },
        { status: 409 }
      );
    }
    if (managementStatus === "PENDING" && profile.role === "supervisor") {
      return NextResponse.json(
        {
          error:
            "Tindakan masih menunggu persetujuan Manajemen. Supervisor belum dapat memulai pelaksanaan.",
        },
        { status: 409 }
      );
    }

    const currentStage = Number(current.stage_number || 1);
    if (currentStage >= 6) {
      return NextResponse.json(
        { error: "Tindakan sudah selesai. Menunggu evaluasi Manajemen." },
        { status: 409 }
      );
    }

    const requested = Number(stage_number);
    let nextStage = Number.isFinite(requested)
      ? Math.min(Math.max(requested, currentStage), 6)
      : currentStage + 1;
    nextStage = Math.min(nextStage, currentStage + 1);

    if (nextStage <= currentStage) {
      return NextResponse.json(
        { error: "Tiket sudah berada pada tahap tersebut." },
        { status: 409 }
      );
    }

    if (profile.role === "hse" && nextStage > 3) {
      return NextResponse.json(
        {
          error:
            "HSE hanya memverifikasi sampai tahap 3. Pelaksanaan tahap 4–6 dilakukan Supervisor setelah persetujuan Manajemen.",
        },
        { status: 403 }
      );
    }
    if (profile.role === "supervisor") {
      if (managementStatus === "PENDING") {
        return NextResponse.json(
          { error: "Menunggu persetujuan Manajemen sebelum pelaksanaan." },
          { status: 409 }
        );
      }
      if (nextStage < 4) {
        return NextResponse.json(
          {
            error:
              "Supervisor menjalankan tahap 4–6. Temuan pada tahap 2–3 masih diverifikasi HSE.",
          },
          { status: 403 }
        );
      }
    }

    const updatePayload: Record<string, unknown> = {
      stage_number: nextStage,
      status: statusForStage(nextStage),
      updated_at: new Date().toISOString(),
    };
    if (notes) updatePayload.hse_verification_notes = notes;
    if (nextStage >= 6) {
      updatePayload.completion_date = today();
    }

    const { data, error } = await client
      .from("corrective_actions")
      .update(updatePayload)
      .eq("id", id)
      .select("*")
      .maybeSingle();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 403 });
    }
    if (!data) {
      return NextResponse.json(
        { error: "Pembaruan ditolak oleh kebijakan akses." },
        { status: 403 }
      );
    }

    if (nextStage === 5) {
      await notifyRoles(client, ["supervisor", "hse"], {
        title: "Perbaikan dimulai",
        body: `Tindakan "${data.title}" mulai dikerjakan di lapangan.`,
        category: "ACTION",
        related_action_id: data.id,
      });
    }

    if (nextStage >= 6) {
      await notifyRoles(client, ["management"], {
        title: "Tindakan selesai — menunggu evaluasi",
        body: `Tindakan "${data.title}" telah diselesaikan Supervisor. Silakan evaluasi efektivitas dan tutup laporan.`,
        category: "EVALUATION",
        related_report_id: data.hazard_report_id,
        related_action_id: data.id,
      });
      if (data.hazard_report_id) {
        const { data: report } = await client
          .from("hazard_reports")
          .select("reporter_id, zone_name")
          .eq("id", data.hazard_report_id)
          .maybeSingle();
        if (report?.reporter_id) {
          await notifyUser(client, report.reporter_id, {
            title: "Tindakan untuk laporan Anda telah selesai",
            body: `Perbaikan di ${report.zone_name} sudah diselesaikan. Menunggu evaluasi akhir Manajemen.`,
            category: "ACTION",
            related_report_id: data.hazard_report_id,
            related_action_id: data.id,
          });
        }
      }
    }

    return NextResponse.json({
      message:
        nextStage >= 6
          ? "Tindakan selesai. Menunggu evaluasi Manajemen."
          : "Tindakan korektif berhasil dimajukan.",
      action: data,
      verified_by: profile.full_name,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
