import { NextRequest, NextResponse } from "next/server";
import { getUserClient } from "@/lib/supabase";
import { resolveProfile } from "@/lib/auth";
import { notifyRoles, notifyUser } from "@/lib/notify";

export const dynamic = "force-dynamic";

const OPERATIONAL_ROLES = ["supervisor", "hse", "management"];
const TARGET_ROLES = ["supervisor", "hse", "management"];

/**
 * GET /api/coordination
 *
 * Supervisor ↔ HSE ↔ Management coordination channel. RLS shows a row to its
 * sender, everyone in the recipient role, and Management for oversight.
 */
export async function GET(req: NextRequest) {
  try {
    const client = getUserClient(req);
    const profile = await resolveProfile(req);
    if (!profile) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const url = new URL(req.url);
    const limit = Math.min(Number(url.searchParams.get("limit") || 80), 100);
    const status = url.searchParams.get("status");

    let query = client
      .from("coordination_requests")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(limit);

    if (status && ["OPEN", "ACKNOWLEDGED", "RESOLVED"].includes(status.toUpperCase())) {
      query = query.eq("status", status.toUpperCase());
    }

    const { data, error } = await query;
    if (error) throw error;

    const rows = (data ?? []) as Record<string, any>[];
    const counts = {
      total: rows.length,
      open: rows.filter((r) => String(r.status).toUpperCase() === "OPEN").length,
      urgent: rows.filter(
        (r) =>
          String(r.priority).toUpperCase() === "URGENT" &&
          String(r.status).toUpperCase() !== "RESOLVED"
      ).length,
      needs_my_response: rows.filter(
        (r) =>
          String(r.to_role) === profile.role &&
          ["OPEN", "ACKNOWLEDGED"].includes(String(r.status).toUpperCase())
      ).length,
      sent_by_me: rows.filter((r) => r.from_id === profile.userId).length,
    };

    return NextResponse.json({
      requests: rows,
      counts,
      viewer_role: profile.role,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/**
 * POST /api/coordination
 *
 * Send a coordination note. The recipient role receives one notification per
 * account; urgent notes also ping Management for oversight.
 */
export async function POST(req: NextRequest) {
  try {
    const client = getUserClient(req);
    const profile = await resolveProfile(req);
    if (!profile) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
    if (!OPERATIONAL_ROLES.includes(profile.role)) {
      return NextResponse.json(
        { error: "Koordinasi hanya tersedia untuk Supervisor, HSE, dan Manajemen." },
        { status: 403 }
      );
    }

    const body = await req.json();
    const {
      to_role,
      subject,
      message,
      priority,
      zone_name,
      related_action_id,
    } = body;

    const target = String(to_role || "").toLowerCase();
    if (!TARGET_ROLES.includes(target)) {
      return NextResponse.json(
        { error: "Tujuan koordinasi harus supervisor, hse, atau management." },
        { status: 400 }
      );
    }

    const subjectText = String(subject || "").trim();
    const messageText = String(message || "").trim();
    if (!subjectText || !messageText) {
      return NextResponse.json(
        { error: "Subjek dan isi koordinasi wajib diisi." },
        { status: 400 }
      );
    }

    const priorityValue = String(priority || "NORMAL").toUpperCase() === "URGENT"
      ? "URGENT"
      : "NORMAL";

    const { data, error } = await client
      .from("coordination_requests")
      .insert({
        from_id: profile.userId,
        from_name: profile.full_name,
        from_role: profile.role,
        to_role: target,
        subject: subjectText,
        message: messageText,
        priority: priorityValue,
        zone_name: zone_name || profile.work_zone || null,
        related_action_id: related_action_id || null,
      })
      .select("*")
      .maybeSingle();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 403 });
    }
    if (!data) {
      return NextResponse.json(
        { error: "Koordinasi tidak dapat dikirim." },
        { status: 403 }
      );
    }

    await notifyRoles(client, [target], {
      title:
        priorityValue === "URGENT"
          ? `Koordinasi URGENT dari ${profile.full_name}`
          : `Koordinasi dari ${profile.full_name}`,
      body: `${subjectText} — ${messageText}`,
      category: "COORDINATION",
    });

    if (priorityValue === "URGENT" && target !== "management") {
      await notifyRoles(client, ["management"], {
        title: `Koordinasi URGENT: ${subjectText}`,
        body: `${profile.full_name} (${profile.role}) mengirim koordinasi urgent ke ${target}.`,
        category: "COORDINATION",
      });
    }

    return NextResponse.json({
      message: "Koordinasi terkirim. Penerima menerima notifikasi.",
      request: data,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/**
 * PATCH /api/coordination
 *
 * Acknowledge or resolve a coordination request. Any visible participant may
 * reply; RLS enforces who can update which row.
 */
export async function PATCH(req: NextRequest) {
  try {
    const client = getUserClient(req);
    const profile = await resolveProfile(req);
    if (!profile) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await req.json();
    const { id, response, status } = body;

    if (!id) {
      return NextResponse.json({ error: "Missing coordination id" }, { status: 400 });
    }

    const nextStatus = String(status || "RESOLVED").toUpperCase();
    if (!["ACKNOWLEDGED", "RESOLVED", "OPEN"].includes(nextStatus)) {
      return NextResponse.json(
        { error: "status harus OPEN, ACKNOWLEDGED, atau RESOLVED." },
        { status: 400 }
      );
    }

    const responseText = typeof response === "string" ? response.trim() : "";
    if (nextStatus === "RESOLVED" && !responseText) {
      return NextResponse.json(
        { error: "Balasan/penyelesaian koordinasi wajib diisi." },
        { status: 400 }
      );
    }

    const { data, error } = await client
      .from("coordination_requests")
      .update({
        status: nextStatus,
        response: responseText || null,
        responded_by: profile.userId,
        responded_by_name: profile.full_name,
        responded_at: new Date().toISOString(),
      })
      .eq("id", id)
      .select("*")
      .maybeSingle();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 403 });
    }
    if (!data) {
      return NextResponse.json(
        { error: "Koordinasi tidak ditemukan atau akses ditolak." },
        { status: 404 }
      );
    }

    if (data.from_id && data.from_id !== profile.userId) {
      await notifyUser(client, data.from_id, {
        title: `Balasan koordinasi: ${data.subject}`,
        body: `${profile.full_name}: ${responseText}`,
        category: "COORDINATION",
      });
    }

    return NextResponse.json({
      message:
        nextStatus === "RESOLVED"
          ? "Koordinasi ditandai selesai."
          : "Koordinasi diperbarui.",
      request: data,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
