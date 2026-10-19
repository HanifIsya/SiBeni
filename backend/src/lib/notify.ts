import type { SupabaseClient } from "@supabase/supabase-js";

export type NotificationCategory =
  | "REPORT"
  | "ACTION"
  | "APPROVAL"
  | "EVALUATION"
  | "COORDINATION"
  | "INFO";

export interface NotificationPayload {
  title: string;
  body?: string;
  category?: NotificationCategory;
  related_report_id?: string | null;
  related_action_id?: string | null;
}

/**
 * Fan-out a notification to every user holding one of the given roles.
 *
 * Notifications are stored one row per recipient so "read" is personal to each
 * account. A failure here must never roll back the safety workflow that
 * triggered it — the action/report is the source of truth, the notification is
 * only a nudge.
 */
export async function notifyRoles(
  client: SupabaseClient,
  roles: string[],
  payload: NotificationPayload
): Promise<void> {
  try {
    const { data: profiles, error } = await client
      .from("profiles")
      .select("id, role")
      .in("role", roles);

    if (error || !profiles?.length) return;

    const rows = profiles.map((profile) => ({
      recipient_id: profile.id,
      recipient_role: profile.role,
      title: payload.title,
      body: payload.body ?? null,
      category: payload.category ?? "INFO",
      related_report_id: payload.related_report_id ?? null,
      related_action_id: payload.related_action_id ?? null,
    }));

    const { error: insertError } = await client.from("notifications").insert(rows);
    if (insertError) console.warn("notifyRoles failed:", insertError.message);
  } catch (err) {
    console.warn("notifyRoles failed:", err);
  }
}

/** Notify one specific account (usually the worker who filed the report). */
export async function notifyUser(
  client: SupabaseClient,
  userId: string | null | undefined,
  payload: NotificationPayload
): Promise<void> {
  if (!userId) return;

  try {
    const { data: profile } = await client
      .from("profiles")
      .select("id, role")
      .eq("id", userId)
      .maybeSingle();
    if (!profile) return;

    const { error } = await client.from("notifications").insert({
      recipient_id: profile.id,
      recipient_role: profile.role,
      title: payload.title,
      body: payload.body ?? null,
      category: payload.category ?? "INFO",
      related_report_id: payload.related_report_id ?? null,
      related_action_id: payload.related_action_id ?? null,
    });
    if (error) console.warn("notifyUser failed:", error.message);
  } catch (err) {
    console.warn("notifyUser failed:", err);
  }
}
