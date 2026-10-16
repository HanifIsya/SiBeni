import { NextRequest, NextResponse } from "next/server";
import { getUserClient } from "@/lib/supabase";
import { resolveProfile } from "@/lib/auth";

export const dynamic = "force-dynamic";

const VALID_TYPES = ["fire", "injury", "chemical_leak", "landslide_flood", "security"];

/**
 * POST /api/emergency — broadcast an SOS.
 *
 * `worker_id` is a UUID foreign key. The old handler wrote whatever string the
 * client sent and, on failure, returned a fabricated `BROADCASTED_SIMULATED`
 * success with invented evacuation distances. Telling a worker in an emergency
 * that the alarm was sent when it was not is the worst possible failure mode,
 * so this handler resolves the real identity and reports the truth.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { worker_name, zone_name, gps_latitude, gps_longitude, emergency_type } = body;

    if (!emergency_type || !zone_name) {
      return NextResponse.json(
        { error: "Missing emergency_type or zone_name" },
        { status: 400 }
      );
    }
    if (!VALID_TYPES.includes(emergency_type)) {
      return NextResponse.json(
        { error: `emergency_type must be one of ${VALID_TYPES.join(", ")}` },
        { status: 400 }
      );
    }

    const client = getUserClient(req);
    const profile = await resolveProfile(req);

    const payload: Record<string, unknown> = {
      worker_id: profile?.id ?? null,
      worker_name: worker_name || profile?.full_name || "Pekerja Tambang",
      zone_name,
      emergency_type,
      status: "ACTIVE",
    };
    if (gps_latitude != null && gps_longitude != null) {
      payload.gps_latitude = gps_latitude;
      payload.gps_longitude = gps_longitude;
    }

    const { data, error } = await client
      .from("emergency_sos_logs")
      .insert(payload)
      .select("id, worker_name, zone_name, emergency_type, status, created_at")
      .single();

    if (error) {
      // Honest failure: the device will queue the alert and show "tersimpan".
      return NextResponse.json(
        { error: error.message, delivered: false },
        { status: 503 }
      );
    }

    return NextResponse.json({
      status: "BROADCASTED",
      delivered: true,
      event: data,
      message: "Sinyal SOS diterima oleh pusat kendali HSE.",
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message, delivered: false }, { status: 500 });
  }
}

/** GET /api/emergency — active SOS feed for the control centre. */
export async function GET(req: NextRequest) {
  try {
    const client = getUserClient(req);
    const status = new URL(req.url).searchParams.get("status");

    let query = client
      .from("emergency_sos_logs")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(50);

    if (status) query = query.eq("status", status.toUpperCase());

    const { data, error } = await query;
    if (error) throw error;

    return NextResponse.json({ events: data ?? [] });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/** PATCH /api/emergency — acknowledge or resolve an SOS. */
export async function PATCH(req: NextRequest) {
  try {
    const { id, status, resolution_notes } = await req.json();
    if (!id) return NextResponse.json({ error: "Missing event id" }, { status: 400 });

    const allowed = ["ACTIVE", "RESPONDED", "RESOLVED"];
    if (!allowed.includes(status)) {
      return NextResponse.json(
        { error: `status must be one of ${allowed.join(", ")}` },
        { status: 400 }
      );
    }

    const client = getUserClient(req);
    const profile = await resolveProfile(req);
    if (!profile) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const updatePayload: Record<string, unknown> = { status };
    if (typeof resolution_notes === "string" && resolution_notes.trim()) {
      updatePayload.resolution_notes = resolution_notes.trim();
    }
    if (status === "RESPONDED") updatePayload.responded_at = new Date().toISOString();
    if (profile.role !== "management" && profile.role !== "hse" && profile.role !== "supervisor") {
      return NextResponse.json({ error: "Akses ditolak" }, { status: 403 });
    }
    if (status === "RESPONDED") updatePayload.responded_by = profile.id;

    const { data, error } = await client
      .from("emergency_sos_logs")
      .update(updatePayload)
      .eq("id", id)
      .select()
      .maybeSingle();

    if (error) return NextResponse.json({ error: error.message }, { status: 403 });
    if (!data) {
      return NextResponse.json({ error: "Peristiwa tidak ditemukan" }, { status: 404 });
    }

    return NextResponse.json({ message: "Status darurat diperbarui.", event: data });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}