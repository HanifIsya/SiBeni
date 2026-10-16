import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { NextRequest } from "next/server";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://qgdnrsnbxwqrouigrskb.supabase.co";
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFnZG5yc25ieHdxcm91aWdyc2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxMzU4MjUsImV4cCI6MjEwNzcxMTgyNX0.GidEFVlR4sRH4babQ7sIGRDmNrWRYCOtQ5s_rXvqOH8";
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const ANON_OPTIONS = {
  auth: { persistSession: false, autoRefreshToken: false },
};

/** Public client. Row Level Security sees "anon" for every request. */
export const supabase = createClient(supabaseUrl, supabaseAnonKey, ANON_OPTIONS);

/**
 * Privileged client for trusted server-side jobs (cron ingest, system alerts).
 * Falls back to the anon client when no service key is configured, so the
 * service never hard-fails on a missing secret.
 */
export const supabaseAdmin = supabaseServiceKey
  ? createClient(supabaseUrl, supabaseServiceKey, ANON_OPTIONS)
  : supabase;

/**
 * A Supabase client bound to the caller's identity.
 *
 * This is the single most important function in the backend. Every write path
 * in this API goes through it so that PostgreSQL's Row Level Security policies
 * are evaluated against the *real* signed-in user rather than `anon`. That is
 * what makes the role matrix (worker / supervisor / hse / management) actually
 * enforce anything instead of silently rejecting or silently allowing writes.
 */
export function getUserClient(req: NextRequest): SupabaseClient {
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return supabase;
  return createClient(supabaseUrl, supabaseAnonKey, {
    ...ANON_OPTIONS,
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
}

/** The caller's auth user id, or null when the request is anonymous. */
export function getUserId(req: NextRequest): string | null {
  return req.headers.get("x-user-id") || null;
}