import { NextRequest, NextResponse } from "next/server";
import { getUserClient } from "@/lib/supabase";
import { resolveProfile } from "@/lib/auth";

export const dynamic = "force-dynamic";

/**
 * GET /api/notifications
 *
 * Personal inbox. Rows are written one-per-recipient by the workflow routes so
 * "read" is personal to each account, including role-wide fan-outs.
 */
export async function GET(req: NextRequest) {
  try {
    const client = getUserClient(req);
    const profile = await resolveProfile(req);
    if (!profile) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const url = new URL(req.url);
    const limit = Math.min(Number(url.searchParams.get("limit") || 60), 100);
    const unreadOnly = url.searchParams.get("unread") === "1";

    let query = client
      .from("notifications")
      .select(
        "id, title, body, category, related_report_id, related_action_id, is_read, created_at"
      )
      .eq("recipient_id", profile.userId)
      .order("created_at", { ascending: false })
      .limit(limit);

    if (unreadOnly) query = query.eq("is_read", false);

    const { data, error } = await query;
    if (error) throw error;

    const { count: unreadCount } = await client
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("recipient_id", profile.userId)
      .eq("is_read", false);

    return NextResponse.json({
      notifications: data || [],
      unread_count: unreadCount || 0,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

/**
 * PATCH /api/notifications
 *
 * Mark one notification, a list of notifications, or the whole inbox as read.
 * The recipient_id filter prevents a caller from mutating another account's
 * inbox even if they guess a notification UUID.
 */
export async function PATCH(req: NextRequest) {
  try {
    const client = getUserClient(req);
    const profile = await resolveProfile(req);
    if (!profile) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await req.json();
    const { id, ids, mark_all } = body;

    let query = client
      .from("notifications")
      .update({ is_read: true })
      .eq("recipient_id", profile.userId);

    if (mark_all) {
      query = query.eq("is_read", false);
    } else if (Array.isArray(ids) && ids.length > 0) {
      query = query.in("id", ids);
    } else if (id) {
      query = query.eq("id", id);
    } else {
      return NextResponse.json(
        { error: "Sertakan id, ids, atau mark_all=true." },
        { status: 400 }
      );
    }

    const { error } = await query;
    if (error) throw error;

    const { count: unreadCount } = await client
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("recipient_id", profile.userId)
      .eq("is_read", false);

    return NextResponse.json({
      message: "Notifikasi ditandai sudah dibaca.",
      unread_count: unreadCount || 0,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
