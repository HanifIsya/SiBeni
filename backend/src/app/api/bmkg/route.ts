import { NextRequest, NextResponse } from "next/server";
import { getUserClient } from "@/lib/supabase";
import { resolveProfile } from "@/lib/auth";

export const dynamic = "force-dynamic";

const EDIT_ROLES = ["hse", "management"];
const SEVERITIES = ["low", "medium", "high", "critical"];

function asStringArray(value: unknown): string[] {
  if (Array.isArray(value)) return value.map((v) => String(v)).filter(Boolean);
  if (typeof value === "string" && value.trim()) {
    return value.split(",").map((v) => v.trim()).filter(Boolean);
  }
  return [];
}

/**
 * GET /api/bmkg
 *
 * Active early warnings. This is the app's only warning source — nothing is
 * hardcoded in the client, so everything here is operator-maintained data.
 */
export async function GET(req: NextRequest) {
  try {
    const client = getUserClient(req);
    const url = new URL(req.url);
    const includeInactive = url.searchParams.get("all") === "1";

    let query = client
      .from("early_warnings")
      .select("*")
      .order("valid_from", { ascending: false })
      .limit(100);

    if (!includeInactive) {
      query = query.eq("is_active", true);
    }

    const { data, error } = await query;
    if (error) throw error;

    return NextResponse.json({ warnings: data ?? [] });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/** POST /api/bmkg — publish a new warning. RLS limits this to HSE / management. */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const profile = await resolveProfile(req);
    if (!profile) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const severity = SEVERITIES.includes(body.severity) ? body.severity : "medium";
    const now = new Date();
    const validFrom = body.valid_from || now.toISOString();
    const validUntil =
      body.valid_until || new Date(now.getTime() + 24 * 3600 * 1000).toISOString();

    const payload = {
      source: (body.source || profile.role.toUpperCase()).slice(0, 50),
      title: (body.title || "").trim(),
      description: (body.description || "").trim(),
      severity,
      affected_zones: asStringArray(body.affected_zones),
      hazard_tags: asStringArray(body.hazard_tags),
      valid_from: validFrom,
      valid_until: validUntil,
      safety_instructions: (body.safety_instructions || "").trim() || null,
      is_active: body.is_active !== false,
    };

    if (!payload.title) {
      return NextResponse.json({ error: "Judul peringatan wajib diisi" }, { status: 400 });
    }
    if (!payload.description) {
      return NextResponse.json(
        { error: "Deskripsi peringatan wajib diisi" },
        { status: 400 }
      );
    }

    const client = getUserClient(req);
    const { data, error } = await client
      .from("early_warnings")
      .insert(payload)
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 403 });
    }

    return NextResponse.json({ message: "Peringatan diterbitkan.", warning: data }, { status: 201 });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/** PATCH /api/bmkg — amend or stand down an existing warning. */
export async function PATCH(req: NextRequest) {
  try {
    const { id, ...changes } = await req.json();
    if (!id) return NextResponse.json({ error: "Missing warning id" }, { status: 400 });

    const client = getUserClient(req);
    const profile = await resolveProfile(req);
    if (!profile) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const updatePayload: Record<string, unknown> = { updated_at: new Date().toISOString() };
    if (typeof changes.title === "string") updatePayload.title = changes.title.trim();
    if (typeof changes.description === "string") {
      updatePayload.description = changes.description.trim();
    }
    if (changes.severity && SEVERITIES.includes(changes.severity)) {
      updatePayload.severity = changes.severity;
    }
    if (changes.affected_zones !== undefined) {
      updatePayload.affected_zones = asStringArray(changes.affected_zones);
    }
    if (changes.hazard_tags !== undefined) {
      updatePayload.hazard_tags = asStringArray(changes.hazard_tags);
    }
    if (typeof changes.safety_instructions === "string") {
      updatePayload.safety_instructions = changes.safety_instructions.trim() || null;
    }
    if (typeof changes.is_active === "boolean") updatePayload.is_active = changes.is_active;
    if (typeof changes.valid_until === "string") {
      updatePayload.valid_until = changes.valid_until;
    }

    const { data, error } = await client
      .from("early_warnings")
      .update(updatePayload)
      .eq("id", id)
      .select()
      .maybeSingle();

    if (error) return NextResponse.json({ error: error.message }, { status: 403 });
    if (!data) {
      return NextResponse.json(
        { error: "Peringatan tidak ditemukan atau akses ditolak." },
        { status: 404 }
      );
    }

    return NextResponse.json({ message: "Peringatan diperbarui.", warning: data });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/** DELETE /api/bmkg — stand a warning down (soft delete keeps the audit trail). */
export async function DELETE(req: NextRequest) {
  try {
    const id = new URL(req.url).searchParams.get("id");
    if (!id) return NextResponse.json({ error: "Missing warning id" }, { status: 400 });

    const client = getUserClient(req);
    const profile = await resolveProfile(req);
    if (!profile) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const { data, error } = await client
      .from("early_warnings")
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq("id", id)
      .select("id, title, is_active")
      .maybeSingle();

    if (error) return NextResponse.json({ error: error.message }, { status: 403 });
    if (!data) {
      return NextResponse.json(
        { error: "Peringatan tidak ditemukan atau akses ditolak." },
        { status: 404 }
      );
    }

    return NextResponse.json({ message: "Peringatan dinonaktifkan.", warning: data });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}