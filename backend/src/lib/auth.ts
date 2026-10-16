import { NextRequest, NextResponse } from "next/server";
import { getUserClient } from "@/lib/supabase";

export const dynamic = "force-dynamic";

/** Thrown-free helper so route handlers stay declarative. */
function fail(message: string, status = 400) {
  return NextResponse.json({ error: message }, { status });
}

/**
 * Resolve the signed-in user's profile.
 *
 * `profiles` is readable by any authenticated user, so this works without the
 * service-role key. Returns null for anonymous requests.
 */
export async function resolveProfile(req: NextRequest) {
  const client = getUserClient(req);
  const { data: userData, error: userErr } = await client.auth.getUser();
  if (userErr || !userData?.user) return null;

  const { data: profile } = await client
    .from("profiles")
    .select("id, employee_id, full_name, role, work_zone, phone_number, avatar_url")
    .eq("id", userData.user.id)
    .maybeSingle();

  return profile ? { userId: userData.user.id, ...profile } : null;
}

/** Guard helper for routes that must never mutate data for anonymous callers. */
export async function requireProfile(req: NextRequest) {
  const profile = await resolveProfile(req);
  if (!profile) return null;
  return profile;
}

/** Guard helper for HSE/management-only routes. */
export async function requireRole(req: NextRequest, roles: string[]) {
  const profile = await resolveProfile(req);
  if (!profile) return null;
  if (!roles.includes(profile.role)) return null;
  return profile;
}

export { fail };