import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export async function GET() {
  const startTime = Date.now();
  let dbStatus = "ok";
  let dbLatencyMs = 0;

  try {
    // Lightweight query: touches Supabase PostgREST API so project never pauses due to inactivity
    const { error } = await supabase.from("mining_zones").select("id").limit(1);
    dbLatencyMs = Date.now() - startTime;
    if (error) {
      dbStatus = `degraded: ${error.message}`;
    }
  } catch (err: any) {
    dbStatus = `error: ${err.message}`;
  }

  return NextResponse.json({
    status: "ok",
    service: "sibeni-backend",
    environment: process.env.NODE_ENV || "production",
    timestamp: new Date().toISOString(),
    uptime_seconds: Math.floor(process.uptime()),
    database: {
      provider: "supabase",
      status: dbStatus,
      latency_ms: dbLatencyMs,
    },
  });
}
