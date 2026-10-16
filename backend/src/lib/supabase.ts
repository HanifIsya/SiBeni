import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://qgdnrsnbxwqrouigrskb.supabase.co";
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFnZG5yc25ieHdxcm91aWdyc2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxMzU4MjUsImV4cCI6MjEwNzcxMTgyNX0.GidEFVlR4sRH4babQ7sIGRDmNrWRYCOtQ5s_rXvqOH8";
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Client for public operations
export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Admin client for backend tasks (cron jobs, system alerts)
export const supabaseAdmin = supabaseServiceKey
  ? createClient(supabaseUrl, supabaseServiceKey)
  : supabase;
