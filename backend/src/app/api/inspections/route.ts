import { NextRequest, NextResponse } from "next/server";
import { getUserClient } from "@/lib/supabase";
import { resolveProfile } from "@/lib/auth";

export const dynamic = "force-dynamic";

const VERIFY_ROLES = ["supervisor", "hse"];

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

    return NextResponse.json({
      corrective_actions: correctiveActions || [],
      inspections: inspections || [],
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/**
 * PATCH /api/inspections — advance a corrective action one stage.
 *
 * The previous implementation used `.select().single()` against an anonymous
 * client. RLS therefore evaluated `auth.uid()` as null, the UPDATE matched zero
 * rows, `.single()` threw, and the endpoint answered 500 — so tapping
 * "Verifikasi" in the app silently did nothing. This handler runs as the real
 * user and returns a precise error instead of failing opaquely.
 */
export async function PATCH(req: NextRequest) {
  try {
    const body = await req.json();
    const { id, stage_number, hse_verification_notes } = body;

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
    if (!VERIFY_ROLES.includes(profile.role)) {
      return NextResponse.json(
        { error: "Verifikasi tindakan korektif hanya untuk Supervisor atau HSE." },
        { status: 403 }
      );
    }

    const client = getUserClient(req);

    const { data: current, error: readErr } = await client
      .from("corrective_actions")
      .select("id, stage_number, status")
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

    const currentStage = Number(current.stage_number || 1);
    const requested = Number(stage_number);
    const nextStage = Number.isFinite(requested)
      ? Math.min(Math.max(requested, currentStage), 6)
      : currentStage + 1;

    if (nextStage <= currentStage) {
      return NextResponse.json(
        { error: "Tiket sudah berada pada tahap tersebut." },
        { status: 409 }
      );
    }

    const updatePayload: Record<string, unknown> = {
      stage_number: nextStage,
      status: statusForStage(nextStage),
      updated_at: new Date().toISOString(),
    };
    if (typeof hse_verification_notes === "string" && hse_verification_notes.trim()) {
      updatePayload.hse_verification_notes = hse_verification_notes.trim();
    }
    if (nextStage >= 6) {
      updatePayload.completion_date = new Date().toISOString().slice(0, 10);
    }

    const { data, error } = await client
      .from("corrective_actions")
      .update(updatePayload)
      .eq("id", id)
      .select("id, title, stage_number, status, hse_verification_notes, updated_at")
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

    return NextResponse.json({
      message: "Tindakan korektif berhasil dimajukan.",
      action: data,
      verified_by: profile.full_name,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
