import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";

export async function GET() {
  try {
    const { data, error } = await supabase
      .from("early_warnings")
      .select("*")
      .eq("is_active", true)
      .order("created_at", { ascending: false });

    if (error) {
      // Fallback mock if database is offline or unmigrated
      return NextResponse.json({
        source: "BMKG",
        title: "PERINGATAN DINI: WASPADA HUJAN LEBAT DISERTAI ANGIN KENCANG",
        period: "07:00 - 19:00 WIB",
        severity: "high",
        affected_zones: ["Pit Utama", "Jalan Angkut KM 4", "Stockpile"],
        hazard_chips: ["Tanah Longsor", "Banjir", "Jalan Licin", "Petir"],
        safety_instructions: "Kecepatan maksimal hauler 25 km/jam. Aktifkan radio channel 3.",
      });
    }

    return NextResponse.json({ warnings: data });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
