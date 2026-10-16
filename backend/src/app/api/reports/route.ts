import { NextRequest, NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const reports = Array.isArray(body) ? body : [body];

    if (reports.length === 0) {
      return NextResponse.json({ message: "No reports to sync" }, { status: 200 });
    }

    const results = [];
    for (const report of reports) {
      const {
        local_id,
        reporter_id,
        reporter_name,
        report_type,
        zone_id,
        zone_name,
        category,
        incident_timestamp,
        gps_latitude,
        gps_longitude,
        description,
        photo_urls,
        is_emergency,
      } = report;

      // Upsert using local_id if available to guarantee idempotency
      const { data, error } = await supabase
        .from("hazard_reports")
        .upsert(
          {
            local_id,
            reporter_id,
            reporter_name: reporter_name || "Pekerja Tambang",
            report_type: report_type || "hazard",
            zone_id,
            zone_name: zone_name || "Pit Utama",
            category: category || "Kondisi Berbahaya",
            incident_timestamp: incident_timestamp || new Date().toISOString(),
            gps_latitude,
            gps_longitude,
            description: description || "Tanpa deskripsi rinci",
            photo_urls: photo_urls || [],
            is_emergency: is_emergency || false,
            sync_status: "synced",
          },
          { onConflict: "local_id" }
        )
        .select()
        .single();

      if (error) {
        results.push({
          local_id,
          synced: false,
          error: error.message,
        });
      } else {
        results.push({
          local_id,
          server_id: data.id,
          synced: true,
        });
      }
    }

    return NextResponse.json({
      message: `Berhasil memproses ${results.length} laporan bahaya.`,
      results,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
